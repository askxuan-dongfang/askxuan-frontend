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
    @Published var selectedSect: String = "全部"
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    let sectOptions: [String] = ["全部", "汉传佛教", "藏传佛教", "道教"]

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    var filteredTemples: [Temple] {
        guard selectedSect != "全部" else { return temples }
        return temples.filter { $0.type == selectedSect }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let resp: PageResponse<Temple> = try await apiClient.request(
                .temples(sect: selectedSect == "全部" ? nil : nil,
                         type: selectedSect == "全部" ? nil : selectedSect,
                         page: 1, size: 20))
            self.temples = resp.list
        } catch {
            self.temples = Temple.mockData
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
