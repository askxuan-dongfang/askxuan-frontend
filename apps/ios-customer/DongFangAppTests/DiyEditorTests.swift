import XCTest
import UIKit
@testable import DongFangApp

@MainActor
struct DiyPublicationContractTests {
    private let legacy = #"{"id":99,"userId":"99029","name":"既有设计","totalPrice":28,"status":"private","orderNo":"DIY-PAID","orderStatus":"in_making"}"#

    @Test func existingOrderDoesNotGrantPublicationWithoutAuthoritativeEligibility() throws {
        let item = try JSONDecoder().decode(MyDesignItem.self, from: Data(legacy.utf8))
        #expect(item.hasOrder)
        #expect(!item.canPublish)
        #expect(item.publicationMessage == "发布资格暂不可用，请刷新后重试")
    }

    @Test func publicationSnapshotAndCopyAttributionDecodeIndependentlyOfEligibility() throws {
        let data = Data(#"{"id":100,"userId":"99029","name":"私有副本","totalPrice":28,"status":"private","sourceDesignId":99,"sourcePublicationId":7100,"publicationEligibility":{"canPublish":false,"reason":"order_required","message":"请先完成定制订单付款和确认"},"draftChanged":false}"#.utf8)
        let copy = try JSONDecoder().decode(DiyDesign.self, from: data)
        #expect(copy.sourceDesignId == 99)
        #expect(copy.sourcePublicationId == 7100)
        #expect(copy.publication == nil)
        #expect(copy.publicationEligibility?.canPublish == false)
        let redecoded = try JSONDecoder().decode(DiyDesign.self, from: JSONEncoder().encode(copy))
        #expect(redecoded.sourcePublicationId == 7100)
    }

    @Test func changedPrivateDraftCanCoexistWithPublishedConfirmedSnapshot() throws {
        let data = Data(#"{"id":99,"name":"新草稿","totalPrice":56,"status":"public","draftChanged":true,"publication":{"id":7100,"designRevision":1,"materialFee":28,"publishedAt":"2026-10-20T10:00:00Z"},"publicationEligibility":{"canPublish":false,"reason":"design_changed","message":"当前草稿尚未完成订单确认"}}"#.utf8)
        let design = try JSONDecoder().decode(DiyDesign.self, from: data)
        #expect(design.status == "public")
        #expect(design.draftChanged == true)
        #expect(design.publication?.materialFee == 28)
        #expect(design.totalPrice == 56)
        #expect(design.publicationEligibility?.reason == "design_changed")
    }

    @Test func publicViewingAlwaysRequestsConfirmedSnapshotWhileEditingUsesDraft() {
        #expect(Endpoint.diyPublishedDesignById(99).path == Endpoint.diyDesignById(99).path)
        #expect(Endpoint.diyPublishedDesignById(99).queryItems == [URLQueryItem(name: "view", value: "published")])
        #expect(Endpoint.diyDesignById(99).queryItems == nil)
    }

    @Test func savingDraftDoesNotSendPublicationStatusOrForgedAttribution() throws {
        let request = DiyDesignSaveRequest(userId: "99029", name: "草稿", designData: "{}", totalPrice: 28, blessServiceCode: nil)
        let encoded = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])
        #expect(encoded["status"] == nil)
        #expect(encoded["publication"] == nil)
        #expect(encoded["sourcePublicationId"] == nil)
    }

    @Test func unknownEligibilityReasonKeepsServiceExplanation() {
        let value = DiyPublicationEligibility(canPublish: false, reason: "future_gate", message: "服务端提供的新限制", orderId: nil, orderNo: nil, designRevision: nil)
        #expect(value.localizedMessage == "服务端提供的新限制")
        #expect(!value.canPublish)
    }

    @Test func missingEligibilityBlocksPublicationBeforeNetworkMutation() async throws {
        let suite = "DiyPublicationTests.\(UUID().uuidString)"
        let store = try #require(UserDefaults(suiteName: suite))
        defer { store.removePersistentDomain(forName: suite) }
        let model = DiyViewModel(draftStore: store)
        model.currentDesign = try JSONDecoder().decode(DiyDesign.self, from: Data(legacy.utf8))
        await model.setPublication(true)
        #expect(model.currentDesign?.status == "private")
        #expect(model.errorMessage == "发布资格暂不可用，请刷新后重试")
        #expect(!model.isSubmitting)
    }
}

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
struct MasterDirectoryRefinementTests {
    private func master() -> Master {
        var result = Master(id: "refinement", dharmaName: "验收师傅", layName: "", templeId: "", templeName: "", position: "独立师傅", sect: "禅宗", type: "佛教", authStatus: "已认证", specialties: ["禅修"], avatar: "", rating: 5, startPrice: 900, consultEnabled: false)
        result.serviceTags = [
            MasterServiceTag(serviceCode: "S001", price: 180, status: "enabled"),
            MasterServiceTag(serviceCode: "S002", price: 900, status: "enabled"),
            MasterServiceTag(serviceCode: "S003", price: 10, status: "disabled")
        ]
        return result
    }

