import XCTest

@MainActor final class TempleOperationsUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    private var env: [String: String] { ProcessInfo.processInfo.environment }
    private func required(_ key: String) throws -> String { try XCTUnwrap(env[key], "Requires isolated temple runtime: " + key) }
    private func launch() throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["ASKXUAN_JOURNEY_API_URL"] = "http://127.0.0.1:63400/api/v1"
        app.launchEnvironment["ASKXUAN_JOURNEY_BOOKING"] = try required("TEMPLE_OPS_BOOKING")
        app.launchArguments = ["--smoke-token", try required("TEMPLE_OPS_CUSTOMER_TOKEN"), "--smoke-user-id", "891022", "-askxuan.language", "zh-Hans", "-askxuan.appearance", "light"]
        app.launch()
        XCTAssertTrue(app.navigationBars["我的服务记录"].waitForExistence(timeout: 20))
        return app
    }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<16 {
            // Xcode can fail hit testing when a lazy list row is clipped at the screen edge.
            if element.exists && !element.frame.isEmpty && app.frame.contains(element.frame) && element.isHittable { return }
            app.swipeUp()
        }
        XCTFail("Element did not become fully visible after scrolling")
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    private func progress() async throws -> [String: Any] {
        let url = try XCTUnwrap(URL(string: "http://127.0.0.1:63400/api/v1/bookings/" + (try required("TEMPLE_OPS_BOOKING")) + "/fulfillment"))
        var request = URLRequest(url: url)
        request.setValue("Bearer " + (try required("TEMPLE_OPS_CUSTOMER_TOKEN")), forHTTPHeaderField: "Authorization")
        request.setValue("customer", forHTTPHeaderField: "X-Client-Type")
        let (data, response) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        let envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(envelope["code"] as? Int, 0)
        return try XCTUnwrap(envelope["data"] as? [String: Any])
    }
    func testReceiptHistoryFromRealCrossPlatformBooking() throws {
        let app = try launch()
        XCTAssertTrue(app.staticTexts["已评价"].firstMatch.waitForExistence(timeout: 20))
        let receipt = app.staticTexts["已补充完整说明，提交第二版测试回执。"]
        reveal(receipt, in: app)
        XCTAssertTrue(app.staticTexts["回执 2"].exists)
        capture(app, "customer-cross-platform-receipt-history")
    }
    func testRequestReceiptRevisionFromNativeUI() async throws {
        let app = try launch()
        let media = app.buttons["查看图片 · 现场记录.png"]
        reveal(media, in: app); media.tap()
        XCTAssertTrue(app.images["现场记录.png"].waitForExistence(timeout: 15))
        capture(app, "customer-native-receipt-image")
        let accept = app.buttons["journey.accept"]; reveal(accept, in: app)
        XCTAssertFalse(accept.isEnabled)
        let expand = app.buttons["需要补充回执"]; reveal(expand, in: app); expand.tap()
        let reason = app.descendants(matching: .any).matching(identifier: "请描述需要补充的内容（至少 5 字）").firstMatch
        reveal(reason, in: app); reason.tap(); reason.typeText("请补充原生验收的现场说明")
        let submit = app.buttons["要求补充回执"]; reveal(submit, in: app); submit.tap()
        let gone = NSPredicate(format: "exists == false")
        let removed = expectation(for: gone, evaluatedWith: submit)
        await fulfillment(of: [removed], timeout: 15)
        let result = try await progress()
        XCTAssertEqual(result["status"] as? String, "in_progress")
        capture(app, "customer-native-request-revision")
    }
    func testAcceptReceiptFromNativeUI() async throws {
        let app = try launch()
        let accept = app.buttons["journey.accept"]; reveal(accept, in: app)
        XCTAssertFalse(accept.isEnabled)
        let reviewed = app.switches["journey.reviewed"]; reveal(reviewed, in: app); reviewed.tap()
        XCTAssertTrue(accept.isEnabled); accept.tap()
        XCTAssertTrue(app.staticTexts["这份心意，已有记录"].waitForExistence(timeout: 15))
        capture(app, "customer-native-receipt-accepted")
        app.buttons["留存这份记录"].tap()
        let result = try await progress()
        XCTAssertEqual(result["status"] as? String, "completed")
        XCTAssertEqual((result["receipts"] as? [[String: Any]])?.count, 2)
    }
    func testContractAmountsFromRealServices() throws {
        let app = try launch()
        app.buttons["订单详情"].tap()
        XCTAssertTrue(app.navigationBars["预约详情"].waitForExistence(timeout: 15))
        reveal(app.staticTexts["预约合同总额"], in: app)
        for (label, amount) in [("预约合同总额", "¥120.75"), ("法师执行费", "¥20.25"), ("寺院服务费与随喜", "¥100.50")] {
            XCTAssertTrue(app.cells.containing(.staticText, identifier: label).staticTexts[amount].exists)
        }
        capture(app, "customer-native-contract-amounts")
    }
}

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
        let entry = app.buttons["home-points-wheel"]
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
        app.launchArguments = ["--smoke-token", "local-parity-fixture", "--smoke-user-id", "99027", "-tab", "4", "-askxuan.language", "zh-Hans", "-askxuan.appearance", "light"]
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

