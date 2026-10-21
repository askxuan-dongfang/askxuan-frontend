import XCTest

/// Opt-in acceptance against the isolated real services. No synthetic-token or mock fallback.
final class OnboardingUITests: XCTestCase {
    private var environment: [String: String] { ProcessInfo.processInfo.environment }

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch(tokenKey: String) throws -> XCUIApplication {
        let base = environment["ASKXUAN_ONBOARDING_API_URL"] ?? ""
        guard let url = URL(string: base), ["127.0.0.1", "localhost"].contains(url.host ?? ""),
              let token = environment[tokenKey], !token.isEmpty else {
            throw XCTSkip("Requires a dedicated real-service localhost onboarding fixture")
        }
        let app = XCUIApplication()
        app.launchEnvironment["ASKXUAN_JOURNEY_API_URL"] = base
        app.launchArguments = ["--smoke-token", token, "-askxuan.language", "zh-Hans"]
        app.launch()
        XCTAssertTrue(app.navigationBars["大师认证"].waitForExistence(timeout: 20))
        return app
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication, direction: String = "up") {
        for _ in 0..<14 {
            if element.exists && element.isHittable { return }
            if direction == "up" { app.swipeUp() } else { app.swipeDown() }
        }
        XCTAssertTrue(element.exists && element.isHittable, "Expected onboarding control to be visible")
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testDraftRetainsAssociationsUntilExplicitResolutionAndReload() throws {
        let app = try launch(tokenKey: "ASKXUAN_ONBOARDING_DRAFT_TOKEN")
        let firstCode = environment["ASKXUAN_ONBOARDING_FIRST_CODE"] ?? "mazu"
        let secondCode = environment["ASKXUAN_ONBOARDING_SECOND_CODE"] ?? "guandi"
        let targetCode = environment["ASKXUAN_ONBOARDING_TARGET_CODE"] ?? "quanzhen"
        let first = app.buttons["onboarding.tradition.\(firstCode)"]
        reveal(first, in: app)
        XCTAssertEqual(first.value as? String, "已选择")
        let second = app.buttons["onboarding.tradition.\(secondCode)"]
        reveal(second, in: app)
        XCTAssertEqual(second.value as? String, "未选择")
        second.tap()
        XCTAssertEqual(second.value as? String, "已选择")
        let picker = app.buttons["onboarding.belief"]
        reveal(picker, in: app, direction: "down")
        picker.tap()
        app.buttons["道教"].tap()
        XCTAssertTrue(app.alerts["确认信仰流派变更"].waitForExistence(timeout: 5))
        app.alerts.buttons["取消"].tap()
        XCTAssertTrue(first.exists)
        picker.tap()
        app.buttons["道教"].tap()
        app.alerts.buttons["更换并保留已选项"].tap()
        let removeFirst = app.buttons["onboarding.remove.\(firstCode)"]
        reveal(removeFirst, in: app)
        XCTAssertTrue(app.buttons["onboarding.remove.\(secondCode)"].exists)
        attach(app, "onboarding-explicit-belief-conflicts")
        removeFirst.tap()
        app.buttons["onboarding.remove.\(secondCode)"].tap()
        let target = app.buttons["onboarding.tradition.\(targetCode)"]
        reveal(target, in: app, direction: "down")
        target.tap()
        let save = app.buttons["onboarding.save"]
        reveal(save, in: app)
        save.tap()
        let notice = app.staticTexts["onboarding.notice"]
        reveal(notice, in: app)
        XCTAssertEqual(notice.label, "草稿已保存")
        app.terminate()
        let reloaded = try launch(tokenKey: "ASKXUAN_ONBOARDING_DRAFT_TOKEN")
        let saved = reloaded.buttons["onboarding.tradition.\(targetCode)"]
        reveal(saved, in: reloaded)
        XCTAssertEqual(saved.value as? String, "已选择")
        XCTAssertFalse(reloaded.buttons["onboarding.remove.\(firstCode)"].exists)
        attach(reloaded, "onboarding-draft-reloaded")
    }

    func testValidAffiliationSubmissionBecomesReadonly() throws {
        let app = try launch(tokenKey: "ASKXUAN_ONBOARDING_SUBMIT_TOKEN")
        let code = environment["ASKXUAN_ONBOARDING_FIRST_CODE"] ?? "mazu"
        let choice = app.buttons["onboarding.tradition.\(code)"]
        reveal(choice, in: app)
        if choice.value as? String != "已选择" { choice.tap() }
        let submit = app.buttons["onboarding.submit"]
        reveal(submit, in: app)
        submit.tap()
        let notice = app.staticTexts["onboarding.notice"]
        reveal(notice, in: app)
        XCTAssertEqual(notice.label, "申请已提交，请等待平台审核")
        reveal(choice, in: app, direction: "down")
        XCTAssertFalse(choice.isEnabled)
        XCTAssertFalse(app.buttons["onboarding.save"].exists)
        attach(app, "onboarding-submitted-readonly")
    }

    func testLegacySubmittedApplicationIsReadonlyWithoutInventedTags() throws {
        let app = try launch(tokenKey: "ASKXUAN_ONBOARDING_SUBMITTED_TOKEN")
        let explanation = app.staticTexts["尚未选择标准宗派／信俗，如需补充请等待平台退回。"]
        reveal(explanation, in: app)
        let sect = app.textFields["onboarding.sect"]
        XCTAssertFalse(sect.isEnabled)
        XCTAssertEqual(sect.value as? String, environment["ASKXUAN_ONBOARDING_LEGACY_SECT"] ?? "历史宗派说明保持原样")
        XCTAssertFalse(app.buttons["onboarding.submit"].exists)
        XCTAssertFalse(app.buttons["onboarding.save"].exists)
        attach(app, "onboarding-legacy-submitted-readonly")
    }
}
