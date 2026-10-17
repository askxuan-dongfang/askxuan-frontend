import XCTest

@MainActor final class PointsHubUITests: XCTestCase {
    func testHomeEntryThreeModesAndRepeatWins() async throws {
        var reset = URLRequest(url: URL(string: "http://127.0.0.1:8914/fixture/reset")!)
        reset.httpMethod = "POST"
        reset.setValue("application/json", forHTTPHeaderField: "Content-Type")
        reset.httpBody = Data(#"{"balance":25,"outcome":"won","prizeId":12}"#.utf8)
        let (_, response) = try await URLSession.shared.data(for: reset)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        let app = XCUIApplication()
        app.launchEnvironment["ASKXUAN_JOURNEY_API_URL"] = "http://127.0.0.1:8914/api/v1"
        app.launchArguments = ["--smoke-token", "local-points-fixture", "--smoke-user-id", "99026", "-tab", "0", "-askxuan.appearance", "light"]
        app.launch()
        let entry = app.buttons["home-points"]
        XCTAssertTrue(entry.waitForExistence(timeout: 20))
        for _ in 0..<3 where !entry.isHittable { app.swipeUp() }
        capture(app, "ios-home-points-entry")
        entry.tap()
        XCTAssertTrue(app.navigationBars["积分中心"].waitForExistence(timeout: 10))
        let modes = app.segmentedControls["points-modes"]
        for name in ["积分转盘", "积分商城", "奖池"] { XCTAssertTrue(modes.buttons[name].exists) }
        modes.buttons["积分商城"].tap()
        XCTAssertTrue(app.textFields["搜索积分商品"].waitForExistence(timeout: 10))
        modes.buttons["奖池"].tap()
        XCTAssertTrue(app.staticTexts["本期大奖池"].waitForExistence(timeout: 10))
        modes.buttons["积分转盘"].tap()
        let spin = app.buttons["10 积分转一次"]
        XCTAssertTrue(spin.waitForExistence(timeout: 10))
        capture(app, "ios-points-hub")
        spin.tap()
        let confirm = app.alerts.buttons["确认扣除 10 积分"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5)); confirm.tap()
        let again = app.buttons["再转一次 · 10 积分"]
        XCTAssertTrue(again.waitForExistence(timeout: 15)); again.tap()
        XCTAssertTrue(confirm.waitForExistence(timeout: 5)); confirm.tap()
        let close = app.buttons["关闭"].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 15)); close.tap()
        let insufficient = app.buttons["积分不足"]
        XCTAssertTrue(insufficient.waitForExistence(timeout: 10)); XCTAssertFalse(insufficient.isEnabled)
        app.buttons["抽奖记录"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["积分记录"].waitForExistence(timeout: 10))
        for code in ["LOCAL-REWARD-1", "LOCAL-REWARD-2"] { XCTAssertTrue(app.staticTexts[code].waitForExistence(timeout: 10)) }
        capture(app, "ios-repeat-spin-records")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(modes.waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}

