import XCTest

final class LanguageUITests: XCTestCase {
    func testLanguageSwitchKeepsLoginDraftAndPersists() {
        let app = XCUIApplication()
        app.launchArguments = ["-askxuan.language", "zh-Hans", "-tab", "4"]
        app.launch()
        let login = app.buttons["立即登录 / 注册"]
        XCTAssertTrue(login.waitForExistence(timeout: 20)); login.tap()
        let account = app.textFields["邮箱／用户名"]
        XCTAssertTrue(account.waitForExistence(timeout: 10)); account.tap(); account.typeText("language-draft@example.test")
        let language = app.buttons["语言"]
        XCTAssertTrue(language.waitForExistence(timeout: 5)); language.tap()
        let traditional = app.staticTexts["繁體中文"]
        XCTAssertTrue(traditional.waitForExistence(timeout: 5)); traditional.tap()
        XCTAssertTrue(app.navigationBars["語言"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        let translatedAccount = app.textFields["郵箱／用戶名"]
        XCTAssertTrue(translatedAccount.waitForExistence(timeout: 5))
        XCTAssertEqual(translatedAccount.value as? String, "language-draft@example.test")
        let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.name = "customer-traditional-login-draft"; screenshot.lifetime = .keepAlways; add(screenshot)
        app.terminate()
        app.launchArguments = ["-tab", "4"]; app.launch()
        XCTAssertTrue(app.buttons["外觀與語言"].waitForExistence(timeout: 15))
    }
}
