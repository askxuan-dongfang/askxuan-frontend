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
    @Published var selectedSect = "全部"
    @Published var selectedPrice = "全部"

    // 所有筛选状态集中管理
    @Published var selectedBeliefCode: String = ""
    @Published var selectedTemple: String = "全部"         // 左侧：所属寺院
    @Published var selectedLevel: String = "全部"          // 左侧：修为等级
    @Published var selectedSpecialty: String = "全部"      // 左侧：擅长领域
    @Published var selectedService: String = "全部"        // 左侧：可提供服务（大师标签 S001-S013）

    @Published var beliefOptions: [BeliefFilterOption] = []

    var filterGroups: [(title: String, options: [String])] {
        [
            ("宗派", ["全部"] + unique(masters.map(\.sect))),
            ("价格区间", ["全部", "200元以下", "200–500元", "500–1000元", "1000元以上"]),
            ("所属寺院", ["全部"] + unique(masters.map(\.templeName))),
            ("职位", ["全部"] + unique(masters.map(\.position))),
            ("擅长领域", ["全部"] + unique(masters.flatMap(\.specialties))),
            ("可提供服务", ["全部"] + ServiceType.allCases.map(\.rawValue))
        ]
    }

    private let apiClient: APIClient
    init(initialBeliefCode: String? = nil, apiClient: APIClient = .shared) {
        self.apiClient = apiClient
        self.selectedBeliefCode = initialBeliefCode ?? ""
    }

    var filteredMasters: [Master] {
        masters.filter { m in
            (selectedRegionCode.isEmpty || m.regionCode == selectedRegionCode) &&
            (selectedTraditionCode.isEmpty || (m.traditionCodes ?? []).contains(selectedTraditionCode)) &&
            (searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || ([m.dharmaName, m.templeName, m.sect] + m.specialties).joined(separator: " ").localizedStandardContains(searchText.trimmingCharacters(in: .whitespacesAndNewlines))) &&
            (selectedBeliefCode.isEmpty || m.beliefCode == selectedBeliefCode) &&
            (selectedSect == "全部" || m.sect == selectedSect) &&
            matchPrice(m) &&
            matchTemple(m, selectedTemple) &&
            matchLevel(m, selectedLevel) &&
            matchSpecialty(m, selectedSpecialty) &&
            matchService(m, selectedService)
        }
    }

    func clearFilters() {
        selectedRegionCode = ""; selectedTraditionCode = ""; searchText = ""; selectedBeliefCode = ""; selectedTemple = "全部"; selectedLevel = "全部"; selectedSpecialty = "全部"; selectedService = "全部"; selectedSect = "全部"; selectedPrice = "全部"
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

    private func matchSpecialty(_ m: Master, _ specialty: String) -> Bool {
        if specialty == "全部" { return true }
        return m.specialties.contains(specialty)
    }

    /// 按可提供服务筛选：大师服务标签（master_service_tag）包含所选服务编码
    private func matchService(_ m: Master, _ serviceName: String) -> Bool {
        if serviceName == "全部" { return true }
        guard let code = ServiceType.allCases.first(where: { $0.rawValue == serviceName })?.code else { return true }
        return (m.serviceTags ?? []).contains { $0.serviceCode == code && ($0.status == nil || $0.status == "" || $0.status == "enabled") }
    }

    func startingPrice(_ master: Master) -> Double? {
        let code = ServiceType.allCases.first { $0.rawValue == selectedService }?.code
        let prices = (master.serviceTags ?? []).filter {
            ($0.status == nil || $0.status == "" || $0.status == "enabled") && (code == nil || $0.serviceCode == code)
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
            async let masterRequest: [Master] = allRecords()
            async let beliefRequest: BeliefListResponse = apiClient.request(.beliefs)
            let (masterResponse, beliefResponse) = try await (masterRequest, beliefRequest)
            guard !Task.isCancelled else { return }
            hasLoaded = true
            masters = masterResponse
            beliefOptions = [BeliefFilterOption(code: "", name: "全部")] + beliefResponse.list.map { BeliefFilterOption(code: $0.code, name: $0.name) }
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
