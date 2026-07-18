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
