//
//  TempleListViewModel.swift
//  DongFangApp
//
//  寺院列表 ViewModel：教派筛选 + 服务筛选 + 数据加载。
//  所有筛选状态集中在 ViewModel，filteredTemples 统一应用全部条件。
//

import SwiftUI

@MainActor
final class TempleListViewModel: ObservableObject {
    @Published var temples: [Temple] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    @Published var selectedRegionCode = ""
    @Published var selectedTraditionCode = ""
    @Published var searchText = ""

    // 所有筛选状态集中管理
    @Published var selectedBeliefCode: String = ""
    @Published var selectedServiceCode: String = ""     // 左侧标准服务编码筛选
    @Published var beliefOptions: [BeliefFilterOption] = []
    @Published var serviceOptions: [ServiceFilterOption] = []

    private let apiClient: APIClient
    init(initialSect: String? = nil, initialBeliefCode: String? = nil, apiClient: APIClient = .shared) {
        self.apiClient = apiClient
        self.selectedBeliefCode = initialBeliefCode == "taoism" ? "daoism" : initialBeliefCode ?? ""
    }

    var filteredTemples: [Temple] {
        temples.filter { t in
            (selectedRegionCode.isEmpty || t.regionCode == selectedRegionCode) &&
            (selectedTraditionCode.isEmpty || (t.traditionCodes ?? []).contains(selectedTraditionCode)) &&
            (searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (t.name + " " + t.region).localizedStandardContains(searchText.trimmingCharacters(in: .whitespacesAndNewlines))) &&
            (selectedBeliefCode.isEmpty || t.beliefCode == selectedBeliefCode) &&
            (selectedServiceCode.isEmpty || (t.serviceCodes ?? []).contains(selectedServiceCode))
        }
    }

    private func allRecords() async throws -> [Temple] {
        var records: [Temple] = []
        var seen = Set<String>()
        var page = 1
        while true {
            try Task.checkCancellation()
            let response: PageResponse<Temple> = try await apiClient.request(.temples(sect: nil, type: nil, serviceCode: nil, page: page, size: 100))
            let next = response.list.filter { seen.insert($0.id).inserted }
            records.append(contentsOf: next)
            if next.isEmpty || records.count >= response.total { return records }
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
            async let templeRequest: [Temple] = allRecords()
            async let beliefRequest: BeliefListResponse = apiClient.request(.beliefs)
            async let serviceRequest: ServiceCatalogResponse = apiClient.request(.serviceTypes)
            let (templeResponse, beliefResponse, serviceResponse) = try await (templeRequest, beliefRequest, serviceRequest)
            guard !Task.isCancelled else { return }
            hasLoaded = true
            temples = templeResponse
            beliefOptions = [BeliefFilterOption(code: "", name: "全部")] + beliefResponse.list.map { BeliefFilterOption(code: $0.code, name: $0.name) }
            serviceOptions = [ServiceFilterOption(code: "", name: "全部")] + serviceResponse.list.map { ServiceFilterOption(code: $0.code, name: $0.name) }
        } catch {
            guard !Task.isCancelled else { return }
            if beliefOptions.isEmpty { beliefOptions = [BeliefFilterOption(code: "", name: "全部")] }
            if serviceOptions.isEmpty { serviceOptions = [ServiceFilterOption(code: "", name: "全部")] }
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct ServiceFilterOption: Identifiable, Hashable {
    let code: String
    let name: String
    var id: String { code }
}

struct BeliefFilterOption: Identifiable, Hashable {
    let code: String
    let name: String
    var id: String { code }
}
