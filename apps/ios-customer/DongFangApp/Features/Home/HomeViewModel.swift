//
//  HomeViewModel.swift
//  DongFangApp
//
//  首页 ViewModel：加载热门寺院 / 热门法师，提供信仰与意图聚合入口。
//  Banner 使用本地 asset（对齐原型 home.html）。
//

import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    /// 首页 Banner（对齐原型 home.html：新春祈福法会 / AI智能问事 / DIY手串定制）
    /// imageURL 使用本地 asset 名（ImageMapper.banners）
    @Published var banners: [BannerItem] = [
        BannerItem(id: "b1", title: "新春祈福法会", subtitle: "名师主法 · 功德回向",
                   imageURL: ImageMapper.banners[0]),
        BannerItem(id: "b2", title: "AI智能问事", subtitle: "玄学大模型 · 即问即答",
                   imageURL: ImageMapper.banners[1]),
        BannerItem(id: "b3", title: "DIY手串定制", subtitle: "选珠搭配 · 法师开光",
                   imageURL: ImageMapper.banners[2])
    ]

    @Published var hotTemples: [Temple] = []
    @Published var hotMasters: [Master] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    /// 信仰入口（对齐新版原型：先按信仰/宗派找到寺院和法师）
    let beliefEntries: [BeliefEntry] = [
        BeliefEntry(id: "han_buddhism", title: "汉传佛教", subtitle: "礼佛祈福", iconName: "leaf.fill"),
        BeliefEntry(id: "daoism", title: "道教", subtitle: "科仪修持", iconName: "sparkles"),
        BeliefEntry(id: "tibetan_buddhism", title: "藏传佛教", subtitle: "传承修持", iconName: "flame.fill"),
        BeliefEntry(id: "folk", title: "民间信仰", subtitle: "民俗祈愿", iconName: "seal.fill")
    ]

    /// 意图入口（把服务、商品、寺院筛选统一为用户意图）
    let intentionEntries: [IntentionEntry] = [
        IntentionEntry(id: "peace", title: "求平安", iconName: "shield.lefthalf.filled", service: .blessing),
        IntentionEntry(id: "wealth", title: "求财运", iconName: "banknote.fill", service: .incense),
        IntentionEntry(id: "love", title: "求姻缘", iconName: "heart.fill", service: .lamp),
        IntentionEntry(id: "career", title: "求事业", iconName: "briefcase.fill", service: .consecration),
        IntentionEntry(id: "study", title: "求学业", iconName: "book.fill", service: .vow),
        IntentionEntry(id: "taisui", title: "化太岁", iconName: "circle.hexagongrid.fill", service: .taisui),
        IntentionEntry(id: "diy", title: "定手串", iconName: "circle.grid.cross.fill", service: .diy),
        IntentionEntry(id: "rite", title: "做法事", iconName: "hands.sparkles.fill", service: .rite)
    ]

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        async let templesResult: Result<[Temple], Error> = fetchTemples()
        async let mastersResult: Result<[Master], Error> = fetchMasters()

        let (templesRes, mastersRes) = await (templesResult, mastersResult)

        switch templesRes {
        case .success(let list):
            // 优先用 ImageMapper 匹配本地 asset，确保图片内容与寺院名称对应
            self.hotTemples = Array(list.prefix(6)).map { applyLocalTempleImage($0) }
        case .failure(let error):
            self.hotTemples = Temple.mockData
            self.errorMessage = error.localizedDescription
        }

        switch mastersRes {
        case .success(let list):
            self.hotMasters = Array(list.prefix(6)).map { applyLocalMasterAvatar($0) }
        case .failure:
            self.hotMasters = Master.mockData
        }

        isLoading = false
    }

    /// 若 ImageMapper 能匹配到本地 asset，则用本地 asset 名替换 coverImage
    private func applyLocalTempleImage(_ temple: Temple) -> Temple {
        if let localAsset = ImageMapper.templeImage(for: temple.name) {
            var t = temple
            t.coverImage = localAsset
            return t
        }
        return temple
    }

    /// 若 ImageMapper 能匹配到本地 asset，则用本地 asset 名替换 avatar
    private func applyLocalMasterAvatar(_ master: Master) -> Master {
        if let localAsset = ImageMapper.masterAvatar(for: master.dharmaName) {
            var m = master
            m.avatar = localAsset
            return m
        }
        return master
    }

    private func fetchTemples() async -> Result<[Temple], Error> {
        do {
            let resp: PageResponse<Temple> = try await apiClient.request(
                .temples(sect: nil, type: nil, serviceCode: nil, page: 1, size: 6))
            return .success(resp.list)
        } catch {
            return .failure(error)
        }
    }

    private func fetchMasters() async -> Result<[Master], Error> {
        do {
            let resp: PageResponse<Master> = try await apiClient.request(
                .masters(type: nil, templeId: nil, page: 1, size: 6))
            return .success(resp.list)
        } catch {
            return .failure(error)
        }
    }
}

/// 首页信仰入口
struct BeliefEntry: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let iconName: String
}

struct BeliefProfile: Codable {
    let code: String
    let name: String
    let summary: String
    let description: String
    let coverImage: String
    let sort: Int
}

/// 首页意图入口
struct IntentionEntry: Identifiable, Hashable {
    let id: String
    let title: String
    let iconName: String
    let service: ServiceType
}

/// Banner 数据模型
struct BannerItem: Identifiable, Hashable {
    let id: String
    let title: String
    var subtitle: String? = nil
    var imageURL: String? = nil
}
