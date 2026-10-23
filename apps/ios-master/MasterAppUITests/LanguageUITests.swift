import XCTest

final class LanguageUITests: XCTestCase {
    func testLanguageSwitchKeepsLoginDraft() {
        let app = XCUIApplication()
        app.launchArguments = ["-askxuan.language", "zh-Hans"]
        app.launch()
        let account = app.textFields["邮箱／用户名"]
        XCTAssertTrue(account.waitForExistence(timeout: 20)); account.tap(); account.typeText("master-draft@example.test")
        let language = app.buttons["语言"]
        XCTAssertTrue(language.waitForExistence(timeout: 5)); language.tap()
        let traditional = app.buttons["繁體中文"]
        XCTAssertTrue(traditional.waitForExistence(timeout: 5)); traditional.tap()
        XCTAssertTrue(app.navigationBars["語言"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        let translatedAccount = app.textFields["郵箱／用戶名"]
        XCTAssertTrue(translatedAccount.waitForExistence(timeout: 5))
        XCTAssertEqual(translatedAccount.value as? String, "master-draft@example.test")
        let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.name = "master-traditional-login-draft"; screenshot.lifetime = .keepAlways; add(screenshot)
    }
}
