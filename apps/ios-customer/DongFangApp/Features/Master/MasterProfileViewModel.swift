//
//  MasterProfileViewModel.swift
//  DongFangApp
//
//  法师主页 ViewModel：加载法师详情 + Tab 切换。
//

import SwiftUI

@MainActor
final class MasterProfileViewModel: ObservableObject {
    @Published var master: Master?
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
            let detail: Master = try await apiClient.request(.masterById(id))
            self.master = detail
        } catch {
            self.master = nil
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
