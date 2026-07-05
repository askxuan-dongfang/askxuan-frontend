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
    @Published var selectedSect: String = "全部"        // 顶部教派标签
    @Published var selectedService: String = "全部"     // 左侧服务筛选

    let sectOptions: [String] = ["全部", "汉传佛教", "南传佛教", "藏传密宗", "道教道观", "民间地方信仰"]
    let serviceFilters: [String] = ["全部", "求姻缘", "求财运", "求事业", "求风水",
                                     "求健康", "求学业", "祈福平安", "超度祭祖", "开光加持"]

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    var filteredTemples: [Temple] {
        temples.filter { t in
            matchSect(t, selectedSect) &&
            matchService(t, selectedService)
        }
    }

    // MARK: - 筛选匹配逻辑（模糊匹配）

    private func matchSect(_ t: Temple, _ sect: String) -> Bool {
        if sect == "全部" { return true }
        if sect.contains("汉传") { return t.type.contains("汉传") || t.sect.contains("禅") }
        if sect.contains("藏传") { return t.type.contains("藏") || t.sect.contains("藏") }
        if sect.contains("道教") { return t.type.contains("道") }
        if sect.contains("民间") { return t.type.contains("民间") }
        return true
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
            let resp: PageResponse<Temple> = try await apiClient.request(
                .temples(sect: nil, type: nil, page: 1, size: 20))
            self.temples = resp.list
        } catch {
            self.temples = Temple.mockData
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
