import XCTest

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
        XCTAssertTrue(app.buttons["从相册选择照片"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.textFields["头像 URL"].exists)
        app.buttons["从相册选择照片"].tap()
        XCTAssertTrue(app.buttons["取消"].waitForExistence(timeout: 10) || app.buttons["Cancel"].waitForExistence(timeout: 3))
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "customer-avatar-photo-picker"; shot.lifetime = .keepAlways; add(shot)
    }
}
