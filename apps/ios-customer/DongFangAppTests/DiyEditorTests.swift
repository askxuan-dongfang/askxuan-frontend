import XCTest
@testable import DongFangApp

@MainActor
final class DiyEditorTests: XCTestCase {
    private var suiteName: String!
    private var draftStore: UserDefaults!
    private var viewModel: DiyViewModel!

    override func setUp() async throws {
        suiteName = "DiyEditorTests.\(UUID().uuidString)"
        draftStore = UserDefaults(suiteName: suiteName)
        draftStore.removePersistentDomain(forName: suiteName)
        viewModel = DiyViewModel(draftStore: draftStore)
    }

    override func tearDown() async throws {
        draftStore.removePersistentDomain(forName: suiteName)
        viewModel = nil
        draftStore = nil
        suiteName = nil
    }

    func testOrderedBeadsDriveAggregatedOrderItems() {
        let wood = material(id: 1, name: "小叶紫檀", price: 28)
        let jade = material(id: 2, name: "和田碧玉", price: 55)

        viewModel.addBead(wood)
        viewModel.addBead(jade)
        viewModel.addBead(wood)
        let jadeId = viewModel.beadSlots[1].id
        viewModel.moveBead(id: jadeId, to: 0)

        let document = viewModel.designDocument()
        XCTAssertEqual(document.beads.map(\.materialId), [2, 1, 1])
        XCTAssertEqual(document.beads.map(\.position), [0, 1, 2])
        XCTAssertEqual(document.items.first(where: { $0.materialId == 1 })?.quantity, 2)
        XCTAssertEqual(viewModel.totalPrice, 111)
    }

    func testUndoAndRedoRestoreExactOrder() {
        let wood = material(id: 1, name: "小叶紫檀", price: 28)
        let jade = material(id: 2, name: "和田碧玉", price: 55)
        viewModel.addBead(wood)
        viewModel.addBead(jade)
        let jadeId = viewModel.beadSlots[1].id

        viewModel.moveBead(id: jadeId, to: 0)
        XCTAssertEqual(viewModel.beadSlots.map(\.materialId), [2, 1])
        viewModel.undo()
        XCTAssertEqual(viewModel.beadSlots.map(\.materialId), [1, 2])
        viewModel.redo()
        XCTAssertEqual(viewModel.beadSlots.map(\.materialId), [2, 1])
    }

    func testFitAllowanceParticipatesInHistoryAndRestoresFromDraft() {
        viewModel.addBead(material(id: 1, name: "小叶紫檀", price: 28))
        viewModel.setFitAllowance(12)
        XCTAssertEqual(viewModel.designDocument().fitAllowanceMm, 12)

        viewModel.undo()
        XCTAssertEqual(viewModel.fitAllowanceMm, 8)
        XCTAssertEqual(viewModel.beadSlots.count, 1)
        viewModel.redo()
        XCTAssertEqual(viewModel.fitAllowanceMm, 12)

        let restored = DiyViewModel(draftStore: draftStore)
        XCTAssertEqual(restored.fitAllowanceMm, 12)
        XCTAssertEqual(restored.beadSlots.count, 1)
        XCTAssertEqual(restored.draftStateText, "已恢复本机草稿")
    }

    func testVersionTwoDocumentRoundTripsAndRestoresWristSize() throws {
        viewModel.addBead(material(id: 1, name: "小叶紫檀", price: 28))
        viewModel.addBead(material(id: 2, name: "南红玛瑙", price: 42))
        viewModel.setWristSize(180)
        let data = try JSONEncoder().encode(viewModel.designDocument())
        let raw = try XCTUnwrap(String(data: data, encoding: .utf8))

        let otherStore = UserDefaults(suiteName: "\(suiteName!).other")!
        otherStore.removePersistentDomain(forName: "\(suiteName!).other")
        let restored = DiyViewModel(draftStore: otherStore)
        restored.restoreDesignData(raw)

        XCTAssertEqual(restored.wristSizeMm, 180)
        XCTAssertEqual(restored.beadSlots.map(\.materialId), [1, 2])
        XCTAssertEqual(restored.designDocument().version, 2)
    }

