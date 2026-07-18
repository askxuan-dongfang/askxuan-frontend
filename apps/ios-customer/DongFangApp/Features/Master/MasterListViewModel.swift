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
    @Published var selectedCategory: String = "全部"       // 顶部分类标签
    @Published var selectedTemple: String = "全部"         // 左侧：所属寺院
    @Published var selectedLevel: String = "全部"          // 左侧：修为等级
    @Published var selectedSpecialty: String = "全部"      // 左侧：擅长领域
    @Published var selectedPriceRange: String = "全部"     // 左侧：价格区间

    let categoryOptions: [String] = ["全部", "汉传法师", "藏传堪布", "道教道长", "民间命理师"]

    let filterGroups: [(title: String, options: [String])] = [
        ("所属寺院", ["全部", "灵隐寺", "白云观", "少林寺", "大昭寺", "普陀山", "武当山"]),
        ("修为等级", ["全部", "方丈", "住持", "高功", "法师"]),
        ("擅长领域", ["全部", "禅修", "内丹", "藏密", "天台", "净土", "风水"]),
        ("价格区间", ["全部", "¥0-200", "¥200-500", "¥500-1000", "¥1000+"])
    ]

    private let apiClient: APIClient
    private let beliefCode: String?

    init(initialBeliefCode: String? = nil, apiClient: APIClient = .shared) {
        self.apiClient = apiClient
        self.beliefCode = initialBeliefCode
    }

    var filteredMasters: [Master] {
        masters.filter { m in
            (beliefCode == nil || m.beliefCode == beliefCode) &&
            matchCategory(m, selectedCategory) &&
            matchTemple(m, selectedTemple) &&
            matchLevel(m, selectedLevel) &&
            matchSpecialty(m, selectedSpecialty) &&
            matchPrice(m, selectedPriceRange)
        }
    }

    // MARK: - 筛选匹配逻辑（模糊匹配，兼容后端实际数据）

    private func matchCategory(_ m: Master, _ cat: String) -> Bool {
        if cat == "全部" { return true }
        if cat.contains("汉传") { return m.type.contains("佛") && m.sect.contains("汉") }
        if cat.contains("藏传") { return m.sect.contains("藏") || m.type.contains("藏") }
        if cat.contains("道教") { return m.type.contains("道") }
        if cat.contains("民间") { return m.type.contains("民间") }
        return true
    }

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

    private func matchPrice(_ m: Master, _ range: String) -> Bool {
        if range == "全部" { return true }
        guard let price = m.startPrice else { return false }
        let value = Int(price)
        switch range {
        case "¥0-200":    return value < 200
        case "¥200-500":  return value >= 200 && value < 500
        case "¥500-1000": return value >= 500 && value < 1000
        case "¥1000+":    return value >= 1000
        default:          return true
        }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let endpoint: Endpoint = beliefCode.map { .mastersByBelief($0, page: 1, size: 20) }
                ?? .masters(type: nil, templeId: nil, page: 1, size: 20)
            let resp: PageResponse<Master> = try await apiClient.request(endpoint)
            self.masters = resp.list
        } catch {
            self.masters = []
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
