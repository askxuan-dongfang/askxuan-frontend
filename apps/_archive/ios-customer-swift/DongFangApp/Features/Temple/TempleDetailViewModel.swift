//
//  TempleDetailViewModel.swift
//  DongFangApp
//
//  寺院详情 ViewModel：加载寺院详情 + Tab 切换。
//

import SwiftUI

@MainActor
final class TempleDetailViewModel: ObservableObject {
    @Published var temple: Temple?
    /// 当前选中的 Tab：0-基础信息 / 1-公共服务 / 2-大师团队 / 3-文创
    @Published var selectedTab: Int = 0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func load(id: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let detail: Temple = try await apiClient.request(.templeById(id))
            self.temple = detail
        } catch {
            // 失败时回退到本地 mock 数据中匹配
            self.temple = Temple.mockData.first(where: { $0.id == id })
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