final class NativeDiscoveryRefinementUITests: XCTestCase {
    private func launch(_ arguments: [String] = [], appearance: String = "light") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["ASKXUAN_JOURNEY_API_URL"] = "http://127.0.0.1:8913/api/v1"
        app.launchArguments = ["-askxuan.language", "zh-Hans", "-askxuan.appearance", appearance, "-tab", "0"] + arguments
        app.launch()
        return app
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testMasterServiceAndPriceGroupsStaySingleLineAndComposeWithSearch() {
        let app = launch()
        let entry = app.buttons["home-masters"]
        XCTAssertTrue(entry.waitForExistence(timeout: 20)); entry.tap()
        let price = app.buttons["master-filter-group-价格区间"]
        XCTAssertTrue(price.waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["master-filter-group-擅长领域"].exists)
        XCTAssertFalse(app.buttons["master-filter-group-可提供服务"].exists)
        XCTAssertFalse(app.buttons["master-filter-group-职位"].exists)
        XCTAssertFalse(app.buttons["master-filter-group-所属寺院"].exists)
        XCTAssertFalse(app.staticTexts["独立师傅 · 含演示资料"].exists)
        let service = app.buttons["master-filter-option-提供服务-S001"]
        XCTAssertTrue(service.waitForExistence(timeout: 10), "Platform services are expanded by default")
        for title in ["提供服务", "价格区间"] {
            let group = app.buttons["master-filter-group-" + title]
            let before = group.frame
            XCTAssertEqual(before.height, 52, accuracy: 1)
            group.tap()
            XCTAssertEqual(group.frame.height, before.height, accuracy: 1)
            XCTAssertEqual(group.frame.width, before.width, accuracy: 1)
            XCTAssertEqual(group.frame.minY, before.minY, accuracy: 1)
            group.tap()
        }
        service.tap()
        XCTAssertTrue(service.isSelected)
        capture(app, "ios-master-service-price-groups")
        app.buttons["搜索"].tap()
        let input = app.textFields["搜索师傅列表"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap(); input.typeText("禪修 祈福\n")
        XCTAssertTrue(app.staticTexts["末页台湾祈福平台师傅"].waitForExistence(timeout: 10))
        price.tap()
        app.buttons["master-filter-option-价格区间-200元以下"].tap()
        let clear = app.buttons["清除筛选"]
        XCTAssertTrue(clear.waitForExistence(timeout: 5)); clear.tap()
        XCTAssertTrue(app.buttons["master-filter-option-提供服务-all"].isSelected)
        XCTAssertTrue(app.staticTexts["末页台湾祈福平台师傅"].waitForExistence(timeout: 10))
        capture(app, "ios-master-specialty-service-text-search")
    }

    func testCompactIdentityOrnamentOnGalleryAndMyDesigns() {
        let app = launch(["--smoke-token", "local-diy-fixture", "--smoke-user-id", "99029", "-tab", "3"])
        let entry = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "DIY 定制")).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 20)); entry.tap()
        let gallery = app.descendants(matching: .any)["diy-home-intro"]
        XCTAssertTrue(gallery.waitForExistence(timeout: 10))
        XCTAssertLessThan(gallery.frame.height, 180)
        let ornament = app.images["diy-identity-ornament"]
        XCTAssertTrue(ornament.exists)
        XCTAssertEqual(ornament.frame.height, 112, accuracy: 1)
        XCTAssertEqual(ornament.label, "一珠，一心意")
        capture(app, "ios-gallery-compact-green-gold-identity")
        app.buttons["我的设计"].firstMatch.tap()
        let mine = app.descendants(matching: .any)["diy-my-designs-intro"]
        XCTAssertTrue(mine.waitForExistence(timeout: 10))
        XCTAssertLessThan(mine.frame.height, 180)
        XCTAssertTrue(ornament.exists)
        XCTAssertEqual(ornament.frame.height, 112, accuracy: 1)
        XCTAssertTrue(app.buttons["diy-my-design-9001"].exists)
        capture(app, "ios-my-designs-compact-green-gold-identity")
    }

    func testHomeContentCardsKeepFourWishesAndThreePointsAcrossTextSizes() {
        for textSize in ["UICTContentSizeCategoryL", "UICTContentSizeCategoryAccessibilityXXXL"] {
            let usesAccessibilityText = textSize == "UICTContentSizeCategoryAccessibilityXXXL"
            let app = launch(["-UIPreferredContentSizeCategoryName", textSize])
            let wishes = ["peace", "wealth", "love", "career"].map { app.buttons["home-intention-" + $0] }
            XCTAssertTrue(wishes[0].waitForExistence(timeout: 20))
            reveal(wishes[0], in: app)
            let wishScroll = app.scrollViews["home-intention-entries"]
            XCTAssertTrue(wishScroll.exists)
            if usesAccessibilityText {
                XCTAssertGreaterThanOrEqual(wishes[0].frame.width, 116)
                XCTAssertGreaterThan(wishes[0].frame.height, 88, "辅助大字号允许心愿卡随完整文字增高")
            } else {
                for wish in wishes {
                    XCTAssertTrue(wish.isHittable, "常规字号首屏完整显示四张心愿卡")
                    XCTAssertGreaterThanOrEqual(wish.frame.minX, wishScroll.frame.minX)
                    XCTAssertLessThanOrEqual(wish.frame.maxX, wishScroll.frame.maxX + 1)
                    XCTAssertEqual(wish.frame.height, 88, accuracy: 1)
                    XCTAssertEqual(wish.frame.width, wishes[0].frame.width, accuracy: 1)
                }
                for index in 1..<wishes.count {
                    XCTAssertEqual(wishes[index].frame.minX - wishes[index - 1].frame.maxX, 12, accuracy: 1)
                }
                XCTAssertGreaterThan(app.buttons["home-intention-study"].frame.maxX, wishScroll.frame.maxX)
            }

            let diy = app.buttons["home-diy"]
            reveal(diy, in: app)
            if usesAccessibilityText {
                XCTAssertGreaterThan(diy.frame.height, 88, "辅助大字号下设计入口保留完整说明")
            } else {
                XCTAssertEqual(diy.frame.height, 88, accuracy: 1)
            }

            let points = ["wheel", "mall", "pool"].map { app.buttons["home-points-" + $0] }
            XCTAssertTrue(points[0].waitForExistence(timeout: 10))
            reveal(points[0], in: app)
            for point in points {
                XCTAssertTrue(point.isHittable)
                XCTAssertGreaterThanOrEqual(point.frame.minX, 0)
                XCTAssertLessThanOrEqual(point.frame.maxX, app.frame.width)
                XCTAssertEqual(point.frame.minY, points[0].frame.minY, accuracy: 1)
                XCTAssertEqual(point.frame.width, points[0].frame.width, accuracy: 1)
                XCTAssertEqual(point.frame.height, points[0].frame.height, accuracy: 1)
                if usesAccessibilityText {
                    XCTAssertGreaterThan(point.frame.height, 88, "积分卡在辅助字号下共同增高")
                } else {
                    XCTAssertEqual(point.frame.height, 88, accuracy: 1)
                }
            }
            for index in 1..<points.count {
                XCTAssertEqual(points[index].frame.minX - points[index - 1].frame.maxX, 12, accuracy: 1)
            }
            capture(app, "ios-home-card-height-" + textSize)
            app.terminate()
        }
    }

    func testHomeRefinedTypeAndOpenSectionsAcrossAppearanceAndLargeText() {
        for (appearance, textSize) in [
            ("light", "UICTContentSizeCategoryL"),
            ("dark", "UICTContentSizeCategoryL"),
            ("dark", "UICTContentSizeCategoryAccessibilityXXXL")
        ] {
            let app = launch(["-UIPreferredContentSizeCategoryName", textSize], appearance: appearance)
            let cards = ["home-temples", "home-masters"].map { app.buttons[$0] }
            XCTAssertTrue(cards[0].waitForExistence(timeout: 20))
            let frames = cards.map(\.frame)
            for frame in frames {
                XCTAssertEqual(frame.width, frames[0].width, accuracy: 1)
                XCTAssertEqual(frame.height, frames[0].height, accuracy: 1)
                XCTAssertGreaterThanOrEqual(frame.height, 140)
                XCTAssertGreaterThanOrEqual(frame.minX, 0)
                XCTAssertLessThanOrEqual(frame.maxX, app.frame.width)
            }
            XCTAssertEqual(frames[0].minY, frames[1].minY, accuracy: 1)
            XCTAssertLessThan(frames[0].maxX, frames[1].minX, "寺庙在左，师傅在右")
            XCTAssertFalse(app.staticTexts["信仰类别"].exists)
            XCTAssertFalse(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-belief-")).firstMatch.exists)
            capture(app, "ios-home-refined-" + appearance + "-" + textSize)
            let firstWish = app.buttons["home-intention-peace"]
            XCTAssertTrue(firstWish.waitForExistence(timeout: 10))
            reveal(firstWish, in: app)
            let wishes = app.scrollViews["home-intention-entries"]
            XCTAssertTrue(wishes.exists)
            let lastWish = app.buttons["home-intention-rite"]
            for _ in 0..<6 where !lastWish.isHittable { wishes.swipeLeft() }
            XCTAssertTrue(lastWish.isHittable, "可横向滑动到第七项做法事")
            XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-intention-")).count, 7)
            XCTAssertFalse(app.buttons["home-intention-diy"].exists)
            let diy = app.buttons["home-diy"]
            reveal(diy, in: app)
            XCTAssertGreaterThan(diy.frame.minY, lastWish.frame.maxY)
            capture(app, "ios-home-open-sections-" + appearance + "-" + textSize)
            app.terminate()
        }
    }

    func testHomePlazaTailAndPointsLinksOpenTheirOwnDestinations() {
        // Synthetic localhost catalogue only; this does not publish designs or spend points.
        let app = launch(["--smoke-token", "local-diy-fixture", "--smoke-user-id", "99029"])
        let firstDesign = app.buttons["home-diy-design-9001"]
        XCTAssertTrue(firstDesign.waitForExistence(timeout: 20))
        reveal(firstDesign, in: app)
        let designs = app.scrollViews["home-diy-designs"]
        XCTAssertTrue(designs.exists)
        let plaza = app.buttons["home-diy-plaza"]
        XCTAssertEqual(app.buttons.matching(identifier: "home-diy-plaza").count, 1)
        for _ in 0..<6 where !plaza.isHittable { designs.swipeLeft() }
        XCTAssertTrue(plaza.isHittable, "设计推荐末尾可进入完整广场")
        XCTAssertGreaterThan(plaza.frame.minX, firstDesign.frame.maxX)
        plaza.tap()
        XCTAssertTrue(app.staticTexts["设计广场"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["diy-gallery-design-9001"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["diy-home-intro"].exists, "广场入口直接展示作品")
        app.buttons["返回"].firstMatch.tap()
        XCTAssertTrue(app.buttons["home-diy"].waitForExistence(timeout: 5), "从设计广场返回首页")

        for (identifier, title, selectedMode) in [
            ("home-points-wheel", "商城", "积分转盘"),
            ("home-points-mall", "转盘", "积分商城"),
            ("home-points-pool", "乐购", "奖池")
        ] {
            let entry = app.buttons[identifier]
            XCTAssertTrue(entry.waitForExistence(timeout: 10))
            reveal(entry, in: app)
            XCTAssertTrue(entry.label.contains(title))
            entry.tap()
            let modes = app.segmentedControls["points-modes"]
            XCTAssertTrue(modes.waitForExistence(timeout: 10))
            XCTAssertTrue(modes.buttons[selectedMode].isSelected, "\(title) 应直接打开\(selectedMode)")
            capture(app, "ios-home-" + identifier + "-destination")
            app.navigationBars.buttons.firstMatch.tap()
            XCTAssertTrue(app.buttons["home-diy"].waitForExistence(timeout: 5), "从积分中心返回首页")
        }
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }
}

@MainActor
final class NativePublicationGateUITests: XCTestCase {
    private func fixture(_ path: String, method: String = "GET") async throws -> [String: Any] {
        var request = URLRequest(url: try XCTUnwrap(URL(string: "http://127.0.0.1:8913/_test/" + path)))
        request.httpMethod = method
        let (data, response) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        let envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try XCTUnwrap(envelope["data"] as? [String: Any])
    }

    private func launchGallery() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["ASKXUAN_JOURNEY_API_URL"] = "http://127.0.0.1:8913/api/v1"
        app.launchArguments = ["--smoke-token", "local-diy-fixture", "--smoke-user-id", "99029", "-tab", "3", "-askxuan.appearance", "light"]
        app.launch()
        let entry = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "DIY 定制")).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 20)); entry.tap()
        XCTAssertTrue(app.buttons["我的设计"].firstMatch.waitForExistence(timeout: 10))
        return app
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<5 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testUnpaidAndUnconfirmedBlockedWhileFinalizedOrderCanPublish() async throws {
        _ = try await fixture("reset", method: "POST")
        let app = launchGallery()
        app.buttons["我的设计"].firstMatch.tap()
        let unpaid = app.buttons["diy-publish-design-9002"]
        XCTAssertTrue(unpaid.waitForExistence(timeout: 15))
        reveal(unpaid, in: app); XCTAssertFalse(unpaid.isEnabled)
        XCTAssertEqual(app.staticTexts["diy-publication-reason-9002"].label, "订单完成真实付款后才可发布，模拟支付不满足发布条件")
        let unconfirmed = app.buttons["diy-publish-design-9003"]
        reveal(unconfirmed, in: app); XCTAssertFalse(unconfirmed.isEnabled)
        XCTAssertEqual(app.staticTexts["diy-publication-reason-9003"].label, "订单已付款，待确认款式、用料和价格后可发布")
        capture(app, "ios-publication-unpaid-unconfirmed-blocked")
        let ready = app.buttons["diy-publish-design-9004"]
        reveal(ready, in: app); XCTAssertTrue(ready.isEnabled); ready.tap()
        XCTAssertTrue(app.buttons["确认发布"].waitForExistence(timeout: 5)); app.buttons["确认发布"].tap()
        XCTAssertTrue(app.buttons["diy-unpublish-design-9004"].waitForExistence(timeout: 10))
        capture(app, "ios-publication-confirmed-order-published")
        let state = try await fixture("state")
        let designs = try XCTUnwrap(state["designs"] as? [String: [String: Any]])
        XCTAssertEqual(designs["9002"]?["status"] as? String, "private")
        XCTAssertEqual(designs["9003"]?["status"] as? String, "private")
        XCTAssertEqual(designs["9004"]?["status"] as? String, "public")
        XCTAssertNotNil(designs["9004"]?["publication"])
        let mutations = try XCTUnwrap(state["requests"] as? [[String: Any]]).filter { $0["method"] as? String == "PUT" }
        XCTAssertEqual(mutations.count, 1)
        XCTAssertEqual(mutations.first?["path"] as? String, "/api/v1/diy/designs/9004/status")
    }

    func testSavedPrivateDraftLeavesPublicSnapshotAndCopyAttributionUnchanged() async throws {
        _ = try await fixture("reset", method: "POST")
        var app = launchGallery()
        app.buttons["我的设计"].firstMatch.tap()
        let ownCard = app.buttons["diy-my-design-9001"]
        XCTAssertTrue(ownCard.waitForExistence(timeout: 15)); ownCard.tap()
        XCTAssertTrue(app.otherElements["diy-3d-stage"].waitForExistence(timeout: 10))
        let wood = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "小叶紫檀圆珠，")).firstMatch
        XCTAssertTrue(wood.waitForExistence(timeout: 5)); wood.tap()
        XCTAssertTrue(app.buttons["第 2 颗 小叶紫檀圆珠"].waitForExistence(timeout: 5))
        app.buttons["保存设计"].tap()
        XCTAssertTrue(app.staticTexts["修改将保存为私有草稿，广场中的已发布定稿保持不变。新款需付款并确认后再发布。"].waitForExistence(timeout: 5))
        app.alerts.buttons["保存"].tap()
        XCTAssertTrue(app.staticTexts["草稿已修改"].waitForExistence(timeout: 15))
        let publish = app.buttons["diy-publish-design-9001"]
        XCTAssertTrue(publish.exists); XCTAssertFalse(publish.isEnabled)
        XCTAssertTrue(app.buttons["diy-unpublish-design-9001"].exists)
        capture(app, "ios-publication-private-draft-preserves-public-work")
        app.terminate()

        app = launchGallery()
        let card = app.descendants(matching: .any)["diy-gallery-design-9001"]
        XCTAssertTrue(card.waitForExistence(timeout: 10)); card.tap()
        XCTAssertTrue(app.buttons["复制并编辑"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["1 颗"].exists)
        XCTAssertFalse(app.staticTexts["2 颗"].exists)
        capture(app, "ios-publication-owner-views-confirmed-snapshot")
        app.buttons["复制并编辑"].tap()
        XCTAssertTrue(app.otherElements["diy-3d-stage"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["第 1 颗 小叶紫檀圆珠"].exists)
        XCTAssertFalse(app.buttons["第 2 颗 小叶紫檀圆珠"].exists)
        let state = try await fixture("state")
        let designs = try XCTUnwrap(state["designs"] as? [String: [String: Any]])
        let source = try XCTUnwrap(designs["9001"])
        XCTAssertEqual(source["status"] as? String, "public")
        XCTAssertEqual(source["draftChanged"] as? Bool, true)
        let copy = try XCTUnwrap(designs.values.first { $0["sourceDesignId"] as? Int == 9001 })
        XCTAssertEqual(copy["sourcePublicationId"] as? Int, 16101)
        XCTAssertEqual(copy["status"] as? String, "private")
        XCTAssertEqual((copy["publicationEligibility"] as? [String: Any])?["canPublish"] as? Bool, false)
        let requests = try XCTUnwrap(state["requests"] as? [[String: Any]])
        XCTAssertTrue(requests.contains { ($0["path"] as? String) == "/api/v1/diy/designs/9001?view=published" })
        capture(app, "ios-publication-copy-retains-confirmed-snapshot")
    }
}

