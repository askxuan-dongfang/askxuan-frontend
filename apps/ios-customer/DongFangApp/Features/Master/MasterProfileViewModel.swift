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
    @Published var services: [TempleServiceInfo] = []
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
            do {
                let list: [TempleServiceInfo] = try await apiClient.request(.templeServices(detail.templeId))
                self.services = list.filter { $0.status == "on_shelf" }
            } catch {
                self.services = []
            }
        } catch {
            self.master = nil
            self.services = []
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
