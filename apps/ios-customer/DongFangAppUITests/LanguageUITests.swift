import XCTest

final class LanguageUITests: XCTestCase {
    func testLanguageSwitchKeepsLoginDraftAndPersists() {
        let app = XCUIApplication()
        app.launchEnvironment["ASKXUAN_JOURNEY_API_URL"] = ProcessInfo.processInfo.environment["ASKXUAN_DIRECTORY_TEST_API_URL"] ?? "http://127.0.0.1:8913/api/v1"
        app.launchArguments = ["-askxuan.language", "zh-Hans", "-tab", "4"]
        app.launch()
        let login = app.buttons["立即登录 / 注册"]
        if !login.waitForExistence(timeout: 3) {
            let logout = app.buttons["退出登录"]
            reveal(logout, in: app)
            logout.tap()
        }
        XCTAssertTrue(login.waitForExistence(timeout: 20)); login.tap()
        let account = app.textFields["邮箱／用户名"]
        let language = app.buttons["login-language"]
        let appearance = app.buttons["login-appearance"]
        let recovery = app.buttons["login-recovery"]
        XCTAssertTrue(account.waitForExistence(timeout: 10))
        reveal(appearance, in: app)
        XCTAssertTrue(app.descendants(matching: .any)["login-preferences"].exists)
        XCTAssertTrue(recovery.exists)
        XCTAssertTrue(language.isHittable)
        XCTAssertGreaterThanOrEqual(language.frame.minY, recovery.frame.maxY)
        XCTAssertGreaterThanOrEqual(appearance.frame.minY, recovery.frame.maxY)
        for _ in 0..<6 where !account.isHittable { app.swipeDown() }
        XCTAssertTrue(account.waitForExistence(timeout: 10)); account.tap()
        dismissKeyboardIntroduction(in: app)
        account.typeText("language-draft@example.test")
        reveal(language, in: app)
        language.tap()
        let traditional = app.buttons["繁體中文"]
        XCTAssertTrue(traditional.waitForExistence(timeout: 5)); traditional.tap()
        XCTAssertTrue(app.navigationBars["語言"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        let translatedAccount = app.textFields["郵箱／用戶名"]
        XCTAssertTrue(translatedAccount.waitForExistence(timeout: 5))
        XCTAssertEqual(translatedAccount.value as? String, "language-draft@example.test")
        reveal(appearance, in: app)
        appearance.tap()
        XCTAssertTrue(app.navigationBars["外觀與語言"].waitForExistence(timeout: 5))
        for title in ["淺色", "深色"] {
            let option = app.buttons[title]
            XCTAssertTrue(option.waitForExistence(timeout: 5)); option.tap()
            let selected = XCTNSPredicateExpectation(predicate: NSPredicate { object, _ in
                (object as? XCUIElement)?.isSelected == true
            }, object: option)
            XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed, "\(title)外观应已选中")
        }
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(translatedAccount.waitForExistence(timeout: 5))
        XCTAssertEqual(translatedAccount.value as? String, "language-draft@example.test")
        reveal(appearance, in: app)
        XCTAssertTrue(appearance.label.contains("深色"), "返回后登录页底部应显示实际外观偏好")
        let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.name = "customer-traditional-login-draft"; screenshot.lifetime = .keepAlways; add(screenshot)
        app.terminate()
        app.launchArguments = ["-tab", "4"]; app.launch()
        XCTAssertTrue(app.buttons["外觀與語言"].waitForExistence(timeout: 15))
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        dismissKeyboardIntroduction(in: app)
        let form = app.scrollViews.containing(.button, identifier: "login-language").firstMatch
        let content = form.exists ? form : app.scrollViews.firstMatch
        let keyboard = app.keyboards.firstMatch
        if keyboard.exists {
            // Returning from a settings destination can restore the text field's focus.
            // Drag the form itself, rather than sending a swipe through the keyboard.
            dragVisibleContent(content, in: app, down: true)
            XCTAssertTrue(keyboard.waitForNonExistence(timeout: 5))
        }
        for _ in 0..<8 {
            if element.isHittable { return }
            dragVisibleContent(content, in: app, down: false)
        }
        XCTAssertTrue(element.isHittable)
    }

    private func dragVisibleContent(_ content: XCUIElement, in app: XCUIApplication, down: Bool) {
        // SwiftUI reports this form as full-screen even when the keyboard covers it.
        let frame = content.frame.intersection(app.frame)
        let navigation = app.navigationBars.firstMatch
        let keyboard = app.keyboards.firstMatch
        let top = max(frame.minY, navigation.exists ? navigation.frame.maxY : frame.minY)
        let bottom = min(frame.maxY, keyboard.exists ? keyboard.frame.minY : frame.maxY)
        XCTAssertGreaterThan(bottom, top, "登录表单必须有未被键盘覆盖的可操作区域")
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let upper = origin.withOffset(CGVector(dx: frame.midX - app.frame.minX, dy: top + (bottom - top) * 0.15 - app.frame.minY))
        let lower = origin.withOffset(CGVector(dx: frame.midX - app.frame.minX, dy: top + (bottom - top) * 0.90 - app.frame.minY))
        (down ? upper : lower).press(forDuration: 0.05, thenDragTo: down ? lower : upper)
    }

    private func dismissKeyboardIntroduction(in app: XCUIApplication) {
        let introduction = app.otherElements["UIContinuousPathIntroductionView"]
        guard introduction.exists else { return }
        let continueButton = introduction.buttons["Continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.tap()
        XCTAssertTrue(introduction.waitForNonExistence(timeout: 5))
    }
}
