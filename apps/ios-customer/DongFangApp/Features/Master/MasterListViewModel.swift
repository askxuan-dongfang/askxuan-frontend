//
//  MasterListViewModel.swift
//  DongFangApp
//
//  法师列表 ViewModel：分类筛选 + 数据加载。
//  所有筛选状态集中在 ViewModel，filteredMasters 统一应用全部条件。
//

import SwiftUI

@MainActor
final class MasterListViewModel: ObservableObject {
    @Published var masters: [Master] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    @Published var selectedRegionCode = ""
    @Published var selectedTraditionCode = ""
    @Published var searchText = ""
    @Published var selectedPrice = "全部"

    // 所有筛选状态集中管理
    @Published var selectedBeliefCode: String = ""
    @Published var selectedTemple: String = "全部"         // 左侧：所属寺院
    @Published var selectedLevel: String = "全部"          // 左侧：职位

    @Published var beliefOptions: [BeliefFilterOption] = []

    var filterGroups: [(title: String, options: [String])] {
        [
            ("价格区间", ["全部", "200元以下", "200–500元", "500–1000元", "1000元以上"]),
            ("所属寺院", ["全部"] + unique(masters.map(\.templeName))),
            ("职位", ["全部"] + unique(masters.map(\.position)))
        ]
    }

    @Published private var searchCatalog = DirectorySearchCatalog()

    private let apiClient: APIClient
    init(initialBeliefCode: String? = nil, apiClient: APIClient = .shared) {
        self.apiClient = apiClient
        self.selectedBeliefCode = initialBeliefCode == "taoism" ? "daoism" : initialBeliefCode ?? ""
    }

    var filteredMasters: [Master] {
        masters.filter { m in
            (selectedRegionCode.isEmpty || m.regionCode == selectedRegionCode) &&
            (selectedTraditionCode.isEmpty || (m.traditionCodes ?? []).contains(selectedTraditionCode)) &&
            DirectorySearch.matches(searchText, fields: DirectorySearch.fields(master: m, catalog: searchCatalog)) &&
            (selectedBeliefCode.isEmpty || m.beliefCode == selectedBeliefCode) &&
            matchPrice(m) &&
            matchTemple(m, selectedTemple) &&
            matchLevel(m, selectedLevel)
        }
    }

    func clearFilters() {
        selectedRegionCode = ""; selectedTraditionCode = ""; searchText = ""; selectedBeliefCode = ""; selectedTemple = "全部"; selectedLevel = "全部"; selectedPrice = "全部"
    }
    private func matchPrice(_ master: Master) -> Bool {
        guard selectedPrice != "全部" else { return true }
        guard let price = startingPrice(master) else { return false }
        switch selectedPrice {
        case "200元以下": return price < 200
        case "200–500元": return price >= 200 && price < 500
        case "500–1000元": return price >= 500 && price < 1000
        default: return price >= 1000
        }
    }

    // MARK: - 筛选匹配逻辑（与 H5 目录语义一致）

    private func matchTemple(_ m: Master, _ temple: String) -> Bool {
        if temple == "全部" { return true }
        return m.templeName == temple
    }

    private func matchLevel(_ m: Master, _ level: String) -> Bool {
        if level == "全部" { return true }
        return m.position == level
    }

    func startingPrice(_ master: Master) -> Double? {
        let prices = (master.serviceTags ?? []).filter {
            $0.status == nil || $0.status == "" || $0.status == "enabled"
        }.map(\.price).filter { $0 > 0 }
        if let value = prices.min() { return value }
        if let value = master.startPrice, value > 0 { return value }
        return master.consultEnabled && master.consultFee > 0 ? master.consultFee : nil
    }

    private func allRecords() async throws -> [Master] {
        var records: [Master] = []
        var seen = Set<String>()
        var page = 1
        while true {
            try Task.checkCancellation()
            let response: PageResponse<Master> = try await apiClient.request(.masters(type: nil, templeId: nil, manageBy: "platform", serviceCode: nil, page: page, size: 100))
            let next = response.list.filter { seen.insert($0.id).inserted }
            records.append(contentsOf: next)
            if records.count >= response.total { return records }
            if next.isEmpty { throw DirectoryLoadError.incomplete }
            page += 1
        }
    }

    private(set) var hasLoaded = false

    func loadIfNeeded() async { if !hasLoaded { await load() } }

    func load() async {
        guard !isLoading else { return }
        defer { isLoading = false }
        isLoading = true
        errorMessage = nil
        do {
            async let masterRequest: [Master] = allRecords()
            async let beliefRequest: BeliefListResponse = apiClient.request(.beliefs)
            async let serviceRequest: ServiceCatalogResponse = apiClient.request(.serviceTypes)
            async let tagRequest: DirectoryItems<DirectoryTag> = apiClient.request(.directoryTags)
            async let regionRequest: DirectoryItems<DirectoryRegion> = apiClient.request(.directoryRegions)
            let (masterResponse, beliefResponse, services, tags, regions) = try await (masterRequest, beliefRequest, serviceRequest, tagRequest, regionRequest)
            guard !Task.isCancelled else { return }
            hasLoaded = true
            masters = masterResponse
            beliefOptions = [BeliefFilterOption(code: "", name: "全部")] + beliefResponse.list.map { BeliefFilterOption(code: $0.code, name: $0.name) }
            searchCatalog = DirectorySearchCatalog(beliefs: beliefOptions, tags: tags.list, services: services.list.map { ServiceFilterOption(code: $0.code, name: $0.name) }, regions: regions.list)
        } catch {
            guard !Task.isCancelled else { return }
            if beliefOptions.isEmpty { beliefOptions = [BeliefFilterOption(code: "", name: "全部")] }
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func unique(_ values: [String]) -> [String] {
        Array(Set(values.filter { !$0.isEmpty })).sorted()
    }
}
