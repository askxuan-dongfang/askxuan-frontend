//
//  TempleListViewModel.swift
//  DongFangApp
//
//  寺院列表 ViewModel：教派筛选 + 数据加载。
//

import SwiftUI

@MainActor
final class TempleListViewModel: ObservableObject {
    @Published var temples: [Temple] = []
    /// 当前选中的教派筛选（"全部" 表示不限）
    @Published var selectedSect: String = "全部"
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    /// 教派筛选项
    let sectOptions: [String] = ["全部", "汉传佛教", "藏传佛教", "道教"]

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    /// 按教派筛选后的寺院
    var filteredTemples: [Temple] {
        guard selectedSect != "全部" else { return temples }
        // 教派匹配：type 字段（汉传佛教/藏传佛教/道教）
        return temples.filter { $0.type == selectedSect }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let list: [Temple] = try await apiClient.request(.temples)
            self.temples = list
        } catch {
            self.temples = Temple.mockData
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
