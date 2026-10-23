import XCTest
@testable import FishtankCore

final class LocalizationTests: XCTestCase {
    func testLiveLanguageUpdatesAlreadyLoadedCatalogEntriesWithoutChangingIDs() {
        let original = L10n.language
        defer { L10n.activate(original) }
        let fish = FishCatalog.byID["goldfin"]!
        let decoration = DecorCatalog.byID["kelp"]!
        let icon = AppIconCatalog.original
        let achievement = AchievementCatalog.all[0]
        let message = L10n.message("Added \(3)")
        for language in L10n.Language.allCases {
            L10n.activate(language)
            XCTAssertEqual(fish.name, L10n.render("Goldfin Starter", language: language))
            XCTAssertEqual(decoration.name, L10n.render("Emerald Seagrass", language: language))
            XCTAssertEqual(icon.name, L10n.render("Classic Goldfin", language: language))
            XCTAssertEqual(achievement.title, L10n.render("First Encounter", language: language))
            XCTAssertEqual(AgentMenuIndicator.Presentation.idle.detail,
                           L10n.render("Waiting for Agent events", language: language))
            XCTAssertEqual(fish.id, "goldfin")
            XCTAssertEqual(icon.id, "classic")
            XCTAssertEqual(L10n.Preference.allCases.compactMap(\.nativeName),
                           ["简体中文", "繁體中文", "English", "日本語"])
            XCTAssertEqual(L10n.text(message), L10n.render("Added {0}", arguments: ["3"], language: language))
        }
    }
    func testLanguagePreferenceDefaultsToSystemAndManualChoiceOverridesSystem() {
        let name = "fishtank-language-test-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        XCTAssertEqual(L10n.selectedPreference(defaults: defaults), .system)
        XCTAssertEqual(L10n.Preference.system.language(preferredLanguages: ["ja"]), .japanese)
        XCTAssertEqual(L10n.Preference.system.language(preferredLanguages: ["de"]), .english)
        for preference in L10n.Preference.allCases where preference != .system {
            defaults.set(preference.rawValue, forKey: L10n.preferenceKey)
            let restored = L10n.selectedPreference(defaults: UserDefaults(suiteName: name)!)
            XCTAssertEqual(restored, preference)
            XCTAssertEqual(restored.language(preferredLanguages: ["de", "zh-Hant"]),
                           L10n.Language(rawValue: preference.rawValue))
        }
        defaults.set("unsupported-value", forKey: L10n.preferenceKey)
        XCTAssertEqual(L10n.selectedPreference(defaults: defaults), .system)
        XCTAssertEqual(L10n.selectedPreference(defaults: defaults).language(preferredLanguages: ["zh-Hant"]), .traditionalChinese)
        defaults.set("system", forKey: L10n.preferenceKey)
        XCTAssertEqual(L10n.selectedPreference(defaults: defaults).language(preferredLanguages: ["en"]), .english)
    }
    func testLanguageNegotiationHonorsScriptRegionOrderAndEnglishFallback() {
        let cases: [([String], L10n.Language)] = [
            (["zh-Hans-CN"], .simplifiedChinese), (["zh_Hans_TW"], .simplifiedChinese),
            (["zh-Hant-CN"], .traditionalChinese), (["zh-TW"], .traditionalChinese),
            (["zh-HK"], .traditionalChinese), (["zh-MO"], .traditionalChinese),
            (["zh-CN"], .simplifiedChinese), (["zh-SG"], .simplifiedChinese),
            (["ja-JP"], .japanese), (["en-GB"], .english),
            (["de-DE", "ja"], .japanese), (["en", "zh-Hans"], .english),
            (["fr", "de"], .english), ([], .english)
        ]
        for (preferred, expected) in cases { XCTAssertEqual(L10n.resolve(preferred), expected, "\(preferred)") }
    }
    func testEveryLanguageContainsAllTemplatesAndPreservesInterpolationAndFormatSpecifiers() throws {
        let english = L10n.catalog(for: .english)
        XCTAssertGreaterThanOrEqual(english.count, 538)
        let tokens = try NSRegularExpression(pattern: #"\{\d+\}|%[0-9]*[a-zA-Z]"#)
        func placeholders(_ text: String) -> [String] {
            tokens.matches(in:text,range:NSRange(text.startIndex...,in:text))
                .map { (text as NSString).substring(with:$0.range) }.sorted()
        }
        for language in L10n.Language.allCases {
            let catalog = L10n.catalog(for: language)
            XCTAssertEqual(Set(catalog.keys), Set(english.keys), language.rawValue)
            for (key, value) in catalog {
                XCTAssertFalse(value.isEmpty, "\(language.rawValue): \(key)")
                XCTAssertEqual(placeholders(value), placeholders(key), "\(language.rawValue): \(key)")
            }
        }
    }
    func testEnglishKeysCarryTheSourceTextAndUnsupportedSystemsUseEnglish() {
        for (key, value) in L10n.catalog(for: .english) {
            XCTAssertNil(key.range(of:"[\\u4e00-\\u9fff]",options:.regularExpression),key)
            XCTAssertEqual(value, key.replacingOccurrences(of:" \\[[^\\]]*\\]$",with:"",options:.regularExpression))
        }
        XCTAssertEqual(L10n.render("Cooldown [badge]",language:.english), "Cooldown")
        XCTAssertEqual(L10n.render("Settings",language:L10n.resolve(["fr-FR"])), "Settings")
        XCTAssertEqual(L10n.render("a.key.that.is.not.present",language:.japanese), "a.key.that.is.not.present")
    }
    func testInterpolatedValuesAreInsertedOnceAndNeverBecomeTranslationKeys() {
        let literal: L10n.Message = "Added \("{1} 我的助手")"
        XCTAssertEqual(literal.key, "Added {0}")
        XCTAssertEqual(literal.arguments, ["{1} 我的助手"])
        let english = L10n.render(literal.key,arguments:literal.arguments,language:.english)
        XCTAssertTrue(english.contains("{1} 我的助手"))
        XCTAssertFalse(english.contains("{0}"))
        let sample = "{\"hook_event_name\":\"Stop\",\"session_id\":\"your-session-id\",\"cwd\":\"/project-path\"}"
        let rendered = L10n.render(sample,language:.english)
        XCTAssertTrue(rendered.contains("your-session-id"))
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with:Data(rendered.utf8)))
    }
    func testNamesAndMessagesAreLocalizedWithoutChangingGameOrWireIdentifiers() {
        for species in FishCatalog.all {
            XCTAssertTrue(species.id.allSatisfy { $0.isASCII })
            XCTAssertFalse(species.name.isEmpty)
        }
        for status in ClaudeHookEvent.Status.allCases { XCTAssertFalse(status.title.isEmpty) }
        XCTAssertEqual(ClaudeHookEvent.Source.codex.rawValue, "codex")
        XCTAssertEqual(ClaudeHookEvent.Source.claudeCode.rawValue, "claude-code")
        XCTAssertEqual(AppIconCatalog.design("classic").resourceName, "FishtankIcon")
    }
}
