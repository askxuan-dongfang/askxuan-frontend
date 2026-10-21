import Testing
import Foundation
@testable import DongFangApp

struct H5ParityTests {
    @Test(arguments: [("0.01", Int64(1)), ("12.34", Int64(1234)), ("100", Int64(10000))])
    func withdrawalUsesExactCents(_ pair: (String, Int64)) { #expect(CreatorWithdrawalInput.cents(pair.0) == pair.1) }
    @Test(arguments: ["-1", "0", "NaN", "1e2", "1.001", " 1", "92233720368547759", "9,99"])
    func rejectsInvalidWithdrawalAmounts(_ amount: String) { #expect(CreatorWithdrawalInput.cents(amount) == nil) }
    @Test @MainActor func regionAndTraditionIntersectWithBeliefAndService() throws {
        let payload = #"{"id":"1","name":"目录示例","regionCode":"southeast_asia","traditionCodes":["theravada"],"beliefCode":"han_buddhism","serviceCodes":["S001"]}"#
        let temple = try JSONDecoder().decode(Temple.self, from: Data(payload.utf8))
        let model = TempleListViewModel()
        model.temples = [temple]; model.selectedRegionCode = "southeast_asia"
        model.selectedTraditionCode = "theravada"; model.selectedServiceCode = "S001"
        #expect(model.filteredTemples.count == 1)
        model.selectedBeliefCode = "daoism"
        #expect(model.filteredTemples.isEmpty)
        model.selectedBeliefCode = ""; model.selectedRegionCode = "mainland"
        #expect(model.filteredTemples.isEmpty)
    }
    @Test @MainActor func priceFilterUsesEnabledStartingPriceAndH5Boundaries() throws {
        let payload = #"{"id":"1","serviceTags":[{"serviceCode":"S001","price":200,"status":"enabled"},{"serviceCode":"S002","price":10,"status":"disabled"}]}"#
        let master = try JSONDecoder().decode(Master.self, from: Data(payload.utf8))
        let model = MasterListViewModel(); model.masters = [master]
        model.selectedPrice = "200元以下"; #expect(model.filteredMasters.isEmpty)
        model.selectedPrice = "200–500元"; #expect(model.filteredMasters.count == 1)
        model.clearFilters()
        #expect(model.filteredMasters.count == 1)
        #expect(model.startingPrice(master) == 200)
    }
}

@MainActor
struct MasterServiceFilterTests {
    private func master(status: String? = "enabled") -> Master {
        var master = Master(id: "service-match", dharmaName: "目录师傅", layName: "", templeId: "T1",
                            templeName: "目录寺院", position: "客堂法师", beliefCode: "han_buddhism",
                            sect: "禅宗", type: "佛教", authStatus: "approved", specialties: ["禅修"],
                            avatar: "", rating: 5, consultEnabled: false)
        master.regionCode = "taiwan"
        master.traditionCodes = ["chan"]
        master.serviceTags = [MasterServiceTag(serviceCode: "S001", price: 200, status: status)]
        return master
    }

    @Test(arguments: [(nil, true), ("", true), ("enabled", true), ("disabled", false), ("off_shelf", false), ("pending", false)] as [(String?, Bool)])
    func serviceFilterRequiresExactCodeAndAvailableStatus(_ sample: (String?, Bool)) {
        let model = MasterListViewModel()
        model.masters = [master(status: sample.0)]
        model.selectedServiceCode = "S001"
        #expect(model.filteredMasters.count == (sample.1 ? 1 : 0))
        model.selectedServiceCode = "S002"
        #expect(model.filteredMasters.isEmpty)
        model.selectedServiceCode = ""
        #expect(model.filteredMasters.count == 1)
    }

    @Test func unavailableOrMissingServiceCannotMatch() {
        let model = MasterListViewModel()
        var noServices = master()
        noServices.serviceTags = nil
        model.masters = [noServices]
        model.selectedServiceCode = "S001"
        #expect(model.filteredMasters.isEmpty)
        noServices.serviceTags = []
        model.masters = [noServices]
        #expect(model.filteredMasters.isEmpty)
    }

    @Test func previewKeepsSelectedServiceVisibleWithoutChangingPriceOrOriginalOrder() {
        let model = MasterListViewModel()
        var record = master()
        record.serviceTags = [
            MasterServiceTag(serviceCode: "S099", price: 1, status: "disabled"),
            MasterServiceTag(serviceCode: "S002", price: 200, status: "enabled"),
            MasterServiceTag(serviceCode: "S003", price: 300, status: nil),
            MasterServiceTag(serviceCode: "S001", price: 500, status: "")
        ]
        let original = record.serviceTags
        #expect(model.previewServices(record).map(\.code) == ["S002", "S003"])
        model.selectedServiceCode = "S001"
        #expect(model.previewServices(record).map(\.code) == ["S001", "S002"])
        #expect(model.startingPrice(record) == 200)
        #expect(record.serviceTags == original)
        model.selectedServiceCode = "S099"
        #expect(model.previewServices(record).map(\.code) == ["S002", "S003"])
        model.clearFilters()
        #expect(model.previewServices(record).map(\.code) == ["S002", "S003"])
    }

    @Test func serviceIntersectsAllDirectoryConditionsAndClearRestoresResults() {
        let model = MasterListViewModel()
        model.masters = [master()]
        model.selectedServiceCode = "S001"
        model.selectedBeliefCode = "han_buddhism"
        model.selectedTraditionCode = "chan"
        model.selectedRegionCode = "taiwan"
        model.searchText = "禪修 目录"
        model.selectedPrice = "200–500元"
        #expect(model.filteredMasters.map(\.id) == ["service-match"])

        model.selectedBeliefCode = "daoism"
        #expect(model.filteredMasters.isEmpty)
        model.selectedBeliefCode = "han_buddhism"
        model.selectedTraditionCode = "pure_land"
        #expect(model.filteredMasters.isEmpty)
        model.selectedTraditionCode = "chan"
        model.selectedRegionCode = "mainland"
        #expect(model.filteredMasters.isEmpty)
        model.selectedRegionCode = "taiwan"
        model.searchText = "不存在"
        #expect(model.filteredMasters.isEmpty)
        model.searchText = "禪修"
        model.selectedPrice = "200元以下"
        #expect(model.filteredMasters.isEmpty)
        model.selectedServiceCode = "disabled-service"

        model.clearFilters()
        #expect(model.selectedServiceCode.isEmpty)
        #expect(model.selectedBeliefCode.isEmpty)
        #expect(model.selectedTraditionCode.isEmpty)
        #expect(model.selectedRegionCode.isEmpty)
        #expect(model.searchText.isEmpty)
        #expect(model.selectedPrice == "全部")
        #expect(model.filteredMasters.map(\.id) == ["service-match"])
    }

    @Test func catalogNamesUseDistinctCodesAcrossEveryDirectoryPage() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MasterServiceCatalogProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let client = APIClient(session: session)
        client.configureBaseURL(try #require(URL(string: "https://master-service-filter.invalid/api/v1")))
        let model = MasterListViewModel(apiClient: client)
        await model.load()

        #expect(model.errorMessage == nil)
        #expect(model.masters.map(\.id) == ["catalog-first", "catalog-last"])
        #expect(model.filterGroups.map(\.title) == ["提供服务", "价格区间"])
        #expect(model.serviceOptions.map(\.code) == ["", "CUSTOM-ONE", "CUSTOM-TWO", "CATALOG-ONLY"])
        #expect(model.serviceOptions.map(\.name) == ["全部", "祈福", "祈福", "供灯"])
        model.selectedServiceCode = "CUSTOM-ONE"
        #expect(model.filteredMasters.map(\.id) == ["catalog-first"])
        #expect(model.previewServices(try #require(model.filteredMasters.first)).first?.name == "祈福")
        model.selectedServiceCode = "CUSTOM-TWO"
        #expect(model.filteredMasters.map(\.id) == ["catalog-last"], "An identically named disabled tag on the first record must not match")
        model.selectedServiceCode = "CATALOG-ONLY"
        #expect(model.filteredMasters.isEmpty)
        model.clearFilters()
        #expect(Set(model.filteredMasters.map(\.position)) == ["客堂法师", "独立道长"])
        model.searchText = "祈福 禪修"
        #expect(model.filteredMasters.map(\.id) == ["catalog-first"], "Catalog service names and specialties remain searchable")
    }
}

/// A deterministic public catalog transport. No production endpoint or account is used.
private final class MasterServiceCatalogProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        guard let url = request.url else { return }
        let list: [[String: Any]]
        let page = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "page" }?.value ?? "1"
        switch url.path {
        case "/api/v1/masters":
            let isFirst = page == "1"
            list = [["id": isFirst ? "catalog-first" : "catalog-last",
                     "dharmaName": isFirst ? "首位师傅" : "末页师傅",
                     "position": isFirst ? "客堂法师" : "独立道长",
                     "templeName": isFirst ? "目录寺院" : "",
                     "specialties": isFirst ? ["禅修"] : ["讲解"],
                     "serviceTags": isFirst ? [
                        ["serviceCode": "CUSTOM-ONE", "price": 200, "status": "enabled"],
                        ["serviceCode": "CUSTOM-TWO", "price": 100, "status": "disabled"],
                        ["serviceCode": "UNLISTED", "price": 300, "status": "enabled"]
                     ] : [["serviceCode": "CUSTOM-TWO", "price": 220, "status": ""]]]]
        case "/api/v1/service-types":
            list = [("CUSTOM-ONE", "祈福"), ("CUSTOM-TWO", "祈福"), ("CATALOG-ONLY", "供灯")].map {
                ["code": $0.0, "name": $0.1, "category": "service", "priceRange": ""]
            }
        case "/api/v1/beliefs", "/api/v1/beliefs/directory-tags", "/api/v1/regions":
            list = []
        default:
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        do {
            let data = try JSONSerialization.data(withJSONObject: ["code": 0, "message": "fixture", "data": [
                "list": list, "total": url.path.hasSuffix("/masters") ? 2 : list.count,
                "page": Int(page) ?? 1, "size": url.path.hasSuffix("/masters") ? 1 : 100
            ]])
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
}
