import XCTest
import UIKit
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

@MainActor
struct DiyCanvasEditorTests {
    private func material(id: Int64, stock: Int = 100, category: String = "main_bead") -> Material {
        Material(id: id, name: "测试材料", spec: "10mm", unitPrice: Double(id) * 10, unit: "颗", category: category,
                 fiveElements: "木", image: "", stock: stock, status: "on_shelf")
    }

    @Test func fitToleranceMatchesBothEndpointsAndEmptyState() {
        let fixtures: [(Double, Bool, DiyFitFeedback.State)] = [(0, false, .empty), (159.9, true, .short), (160, true, .good), (176, true, .good), (176.1, true, .long)]
        for (inner, hasBeads, expected) in fixtures {
            #expect(DiyFitFeedback(innerMm: inner, wristMm: 160, allowanceMm: 8, hasBeads: hasBeads).state == expected)
        }
        #expect(DiyFitFeedback(innerMm: 159.9, wristMm: 160, allowanceMm: 8, hasBeads: true).detail == "还差约 9 mm")
    }

    @Test func replacementPreservesFullBraceletIdentityAndSupportsUndoAndDraftRestore() throws {
        let suite = "DiyCanvasEditorTests.\(UUID().uuidString)"
        let store = try #require(UserDefaults(suiteName: suite))
        defer { store.removePersistentDomain(forName: suite) }
        let model = DiyViewModel(draftStore: store)
        let wood = material(id: 1), jade = material(id: 2, stock: 1)
        for _ in 0..<60 { model.addBead(wood) }
        let identities = model.beadSlots.map(\.id)
        #expect(model.replaceBead(id: identities[26], with: jade))
        #expect(model.beadSlots.map(\.id) == identities)
        #expect(model.beadSlots[26].materialId == jade.id)
        #expect(model.totalPrice == 610)
        #expect(!model.replaceBead(id: identities[27], with: jade))
        #expect(model.replaceBead(id: identities[26], with: jade))
        #expect(!model.replaceBead(id: identities[26], with: material(id: 3, category: "cord")))
        model.undo(); model.undo()
        #expect(model.beadSlots[26].materialId == wood.id)
        model.redo()
        let restored = DiyViewModel(draftStore: store)
        #expect(restored.beadSlots.map(\.id) == identities)
        #expect(restored.beadSlots[26].materialId == jade.id)
    }

    @Test func usedCategoryFollowsUndoAndIncludesCord() throws {
        let suite = "DiyCanvasUsedTests.\(UUID().uuidString)"
        let store = try #require(UserDefaults(suiteName: suite))
        defer { store.removePersistentDomain(forName: suite) }
        let model = DiyViewModel(draftStore: store)
        let wood = material(id: 1), jade = material(id: 2), cord = material(id: 3, category: "cord")
        model.materials = [wood, jade, cord]
        model.selectCategory("used")
        #expect(model.filteredMaterials.isEmpty)
        model.addBead(wood); model.setCord(cord)
        #expect(model.filteredMaterials.map(\.id) == [1, 3])
        model.undo()
        #expect(model.filteredMaterials.map(\.id) == [1])
    }
}

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

@MainActor
final class NativeBrandTests: XCTestCase {
    func testBrandAssetsResolveInBothAppearances() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            for name in ["brand-logo", "brand-atelier", "launch-brand"] {
                XCTAssertNotNil(UIImage(named: name, in: Bundle.main, compatibleWith: traits), "Missing \(name) / \(style)")
            }
            XCTAssertNotNil(UIColor(named: "LaunchBackground", in: Bundle.main, compatibleWith: traits))
        }
    }
    func testDirectorySymbolsAreAvailableOnTheSupportedRuntime() {
        for name in ["sun.max", "mountain.2", "leaf", "house.lodge", "building.columns", "person.crop.circle", "sparkles"] {
            XCTAssertNotNil(UIImage(systemName: name), "Missing SF Symbol: \(name)")
        }
    }
}


@MainActor
struct ConsecrationContractTests {
    @Test func emptyDesignPlazaAcceptsNullList() throws {
        let page = try JSONDecoder().decode(PageResponse<DiyDesign>.self, from: Data(#"{"total":0,"list":null,"page":1,"size":20}"#.utf8))
        #expect(page.list.isEmpty)
        #expect(page.total == 0)
    }
    @Test func orderRetainsCentsAndCompletedCertificate() throws {
        let raw = #"{"id":2,"orderNo":"DIY-test","designId":1,"status":"blessing_in_progress","materialFee":56,"blessFee":39.5,"totalFee":95.5,"blessingTask":{"id":2,"taskNo":"BT-test","diyOrderNo":"DIY-test","templeCode":"T001","masterCode":"M001","status":"completed","certificateUrls":["https://example.test/cert.png"],"assignTime":"2026-10-19","completeTime":"2026-10-19"}}"#
        let order = try JSONDecoder().decode(DiyOrder.self, from: Data(raw.utf8))
        #expect(order.totalFeeText == "¥95.50")
        #expect(order.statusDisplayText == "开光中")
        #expect(order.blessingTask?.certificateUrls?.count == 1)
    }
    @Test func existingOfferingRetainsProviderAndExactPrice() throws {
        let data = Data(#"{"id":7,"serviceCode":"consecration:temple:7","sourceServiceCode":"S006","providerType":"temple","serviceName":"开光","templeName":"测试寺院","price":39.50,"status":"on_shelf"}"#.utf8)
        let service = try JSONDecoder().decode(BlessingService.self, from: data)
        #expect(service.isConsecration)
        #expect(service.providerName == "测试寺院")
        #expect(service.priceText == "¥39.50")
        let request = DiyDesignOrderCreateRequest(userId: "test", blessServiceCode: service.serviceCode, addressId: 1, expectedBlessFee: service.price)
        let body = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])
        #expect(body["expectedBlessFee"] as? Double == 39.50)
        #expect(body["blessServiceCode"] as? String == "consecration:temple:7")
    }
    @Test func legacyMarkupIsNotSelectableAndZeroPriceIsPreserved() throws {
        let legacy = try JSONDecoder().decode(BlessingService.self, from: Data(#"{"id":1,"serviceName":"加持","price":168,"status":"on_shelf"}"#.utf8))
        #expect(!legacy.isConsecration)
        let request = DiyOrderCreateRequest(userId: "test", designId: 1, items: [], blessServiceCode: nil, addressId: 1, expectedBlessFee: 0)
        let body = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])
        #expect(body["expectedBlessFee"] as? Double == 0)
        #expect(body["blessServiceCode"] == nil)
    }
}