final class NativeGrowthNavigationUITests: XCTestCase {
    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["ASKXUAN_JOURNEY_API_URL"] = "http://127.0.0.1:8913/api/v1"
        app.launchArguments = ["-askxuan.appearance", "light"] + arguments
        app.launch()
        return app
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<12 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testFourMainTabsAndRulesInsideBenefitsKeepHistoricalVersions() {
        let app = launch(["--smoke-token", "local-diy-fixture", "--smoke-user-id", "99029", "-tab", "4"])
        XCTAssertTrue(app.buttons["profile-growth"].waitForExistence(timeout: 20))
        app.buttons["profile-growth"].tap()
        let tabs = app.segmentedControls["growth-primary-tabs"]
        XCTAssertTrue(tabs.waitForExistence(timeout: 15))
        XCTAssertEqual(tabs.buttons.count, 4)
        XCTAssertFalse(app.buttons["成长规则与历史版本"].exists)
        tabs.buttons["权益"].tap()
        let rules = app.buttons["growth-rules-disclosure"]
        reveal(rules, in: app)
        XCTAssertFalse(app.buttons["growth-rule-acquisition"].exists)
        rules.tap()
        let acquisition = app.buttons["growth-rule-acquisition"]
        XCTAssertTrue(acquisition.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["growth-rule-upgrade"].exists)
        XCTAssertTrue(app.buttons["growth-rule-discounts"].exists)
        acquisition.tap()
        XCTAssertTrue(app.staticTexts["周期任务月上限 300"].waitForExistence(timeout: 5))
        acquisition.tap()
        let history = app.buttons["growth-rule-history"]
        reveal(history, in: app); history.tap()
        let old = app.buttons["growth-rule-version-local-history-v1"]
        XCTAssertTrue(old.waitForExistence(timeout: 5))
        capture(app, "ios-growth-rules-in-benefits-with-history")
        let next = app.buttons["下一页"]
        reveal(next, in: app); XCTAssertTrue(next.isEnabled); next.tap()
        XCTAssertTrue(app.buttons["growth-rule-version-local-history-v0"].waitForExistence(timeout: 10))
        capture(app, "ios-growth-rule-history-pagination")
    }

