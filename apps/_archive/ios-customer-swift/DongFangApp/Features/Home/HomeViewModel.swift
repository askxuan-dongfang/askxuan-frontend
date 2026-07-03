//
//  HomeViewModel.swift
//  DongFangApp
//
//  首页 ViewModel：加载 Banner / 热门寺院 / 热门师傅。
//

import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    /// 轮播图（本地占位，使用 Assets 中的 banner-ad-1/2/3）
    @Published var banners: [BannerItem] = [
        BannerItem(id: "b1", imageName: "banner-ad-1", title: "岁末祈福大典"),
        BannerItem(id: "b2", imageName: "banner-ad-2", title: "线上祈福 福泽绵长"),
        BannerItem(id: "b3", imageName: "banner-ad-3", title: "雪域修行 心灵之旅")
    ]

    /// 热门寺院
    @Published var hotTemples: [Temple] = []
    /// 热门师傅
    @Published var hotMasters: [Master] = []
    /// 加载态
    @Published var isLoading: Bool = false
    /// 错误信息
    @Published var errorMessage: String? = nil

    /// 热门服务 8 宫格（DIY/祈福/供灯/上香/还愿/超度/开光/化太岁）
    let hotServices: [ServiceType] = [
        .diy, .blessing, .lamp, .incense,
        .vow, .rite, .consecration, .taisui
    ]

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    /// 加载首页数据（并发请求寺院与师傅列表）
    func load() async {
        isLoading = true
        errorMessage = nil

        async let templesResult: Result<[Temple], Error> = fetchTemples()
        async let mastersResult: Result<[Master], Error> = fetchMasters()

        let (templesRes, mastersRes) = await (templesResult, mastersResult)

        switch templesRes {
        case .success(let list):
            // 取前 6 个作为热门
            self.hotTemples = Array(list.prefix(6))
        case .failure(let error):
            self.hotTemples = Temple.mockData
            self.errorMessage = error.localizedDescription
        }

        switch mastersRes {
        case .success(let list):
            self.hotMasters = Array(list.prefix(6))
        case .failure:
            self.hotMasters = Master.mockData
        }

        isLoading = false
    }

    private func fetchTemples() async -> Result<[Temple], Error> {
        do {
            let list: [Temple] = try await apiClient.request(.temples)
            return .success(list)
        } catch {
            return .failure(error)
        }
    }

    private func fetchMasters() async -> Result<[Master], Error> {
        do {
            let list: [Master] = try await apiClient.request(.masters)
            return .success(list)
        } catch {
            return .failure(error)
        }
    }
}
