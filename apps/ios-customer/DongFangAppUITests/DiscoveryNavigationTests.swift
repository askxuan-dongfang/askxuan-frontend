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
}
