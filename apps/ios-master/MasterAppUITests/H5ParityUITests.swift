import XCTest

final class H5ParityUITests: XCTestCase {
    func testProfileContentStudioMatchesH5Entrypoint() {
        let app = XCUIApplication()
        app.launchEnvironment["ASKXUAN_JOURNEY_API_URL"] = "http://127.0.0.1:5399/api/v1"
        // Synthetic identity accepted by the localhost read-only fixture only.
        let payload = Data(#"{"roles":["master"],"masterId":1,"userId":10001,"nickname":"Local Test"}"#.utf8)
            .base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        let fixtureToken = "eyJhbGciOiJub25lIn0.\(payload).fixture"
        app.launchArguments = ["--smoke-token", fixtureToken, "-tab", "3", "-askxuan.appearance", "dark"]
        app.launch()
        XCTAssertTrue(app.staticTexts["本地验收师傅"].waitForExistence(timeout: 20))
        let content = app.buttons["内容与直播"]
        XCTAssertTrue(content.waitForExistence(timeout: 20)); content.tap()
        XCTAssertTrue(app.navigationBars["内容与直播"].waitForExistence(timeout: 10))
        let article = app.segmentedControls.buttons["图文"]
        XCTAssertTrue(article.waitForExistence(timeout: 5)); article.tap()
        XCTAssertTrue(app.buttons["选择图片（最多 9 张）"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["保存草稿"].exists)
        XCTAssertTrue(app.buttons["提交审核"].exists)
        XCTAssertTrue(app.staticTexts["直播能力未开放"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "数据解析失败")).firstMatch.exists)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "master-content-studio-dark"
        shot.lifetime = .keepAlways; add(shot)
        // Read-only UI acceptance: do not upload, publish, or start a live room.
    }
}
