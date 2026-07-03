//
//  MasterListViewModel.swift
//  DongFangApp
//
//  师傅列表 ViewModel：教派筛选 + 数据加载。
//

import SwiftUI

@MainActor
final class MasterListViewModel: ObservableObject {
    @Published var masters: [Master] = []
    /// 教派筛选："全部" / "佛教" / "道教" / "藏传"
    @Published var selectedCategory: String = "全部"
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    /// 分类筛选项（按 type 字段：佛教/道教）
    let categoryOptions: [String] = ["全部", "佛教", "道教", "藏传"]

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    /// 按分类筛选后的师傅
    var filteredMasters: [Master] {
        guard selectedCategory != "全部" else { return masters }
        if selectedCategory == "藏传" {
            return masters.filter { $0.sect.contains("藏") }
        }
        return masters.filter { $0.type == selectedCategory }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let list: [Master] = try await apiClient.request(.masters)
            self.masters = list
        } catch {
            self.masters = Master.mockData
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
