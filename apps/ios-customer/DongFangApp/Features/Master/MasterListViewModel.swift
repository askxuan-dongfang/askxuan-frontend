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
    @Published var selectedServiceCode: String = ""

    @Published var beliefOptions: [BeliefFilterOption] = []
    @Published private(set) var serviceOptions = [ServiceFilterOption(code: "", name: "全部")]

    var filterGroups: [(title: String, options: [ServiceFilterOption])] {
        [
            ("提供服务", serviceOptions),
            ("价格区间", ["全部", "200元以下", "200–500元", "500–1000元", "1000元以上"].map { ServiceFilterOption(code: $0, name: $0) })
        ]
    }

    @Published private var searchCatalog = DirectorySearchCatalog()
    @Published private var ratingsLoadState = RatingsLoadState.loading

    private enum RatingsLoadState {
        case loading
        case loaded([String: ReviewRatingSummary])
        case unavailable
    }

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
            (selectedServiceCode.isEmpty || (m.serviceTags ?? []).contains {
                $0.serviceCode == selectedServiceCode && ($0.status == nil || $0.status == "" || $0.status == "enabled")
            }) &&
            matchPrice(m)
        }
    }

    func clearFilters() {
        selectedRegionCode = ""; selectedTraditionCode = ""; searchText = ""; selectedBeliefCode = ""; selectedServiceCode = ""; selectedPrice = "全部"
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

    func startingPrice(_ master: Master) -> Double? {
        let prices = (master.serviceTags ?? []).filter {
            $0.status == nil || $0.status == "" || $0.status == "enabled"
        }.map(\.price).filter { $0 > 0 }
        if let value = prices.min() { return value }
        if let value = master.startPrice, value > 0 { return value }
        return master.consultEnabled && master.consultFee > 0 ? master.consultFee : nil
    }

    func previewServices(_ master: Master) -> [ServiceFilterOption] {
        var tags = (master.serviceTags ?? []).filter {
            $0.status == nil || $0.status == "" || $0.status == "enabled"
        }
        if let selectedIndex = tags.firstIndex(where: { $0.serviceCode == selectedServiceCode }) {
            tags.insert(tags.remove(at: selectedIndex), at: 0)
        }
        return tags.prefix(2).map { tag in
            serviceOptions.first { $0.code == tag.serviceCode }
                ?? ServiceFilterOption(code: tag.serviceCode, name: ServiceType.from(serviceCode: tag.serviceCode)?.rawValue ?? tag.serviceCode)
        }
    }

    func ratingState(for master: Master) -> MasterCardRatingState {
        switch ratingsLoadState {
        case .loading: return .loading
        case .unavailable: return .unavailable
        case .loaded(let summaries): return summaries[master.id]?.masterCardState ?? .unrated
        }
    }

    private func loadRatings() async {
        ratingsLoadState = .loading
        do {
            let summaries: [ReviewRatingSummary] = try await apiClient.request(.reviewRatings)
            guard !Task.isCancelled else { return }
            // One public batch covers the directory, independent of filters and pagination.
            let masters = summaries.filter { $0.kind == "master" }
            ratingsLoadState = .loaded(Dictionary(masters.map { ($0.code, $0) }, uniquingKeysWith: { _, latest in latest }))
        } catch {
            guard !Task.isCancelled else { return }
            ratingsLoadState = .unavailable
        }
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
        async let ratingsRequest: Void = loadRatings()
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
            serviceOptions = [ServiceFilterOption(code: "", name: "全部")] + services.list.map { ServiceFilterOption(code: $0.code, name: $0.name) }
            searchCatalog = DirectorySearchCatalog(beliefs: beliefOptions, tags: tags.list, services: serviceOptions, regions: regions.list)
        } catch {
            guard !Task.isCancelled else { return }
            if beliefOptions.isEmpty { beliefOptions = [BeliefFilterOption(code: "", name: "全部")] }
            self.errorMessage = error.localizedDescription
        }
        await ratingsRequest
    }
}
