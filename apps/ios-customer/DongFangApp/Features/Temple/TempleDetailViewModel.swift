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
    @Published var services: [TempleServiceInfo] = []
    @Published var masters: [Master] = []
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
        async let detailResult: Result<TempleDetail, Error> = fetchDetail(id: id)
        async let mastersResult: Result<[Master], Error> = fetchMasters(templeId: id)

        let (detailRes, mastersRes) = await (detailResult, mastersResult)

        switch detailRes {
        case .success(let detail):
            self.temple = detail.temple
            self.services = detail.services ?? []
        case .failure(let error):
            self.temple = Temple.mockData.first(where: { $0.id == id })
            self.errorMessage = error.localizedDescription
        }

        switch mastersRes {
        case .success(let list):
            self.masters = list
        case .failure:
            self.masters = Master.mockData
        }

        isLoading = false
    }

    private func fetchDetail(id: String) async -> Result<TempleDetail, Error> {
        do {
            let detail: TempleDetail = try await apiClient.request(.templeById(id))
            return .success(detail)
        } catch {
            return .failure(error)
        }
    }

    private func fetchMasters(templeId: String) async -> Result<[Master], Error> {
        do {
            let resp: PageResponse<Master> = try await apiClient.request(
                .masters(type: nil, templeId: templeId, page: 1, size: 20))
            return .success(resp.list)
        } catch {
            return .failure(error)
        }
    }
}