    func testLegacyItemsMigrateToOrderedSlotsAndCord() throws {
        let legacy = [
            DiyOrderItem(
                materialId: 1,
                materialName: "小叶紫檀",
                spec: "10mm",
                unitPrice: 28,
                quantity: 2,
                subtype: "main_bead"
            ),
            DiyOrderItem(
                materialId: 9,
                materialName: "弹力绳",
                spec: "1mm",
                unitPrice: 5,
                quantity: 1,
                subtype: "cord"
            )
        ]
        let data = try JSONEncoder().encode(legacy)
        viewModel.restoreDesignData(try XCTUnwrap(String(data: data, encoding: .utf8)))

        XCTAssertEqual(viewModel.beadSlots.count, 2)
        XCTAssertEqual(viewModel.selectedCord?.id, 9)
        XCTAssertEqual(viewModel.cartItems.count, 2)
        XCTAssertEqual(viewModel.designDocument().items.count, 2)
    }

    func testDraftRestoresAfterNewViewModelIsCreated() {
        viewModel.addBead(material(id: 1, name: "小叶紫檀", price: 28))
        viewModel.setWristSize(170)

        let restored = DiyViewModel(draftStore: draftStore)
        XCTAssertEqual(restored.beadSlots.count, 1)
        XCTAssertEqual(restored.wristSizeMm, 170)
        XCTAssertEqual(restored.draftStateText, "已恢复本机草稿")
    }

    func testDiameterAndFitStateUseMillimeters() {
        let twelveMillimeter = material(id: 3, name: "沉香木", spec: "12mm", price: 66)
        XCTAssertEqual(twelveMillimeter.resolvedDiameterMm, 12)

        for _ in 0..<14 { viewModel.addBead(twelveMillimeter) }
        XCTAssertEqual(viewModel.usedLengthMm, 168)
        XCTAssertEqual(viewModel.fitState, .loose(remainingBeads: 4))

        // 按珠子内侧计算，17 颗的内周长约 166 mm，接近手围加松量。
        for _ in 0..<3 { viewModel.addBead(twelveMillimeter) }
        XCTAssertEqual(viewModel.usedLengthMm, 204)
        XCTAssertEqual(viewModel.fitState, .good)
    }

    private func material(
        id: Int64,
        name: String,
        spec: String = "10mm",
        price: Double
    ) -> Material {
        Material(
            id: id,
            name: name,
            spec: spec,
            unitPrice: price,
            unit: "颗",
            category: "main_bead",
            fiveElements: "木",
            image: "",
            stock: 100,
            status: "on_shelf"
        )
    }
}

import Testing

@Suite("H5 discovery and native routing parity")
struct DiscoveryParityTests {
    private func promotion(type: String = "ad_landing", value: String = "/c/masters", image: String = "/media/banner.jpg", status: String = "enabled", start: String = "2000-01-01", end: String = "2099-12-31") throws -> HomePromotion {
        let raw: [String: Any] = ["id": 1, "title": "推荐", "placement": "customer_home", "imageUrl": image, "linkType": type, "linkValue": value, "sort": 1, "status": status, "startTime": start, "endTime": end]
        return try JSONDecoder().decode(HomePromotion.self, from: JSONSerialization.data(withJSONObject: raw))
    }
    @Test func configuredRecommendationOpensNativeDirectory() throws {
        let banner = try promotion()
        #expect(banner.route == "/c/masters")
        #expect(banner.isVisible)
        #expect(try promotion(type: "diy", value: "").route == "/c/diy")
        #expect(try promotion(type: "temple", value: "T001").route == "/c/temples/T001")
        #expect(try promotion(type: "activity", value: "25").route == "/c/activities/25")
    }
    @Test func malformedOrExternalDestinationsAreRejected() throws {
        #expect(try promotion(value: "https://example.com").route == nil)
        #expect(try promotion(type: "temple", value: "../profile").route == nil)
        #expect(try promotion(type: "diy", value: "redirect").route == nil)
        #expect(try promotion(image: "//example.com/banner.jpg").isVisible == false)
        #expect(try promotion(image: "https://user:password@example.com/banner.jpg").isVisible == false)
    }
    @Test func unpublishedExpiredAndInvalidSchedulesStayHidden() throws {
        #expect(try promotion(status: "draft").isVisible == false)
        #expect(try promotion(end: "2000-01-02").isVisible == false)
        #expect(try promotion(start: "2099-01-01").isVisible == false)
        #expect(try promotion(start: "bad-date").isVisible == false)
    }
}
