//
//  MasterListViewModel.swift
//  DongFangApp
//
//  法师列表 ViewModel：分类筛选 + 数据加载。
//

import SwiftUI

@MainActor
final class MasterListViewModel: ObservableObject {
    @Published var masters: [Master] = []
    @Published var selectedCategory: String = "全部"
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    let categoryOptions: [String] = ["全部", "佛教", "道教", "藏传"]

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

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
            let resp: PageResponse<Master> = try await apiClient.request(
                .masters(type: nil, templeId: nil, page: 1, size: 20))
            self.masters = resp.list
        } catch {
            self.masters = Master.mockData
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
