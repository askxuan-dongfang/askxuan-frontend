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

    // 所有筛选状态集中管理
    @Published var selectedBeliefCode: String = ""
    @Published var selectedTemple: String = "全部"         // 左侧：所属寺院
    @Published var selectedLevel: String = "全部"          // 左侧：修为等级
    @Published var selectedSpecialty: String = "全部"      // 左侧：擅长领域

    @Published var beliefOptions: [BeliefFilterOption] = []

    var filterGroups: [(title: String, options: [String])] {
        [
            ("所属寺院", ["全部"] + unique(masters.map(\.templeName))),
            ("职位", ["全部"] + unique(masters.map(\.position))),
            ("擅长领域", ["全部"] + unique(masters.flatMap(\.specialties)))
        ]
    }

    private let apiClient: APIClient
    init(initialBeliefCode: String? = nil, apiClient: APIClient = .shared) {
        self.apiClient = apiClient
        self.selectedBeliefCode = initialBeliefCode ?? ""
    }

    var filteredMasters: [Master] {
        masters.filter { m in
            (selectedBeliefCode.isEmpty || m.beliefCode == selectedBeliefCode) &&
            matchTemple(m, selectedTemple) &&
            matchLevel(m, selectedLevel) &&
            matchSpecialty(m, selectedSpecialty)
        }
    }

    // MARK: - 筛选匹配逻辑（模糊匹配，兼容后端实际数据）

    private func matchTemple(_ m: Master, _ temple: String) -> Bool {
        if temple == "全部" { return true }
        return m.templeName.contains(temple)
    }

    private func matchLevel(_ m: Master, _ level: String) -> Bool {
        if level == "全部" { return true }
        return m.position == level
    }

    private func matchSpecialty(_ m: Master, _ specialty: String) -> Bool {
        if specialty == "全部" { return true }
        return m.specialties.contains { $0.contains(specialty) || specialty.contains($0) }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            async let masterRequest: PageResponse<Master> = apiClient.request(.masters(type: nil, templeId: nil, manageBy: "platform", page: 1, size: 100))
            async let beliefRequest: BeliefListResponse = apiClient.request(.beliefs)
            let (masterResponse, beliefResponse) = try await (masterRequest, beliefRequest)
            masters = masterResponse.list
            beliefOptions = [BeliefFilterOption(code: "", name: "全部")] + beliefResponse.list.map { BeliefFilterOption(code: $0.code, name: $0.name) }
        } catch {
            self.masters = []
            self.beliefOptions = [BeliefFilterOption(code: "", name: "全部")]
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func unique(_ values: [String]) -> [String] {
        Array(Set(values.filter { !$0.isEmpty })).sorted()
    }
}