    func testGuestCurrentRulesLinkOpensExpandedBenefitsRules() {
        let signedIn = launch(["--smoke-token", "local-diy-fixture", "--smoke-user-id", "99029", "-tab", "4"])
        XCTAssertTrue(signedIn.buttons["profile-growth"].waitForExistence(timeout: 20))
        let logout = signedIn.buttons["退出登录"]
        reveal(logout, in: signedIn)
        logout.tap()
        XCTAssertTrue(signedIn.buttons["立即登录 / 注册"].waitForExistence(timeout: 10))
        signedIn.terminate()
        let app = launch(["-tab", "3"])
        let product = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "本地验收手串")).firstMatch
        XCTAssertTrue(product.waitForExistence(timeout: 20)); product.tap()
        let rulesLink = app.buttons["查看当前规则"]
        reveal(rulesLink, in: app); rulesLink.tap()
        XCTAssertTrue(app.navigationBars["等级权益"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["growth-rule-acquisition"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["growth-rule-upgrade"].exists)
        XCTAssertTrue(app.buttons["growth-rule-discounts"].exists)
        XCTAssertFalse(app.navigationBars["成长规则与历史版本"].exists)
        capture(app, "ios-growth-public-rules-link-opens-benefits")
    }
}

final class NativePublicSearchUITests: XCTestCase {
    func testHomeDirectoryEntriesAndCompletePublicSearch() {
        let app = XCUIApplication()
        app.launchEnvironment["ASKXUAN_JOURNEY_API_URL"] = "http://127.0.0.1:8913/api/v1"
        app.launchArguments = ["-askxuan.language", "zh-Hans", "-askxuan.appearance", "light", "-tab", "0"]
        app.launch()
        let temples = app.buttons["home-temples"], masters = app.buttons["home-masters"]
        XCTAssertTrue(temples.waitForExistence(timeout: 20))
        XCTAssertTrue(masters.exists)
        XCTAssertEqual(masters.frame.width, temples.frame.width, accuracy: 1)
        XCTAssertEqual(masters.frame.height, temples.frame.height, accuracy: 1)
        XCTAssertEqual(temples.frame.minY, masters.frame.minY, accuracy: 1)
        XCTAssertLessThan(temples.frame.maxX, masters.frame.minX)
        capture(app, "ios-home-two-directory-entries")
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
    func testGeneratedModelLoadsAndRotates() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["ASKXUAN_JOURNEY_API_URL"] = "http://127.0.0.1:8927/api/v1"
        app.launchArguments = ["--smoke-token", "local-diy-fixture", "--smoke-user-id", "99032", "--parity-diy-studio", "-askxuan.appearance", "light", "-askxuan.language", "zh-Hans"]
        app.launch()
        let stage = app.otherElements["diy-3d-stage"]
        XCTAssertTrue(stage.waitForExistence(timeout: 25))
        if app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "第 1 颗 ")).firstMatch.exists { clearDraft(app) }
        app.buttons["普通串珠"].tap()
        let fixed = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "固定孔位珠，")).firstMatch
        XCTAssertTrue(fixed.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "建模验证挂件，")).firstMatch.exists)
        for _ in 0..<3 { fixed.tap() }
        app.buttons["动态挂件"].tap()
        let material = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "建模验证挂件，")).firstMatch
        XCTAssertTrue(material.waitForExistence(timeout: 5)); material.tap()
        let ornament = app.buttons["第 4 颗 建模验证挂件"]
        // Accessibility bounds are built from the downloaded real mesh, never a placeholder.
        XCTAssertTrue(ornament.waitForExistence(timeout: 30))
        XCTAssertGreaterThan(ornament.frame.width, 5)
        let bodyFrame = ornament.frame
        XCTAssertTrue(bodyFrame.minX.isFinite && bodyFrame.minY.isFinite && bodyFrame.maxX.isFinite && bodyFrame.maxY.isFinite)
        let loaded = XCTAttachment(screenshot: app.screenshot()); loaded.name = "ios-generated-usdz-loaded"; loaded.lifetime = .keepAlways; add(loaded)
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: bodyFrame.midX, dy: bodyFrame.midY)).tap()
        XCTAssertTrue(ornament.isSelected)
        let before = ornament.frame
        let fit = app.descendants(matching: .any)["diy-fit-feedback"].label
        stage.coordinate(withNormalizedOffset: CGVector(dx: 0.10, dy: 0.1)).press(forDuration: 0.1,
            thenDragTo: stage.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.20)))
        XCTAssertNotEqual(ornament.frame, before)
        XCTAssertEqual(app.descendants(matching: .any)["diy-fit-feedback"].label, fit)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "ios-generated-usdz-real-body"; shot.lifetime = .keepAlways; add(shot)
        clearDraft(app)
    }

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
        app.launchArguments = ["--smoke-token", "local-diy-fixture", "--smoke-user-id", user, "--parity-diy-studio", "-askxuan.appearance", "light", "-askxuan.language", "zh-Hans"]
        app.launch()
        XCTAssertTrue(app.otherElements["diy-3d-stage"].waitForExistence(timeout: 25))
        return app
    }

    private func searchMaterial(_ name: String, in app: XCUIApplication) {
        let field = app.textFields["搜索材质或规格"]
        field.tap()
        let introduction = app.otherElements["UIContinuousPathIntroductionView"]
        if introduction.exists {
            let button = introduction.buttons["Continue"]
            XCTAssertTrue(button.waitForExistence(timeout: 5)); button.tap()
            XCTAssertTrue(introduction.waitForNonExistence(timeout: 5))
        }
        field.typeText(name + "\n")
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
        XCTAssertTrue(app.staticTexts["修改将保存为私有草稿，广场中的已发布定稿保持不变。新款需付款并确认后再发布。"].waitForExistence(timeout: 5))
        app.buttons["取消"].tap()
        app.buttons["返回"].firstMatch.tap()
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        app.buttons["diy-unpublish-design-9001"].tap()
        app.buttons["确认下架"].tap()
        let unpublished = NSPredicate(format: "label == %@", "发布到广场")
        expectation(for: unpublished, evaluatedWith: app.buttons["diy-publish-design-9001"])
        waitForExpectations(timeout: 5)
        app.buttons["diy-publish-design-9001"].tap()
        app.buttons["确认发布"].tap()
        XCTAssertTrue(app.buttons["diy-unpublish-design-9001"].waitForExistence(timeout: 5))
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
    func testGravityKnotFreeRotationAndDragOutUndo() {
        executionTimeAllowance = 180
        let app = studioApp(user: "99031")
        let stage = app.otherElements["diy-3d-stage"]
        let wood = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "小叶紫檀圆珠，")).firstMatch
        XCTAssertTrue(wood.waitForExistence(timeout: 20))
        if app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "第 1 颗 ")).firstMatch.exists { clearDraft(app) }
        wood.tap(); wood.tap(); wood.tap()
        searchMaterial("中国结流苏", in: app)
        let material = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "中国结流苏，")).firstMatch
        XCTAssertTrue(material.waitForExistence(timeout: 5)); material.tap()
        let knot = app.buttons["第 4 颗 中国结流苏"]
        XCTAssertTrue(knot.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["diy-presentation-mode"].exists)
        let fit = app.descendants(matching: .any)["diy-fit-feedback"].label
        // A real hit on the long body must select the accessory, with no torus.
        knot.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65)).tap()
        XCTAssertTrue(knot.isSelected)
        let selected = XCTAttachment(screenshot: app.screenshot()); selected.name = "ios-hanging-knot-selected"; selected.lifetime = .keepAlways; add(selected)
        let before = knot.frame
        stage.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.10)).press(forDuration: 0.1,
            thenDragTo: stage.coordinate(withNormalizedOffset: CGVector(dx: 0.62, dy: 0.18)))
        XCTAssertNotEqual(knot.frame, before)
        XCTAssertEqual(app.descendants(matching: .any)["diy-fit-feedback"].label, fit)
        app.buttons["重置 3D 视角"].tap()
        let oldID = knot.identifier
        let outside = stage.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.04))
        knot.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65)).press(forDuration: 0.1, thenDragTo: outside)
        XCTAssertTrue(knot.waitForNonExistence(timeout: 5))
        app.buttons["撤销"].tap()
        XCTAssertTrue(knot.waitForExistence(timeout: 5)); XCTAssertEqual(knot.identifier, oldID)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "ios-hanging-knot-restored"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["保存设计"].tap()
        XCTAssertTrue(app.textFields["设计名称"].waitForExistence(timeout: 5))
        app.buttons["取消"].tap()
        clearDraft(app)
    }

    func testDirectBeadDragReordersThenDragOutDeletesAndUndoRestores() {
        let app = studioApp(user: "99022")
        let stage = app.otherElements["diy-3d-stage"]
        let wood = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "小叶紫檀圆珠，")).firstMatch
        XCTAssertTrue(wood.waitForExistence(timeout: 20))
        if app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "第 1 颗 ")).firstMatch.exists { clearDraft(app) }
        wood.tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "星月菩提，")).firstMatch.tap()
        searchMaterial("凤眼菩提", in: app)
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

