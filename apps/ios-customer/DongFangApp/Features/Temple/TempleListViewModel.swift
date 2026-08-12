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

    // 所有筛选状态集中管理
    @Published var selectedBeliefCode: String = ""
    @Published var selectedService: String = "全部"     // 左侧服务筛选
    @Published var beliefOptions: [BeliefFilterOption] = []

    var serviceFilters: [String] {
        ["全部"] + Array(Set(temples.flatMap { $0.serviceTags ?? [] })).sorted()
    }

    private let apiClient: APIClient
    init(initialSect: String? = nil, initialBeliefCode: String? = nil, apiClient: APIClient = .shared) {
        self.apiClient = apiClient
        self.selectedBeliefCode = initialBeliefCode ?? ""
    }

    var filteredTemples: [Temple] {
        temples.filter { t in
            (selectedBeliefCode.isEmpty || t.beliefCode == selectedBeliefCode) &&
            matchService(t, selectedService)
        }
    }

    private func matchService(_ t: Temple, _ service: String) -> Bool {
        if service == "全部" { return true }
        let tags = t.serviceTags ?? []
        return tags.contains { $0.contains(service) || service.contains($0) }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            async let templeRequest: PageResponse<Temple> = apiClient.request(.temples(sect: nil, type: nil, serviceCode: nil, page: 1, size: 100))
            async let beliefRequest: BeliefListResponse = apiClient.request(.beliefs)
            let (templeResponse, beliefResponse) = try await (templeRequest, beliefRequest)
            temples = templeResponse.list
            beliefOptions = [BeliefFilterOption(code: "", name: "全部")] + beliefResponse.list.map { BeliefFilterOption(code: $0.code, name: $0.name) }
        } catch {
            self.temples = []
            self.beliefOptions = [BeliefFilterOption(code: "", name: "全部")]
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct BeliefFilterOption: Identifiable, Hashable {
    let code: String
    let name: String
    var id: String { code }
}
