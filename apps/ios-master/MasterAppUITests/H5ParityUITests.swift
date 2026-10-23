import XCTest

@MainActor final class TempleOperationsUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    private let base = "http://127.0.0.1:63400/api/v1"
    private var env: [String: String] { ProcessInfo.processInfo.environment }
    private func required(_ key: String) throws -> String { try XCTUnwrap(env[key], "Requires isolated temple runtime: " + key) }
    private func launch(booking: Bool = false) throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["ASKXUAN_JOURNEY_API_URL"] = base
        if booking { app.launchEnvironment["ASKXUAN_JOURNEY_BOOKING"] = try required("TEMPLE_OPS_BOOKING") }
        app.launchArguments = ["--smoke-token", try required("TEMPLE_OPS_MASTER_TOKEN"), "-tab", "0", "-askxuan.language", "zh-Hans", "-askxuan.appearance", "light"]
        app.launch()
        return app
    }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<12 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    private func read(_ path: String) async throws -> [String: Any] {
        var request = URLRequest(url: try XCTUnwrap(URL(string: base + path)))
        request.setValue("Bearer " + (try required("TEMPLE_OPS_MASTER_TOKEN")), forHTTPHeaderField: "Authorization")
        request.setValue("master", forHTTPHeaderField: "X-Client-Type")
        let (data, response) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        let envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(envelope["code"] as? Int, 0)
        return try XCTUnwrap(envelope["data"] as? [String: Any])
    }
    private func calendar(_ app: XCUIApplication) throws {
        let entry = app.buttons["设置日程"]
        XCTAssertTrue(entry.waitForExistence(timeout: 20)); reveal(entry, in: app); entry.tap()
        XCTAssertTrue(app.navigationBars["日程日历"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["calendar.title"].isHittable)
        capture(app, "master-calendar-navigation-title")
        let day = app.buttons["calendar.day." + (try required("TEMPLE_OPS_DATE"))]
        XCTAssertTrue(day.waitForExistence(timeout: 10)); day.tap()
        XCTAssertTrue(app.buttons["设置休息日"].waitForExistence(timeout: 10))
    }
    func testSharedCalendarWithRealServices() async throws {
        let date = try required("TEMPLE_OPS_DATE")
        let path = "/admin/masters/schedules?date=" + date
        let before = try await read(path)
        XCTAssertEqual((before["list"] as? [[String: Any]])?.count, 0)
        let app = try launch(); try calendar(app)
        let empty = app.staticTexts["尚未设置日期排班，当前沿用服务时段"]
        XCTAssertTrue(empty.waitForExistence(timeout: 10))
        let slot = app.buttons["calendar.slot.09:00-12:00"]
        reveal(slot, in: app); XCTAssertFalse(slot.isSelected); slot.tap(); XCTAssertTrue(slot.isSelected)
        XCTAssertTrue(slot.label.contains("已选择"))
        let draft = try await read(path)
        XCTAssertEqual((draft["list"] as? [[String: Any]])?.count, 0)
        capture(app, "master-calendar-unsaved-draft")
        let refresh = app.buttons["calendar.reload"]
        for _ in 0..<10 where !refresh.isHittable { app.swipeDown() }
        refresh.tap()
        XCTAssertTrue(empty.waitForExistence(timeout: 10))
        reveal(slot, in: app); XCTAssertFalse(slot.isSelected)
        let rest = app.buttons["设置休息日"]; reveal(rest, in: app); rest.tap()
        XCTAssertTrue(app.staticTexts["已设为休息日"].waitForExistence(timeout: 15))
        let saved = try await read(path)
        let rows = try XCTUnwrap(saved["list"] as? [[String: Any]])
        XCTAssertEqual(rows.first?["status"] as? String, "off")
        XCTAssertTrue((rows.first?["revision"] as? Int ?? 0) > 0)
        let available = try await read("/bookings/availability?templeId=T_OPS_WEB&serviceId=S001&masterId=M_OPS_WEB&date=" + date)
        let slots = try XCTUnwrap(available["slots"] as? [[String: Any]])
        XCTAssertFalse(slots.isEmpty); XCTAssertTrue(slots.allSatisfy { $0["available"] as? Bool == false })
        capture(app, "master-calendar-saved-rest-day")
    }
    func testRestoreSharedCalendarFromNativeUI() async throws {
        let app = try launch(); try calendar(app)
        for time in ["09:00-12:00", "13:00-17:00"] {
            let slot = app.buttons["calendar.slot." + time]; reveal(slot, in: app)
            if !slot.isSelected { slot.tap() }
        }
        let save = app.buttons["保存日程"]; reveal(save, in: app); save.tap()
        XCTAssertTrue(app.staticTexts["日程已保存"].waitForExistence(timeout: 15))
        let saved = try await read("/admin/masters/schedules?date=" + (try required("TEMPLE_OPS_DATE")))
        let row = try XCTUnwrap((saved["list"] as? [[String: Any]])?.first)
        XCTAssertEqual(row["status"] as? String, "available")
        XCTAssertEqual(row["timeSlots"] as? [String], ["09:00-12:00", "13:00-17:00"])
        capture(app, "master-calendar-restored")
    }
    func testStartAndRecordProgressFromRealServices() async throws {
        let app = try launch(booking: true)
        let confirm = app.buttons["确认接单"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 20)); confirm.tap()
        let start = app.buttons["开始执行"]
        XCTAssertTrue(start.waitForExistence(timeout: 15)); start.tap()
        let field = app.descendants(matching: .any)["journey.progress.text"].firstMatch
        reveal(field, in: app); field.tap(); field.typeText("原生端已开始执行，正在整理测试回执。")
        let publish = app.buttons["发布真实进展"]; reveal(publish, in: app); publish.tap()
        XCTAssertTrue(app.staticTexts["阶段记录已发布。"].waitForExistence(timeout: 15))
        let result = try await read("/bookings/" + (try required("TEMPLE_OPS_BOOKING")) + "/fulfillment")
        XCTAssertEqual(result["status"] as? String, "in_progress")
        let records = try XCTUnwrap(result["records"] as? [[String: Any]])
        XCTAssertTrue(records.contains { $0["content"] as? String == "原生端已开始执行，正在整理测试回执。" })
        capture(app, "master-native-progress")
    }
    func testSubmitReceiptFromRealServices() async throws {
        let app = try launch(booking: true)
        XCTAssertTrue(app.navigationBars["服务履约"].waitForExistence(timeout: 20))
        let field = app.descendants(matching: .any)["journey.receipt.text"].firstMatch
        reveal(field, in: app); field.tap(); field.typeText(try required("TEMPLE_OPS_RECEIPT_TEXT"))
        let submit = app.buttons["提交回执，等待信众确认"]
        reveal(submit, in: app); XCTAssertFalse(submit.isEnabled)
        let photo = app.buttons["journey.receipt.photo"]; reveal(photo, in: app); photo.tap()
        XCTAssertTrue(app.buttons["取消"].waitForExistence(timeout: 15))
        let loaded = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.staticTexts["正在加载…"].firstMatch)
        await fulfillment(of: [loaded], timeout: 30)
        let image = app.images.matching(identifier: "PXGGridLayout-Info").firstMatch
        XCTAssertTrue(image.waitForExistence(timeout: 15))
        XCTAssertFalse(image.frame.isEmpty)
        // shortcut: iOS 27 thumbnails lack AX hit points; use their center until XCTest fixes this.
        image.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let uploaded = expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: submit)
        await fulfillment(of: [uploaded], timeout: 20)
        reveal(submit, in: app); submit.tap()
        let saved = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: submit)
        await fulfillment(of: [saved], timeout: 20)
        let result = try await read("/bookings/" + (try required("TEMPLE_OPS_BOOKING")) + "/fulfillment")
        XCTAssertEqual(result["status"] as? String, "pending_receipt")
        let receipt = try XCTUnwrap((result["receipts"] as? [[String: Any]])?.last)
        XCTAssertEqual(receipt["summary"] as? String, try required("TEMPLE_OPS_RECEIPT_TEXT"))
        XCTAssertFalse((receipt["files"] as? [[String: Any]] ?? []).isEmpty)
        capture(app, "master-native-receipt-submitted")
    }
}

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