final class H5ParityUITests: XCTestCase {
    private func app(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["ASKXUAN_JOURNEY_API_URL"] = "http://127.0.0.1:5399/api/v1"
        app.launchArguments = ["-askxuan.appearance", "light"] + arguments
        app.launch()
        return app
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name
        attachment.lifetime = .keepAlways; add(attachment)
    }
    func testDirectoryFiltersAndNativeBack() {
        let app = app()
        let temples = app.buttons["home-temples"]
        XCTAssertTrue(temples.waitForExistence(timeout: 20)); temples.tap()
        XCTAssertTrue(app.buttons["全部地区"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["大陆"].waitForExistence(timeout: 10)); app.buttons["大陆"].tap()
        XCTAssertTrue(app.buttons["清除"].waitForExistence(timeout: 5)); app.buttons["清除"].tap()
        XCTAssertTrue(app.buttons["宗派与信俗筛选"].waitForExistence(timeout: 10))
        app.buttons["宗派与信俗筛选"].tap()
        XCTAssertTrue(app.buttons["全部宗派 / 信俗"].waitForExistence(timeout: 5)); app.buttons["全部宗派 / 信俗"].tap()
        capture(app, "ios-temple-directory-parity")
        app.buttons["返回"].firstMatch.tap()
        XCTAssertTrue(app.buttons["home-masters"].waitForExistence(timeout: 5)); app.buttons["home-masters"].tap()
        XCTAssertTrue(app.buttons["全部地区"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["大陆"].waitForExistence(timeout: 10)); app.buttons["大陆"].tap()
        XCTAssertTrue(app.buttons["清除"].waitForExistence(timeout: 5)); app.buttons["清除"].tap()
        capture(app, "ios-master-directory-parity")
    }
    func testCreatorWalletPresentationAndInvalidAmount() {
        let app = app(["--smoke-token", "local-parity-fixture", "--smoke-user-id", "10001", "--parity-creator-wallet"])
        XCTAssertTrue(app.buttons["申请提现"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["¥1234.56"].exists)
        capture(app, "ios-creator-wallet")
        app.buttons["申请提现"].tap()
        XCTAssertTrue(app.textFields["金额（元）"].waitForExistence(timeout: 5))
        app.textFields["金额（元）"].tap(); app.textFields["金额（元）"].typeText("1.001")
        app.buttons["确认申请"].tap()
        XCTAssertTrue(app.staticTexts["请输入有效金额，且不低于最低提现额、不超过可提现余额"].waitForExistence(timeout: 5))
        capture(app, "ios-withdrawal-validation")
        app.buttons["取消"].tap()
    }
    func testPublicServiceCatalogEntry() {
        let app = app()
        let entry = app.buttons["home-services"]
        XCTAssertTrue(app.buttons["home-temples"].waitForExistence(timeout: 20))
        for _ in 0..<3 where !entry.isHittable { app.swipeUp() }
        XCTAssertTrue(entry.isHittable); entry.tap()
        XCTAssertTrue(app.navigationBars["预约服务"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["祈福"].waitForExistence(timeout: 10))
        capture(app, "ios-public-services")
    }
}

final class ProfileExperienceUITests: XCTestCase {

    func testAvatarEntryAndPhotoPicker() {
        let app = XCUIApplication()
        app.launchEnvironment["ASKXUAN_JOURNEY_API_URL"] = "http://127.0.0.1:5437/api/v1"
        app.launchArguments = ["--smoke-token", "local-fixture", "--smoke-user-id", "9001", "-tab", "4", "-askxuan.appearance", "dark"]
        app.launch()
        XCTAssertTrue(app.buttons["更换头像"].waitForExistence(timeout: 20)); app.buttons["更换头像"].tap()
        XCTAssertFalse(app.buttons["从相册选择照片"].exists)
        XCTAssertFalse(app.textFields["头像 URL"].exists)
        XCTAssertTrue(app.buttons["取消"].waitForExistence(timeout: 10) || app.buttons["Cancel"].waitForExistence(timeout: 3))
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "customer-avatar-photo-picker"; shot.lifetime = .keepAlways; add(shot)
        let cancel = app.buttons["取消"].exists ? app.buttons["取消"] : app.buttons["Cancel"]
        cancel.tap()
        XCTAssertTrue(app.buttons["更换头像"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["编辑资料"].exists)
    }
}

final class DiyStudioUITests: XCTestCase {
    private func requestClear(_ app: XCUIApplication) {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "手围 ")).firstMatch.tap()
        let clear = app.buttons["清空设计"]
        XCTAssertTrue(clear.waitForExistence(timeout: 5)); clear.tap()
        XCTAssertTrue(app.buttons["清空搭配"].waitForExistence(timeout: 5))
    }

    private func clearDraft(_ app: XCUIApplication) {
        requestClear(app)
        app.buttons["清空搭配"].tap()
        let firstBead = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "第 1 颗 ")).firstMatch
        XCTAssertTrue(firstBead.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["清空搭配"].waitForNonExistence(timeout: 5))
    }

    func testClearDialogCancelAndSearchFocus() {
        let app = XCUIApplication()
        app.launchEnvironment["ASKXUAN_JOURNEY_API_URL"] = "http://127.0.0.1:8913/api/v1"
        app.launchArguments = ["--smoke-token", "local-diy-fixture", "--smoke-user-id", "99024", "--parity-diy-studio", "-askxuan.appearance", "light"]
        app.launch()
        XCTAssertTrue(app.otherElements["diy-3d-stage"].waitForExistence(timeout: 25))
        if app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "第 1 颗 ")).firstMatch.exists { clearDraft(app) }
        let wood = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "小叶紫檀圆珠，")).firstMatch
        XCTAssertTrue(wood.waitForExistence(timeout: 10)); wood.tap()
        requestClear(app)
        if app.buttons["取消"].exists {
            app.buttons["取消"].tap()
        } else {
            // Compact confirmation popovers dismiss by tapping outside them.
            app.staticTexts["东方珠作"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        XCTAssertTrue(app.buttons["清空搭配"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["第 1 颗 小叶紫檀圆珠"].exists)
        clearDraft(app)
        let search = app.textFields["搜索材质或规格"]
        search.tap(); search.typeText("白玉\n")
        let jade = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "白玉，")).firstMatch
        XCTAssertTrue(jade.waitForExistence(timeout: 5)); jade.tap()
        XCTAssertTrue(app.buttons["第 1 颗 白玉"].waitForExistence(timeout: 5))
    }

    func testOriginalGalleryAndEditorNavigation() {
        let app = XCUIApplication()
        app.launchEnvironment["ASKXUAN_JOURNEY_API_URL"] = "http://127.0.0.1:8913/api/v1"
        app.launchArguments = ["--smoke-token", "local-diy-fixture", "--smoke-user-id", "99025", "-tab", "3", "-askxuan.appearance", "light"]
        app.launch()
        let entry = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "DIY 定制")).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 20)); entry.tap()
        let start = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "开始我的设计")).firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["灵感即将相遇"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["重新加载"].exists)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "ios-original-gallery"; shot.lifetime = .keepAlways; add(shot)
        start.tap()
        XCTAssertTrue(app.otherElements["diy-3d-stage"].waitForExistence(timeout: 10))
        app.buttons["返回"].firstMatch.tap()
        XCTAssertTrue(start.waitForExistence(timeout: 5))
    }

    func testMaterialShowcaseAndFitDialog() {
        let app = XCUIApplication()
        app.launchEnvironment["ASKXUAN_JOURNEY_API_URL"] = "http://127.0.0.1:8913/api/v1"
        app.launchArguments = ["--smoke-token", "local-diy-fixture", "--smoke-user-id", "99023", "--parity-diy-studio", "-askxuan.appearance", "light"]
        app.launch()
        XCTAssertTrue(app.otherElements["diy-3d-stage"].waitForExistence(timeout: 25))
        if app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "第 1 颗 ")).firstMatch.exists {
            clearDraft(app)
        }
        for name in ["小叶紫檀圆珠", "星月菩提", "白玉", "青金石", "蜜蜡", "紫水晶", "虎眼石", "绿松石工艺珠"] {
            if app.buttons["清除搜索"].exists { app.buttons["清除搜索"].tap() }
            let field = app.textFields["搜索材质或规格"]
            field.tap(); field.typeText(name + "\n")
            let material = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name + "，")).firstMatch
            XCTAssertTrue(material.waitForExistence(timeout: 5)); material.tap()
        }
        app.buttons["清除搜索"].tap()
        XCTAssertTrue(app.buttons["第 8 颗 绿松石工艺珠"].exists)
        let materials = XCTAttachment(screenshot: app.screenshot()); materials.name = "ios-material-showcase"; materials.lifetime = .keepAlways; add(materials)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "手围 ")).firstMatch.tap()
        XCTAssertTrue(app.buttons["清空设计"].waitForExistence(timeout: 5))
        let fit = XCTAttachment(screenshot: app.screenshot()); fit.name = "ios-fit-settings"; fit.lifetime = .keepAlways; add(fit)
    }
    func testSingleSceneEditingAndHistory() {
        let app = XCUIApplication()
        app.launchEnvironment["ASKXUAN_JOURNEY_API_URL"] = "http://127.0.0.1:8913/api/v1"
        app.launchArguments = ["--smoke-token", "local-diy-fixture", "--smoke-user-id", "99022", "--parity-diy-studio", "-askxuan.appearance", "light"]
        app.launch()
        let stage = app.otherElements["diy-3d-stage"]
        XCTAssertTrue(stage.waitForExistence(timeout: 25))
        if app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "第 1 颗 ")).firstMatch.exists {
            clearDraft(app)
        }
        XCTAssertFalse(app.buttons["2D"].exists)
        XCTAssertFalse(app.buttons["3D"].exists)
        let wood = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "小叶紫檀圆珠，")).firstMatch
        XCTAssertTrue(wood.waitForExistence(timeout: 20)); wood.tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "星月菩提，")).firstMatch.tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "凤眼菩提，")).firstMatch.tap()
        XCTAssertTrue(app.buttons["第 3 颗 凤眼菩提"].waitForExistence(timeout: 5))
        app.buttons["向前移动珠子"].tap()
        XCTAssertTrue(app.buttons["第 2 颗 凤眼菩提"].exists)
        app.buttons["撤销"].tap()
        XCTAssertTrue(app.buttons["第 3 颗 凤眼菩提"].exists)
        app.buttons["重做"].tap()
        XCTAssertTrue(app.buttons["第 2 颗 凤眼菩提"].exists)
        app.buttons["第 1 颗 小叶紫檀圆珠"].tap()
        app.buttons["复制"].tap()
        XCTAssertTrue(app.buttons["第 2 颗 小叶紫檀圆珠"].exists)
        app.buttons["删除"].tap()
        XCTAssertTrue(app.buttons["第 2 颗 凤眼菩提"].exists)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "ios-single-3d-studio"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["重置 3D 视角"].tap()
        stage.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.28)).press(forDuration: 0.15, thenDragTo: stage.coordinate(withNormalizedOffset: CGVector(dx: 0.68, dy: 0.65)))
        XCTAssertTrue(app.buttons["第 2 颗 小叶紫檀圆珠"].waitForExistence(timeout: 5))
        app.buttons["撤销"].tap()
        XCTAssertTrue(app.buttons["第 1 颗 小叶紫檀圆珠"].exists)
    }
}