@MainActor final class AiReportWalletUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    private func fixture(_ path: String, body: [String: Any]? = nil) async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: "http://127.0.0.1:8926/fixture/" + path)!)
        if let body { request.httpMethod = "POST"; request.httpBody = try JSONSerialization.data(withJSONObject: body); request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        let (data, response) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        return try XCTUnwrap((JSONSerialization.jsonObject(with: data) as? [String: Any])?["data"] as? [String: Any])
    }
    private func launchReport() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["ASKXUAN_JOURNEY_API_URL"] = "http://127.0.0.1:8926/api/v1"
        app.launchArguments = ["--smoke-token", "local-ai-wallet-fixture", "--smoke-user-id", "99026", "-tab", "2", "-askxuan.language", "zh-Hans", "-askxuan.appearance", "light"]
        app.launch()
        let library = app.segmentedControls.buttons["我的报告"]
        XCTAssertTrue(library.waitForExistence(timeout: 20)); library.tap()
        let report = app.staticTexts["本地钱包报告"].firstMatch
        XCTAssertTrue(report.waitForExistence(timeout: 10)); report.tap()
        XCTAssertTrue(app.staticTexts["免费摘要始终保留"].waitForExistence(timeout: 10))
        return app
    }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 {
            if element.exists && element.isHittable && app.frame.contains(element.frame) { return }
            app.swipeUp()
        }
        XCTFail("Expected visible control: " + element.identifier)
    }
    private func checkout(_ app: XCUIApplication) {
        let pay = app.buttons["ai-report-wallet-pay"]
        reveal(pay, in: app); pay.tap()
        XCTAssertTrue(app.buttons["cashier-confirm"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["演示支付，不扣真实资金"].exists)
        XCTAssertFalse(app.staticTexts["积分"].exists)
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name
        attachment.lifetime = .keepAlways; add(attachment)
    }
    func testDefaultDemoWalletPriceRecoversStaleQuoteAndUnlocksOnce() async throws {
        _ = try await fixture("reset", body: ["price": 990, "balance": 5000, "stale": true, "mode": "demo"])
        let app = launchReport()
        XCTAssertTrue(app.staticTexts["¥9.90"].waitForExistence(timeout: 10))
        checkout(app)
        XCTAssertTrue(app.buttons["模拟余额支付"].exists)
        let confirm = app.buttons["cashier-confirm"]
        reveal(confirm, in: app); XCTAssertTrue(confirm.isEnabled); confirm.tap()
        let refresh = app.buttons["重新获取报价"]
        reveal(refresh, in: app); XCTAssertTrue(refresh.waitForExistence(timeout: 10))
        XCTAssertFalse(confirm.isEnabled)
        capture(app, "ios-ai-wallet-stale-quote")
        refresh.tap()
        let enabled = NSPredicate(format: "enabled == true")
        await fulfillment(of: [expectation(for: enabled, evaluatedWith: confirm)], timeout: 10)
        reveal(confirm, in: app); confirm.tap()
        XCTAssertTrue(app.staticTexts["完整分析 · 已解锁"].waitForExistence(timeout: 10))
        capture(app, "ios-ai-wallet-unlocked")
        let state = try await fixture("state")
        XCTAssertEqual(state["charges"] as? Int, 1)
        XCTAssertEqual(state["balance"] as? Int, 4010)
        let payments = try XCTUnwrap(state["payments"] as? [[String: Any]])
        XCTAssertEqual(payments.count, 2)
        XCTAssertTrue(payments.allSatisfy { $0["channel"] as? String == "demo_balance" && $0["expectedCents"] as? Int == 990 })
        XCTAssertFalse((state["requests"] as? [String] ?? []).contains("/api/v1/payments/ai-report"))
        app.terminate()
        let reopened = launchReport()
        XCTAssertTrue(reopened.staticTexts["完整分析 · 已解锁"].waitForExistence(timeout: 10))
        XCTAssertFalse(reopened.buttons["ai-report-wallet-pay"].exists)
        let finalState = try await fixture("state")
        XCTAssertEqual(finalState["charges"] as? Int, 1)
    }
    func testConfiguredPriceInsufficientBalanceAndWalletReturn() async throws {
        _ = try await fixture("reset", body: ["price": 1290, "balance": 500])
        let app = launchReport()
        XCTAssertTrue(app.staticTexts["¥12.90"].waitForExistence(timeout: 10))
        checkout(app)
        let confirm = app.buttons["cashier-confirm"]
        XCTAssertFalse(confirm.isEnabled)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS '余额不足'")).firstMatch.exists)
        capture(app, "ios-ai-wallet-insufficient")
        let wallet = app.buttons["查看钱包与充值"]
        reveal(wallet, in: app); wallet.tap()
        XCTAssertTrue(app.navigationBars["钱包余额"].waitForExistence(timeout: 10))
        _ = try await fixture("balance", body: ["balance": 3000])
        app.navigationBars.buttons.firstMatch.tap()
        await fulfillment(of: [expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: confirm)], timeout: 10)
        reveal(confirm, in: app); confirm.tap()
        XCTAssertTrue(app.staticTexts["完整分析 · 已解锁"].waitForExistence(timeout: 10))
        let state = try await fixture("state")
        XCTAssertEqual(state["balance"] as? Int, 1710)
        XCTAssertEqual(state["charges"] as? Int, 1)
    }
}