final class ProfileExperienceUITests: XCTestCase {

    func testAvatarAndSpecialtyControls() {
        let app = XCUIApplication()
        app.launchEnvironment["ASKXUAN_JOURNEY_API_URL"] = "http://127.0.0.1:5437/api/v1"
        let payload = Data(#"{"roles":["master"],"masterId":9002,"userId":9002,"nickname":"明觉"}"#.utf8).base64EncodedString().replacingOccurrences(of: "=", with: "")
        app.launchArguments = ["--smoke-token", "eyJhbGciOiJub25lIn0.\(payload).fixture", "-tab", "3", "-askxuan.appearance", "dark"]
        app.launch()
        XCTAssertTrue(app.buttons["更换头像"].waitForExistence(timeout: 20)); app.buttons["更换头像"].tap()
        XCTAssertFalse(app.buttons["从相册选择照片"].exists)
        XCTAssertTrue(app.buttons["取消"].waitForExistence(timeout: 5) || app.buttons["Cancel"].waitForExistence(timeout: 5))
        let cancel = app.buttons["取消"].exists ? app.buttons["取消"] : app.buttons["Cancel"]
        cancel.tap()
        XCTAssertFalse(app.textFields["头像 URL"].exists)
        app.buttons["个人资料"].firstMatch.tap()
        let specialty = app.buttons["祈福"]
        for _ in 0..<3 where !specialty.isHittable { app.swipeUp() }
        XCTAssertTrue(specialty.waitForExistence(timeout: 5)); specialty.tap()
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "master-profile-specialties"; shot.lifetime = .keepAlways; add(shot)
    }
}
