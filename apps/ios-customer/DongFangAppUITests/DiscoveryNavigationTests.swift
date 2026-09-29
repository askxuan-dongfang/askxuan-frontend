import XCTest

final class DiscoveryNavigationTests: XCTestCase {
    private func openApp(appearance: String = "light") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-askxuan.appearance", appearance, "-tab", "0"]
        app.launch()
        return app
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testHomeDirectoriesSearchAndNativeReturn() {
        let app = openApp()
        let temples = app.buttons["home-temples"]
        XCTAssertTrue(temples.waitForExistence(timeout: 20))
        capture(app, "home-light")
        temples.tap()
        let search = app.buttons["搜索"]
        XCTAssertTrue(search.waitForExistence(timeout: 10)); search.tap()
        let field = app.textFields["搜索寺院名称、地区"]
        XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap(); field.typeText("NO_MATCH_12345")
        XCTAssertTrue(app.buttons["清除筛选"].waitForExistence(timeout: 15))
        app.buttons["清除筛选"].tap()
        capture(app, "temple-search")
        app.buttons["返回"].firstMatch.tap()
        XCTAssertTrue(temples.waitForExistence(timeout: 5))
        app.buttons["home-masters"].tap()
        XCTAssertTrue(app.buttons["搜索"].waitForExistence(timeout: 5))
        app.buttons["搜索"].tap()
        XCTAssertTrue(app.textFields["搜索师傅、宗派或专长"].waitForExistence(timeout: 5))
        capture(app, "master-directory")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5)).press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
        XCTAssertTrue(temples.waitForExistence(timeout: 5))
    }
    func testGuestCanEnterDiyEditor() {
        let app = openApp(appearance: "dark")
        let diy = app.buttons["home-intention-diy"]
        XCTAssertTrue(diy.waitForExistence(timeout: 25))
        if !diy.isHittable { app.swipeUp() }
        capture(app, "home-dark")
        diy.tap()
        let start = app.staticTexts["diy-start"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        if !start.isHittable { app.swipeUp() }
        start.tap()
        XCTAssertTrue(app.buttons["diy-mode-2d"].waitForExistence(timeout: 15))
        capture(app, "diy-editor-guest")
    }
    func testRootTabsRetainNativeNavigation() {
        let app = openApp()
        for tab in ["对话", "AI问事", "商城", "我的", "首页"] {
            let button = app.tabBars.buttons[tab]
            XCTAssertTrue(button.waitForExistence(timeout: 10)); button.tap()
            capture(app, "tab-" + tab)
        }
    }
    func testCancelledEdgeBackKeepsDetailAndCompletedBackRestoresTabBar() {
        let app = openApp()
        let temples = app.buttons["home-temples"]
        XCTAssertTrue(temples.waitForExistence(timeout: 20))
        temples.tap()
        let back = app.buttons["返回"].firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 10))
        let edge = app.coordinate(withNormalizedOffset: CGVector(dx: 0.005, dy: 0.5))
        let partial = app.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))
        edge.press(forDuration: 0.1, thenDragTo: partial, withVelocity: .slow, thenHoldForDuration: 0.3)
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        XCTAssertFalse(app.tabBars.buttons["首页"].isHittable)
        capture(app, "cancelled-native-back")
        edge.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)))
        XCTAssertTrue(temples.waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["首页"].isHittable)
        capture(app, "completed-native-back")
    }

    func testReportFirstGuestExamplesAndNativeBack() {
        let app = XCUIApplication()
        app.launchArguments = ["-askxuan.appearance", "light", "-tab", "2"]
        app.launch()
        let bazi = app.buttons["ai-topic-bazi"]
        XCTAssertTrue(bazi.waitForExistence(timeout: 15))
        capture(app, "report-first-topics")
        bazi.tap()
        XCTAssertTrue(app.staticTexts["登录后生成个人报告"].waitForExistence(timeout: 5))
        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5)); back.tap()
        XCTAssertTrue(bazi.waitForExistence(timeout: 5))
        let examples = app.buttons["先看一份示例报告"]
        for _ in 0..<8 { if examples.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(examples.isHittable); examples.tap()
        let sample = app.buttons["ai-example-bazi"]
        if !sample.isHittable { app.swipeUp() }
        XCTAssertTrue(sample.waitForExistence(timeout: 5)); sample.tap()
        XCTAssertTrue(app.navigationBars["示例报告"].waitForExistence(timeout: 5))
        capture(app, "report-native-example")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.005, dy: 0.5)).press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)))
        XCTAssertTrue(examples.waitForExistence(timeout: 5))
        app.segmentedControls.buttons["问 AI"].tap()
        XCTAssertTrue(app.staticTexts["登录后使用 问 AI"].waitForExistence(timeout: 5))
        app.segmentedControls.buttons["我的报告"].tap()
        XCTAssertTrue(app.staticTexts["登录后使用 我的报告"].waitForExistence(timeout: 5))
    }

}