    @Test func priceAndTextSearchRemainIndependentOfServiceSelection() {
        let model = MasterListViewModel()
        let record = master()
        model.masters = [record]
        #expect(model.startingPrice(record) == 180)
        model.selectedPrice = "200元以下"
        model.searchText = "禪修"
        #expect(model.filteredMasters.map(\.id) == ["refinement"])
        model.selectedPrice = "500–1000元"
        #expect(model.filteredMasters.isEmpty)
        model.clearFilters()
        #expect(model.filteredMasters.count == 1)
    }

    @Test func serviceAndSpecialtyWordsStaySearchable() {
        let catalog = DirectorySearchCatalog(services: [
            ServiceFilterOption(code: "S001", name: "祈福"),
            ServiceFilterOption(code: "S002", name: "供灯"),
            ServiceFilterOption(code: "S003", name: "已停服务")
        ])
        let fields = DirectorySearch.fields(master: master(), catalog: catalog)
        #expect(DirectorySearch.matches("禪修 祈福", fields: fields))
        #expect(DirectorySearch.matches("供燈", fields: fields))
        #expect(!DirectorySearch.matches("已停服务", fields: fields))
    }
}

@MainActor
struct NativePublicSearchTests {
    private func page(_ rows: [[String: Any]], total: Int? = nil, number: Int = 1, size: Int = 2) throws -> NativeSearchPage {
        try JSONDecoder().decode(NativeSearchPage.self, from: JSONSerialization.data(withJSONObject: ["list": rows, "total": total ?? rows.count, "page": number, "size": size]))
    }
    @Test func traditionalAndSimplifiedKeywordsMatchAcrossFieldsWithAND() {
        #expect(NativePublicSearch.matches(" 臺灣  祈福 ", fields: ["台湾", "祈福服务"]))
        #expect(NativePublicSearch.matches("ＤＩＹ 蓮花", fields: ["diy", "莲花挂件"]))
        #expect(!NativePublicSearch.matches("台湾 祈福", fields: ["大陆", "祈福"]))
        #expect(!NativePublicSearch.matches("  ", fields: ["任意内容"]))
    }
    @Test func readsEveryCappedPageAndDeduplicatesPublicRecords() async throws {
        var requested: [Int] = []
        let records = try await NativePublicSearch.allPages({ .diyDesigns(page: $0, size: 100) }) { endpoint in
            guard case .diyDesigns(let number, _) = endpoint else { throw NativeSearchFailure.incompletePage }
            requested.append(number)
            if number == 1 { return try page([["id": 1, "name": "第一份"], ["id": 2, "name": "第二份"]], total: 3) }
            return try page([["id": 2, "name": "第二份"], ["id": 3, "name": "末页繁體作品"]], total: 3, number: 2)
        }
        #expect(requested == [1, 2])
        #expect(records.map(\.id) == ["1", "2", "3"])
        #expect(NativePublicSearch.matches("繁体", fields: records[2].searchableFields))
    }
    @Test func incompleteOrRepeatedPagesAreFailuresInsteadOfEmptyResults() async throws {
        for repeated in [false, true] {
            do {
                _ = try await NativePublicSearch.allPages({ .diyDesigns(page: $0, size: 100) }) { endpoint in
                    guard case .diyDesigns(let number, _) = endpoint else { throw NativeSearchFailure.incompletePage }
                    return try page(number == 1 || repeated ? [["id": "1", "name": "首屏"]] : [], total: 2, number: number)
                }
                Issue.record("Incomplete public indexes must not be reported as complete")
            } catch { #expect(error is NativeSearchFailure) }
        }
    }
    @Test func acceptsNullEmptyListsButRejectsNullMissingPages() async throws {
        let empty = try JSONDecoder().decode(NativeSearchPage.self, from: Data(#"{"list":null,"total":0,"page":1,"size":100}"#.utf8))
        let result = try await NativePublicSearch.allPages({ .diyDesigns(page: $0, size: 100) }) { _ in empty }
        #expect(result.isEmpty)
        let incomplete = try JSONDecoder().decode(NativeSearchPage.self, from: Data(#"{"list":null,"total":2,"page":1,"size":100}"#.utf8))
        do {
            _ = try await NativePublicSearch.allPages({ .diyDesigns(page: $0, size: 100) }) { _ in incomplete }
            Issue.record("Null records cannot satisfy a non-zero total")
        } catch { #expect(error is NativeSearchFailure) }
    }
    @Test func keepsFullDescriptionsAndExcludesDisabledServices() throws {
        let record = try page([["id": "1", "description": String(repeating: "很长的介绍", count: 100) + "末尾关键词", "serviceTags": [["serviceCode": "S001", "status": "enabled"], ["serviceCode": "S002", "status": "disabled"]]]]).list[0]
        #expect(NativePublicSearch.matches("末尾关键词", fields: record.searchableFields))
        #expect(record.searchableFields.contains("S001"))
        #expect(!record.searchableFields.contains("S002"))
    }
    @Test func categoryFailuresRetryIndependentlyAndOldSearchCannotOverwriteNew() async throws {
        var templeCalls = 0
        var productFailure = true
        let model = NativeGlobalSearchModel { endpoint in
            switch endpoint {
            case .temples:
                templeCalls += 1
                let number = templeCalls
                if number == 1 { try? await Task.sleep(for: .milliseconds(120)) }
                return try page([["id": String(number), "name": number == 1 ? "旧结果" : "新结果"]])
            case .products:
                if productFailure { throw NativeSearchFailure.incompletePage }
                return try page([["id": "3", "name": "新结果商品"]])
            default: return try page([])
            }
        }
        model.submit("旧结果")
        while templeCalls == 0 { await Task.yield() }
        model.submit("新结果")
        try await Task.sleep(for: .milliseconds(220))
        #expect(model.sections[.temples]?.results.first?.title == "新结果")
        #expect(model.sections[.products]?.error != nil)
        productFailure = false
        model.retry(.products)
        try await Task.sleep(for: .milliseconds(50))
        #expect(model.sections[.products]?.error == nil)
        #expect(model.sections[.products]?.results.first?.title == "新结果商品")
        #expect(templeCalls == 2)
        model.cancel()
    }
}

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

    @Test func studioCategoryOverridesLegacyClassificationWithoutChangingOrderSubtype() throws {
        let suite = "DiyStudioCategoryTests.\(UUID().uuidString)"
        let store = try #require(UserDefaults(suiteName: suite))
        defer { store.removePersistentDomain(forName: suite) }
        let model = DiyViewModel(draftStore: store)
        var fixed = material(id: 1, category: "pendant")
        var moving = material(id: 2, category: "buddha_head")
        fixed.renderAssets = #"{"studio":{"version":1,"part":"bead","motion":"fixed","source":"template","templateId":"round","dimensionsMm":[10,10,10],"rotation":[0,0,0],"mount":[0,0,0],"connectorMm":0,"rigidFraction":0.4,"photos":[],"previewConfirmed":true}}"#
        moving.renderAssets = #"{"studio":{"version":1,"part":"hanging","motion":"rigid","source":"template","templateId":"buddha_head","dimensionsMm":[10,10,10],"rotation":[0,0,0],"mount":[0,0,-0.5],"connectorMm":3,"rigidFraction":0.4,"photos":[],"previewConfirmed":true}}"#
        let legacy = material(id: 3, category: "tassel"), cord = material(id: 4, category: "cord")
        model.materials = [fixed, moving, legacy, cord]
        #expect(model.categories.map(\.code) == ["used", "all", "bead", "hanging", "cord"])
        model.selectCategory("bead")
        #expect(model.filteredMaterials.map(\.id) == [1])
        model.selectCategory("hanging")
        #expect(model.filteredMaterials.map(\.id) == [2, 3])
        model.selectCategory("cord")
        #expect(model.filteredMaterials.map(\.id) == [4])
        model.addBead(fixed); model.addBead(moving)
        #expect(model.beadSlots.map(\.subtype) == ["pendant", "buddha_head"])
        #expect(model.designDocument().items.map(\.subtype) == ["pendant", "buddha_head"])
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


@MainActor
struct DiyDirectDragTests {
    private var envelope: DiyDragEnvelope {
        DiyDragEnvelope(points: [CGPoint(x: 50, y: 50), CGPoint(x: 250, y: 50), CGPoint(x: 250, y: 250), CGPoint(x: 50, y: 250)])
    }
    @Test func hullIncludesInnerOpeningAndAccessoryExtents() {
        let loop = (0..<64).map { i in CGPoint(x: 150 + 100*cos(Double(i) * .pi / 32), y: 150 + 60*sin(Double(i) * .pi / 32)) }
        let actual = DiyDragEnvelope(points: loop + [CGPoint(x: 130,y: 270),CGPoint(x: 170,y: 270)])
        #expect(actual.distance(to: CGPoint(x: 150,y: 150)) == 0)
        #expect(actual.distance(to: CGPoint(x: 150,y: 265)) == 0)
        #expect(actual.distance(to: CGPoint(x: 150,y: 294)) == 24)
        #expect(actual.distance(to: CGPoint(x: 150,y: 294.1)) > 24)
    }
    @Test func activationOffsetAndBoundaryAreSharedAcrossClients() {
        var drag = DiyBeadDragSession(id: "a", initialIndex: 0, pointer: CGPoint(x: 240,y: 150), anchor: CGPoint(x: 250,y: 150), envelope: envelope)
        drag.update(pointer: CGPoint(x: 245.99,y: 150), targetIndex: 1)
        #expect(drag.completion(endedNormally: true) == .unchanged)
        drag.update(pointer: CGPoint(x: 246,y: 150), targetIndex: 1)
        #expect(drag.completion(endedNormally: true) == .move("a",1))
        drag.update(pointer: CGPoint(x: 264,y: 150), targetIndex: 1)
        #expect(!drag.deletionArmed)
        drag.update(pointer: CGPoint(x: 264.01,y: 150), targetIndex: 1)
        #expect(drag.deletionArmed)
        #expect(drag.completion(endedNormally: true) == .remove("a"))
    }
    @Test func ReturnInsideAndCancellationNeverDelete() {
        var drag = DiyBeadDragSession(id: "a", initialIndex: 0, pointer: CGPoint(x: 250,y: 150), anchor: CGPoint(x: 250,y: 150), envelope: envelope)
        drag.update(pointer: CGPoint(x: 300,y: 150), targetIndex: 1)
        #expect(drag.deletionArmed)
        #expect(drag.completion(endedNormally: false) == .unchanged)
        drag.update(pointer: CGPoint(x: 274,y: 150), targetIndex: 0)
        #expect(!drag.deletionArmed)
        #expect(drag.completion(endedNormally: true) == .unchanged)
        drag.update(pointer: CGPoint(x: 150,y: 150), targetIndex: 1)
        #expect(!drag.deletionArmed)
        #expect(drag.completion(endedNormally: true) == .move("a",1))
    }
    @Test func viewingAWorkDoesNotReplaceTheEditorsLocalDraft() throws {
        let suite = "DiyReadonlyTests.\(UUID().uuidString)", store = try #require(UserDefaults(suiteName: suite))
        defer { store.removePersistentDomain(forName: suite) }
        let model = DiyViewModel(draftStore: store)
        let material = Material(id: 1, name: "木珠", spec: "10mm", unitPrice: 10, unit: "颗", category: "main_bead", fiveElements: "木", image: "", stock: 100, status: "on_shelf")
        model.addBead(material)
        let original = model.beadSlots.map(\.id)
        let other = DiyDesignDocument(wristSizeMm: 180, beads: [DiyBeadSlot(material: material, position: 0)], items: [])
        let raw = try #require(String(data: JSONEncoder().encode(other), encoding: .utf8))
        model.restoreDesignData(raw, persist: false)
        #expect(model.wristSizeMm == 180)
        let restored = DiyViewModel(draftStore: store)
        #expect(restored.beadSlots.map(\.id) == original)
        #expect(restored.wristSizeMm == 160)
    }

    @Test func completedRemovalHasOneUndoAndRestoresIdentity() throws {
        let suite = "DiyDirectDragTests.\(UUID().uuidString)", store = try #require(UserDefaults(suiteName: suite))
        defer { store.removePersistentDomain(forName: suite) }
        let model = DiyViewModel(draftStore: store)
        let material = Material(id: 1, name: "木珠", spec: "10mm", unitPrice: 10, unit: "颗", category: "main_bead", fiveElements: "木", image: "", stock: 100, status: "on_shelf")
        model.addBead(material); model.addBead(material)
        let before = model.beadSlots.map(\.id), id = try #require(before.first)
        var drag = DiyBeadDragSession(id: id, initialIndex: 0, pointer: CGPoint(x: 250,y: 150), anchor: CGPoint(x: 250,y: 150), envelope: envelope)
        for x in [260.0,280,300] { drag.update(pointer: CGPoint(x:x,y:150), targetIndex:1) }
        #expect(model.beadSlots.map(\.id) == before)
        if case .remove(let removed) = drag.completion(endedNormally: true) { model.removeBead(id: removed) }
        #expect(model.beadSlots.count == 1)
        model.undo(); #expect(model.beadSlots.map(\.id) == before)
        model.redo(); #expect(model.beadSlots.map(\.id) == Array(before.dropFirst()))
    }
}
