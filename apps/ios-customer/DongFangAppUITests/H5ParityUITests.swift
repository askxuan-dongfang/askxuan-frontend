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
        app.launchEnvironment["ASKXUAN_JOURNEY_API_URL"] = ProcessInfo.processInfo.environment["ASKXUAN_DIRECTORY_TEST_API_URL"] ?? "http://127.0.0.1:5399/api/v1"
        app.launchArguments = ["-askxuan.appearance", "light"] + arguments
        app.launch()
        return app
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name
        attachment.lifetime = .keepAlways; add(attachment)
    }
    func testDirectoryFiltersAndNativeBack() {
        let app = XCUIApplication()
        app.launchEnvironment["ASKXUAN_JOURNEY_API_URL"] = "http://127.0.0.1:8913/api/v1"
        app.launchArguments = ["-askxuan.appearance", "light"]
        app.launch()
        for (entry, title, searchLabel, match) in [
            ("home-temples", "找寺院", "搜索寺院列表", "末页台湾祈福禅院"),
            ("home-masters", "找师傅", "搜索师傅列表", "末页台湾祈福平台师傅")
        ] {
            let home = app.buttons[entry]
            XCTAssertTrue(home.waitForExistence(timeout: 20)); home.tap()
            let trigger = app.buttons["directory-region-trigger"]
            XCTAssertTrue(trigger.waitForExistence(timeout: 15))
            let rowY = trigger.frame.midY
            let beliefY = app.buttons["directory-belief-han_buddhism"].frame.midY
            XCTAssertEqual(rowY, beliefY, accuracy: 2)
            trigger.tap()
            let taiwan = app.buttons["directory-region-taiwan"]
            XCTAssertTrue(taiwan.waitForExistence(timeout: 5))
            XCTAssertEqual(trigger.frame.midY, rowY, accuracy: 1)
            app.buttons["directory-belief-han_buddhism"].tap()
            let chan = app.buttons["directory-tradition-chan"]
            XCTAssertTrue(chan.waitForExistence(timeout: 5))
            XCTAssertFalse(taiwan.exists, "Only one floating filter can be open")
            XCTAssertEqual(trigger.frame.midY, rowY, accuracy: 1)
            chan.tap()
            XCTAssertTrue(chan.waitForNonExistence(timeout: 5))
            trigger.tap()
            XCTAssertTrue(taiwan.waitForExistence(timeout: 5)); taiwan.tap()
            XCTAssertTrue(taiwan.waitForNonExistence(timeout: 5))
            app.buttons["搜索"].tap()
            let search = app.textFields[searchLabel]
            XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("臺灣 祈福\n")
            XCTAssertTrue(app.staticTexts[match].waitForExistence(timeout: 10), "Directory search includes complete pages and translated service/region labels")
            capture(app, "ios-" + entry + "-region-search")
            app.buttons["返回"].firstMatch.tap()
            XCTAssertTrue(home.waitForExistence(timeout: 5))
        }
    }
    func testShopSearchAndCartShareOneRow() {
        let app = app(["--smoke-token", "local-parity-fixture", "--smoke-user-id", "99027", "-tab", "3"])
        let search = app.textFields["shop-search"], cart = app.buttons["shop-cart"]
        XCTAssertTrue(search.waitForExistence(timeout: 20))
        XCTAssertTrue(cart.exists)
        XCTAssertEqual(search.frame.midY, cart.frame.midY, accuracy: 2)
        XCTAssertGreaterThan(cart.frame.minX, search.frame.maxX)
        XCTAssertFalse(app.staticTexts.matching(identifier: "商城").allElementsBoundByIndex.contains { $0.frame.minY < cart.frame.maxY })
        search.tap(); search.typeText("线香\n")
        XCTAssertTrue(app.staticTexts["本地验收线香"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["本地验收手串"].exists)
        capture(app, "ios-shop-search-cart-row")
        cart.tap()
        XCTAssertTrue(app.navigationBars["购物车"].waitForExistence(timeout: 5))
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

    func testGrowthValueInAlignedAccountStats() {
        let app = XCUIApplication()
        app.launchEnvironment["ASKXUAN_JOURNEY_API_URL"] = ProcessInfo.processInfo.environment["ASKXUAN_DIRECTORY_TEST_API_URL"] ?? "http://127.0.0.1:5399/api/v1"
        app.launchArguments = ["--smoke-token", "local-parity-fixture", "--smoke-user-id", "99027", "-tab", "4", "-askxuan.appearance", "light"]
        app.launch()
        let growth = app.buttons["profile-growth"], points = app.buttons["profile-points"], coupons = app.buttons["profile-coupons"]
        XCTAssertTrue(growth.waitForExistence(timeout: 20))
        XCTAssertTrue(points.exists); XCTAssertTrue(coupons.exists)
        XCTAssertEqual(growth.frame.minY, points.frame.minY, accuracy: 1)
        XCTAssertEqual(growth.frame.height, points.frame.height, accuracy: 1)
        XCTAssertEqual(growth.frame.width, points.frame.width, accuracy: 1)
        XCTAssertEqual(points.frame.minY, coupons.frame.minY, accuracy: 1)
        XCTAssertLessThan(growth.frame.maxX, points.frame.minX)
        XCTAssertFalse(app.staticTexts["我的成长"].exists)
        let loaded = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", "320"), object: growth)
        wait(for: [loaded], timeout: 15)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "ios-profile-growth-stats"; shot.lifetime = .keepAlways; add(shot)
        growth.tap()
        XCTAssertTrue(app.navigationBars["我的成长"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["320 成长值"].waitForExistence(timeout: 10))
    }

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

final class NativePublicSearchUITests: XCTestCase {
    func testEqualHomeCardsAndCompletePublicSearch() {
        let app = XCUIApplication()
        app.launchEnvironment["ASKXUAN_JOURNEY_API_URL"] = "http://127.0.0.1:8913/api/v1"
        app.launchArguments = ["-askxuan.appearance", "light"]
        app.launch()
        let temples = app.buttons["home-temples"], masters = app.buttons["home-masters"]
        let diy = app.buttons["home-diy"], points = app.buttons["home-points"]
        XCTAssertTrue(temples.waitForExistence(timeout: 20))
        for card in [masters, diy, points] { XCTAssertTrue(card.exists); XCTAssertEqual(card.frame.size.width, temples.frame.width, accuracy: 1); XCTAssertEqual(card.frame.size.height, temples.frame.height, accuracy: 1) }
        XCTAssertEqual(temples.frame.minY, masters.frame.minY, accuracy: 1)
        XCTAssertEqual(diy.frame.minY, points.frame.minY, accuracy: 1)
        XCTAssertGreaterThan(diy.frame.minY, temples.frame.maxY)
        XCTAssertTrue((96...104).contains(temples.frame.height))
        capture(app, "ios-home-equal-four-cards")
        app.buttons["home-global-search"].tap()
        let input = app.textFields["global-search-input"]
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["搜索全站功能与公开内容"].exists)
        input.tap(); input.typeText("臺灣 祈福\n")
        XCTAssertTrue(app.buttons["global-result-temples-3"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["global-result-masters-3"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["global-result-temples-1"].exists)
        capture(app, "ios-global-search-traditional-second-page")
        let retry = app.buttons["global-retry-posts"]
        for _ in 0..<5 where !retry.isHittable { app.swipeUp() }
        XCTAssertTrue(retry.exists, "A failed category must expose retry instead of a zero-result count")
        retry.tap()
        XCTAssertTrue(retry.waitForNonExistence(timeout: 10))
        app.buttons["清除搜索"].tap()
        input.tap(); input.typeText("蓮花\n")
        let product = app.buttons["global-result-products-9902703"]
        for _ in 0..<4 where !product.isHittable { app.swipeUp() }
        XCTAssertTrue(product.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["末页繁体莲花手串"].exists)
        capture(app, "ios-global-search-product-second-page")
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name
        attachment.lifetime = .keepAlways; add(attachment)
    }
}

final class DiyStudioUITests: XCTestCase {
    func testOpenCanvasFitUsedMaterialsAndExpandedPreview() {
        let app = studioApp(user: "99026")
        let stage = app.otherElements["diy-3d-stage"]
        let wood = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "小叶紫檀圆珠，")).firstMatch
        XCTAssertTrue(wood.waitForExistence(timeout: 20))
        if app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "第 1 颗 ")).firstMatch.exists { clearDraft(app) }
        XCTAssertTrue(app.descendants(matching: .any)["diy-fit-feedback"].exists)
        XCTAssertGreaterThan(stage.frame.height, 270, "The actual SCNView should occupy the larger upper canvas")
        XCTAssertFalse(app.buttons["编辑选中珠子"].exists)
        wood.tap()
        XCTAssertTrue(app.buttons["第 1 颗 小叶紫檀圆珠"].waitForExistence(timeout: 5))
        app.buttons["正在使用"].tap()
        XCTAssertTrue(wood.exists)
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "白玉，")).firstMatch.exists)
        let originalHeight = stage.frame.height
        app.buttons["diy-expand-preview"].tap()
        XCTAssertFalse(app.textFields["搜索材质或规格"].exists)
        XCTAssertGreaterThan(stage.frame.height, originalHeight)
        let expanded = XCTAttachment(screenshot: app.screenshot()); expanded.name = "ios-direct-canvas-expanded"; expanded.lifetime = .keepAlways; add(expanded)
        app.buttons["diy-expand-preview"].tap()
        XCTAssertTrue(app.textFields["搜索材质或规格"].waitForExistence(timeout: 5))
        clearDraft(app)
    }
    private func studioApp(user: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["ASKXUAN_JOURNEY_API_URL"] = "http://127.0.0.1:8913/api/v1"
        app.launchArguments = ["--smoke-token", "local-diy-fixture", "--smoke-user-id", user, "--parity-diy-studio", "-askxuan.appearance", "light"]
        app.launch()
        XCTAssertTrue(app.otherElements["diy-3d-stage"].waitForExistence(timeout: 25))
        return app
    }

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
        XCTAssertLessThan(app.descendants(matching: .any)["diy-home-intro"].frame.height, 180)
        XCTAssertFalse(app.buttons["重新加载"].exists)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "ios-original-gallery"; shot.lifetime = .keepAlways; add(shot)
        start.tap()
        XCTAssertTrue(app.otherElements["diy-3d-stage"].waitForExistence(timeout: 10))
        app.buttons["返回"].firstMatch.tap()
        XCTAssertTrue(start.waitForExistence(timeout: 5))
    }

    func testGalleryOwnWorkIsReadonlyAndCopyCreatesEditor() {
        let app = XCUIApplication()
        app.launchEnvironment["ASKXUAN_JOURNEY_API_URL"] = "http://127.0.0.1:8913/api/v1"
        app.launchArguments = ["--smoke-token", "local-diy-fixture", "--smoke-user-id", "99029", "-tab", "3", "-askxuan.appearance", "light"]
        app.launch()
        let entry = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "DIY 定制")).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 20)); entry.tap()
        let card = app.descendants(matching: .any)["diy-gallery-design-9001"]
        XCTAssertTrue(card.waitForExistence(timeout: 10)); card.tap()
        XCTAssertTrue(app.buttons["复制并编辑"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["作者：我"].exists)
        XCTAssertFalse(app.buttons["继续编辑"].exists)
        XCTAssertFalse(app.buttons["管理公开作品"].exists)
        XCTAssertFalse(app.buttons["立即下单"].exists)
        let detail = XCTAttachment(screenshot: app.screenshot()); detail.name = "ios-gallery-readonly-own-design"; detail.lifetime = .keepAlways; add(detail)
        app.buttons["复制并编辑"].tap()
        XCTAssertTrue(app.otherElements["diy-3d-stage"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["第 1 颗 小叶紫檀圆珠"].exists)
        app.buttons["返回"].firstMatch.tap()
        XCTAssertTrue(app.buttons["复制并编辑"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["作者：我"].exists)
    }

    func testMyDesignsOpenEditorAndManagePublication() {
        let app = XCUIApplication()
        app.launchEnvironment["ASKXUAN_JOURNEY_API_URL"] = "http://127.0.0.1:8913/api/v1"
        app.launchArguments = ["--smoke-token", "local-diy-fixture", "--smoke-user-id", "99029", "-tab", "3", "-askxuan.appearance", "light"]
        app.launch()
        let entry = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "DIY 定制")).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 20)); entry.tap()
        XCTAssertTrue(app.buttons["我的设计"].firstMatch.waitForExistence(timeout: 10))
        app.buttons["我的设计"].firstMatch.tap()
        let ownCard = app.buttons["diy-my-design-9001"]
        XCTAssertTrue(ownCard.waitForExistence(timeout: 20))
        let edit = app.buttons["diy-edit-design-9001"]
        XCTAssertTrue(edit.exists)
        XCTAssertTrue(app.staticTexts["已发布"].exists)
        XCTAssertTrue(ownCard.exists); ownCard.tap()
        XCTAssertTrue(app.otherElements["diy-3d-stage"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["复制并编辑"].exists)
        app.buttons["保存设计"].tap()
        XCTAssertTrue(app.staticTexts["保存修改后将转为未发布，可在我的设计中重新发布。"].waitForExistence(timeout: 5))
        app.buttons["取消"].tap()
        app.buttons["返回"].firstMatch.tap()
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        app.buttons["diy-publish-design-9001"].tap()
        app.buttons["确认下架"].tap()
        let unpublished = NSPredicate(format: "label == %@", "发布到广场")
        expectation(for: unpublished, evaluatedWith: app.buttons["diy-publish-design-9001"])
        waitForExpectations(timeout: 5)
        app.buttons["diy-publish-design-9001"].tap()
        app.buttons["确认发布"].tap()
        let published = NSPredicate(format: "label == %@", "下架")
        expectation(for: published, evaluatedWith: app.buttons["diy-publish-design-9001"])
        waitForExpectations(timeout: 5)
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
    func testDirectBeadDragReordersThenDragOutDeletesAndUndoRestores() {
        let app = studioApp(user: "99022")
        let stage = app.otherElements["diy-3d-stage"]
        let wood = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "小叶紫檀圆珠，")).firstMatch
        XCTAssertTrue(wood.waitForExistence(timeout: 20))
        if app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "第 1 颗 ")).firstMatch.exists { clearDraft(app) }
        wood.tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "星月菩提，")).firstMatch.tap()
        let search = app.textFields["搜索材质或规格"]
        search.tap(); search.typeText("凤眼菩提\n")
        let phoenix = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "凤眼菩提，")).firstMatch
        XCTAssertTrue(phoenix.waitForExistence(timeout: 5)); phoenix.tap()
        app.buttons["清除搜索"].tap()
        let first = app.buttons["第 1 颗 小叶紫檀圆珠"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["编辑选中珠子"].exists)
        app.buttons["重置 3D 视角"].tap()
        // Accessibility frames are the projected real bodies. Prove the real
        // center hits the bead before using that physical point for a drag.
        let from = first.coordinate(withNormalizedOffset: CGVector(dx: 0.5,dy: 0.5))
        from.tap(); XCTAssertTrue(first.isSelected)
        let target = app.buttons["第 2 颗 星月菩提"].coordinate(withNormalizedOffset: CGVector(dx: 0.5,dy: 0.5))
        from.press(forDuration: 0.1, thenDragTo: target)
        XCTAssertTrue(app.buttons["第 2 颗 小叶紫檀圆珠"].waitForExistence(timeout: 5))
        app.buttons["撤销"].tap()
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        let originalID = first.identifier
        let outside = stage.coordinate(withNormalizedOffset: CGVector(dx: 0.97,dy: 0.04))
        first.coordinate(withNormalizedOffset: CGVector(dx: 0.5,dy: 0.5)).press(forDuration: 0.1, thenDragTo: outside)
        XCTAssertTrue(first.waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "第 3 颗 ")).firstMatch.exists)
        app.buttons["撤销"].tap()
        XCTAssertTrue(first.waitForExistence(timeout: 5)); XCTAssertEqual(first.identifier, originalID)
        app.buttons["重做"].tap(); XCTAssertTrue(first.waitForNonExistence(timeout: 5))
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "ios-direct-drag-delete"; shot.lifetime = .keepAlways; add(shot)
        clearDraft(app)
    }
}
