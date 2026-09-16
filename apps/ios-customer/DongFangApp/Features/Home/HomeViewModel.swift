//
//  HomeViewModel.swift
//  DongFangApp
//
//  首页 ViewModel：加载热门寺院 / 热门法师，提供信仰与意图聚合入口。
//  Banner 使用本地应用资源。
//

import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var banners: [HomePromotion] = []

    @Published var hotTemples: [Temple] = []
    @Published var hotMasters: [Master] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    @Published var beliefEntries: [BeliefEntry] = []
    @Published var intentionEntries: [IntentionEntry] = []

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        async let promotionsResult: [HomePromotion] = fetchPromotions()
        async let templesResult: Result<[Temple], Error> = fetchTemples()
        async let mastersResult: Result<[Master], Error> = fetchMasters()
        async let beliefsResult: Result<[BeliefEntry], Error> = fetchBeliefs()
        async let intentionsResult: Result<[IntentionEntry], Error> = fetchIntentions()

        let (templesRes, mastersRes, beliefsRes, intentionsRes) = await (templesResult, mastersResult, beliefsResult, intentionsResult)

        switch templesRes {
        case .success(let list):
            self.hotTemples = Array(list.prefix(6))
        case .failure(let error):
            self.hotTemples = []
            self.errorMessage = error.localizedDescription
        }

        switch mastersRes {
        case .success(let list):
            self.hotMasters = Array(list.prefix(6))
        case .failure(let error):
            self.hotMasters = []
            if self.errorMessage == nil { self.errorMessage = error.localizedDescription }
        }

        switch beliefsRes {
        case .success(let list): beliefEntries = list
        case .failure(let error):
            beliefEntries = []
            if errorMessage == nil { errorMessage = error.localizedDescription }
        }

        switch intentionsRes {
        case .success(let list): intentionEntries = Array((list.filter { $0.landingType == "diy" } + list.filter { $0.landingType != "diy" }).prefix(8))
        case .failure(let error):
            intentionEntries = []
            if errorMessage == nil { errorMessage = error.localizedDescription }
        }

        banners = await promotionsResult
        isLoading = false
    }

    private func fetchPromotions() async -> [HomePromotion] {
        do {
            let response: HomePromotionList = try await apiClient.request(.homePromotions)
            return response.list.filter { $0.isVisible }.sorted { $0.sort == $1.sort ? $0.id > $1.id : $0.sort < $1.sort }
        } catch { return [] }
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
                .masters(type: nil, templeId: nil, manageBy: "platform", serviceCode: nil, page: 1, size: 6))
            return .success(resp.list)
        } catch {
            return .failure(error)
        }
    }

    private func fetchBeliefs() async -> Result<[BeliefEntry], Error> {
        do {
            let response: BeliefListResponse = try await apiClient.request(.beliefs)
            return .success(response.list.map(BeliefEntry.init))
        } catch {
            return .failure(error)
        }
    }

    private func fetchIntentions() async -> Result<[IntentionEntry], Error> {
        do {
            let response: IntentionTagListResponse = try await apiClient.request(.intentionTags)
            return .success(response.list.map(IntentionEntry.init))
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

    init(profile: BeliefProfile) {
        id = profile.code
        title = profile.name
        subtitle = profile.summary
        iconName = profile.icon.isEmpty ? "sparkles" : profile.icon
    }
}

struct BeliefProfile: Codable {
    let code: String
    let name: String
    let summary: String
    let description: String
    let coverImage: String
    let icon: String
    let sort: Int
    let status: String
}

struct BeliefListResponse: Codable { let list: [BeliefProfile] }

/// 首页意图入口
struct IntentionEntry: Identifiable, Hashable {
    let id: String
    let title: String
    let iconName: String
    let summary: String
    let landingType: String
    let landingValue: String
    let actionTitle: String

    init(tag: IntentionTag) {
        id = tag.code
        title = tag.name
        iconName = tag.icon.isEmpty ? "sparkles" : tag.icon
        summary = tag.description
        landingType = tag.landingType
        landingValue = tag.landingValue
        actionTitle = tag.actionTitle.isEmpty ? "立即办理" : tag.actionTitle
    }

    var service: ServiceType? { ServiceType.from(serviceCode: landingValue) }
}

struct IntentionTag: Codable, Identifiable, Hashable {
    let code: String
    let name: String
    let description: String
    let icon: String
    let landingType: String
    let landingValue: String
    let actionTitle: String
    let sort: Int
    let status: String
    var id: String { code }
}

struct IntentionTagListResponse: Codable { let list: [IntentionTag] }

struct IntentionResource: Codable, Identifiable, Hashable {
    let resourceType: String
    let sourceId: String
    let title: String
    let subtitle: String
    let price: Double
    let image: String
    let orderTarget: String
    let templeCode: String?
    let serviceCode: String?
    let masterCode: String?
    var id: String { "\(resourceType):\(sourceId)" }
}

struct IntentionHubResponse: Codable {
    let tags: [IntentionTag]
    let total: Int
    let list: [IntentionResource]
    let page: Int
    let size: Int
}

/// Banner 数据模型
struct BannerItem: Identifiable, Hashable {
    let id: String
    let title: String
    var subtitle: String? = nil
    var imageURL: String? = nil
}
