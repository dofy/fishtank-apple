import XCTest

final class FishtankUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)"]
        app.launchEnvironment["FISHTANK_UI_TEST_ID"] = UUID().uuidString
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        XCTAssertTrue(app.buttons["繁育"].waitForExistence(timeout: 20))
    }
    private func capture(_ name: String) {
        Thread.sleep(forTimeInterval: 0.3) // Let the compositor finish the last button/rotation frame.
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testBreedingPersistsAcrossRelaunchAndAllPagesOpen() throws {
        app.buttons["繁育"].tap()
        app.buttons["推荐配对"].tap()
        let breed = app.buttons["开始繁育 · 1 爱心"]
        XCTAssertTrue(breed.isEnabled)
        XCTAssertTrue(app.staticTexts["breed.odds"].exists)
        capture("breed-selected")
        let actionFrame = breed.frame
        app.scrollViews.firstMatch.swipeUp()
        XCTAssertEqual(breed.frame.minY, actionFrame.minY, accuracy: 1)
        XCTAssertTrue(breed.isHittable)
        XCTAssertTrue(app.staticTexts["breed.odds"].isHittable)
        breed.tap()
        XCTAssertTrue(app.buttons["收下小鱼"].waitForExistence(timeout: 10))
        // The modal owns interaction; underlying page actions must not remain accessible.
        XCTAssertFalse(app.buttons["繁育"].exists && app.buttons["繁育"].isEnabled)
        capture("birth-result")
        app.buttons["收下小鱼"].tap()
        app.buttons["鱼群"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "背包 4")).firstMatch.exists)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["鱼群"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "背包 4")).firstMatch.exists)
        for page in ["合成", "装饰", "收藏", "设置"] {
            app.buttons[page].tap(); capture("page-" + page)
        }
        XCTAssertTrue(app.switches["audio.music"].exists)
        let music = app.switches["audio.music"]
        music.tap()
        XCTAssertTrue(["0", "已关闭"].contains(music.value as? String ?? ""))
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["设置"].waitForExistence(timeout: 15))
        app.buttons["设置"].tap()
        XCTAssertTrue(["0", "已关闭"].contains(app.switches["audio.music"].value as? String ?? ""))
        let exporter = app.buttons["导出 JSON"]
        for _ in 0..<4 where !exporter.isHittable { app.swipeUp() }
        XCTAssertTrue(exporter.isHittable)
        capture("backup-controls")
        // Opening the system exporter also verifies the FileDocument bridge.
        exporter.tap()
        let cancellation = app.buttons.matching(NSPredicate(format: "label IN %@", ["取消", "Cancel"])).firstMatch
        XCTAssertTrue(cancellation.waitForExistence(timeout: 10))
        capture("system-exporter")
        if app.buttons["取消"].exists { app.buttons["取消"].tap() } else { app.buttons["Cancel"].tap() }
    }
    func testImmersiveAquariumRestoresManagementAndOrientation() throws {
        let heading = app.staticTexts["aquarium.heading"]
        let before = heading.label
        XCTAssertFalse(app.staticTexts["Fishtank / 口袋海洋"].exists)
        capture("ipad-management-portrait")
        app.buttons["沉浸观赏鱼缸"].tap()
        let aquarium = app.buttons["aquarium.observation"]
        XCTAssertTrue(aquarium.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["繁育"].exists)
        XCTAssertFalse(app.buttons["返回手册"].exists)
        XCTAssertFalse(app.buttons["投喂"].exists)
        XCTAssertFalse(heading.exists)
        XCTAssertEqual(aquarium.frame.width, app.frame.width, accuracy: 2)
        XCTAssertEqual(aquarium.frame.height, app.frame.height, accuracy: 2)
        aquarium.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.12)).tap()
        let fed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "已投喂一颗鱼食"), object: aquarium)
        XCTAssertEqual(XCTWaiter.wait(for: [fed], timeout: 3), .completed)
        capture("observation-portrait-tap-feed")
        aquarium.doubleTap()
        XCTAssertTrue(app.staticTexts["退出全屏预览？"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["继续观赏"].isHittable)
        XCTAssertTrue(app.buttons["退出预览"].isHittable)
        capture("observation-exit-confirmation")
        app.buttons["继续观赏"].tap()
        XCTAssertTrue(aquarium.waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["退出全屏预览？"].exists)
        XCUIDevice.shared.orientation = .landscapeLeft
        let resized = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            abs(aquarium.frame.width - self.app.frame.width) < 2 && abs(aquarium.frame.height - self.app.frame.height) < 2
        }, object: aquarium)
        XCTAssertEqual(XCTWaiter.wait(for: [resized], timeout: 5), .completed)
        XCTAssertEqual(aquarium.frame.width, app.frame.width, accuracy: 2)
        XCTAssertEqual(aquarium.frame.height, app.frame.height, accuracy: 2)
        capture("observation-landscape-no-controls")
        aquarium.doubleTap()
        XCTAssertTrue(app.buttons["退出预览"].waitForExistence(timeout: 3))
        app.buttons["退出预览"].tap()
        XCTAssertTrue(app.buttons["繁育"].waitForExistence(timeout: 5))
        XCTAssertEqual(heading.label, before)
        XCTAssertFalse(app.staticTexts["Fishtank / 口袋海洋"].exists)
        capture("ipad-management-landscape")
        app.buttons["沉浸观赏鱼缸"].tap()
        aquarium.doubleTap()
        app.buttons["退出预览"].tap()
        XCTAssertTrue(app.buttons["鱼群"].exists)
    }

    func testSharedHeaderSortingAndDisplayedBadges() throws {
        let header = app.staticTexts["aquarium.heading"]
        let headerY = header.frame.minY
        let acquired = app.buttons["fish.sort.acquired"]
        for _ in 0..<4 where !acquired.isHittable { app.scrollViews.firstMatch.swipeUp() }
        acquired.tap()
        func names() -> [String] {
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "fish.card."))
                .allElementsBoundByIndex.map { $0.label.contains("灰鲦鱼") ? "灰鲦鱼" : "金鳍初始鱼" }
        }
        XCTAssertEqual(names().first, "灰鲦鱼")
        app.buttons["fish.sort.direction"].tap()
        XCTAssertEqual(names().first, "金鳍初始鱼")
        XCTAssertEqual(names().last, "灰鲦鱼")
        app.buttons["fish.sort.direction"].tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "收回灰鲦鱼")).firstMatch.tap()
        app.buttons["fish.sort.displayed"].tap()
        XCTAssertEqual(names().last, "灰鲦鱼")
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "fish.displayed").firstMatch.exists)
        capture("tank-sort-displayed")
        app.buttons["繁育"].tap()
        XCTAssertEqual(header.frame.minY, headerY, accuracy: 1)
        XCTAssertTrue(app.staticTexts["两条亲代，一次新的相遇。"].isHittable)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "fish.displayed").firstMatch.exists)
        app.scrollViews.firstMatch.swipeUp()
        XCTAssertEqual(header.frame.minY, headerY, accuracy: 1)
        app.buttons["设置"].tap()
        app.scrollViews.firstMatch.swipeUp()
        XCTAssertEqual(header.frame.minY, headerY, accuracy: 1)
        app.buttons["繁育"].tap()
        XCTAssertTrue(app.staticTexts["两条亲代，一次新的相遇。"].isHittable)
        app.buttons["鱼群"].tap()
        XCTAssertTrue(app.staticTexts["我的鱼群"].isHittable)
        XCTAssertEqual(header.frame.minY, headerY, accuracy: 1)
    }

    func testWholeCardActionsAndSecondaryControls() throws {
        let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "fish.card."))
        let card = cards.firstMatch
        for _ in 0..<4 where !card.isHittable { app.scrollViews.firstMatch.swipeUp() }
        let id = card.identifier
        let fish = app.buttons[id]
        XCTAssertEqual(fish.value as? String, "展示中")
        fish.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.9)).tap()
        XCTAssertEqual(fish.value as? String, "未展示")
        fish.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)).tap()
        XCTAssertEqual(fish.value as? String, "展示中")
        app.buttons["锁定金鳍初始鱼"].firstMatch.tap()
        XCTAssertEqual(fish.value as? String, "展示中", "锁定不能触发收回")
        XCTAssertTrue(app.buttons["解锁金鳍初始鱼"].firstMatch.exists)
        app.buttons["繁育"].tap()
        let parent = app.buttons[id]
        XCTAssertEqual(parent.value as? String, "未选择")
        parent.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.95)).tap()
        XCTAssertEqual(parent.value as? String, "已选择")
        capture("whole-card-breed-selected")
        parent.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)).tap()
        XCTAssertEqual(parent.value as? String, "未选择")
        capture("whole-card-breed")
        app.buttons["装饰"].tap()
        let kelp = app.buttons["decor.card.kelp"]
        for _ in 0..<4 where !kelp.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertEqual(kelp.value as? String, "展示中")
        kelp.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.9)).tap()
        XCTAssertEqual(kelp.value as? String, "未展示")
        kelp.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6)).tap()
        XCTAssertEqual(kelp.value as? String, "展示中")
        app.buttons["翻转翠绿海草"].tap()
        XCTAssertEqual(kelp.value as? String, "展示中", "翻转不能触发收回")
        XCTAssertFalse(app.buttons["放入鱼缸"].exists)
        XCTAssertFalse(app.buttons["收回装饰"].exists)
        capture("whole-card-decor")
    }

    func testMedalCardsAndReadOnlyCatalog() throws {
        app.terminate()
        app.launchEnvironment["FISHTANK_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["FISHTANK_UI_TEST_SCENARIO"] = "merge"
        app.launch()
        XCTAssertTrue(app.buttons["收藏"].waitForExistence(timeout: 15))
        app.buttons["收藏"].tap()
        let entry = app.otherElements["catalog.entry.goldfin"]
        XCTAssertTrue(entry.exists)
        XCTAssertEqual(entry.buttons.count, 0)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "catalog.entry.")).count, 0)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "fish.displayed").firstMatch.exists)
        capture("catalog-static-entries")
        func openMedals() {
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "勋章 ")).firstMatch.tap()
        }
        openMedals()
        let medal = app.buttons["medal.card.first-friend"]
        XCTAssertTrue(medal.isEnabled)
        XCTAssertEqual(medal.value as? String, "未展示")
        medal.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.92)).tap()
        XCTAssertEqual(medal.value as? String, "展示中")
        medal.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)).tap()
        XCTAssertEqual(medal.value as? String, "未展示")
        medal.tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["收藏"].waitForExistence(timeout: 15))
        app.buttons["收藏"].tap(); openMedals()
        XCTAssertEqual(medal.value as? String, "展示中")
        XCTAssertFalse(app.buttons["medal.card.tier-one"].isEnabled)
        app.buttons["全部取下"].tap()
        XCTAssertEqual(medal.value as? String, "未展示")
        app.buttons["挂上全部"].tap()
        XCTAssertEqual(medal.value as? String, "展示中")
        XCTAssertFalse(app.buttons["挂上勋章"].exists)
        capture("medals-whole-card-highlight")
    }

    func testPortraitLandscapeLayouts() throws {
        capture("portrait-tank")
        XCUIDevice.shared.orientation = .landscapeLeft
        let landscape = expectation(for: NSPredicate { _, _ in self.app.frame.width > self.app.frame.height }, evaluatedWith: app)
        wait(for: [landscape], timeout: 10)
        print("LANDSCAPE FRAME", app.frame)
        XCTAssertTrue(app.buttons["设置"].waitForExistence(timeout: 10))
        capture("landscape-tank")
        app.buttons["装饰"].tap()
        capture("landscape-decor")
        XCUIDevice.shared.orientation = .portrait
        let portrait = expectation(for: NSPredicate { _, _ in self.app.frame.height > self.app.frame.width }, evaluatedWith: app)
        wait(for: [portrait], timeout: 10)
        app.buttons["设置"].tap()
        capture("portrait-settings")
        XCTAssertTrue(app.buttons["鱼群"].isHittable)
    }
    func testCompact320PointLayout() throws {
        app.terminate()
        app.launchEnvironment["FISHTANK_UI_TEST_WIDTH"] = "320"
        app.launch()
        XCTAssertTrue(app.buttons["鱼群"].waitForExistence(timeout: 15))
        for page in ["鱼群", "繁育", "合成", "装饰", "收藏", "设置"] {
            let button = app.buttons[page]
            XCTAssertTrue(button.isHittable, page)
            button.tap()
            if page == "繁育" {
                app.buttons["推荐配对"].tap()
                let breed = app.buttons["开始繁育 · 1 爱心"]
                XCTAssertTrue(breed.isEnabled)
                let actionFrame = breed.frame
                app.scrollViews.firstMatch.swipeUp()
                XCTAssertEqual(breed.frame.minY, actionFrame.minY, accuracy: 1)
                XCTAssertTrue(breed.isHittable)
                XCTAssertTrue(app.staticTexts["breed.odds"].isHittable)
            }
            capture("compact-" + page)
        }
        let content = app.buttons["鱼群"].frame.union(app.buttons["设置"].frame)
        XCTAssertLessThanOrEqual(content.width, 320)
    }

    func testReadableCompactMergeConfirmation() throws {
        app.terminate()
        app.launchEnvironment["FISHTANK_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["FISHTANK_UI_TEST_WIDTH"] = "320"
        app.launchEnvironment["FISHTANK_UI_TEST_SCENARIO"] = "merge"
        app.launch()
        XCTAssertTrue(app.buttons["合成"].waitForExistence(timeout: 15))
        app.buttons["合成"].tap()
        let automatic = app.buttons["自动选材"]
        for _ in 0..<5 where !automatic.isHittable { app.scrollViews.firstMatch.swipeUp() }
        automatic.tap()
        app.buttons["合成新鱼 · 消耗 10 条"].tap()
        let confirm = app.buttons["消耗材料并合成"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        let cancel = app.buttons["取消"]
        XCTAssertTrue(confirm.isHittable && cancel.isHittable)
        if abs(cancel.frame.midY - confirm.frame.midY) < 2 {
            XCTAssertLessThanOrEqual(cancel.frame.maxX, confirm.frame.minX)
        } else {
            XCTAssertLessThanOrEqual(confirm.frame.maxY, cancel.frame.minY)
        }
        XCTAssertGreaterThanOrEqual(confirm.frame.width, 158)
        XCTAssertGreaterThanOrEqual(cancel.frame.width, 60)
        XCTAssertGreaterThanOrEqual(confirm.frame.height, 48)
        capture("readable-compact-merge-confirmation")
        cancel.tap()
        XCTAssertFalse(confirm.exists)
    }

    func testMergeConfirmationInheritsGradeAndPreservesLockedFish() throws {
        app.terminate()
        app.launchEnvironment["FISHTANK_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["FISHTANK_UI_TEST_SCENARIO"] = "merge"
        app.launch()
        XCTAssertTrue(app.buttons["合成"].waitForExistence(timeout: 15))
        app.buttons["合成"].tap()
        let tier = app.buttons["1★"]
        XCTAssertEqual(tier.value as? String, "已选中")
        tier.tap()
        XCTAssertEqual(tier.value as? String, "未选中")
        tier.tap()
        app.buttons["自动选材"].tap()
        app.buttons["合成新鱼 · 消耗 10 条"].tap()
        XCTAssertTrue(app.buttons["消耗材料并合成"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["合成"].exists && app.buttons["合成"].isEnabled)
        app.buttons["消耗材料并合成"].tap()
        XCTAssertTrue(app.buttons["收下小鱼"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "2★ · 品阶 4")).firstMatch.exists)
        capture("merged-fish")
        app.buttons["收下小鱼"].tap()
        app.buttons["鱼群"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "背包 5")).firstMatch.exists)
        XCTAssertTrue(app.buttons["解锁铜带蝶鱼"].exists)
    }

    func testLocalMaturityNotificationIsDeliveredAfterBackgrounding() throws {
        app.terminate()
        app.launchEnvironment["FISHTANK_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["FISHTANK_UI_TEST_SCENARIO"] = "reminder"
        app.launch()
        XCTAssertTrue(app.buttons["设置"].waitForExistence(timeout: 15))
        app.buttons["设置"].tap()
        let reminder = app.switches["成年 / 冷却 / 爱心回满提醒"]
        for _ in 0..<6 where !reminder.isHittable { app.swipeUp() }
        XCTAssertTrue(reminder.isHittable)
        if ["1", "已开启"].contains(reminder.value as? String ?? "") { reminder.tap() }
        reminder.tap()
        capture("notification-permission")
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let labels = NSPredicate(format: "label IN %@", ["Allow", "允许", "允許", "Allow Notifications", "允许通知"])
        let appAllow = app.alerts.buttons.matching(labels).firstMatch
        let systemAllow = springboard.alerts.buttons.matching(labels).firstMatch
        if appAllow.waitForExistence(timeout: 3) { appAllow.tap() }
        else if systemAllow.waitForExistence(timeout: 3) { systemAllow.tap() }
        let enabled = expectation(for: NSPredicate { _, _ in ["1", "已开启"].contains(reminder.value as? String ?? "") }, evaluatedWith: reminder)
        wait(for: [enabled], timeout: 10)
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(springboard.staticTexts["小鱼长大了"].waitForExistence(timeout: 40))
        capture("delivered-local-notification")
        app.activate()
        XCTAssertTrue(app.buttons["设置"].waitForExistence(timeout: 10))
        if ["1", "已开启"].contains(reminder.value as? String ?? "") { reminder.tap() }
    }

}
