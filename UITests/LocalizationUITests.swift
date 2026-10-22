import XCTest

final class LocalizationUITests: XCTestCase {
    func testManualLanguageChangesImmediatelyAndReturnsToSystem() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["FISHTANK_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["FISHTANK_UI_TEST_WIDTH"] = "320"
        app.launchArguments = ["-AppleLanguages", "(en)"]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 20))
        app.buttons["Settings"].tap()
        app.buttons["settings.language.ja"].tap()
        XCTAssertEqual(app.buttons["settings.language.ja"].value as? String, "選択済み")
        XCTAssertEqual(app.staticTexts["aquarium.heading"].label, "ピクセルオーシャン")
        XCTAssertTrue(app.buttons["settings.language.system"].isHittable)
        app.buttons["settings.language.system"].tap()
        XCTAssertEqual(app.staticTexts["aquarium.heading"].label, "Pixel Ocean")
        // The chosen system preference also remains in effect on a new launch.
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 20))
        XCTAssertEqual(app.staticTexts["aquarium.heading"].label, "Pixel Ocean")
        app.terminate()
    }

    func testMusicChoicesAtNarrowWidthPersistWithoutEnablingMusic() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["FISHTANK_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["FISHTANK_UI_TEST_WIDTH"] = "320"
        app.launchArguments = ["-AppleLanguages", "(en)"]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 20))
        app.buttons["Settings"].tap()
        let music = app.switches["audio.music"]
        if music.value as? String == "1" { music.tap() }
        for track in ["lofi", "tide", "chiptune", "japanese", "taiwan", "jazz"] {
            let button = app.buttons["audio.track." + track]
            if !button.isHittable { app.swipeUp() }
            XCTAssertTrue(button.isHittable, track)
            button.tap()
            XCTAssertEqual(button.value as? String, "Selected", track)
            XCTAssertEqual(music.value as? String, "0")
        }
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "six-music-styles-narrow"; screenshot.lifetime = .keepAlways; add(screenshot)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 20))
        app.buttons["Settings"].tap()
        XCTAssertEqual(app.buttons["audio.track.jazz"].value as? String, "Selected")
        XCTAssertEqual(app.switches["audio.music"].value as? String, "0")
        app.terminate()
    }

    func testFourLanguagesAndEnglishFallbackAtNarrowWidth() {
        continueAfterFailure = false
        let cases = [
            ("en", "Breed", "Settings", "Pixel Ocean", "Starter"),
            ("zh-Hans", "繁育", "设置", "像素海洋", "初始"),
            ("zh-Hant", "繁育", "設定", "像素海洋", "初始"),
            ("ja", "繁殖", "設定", "ピクセルオーシャン", "初期"),
            ("de-DE", "Breed", "Settings", "Pixel Ocean", "Starter")
        ]
        for (language, breedTitle, settingsTitle, headingTitle, starterTitle) in cases {
            let app = XCUIApplication()
            app.launchEnvironment["FISHTANK_UI_TEST_ID"] = UUID().uuidString
            app.launchEnvironment["FISHTANK_UI_TEST_WIDTH"] = "320"
            app.launchArguments = ["-AppleLanguages", "(\(language))"]
            XCUIDevice.shared.orientation = .portrait
            app.launch()
            XCTAssertTrue(app.buttons[breedTitle].waitForExistence(timeout: 20), language)
            XCTAssertEqual(app.staticTexts["aquarium.heading"].label, headingTitle, language)
            app.buttons[breedTitle].tap()
            XCTAssertTrue(app.buttons[starterTitle].isHittable, language)
            XCTAssertTrue(app.buttons[starterTitle].frame.intersection(app.buttons["1★"].frame).isEmpty,
                          "Tier buttons must not overlap: " + language)
            XCTAssertTrue(app.buttons[settingsTitle].isHittable, language)
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = "narrow-localization-" + language; attachment.lifetime = .keepAlways; add(attachment)
            app.buttons[settingsTitle].tap()
            XCTAssertTrue(app.switches["audio.music"].exists, language)
            app.terminate()
        }
    }
}
