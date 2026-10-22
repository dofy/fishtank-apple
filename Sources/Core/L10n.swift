import Foundation

/// Explicit localized text keeps interpolation arguments separate from translation keys.
/// Wire IDs and saved/user-entered strings never pass through this interface implicitly.
enum L10n {
    static let preferenceKey = "appearance.language"
    enum Preference: String, CaseIterable {
        case system
        case simplifiedChinese = "zh-Hans", traditionalChinese = "zh-Hant", english = "en", japanese = "ja"

        // Autonyms deliberately stay in their own language, regardless of UI locale.
        var nativeName: String? {
            switch self {
            case .system: return nil
            case .simplifiedChinese: return "简体中文"
            case .traditionalChinese: return "繁體中文"
            case .english: return "English"
            case .japanese: return "日本語"
            }
        }

        func language(preferredLanguages: [String]) -> Language {
            Language(rawValue: rawValue) ?? L10n.resolve(preferredLanguages)
        }
    }
    enum Language: String, CaseIterable {
        case english = "en", simplifiedChinese = "zh-Hans", traditionalChinese = "zh-Hant", japanese = "ja"
        var fontResource: String {
            switch self {
            case .english: return "DepartureMono-Regular"
            case .simplifiedChinese: return "FusionPixel"
            case .traditionalChinese: return "FusionPixel-Traditional"
            case .japanese: return "FusionPixel-Japanese"
            }
        }
    }
    struct Message: ExpressibleByStringLiteral, ExpressibleByStringInterpolation {
        let key: String
        let arguments: [String]
        init(stringLiteral value: String) { key = value; arguments = [] }
        init(stringInterpolation: StringInterpolation) {
            key = stringInterpolation.key; arguments = stringInterpolation.arguments
        }
        struct StringInterpolation: StringInterpolationProtocol {
            var key = ""
            var arguments: [String] = []
            init(literalCapacity: Int, interpolationCount: Int) { arguments.reserveCapacity(interpolationCount) }
            mutating func appendLiteral(_ value: String) { key += value }
            mutating func appendInterpolation<T>(_ value: T) {
                key += "{\(arguments.count)}"; arguments.append(String(describing: value))
            }
        }
    }
    private static let languageLock = NSLock()
    private static var activeLanguage = selectedPreference().language(preferredLanguages: Locale.preferredLanguages)
    static var language: Language {
        languageLock.lock(); defer { languageLock.unlock() }
        return activeLanguage
    }
    static func activate(_ language: Language) {
        languageLock.lock(); defer { languageLock.unlock() }
        activeLanguage = language
    }
    static func selectedPreference(defaults: UserDefaults = .standard) -> Preference {
        defaults.string(forKey: preferenceKey).flatMap(Preference.init(rawValue:)) ?? .system
    }
    static func resolve(_ preferred: [String]) -> Language {
        for value in preferred {
            let parts = value.replacingOccurrences(of: "_", with: "-").lowercased().split(separator: "-").map(String.init)
            guard let base = parts.first else { continue }
            switch base {
            case "en": return .english
            case "ja": return .japanese
            case "zh":
                if parts.contains("hant") { return .traditionalChinese }
                if parts.contains("hans") { return .simplifiedChinese }
                return parts.contains(where: { ["tw", "hk", "mo"].contains($0) }) ? .traditionalChinese : .simplifiedChinese
            default: continue
            }
        }
        return .english
    }
    static func message(_ message: Message) -> Message { message }
    static func text(_ message: Message) -> String {
        render(message.key, arguments: message.arguments, language: language)
    }
    /// Mark a catalog key for deferred rendering in immutable model metadata.
    static func source(_ key: String) -> String { key }
    /// For stable enum raw values and other source keys, never arbitrary user content.
    static func key(_ source: String) -> String { render(source, language: language) }
    static func render(_ key: String, arguments: [String] = [], language: Language) -> String {
        let template = catalogs[language]?[key] ?? catalogs[.english]?[key] ?? key
        // A single pass prevents a user value such as "{1}" from being re-interpreted.
        var result = "", remainder = template[...]
        while let start = remainder.firstIndex(of: "{"), let end = remainder[start...].firstIndex(of: "}") {
            result += remainder[..<start]
            let token = remainder[remainder.index(after: start)..<end]
            if let index = Int(token), arguments.indices.contains(index) { result += arguments[index] }
            else { result += remainder[start...end] }
            remainder = remainder[remainder.index(after: end)...]
        }
        return result + remainder
    }
    static var availableKeys: Set<String> { Set(catalogs[.english]?.keys.map { $0 } ?? []) }
    static func catalog(for language: Language) -> [String: String] { catalogs[language] ?? [:] }
    private static let catalogs: [Language: [String: String]] = {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        return Dictionary(uniqueKeysWithValues: Language.allCases.map { language in
            let url = bundle.url(forResource: language.rawValue, withExtension: "json", subdirectory: "Localizations")
                ?? bundle.url(forResource: language.rawValue, withExtension: "json")
            let entries = url.flatMap { try? Data(contentsOf: $0) }.flatMap { try? JSONDecoder().decode([String:String].self, from: $0) } ?? [:]
            return (language, entries)
        })
    }()
}
