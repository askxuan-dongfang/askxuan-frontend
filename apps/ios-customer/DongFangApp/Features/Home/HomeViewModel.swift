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
        iconName = ["han_buddhism": "sun.max", "tibetan_buddhism": "mountain.2", "daoism": "leaf", "folk": "house.lodge"][profile.code] ?? "building.columns"
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

enum NativeSearchCategory: String, CaseIterable, Identifiable {
    case functions, temples, masters, services, products, designs, posts, promotions
    var id: String { rawValue }
    var title: String {
        switch self {
        case .functions: "功能入口"
        case .temples: "寺院"
        case .masters: "师傅"
        case .services: "服务与心愿"
        case .products: "商品"
        case .designs: "手串作品"
        case .posts: "动态"
        case .promotions: "推荐活动与专题"
        }
    }
}

struct NativeSearchResult: Identifiable {
    let id: String
    let title: String
    let summary: String
    let route: String
    var intention: IntentionTag? = nil
}

struct NativeSearchSection {
    var results: [NativeSearchResult] = []
    var loading = false
    var error: String?
    var visibleCount = 20
}

/// Preserve complete public descriptions for matching; only the rendered summary is shortened.
indirect enum NativeSearchValue: Codable {
    case string(String), integer(Int64), number(Double), bool(Bool), array([NativeSearchValue]), object([String: NativeSearchValue]), null
    init(from decoder: Decoder) throws {
        let box = try decoder.singleValueContainer()
        if box.decodeNil() { self = .null }
        else if let value = try? box.decode(String.self) { self = .string(value) }
        else if let value = try? box.decode(Bool.self) { self = .bool(value) }
        else if let value = try? box.decode(Int64.self) { self = .integer(value) }
        else if let value = try? box.decode(Double.self) { self = .number(value) }
        else if let value = try? box.decode([NativeSearchValue].self) { self = .array(value) }
        else { self = .object(try box.decode([String: NativeSearchValue].self)) }
    }
    func encode(to encoder: Encoder) throws {
        var box = encoder.singleValueContainer()
        switch self {
        case .string(let value): try box.encode(value)
        case .integer(let value): try box.encode(value)
        case .number(let value): try box.encode(value)
        case .bool(let value): try box.encode(value)
        case .array(let value): try box.encode(value)
        case .object(let value): try box.encode(value)
        case .null: try box.encodeNil()
        }
    }
    var strings: [String] {
        switch self {
        case .string(let value): [value]
        case .integer(let value): [String(value)]
        case .number(let value): [value.rounded() == value ? String(format: "%.0f", value) : String(value)]
        case .array(let values): values.flatMap(\.strings)
        case .object(let values): values.keys.sorted().flatMap { values[$0]?.strings ?? [] }
        default: []
        }
    }
}

struct NativeSearchRecord: Decodable, Identifiable {
    let fields: [String: NativeSearchValue]
    init(from decoder: Decoder) throws { fields = try decoder.singleValueContainer().decode([String: NativeSearchValue].self) }
    var id: String { text("id", "code") }
    func text(_ keys: String...) -> String { keys.lazy.compactMap { fields[$0]?.strings.first }.first(where: { !$0.isEmpty }) ?? "" }
    func decode<T: Decodable>(_ type: T.Type) throws -> T { try JSONDecoder().decode(type, from: JSONEncoder().encode(fields)) }
    var searchableFields: [String] {
        let keys = ["name", "title", "dharmaName", "layName", "description", "summary", "intro", "bio", "content", "tags", "serviceCodes", "specialties", "templeName", "position", "type", "category", "categoryName", "beliefCode", "sect", "traditionCodes", "region", "regionCode", "address", "location", "landingType", "landingValue", "actionTitle"]
        var result = keys.flatMap { fields[$0]?.strings ?? [] }
        if case .array(let tags) = fields["serviceTags"] {
            for tag in tags {
                if case .object(let value) = tag, let status = value["status"]?.strings.first,
                   !["", "enabled"].contains(status) { continue }
                result += tag.strings
            }
        }
        return result
    }
}

struct NativeSearchPage: Decodable {
    let list: [NativeSearchRecord]
    let total: Int?
    let page: Int?
    let size: Int?
    enum CodingKeys: String, CodingKey { case list, total, page, size }
    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        list = try box.decodeIfPresent([NativeSearchRecord].self, forKey: .list) ?? []
        total = try box.decodeIfPresent(Int.self, forKey: .total)
        page = try box.decodeIfPresent(Int.self, forKey: .page)
        size = try box.decodeIfPresent(Int.self, forKey: .size)
    }
}

enum NativeSearchFailure: Error, LocalizedError {
    case incompletePage
    var errorDescription: String? { "部分内容未能完整加载，请重试" }
}

enum NativePublicSearch {
    static func normalize(_ text: String) -> String {
        DirectorySearch.normalize(text)
    }
    static func tokens(_ query: String) -> [String] { normalize(query).split(whereSeparator: \.isWhitespace).map(String.init) }
    static func matches(_ query: String, fields: [String]) -> Bool {
        let words = tokens(query)
        guard !words.isEmpty else { return false }
        let content = normalize(fields.joined(separator: " "))
        return words.allSatisfy(content.contains)
    }

    /// Use unique IDs and the server total, so a server-side size cap cannot truncate the search.
    @MainActor static func allPages(_ endpoint: (Int) -> Endpoint, fetch: (Endpoint) async throws -> NativeSearchPage) async throws -> [NativeSearchRecord] {
        var result: [NativeSearchRecord] = []
        var seen = Set<String>()
        var page = 1
        while true {
            try Task.checkCancellation()
            let response = try await fetch(endpoint(page))
            try Task.checkCancellation()
            let before = result.count
            for row in response.list {
                guard !row.id.isEmpty else { throw NativeSearchFailure.incompletePage }
                if seen.insert(row.id).inserted { result.append(row) }
            }
            guard let total = response.total else { throw NativeSearchFailure.incompletePage }
            if result.count >= total { return result }
            guard result.count > before else { throw NativeSearchFailure.incompletePage }
            page += 1
        }
    }

    static let functions: [(String, String, String)] = [
        ("找寺院", "寺庙 佛寺 道观 宫观 寺院 服务", "/c/temples"),
        ("找师傅", "大师 法师 道长 咨询 预约", "/c/masters"),
        ("DIY手串", "设计 珠子 材料 定制 手链", "/c/diy"),
        ("积分中心", "积分 转盘 兑换 奖池", "/c/points"),
        ("商城", "购物 商品", "/c/shop"),
        ("AI问事", "人工智能 问答 八字 紫微 六爻 塔罗", "/c/ai"),
        ("我的成长", "成长值 功德值 等级 权益 折扣", "/c/growth"),
        ("我的预约", "服务 订单 预约", "/c/bookings"),
        ("商城订单", "购买 订单 收货 物流", "/c/shop/orders"),
        ("定制订单", "DIY 手串 定制 订单", "/c/diy/orders"),
        ("收货地址", "地址 管理", "/c/addresses"),
        ("我的设计", "手串 草稿 编辑 发布", "/c/diy?tab=mine"),
        ("我的收藏", "收藏 关注", "/c/favorites"),
        ("对话", "私聊 消息 咨询", "/c/chats"),
        ("大师广场", "社区 动态 图文 视频", "/c/chats?tab=plaza"),
        ("钱包与创作收益", "钱包 消费余额 收益 提现", "/c/wallet"),
        ("活动奖池", "活动 奖池 抽奖", "/c/rewards")
    ]
}

@MainActor
final class NativeGlobalSearchModel: ObservableObject {
    typealias Fetch = (Endpoint) async throws -> NativeSearchPage
    @Published private(set) var query = ""
    @Published private(set) var sections: [NativeSearchCategory: NativeSearchSection] = [:]
    private let fetch: Fetch
    private var generation = UUID()
    private var tasks: [NativeSearchCategory: Task<Void, Never>] = [:]

    init(fetch: @escaping Fetch = { try await APIClient.shared.request($0) }) { self.fetch = fetch }
    func submit(_ text: String) {
        cancel()
        query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        sections = [:]
        guard !NativePublicSearch.tokens(query).isEmpty else { return }
        let functions = NativePublicSearch.functions.filter { NativePublicSearch.matches(query, fields: [$0.0, $0.1]) }
        sections[.functions] = NativeSearchSection(results: functions.map { NativeSearchResult(id: $0.2, title: $0.0, summary: "", route: $0.2) })
        for category in NativeSearchCategory.allCases where category != .functions { retry(category) }
    }
    func cancel() {
        generation = UUID()
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
        for category in NativeSearchCategory.allCases where sections[category]?.loading == true {
            sections[category] = NativeSearchSection(error: "搜索已暂停，请重试")
        }
    }
    func showMore(_ category: NativeSearchCategory) { sections[category]?.visibleCount += 20 }
    func retry(_ category: NativeSearchCategory) {
        guard !query.isEmpty else { return }
        tasks[category]?.cancel()
        sections[category] = NativeSearchSection(loading: true)
        let requestGeneration = generation
        let requestQuery = query
        tasks[category] = Task { [weak self] in
            guard let self else { return }
            do {
                let results = try await self.load(category, query: requestQuery)
                guard !Task.isCancelled, self.generation == requestGeneration else { return }
                self.sections[category] = NativeSearchSection(results: results)
            } catch {
                guard !Task.isCancelled, self.generation == requestGeneration else { return }
                self.sections[category] = NativeSearchSection(error: error.localizedDescription)
            }
        }
    }

    private func directoryCatalog() async throws -> DirectorySearchCatalog {
        async let beliefs = fetch(.beliefs)
        async let tags = fetch(.directoryTags)
        async let regions = fetch(.directoryRegions)
        async let services = fetch(.serviceTypes)
        let pages = try await (beliefs, tags, regions, services)
        return DirectorySearchCatalog(
            beliefs: pages.0.list.map { BeliefFilterOption(code: $0.text("code"), name: $0.text("name")) },
            tags: try pages.1.list.map { try $0.decode(DirectoryTag.self) },
            services: pages.3.list.map { ServiceFilterOption(code: $0.text("code"), name: $0.text("name")) },
            regions: try pages.2.list.map { try $0.decode(DirectoryRegion.self) })
    }

    private func load(_ category: NativeSearchCategory, query: String) async throws -> [NativeSearchResult] {
        var records: [NativeSearchRecord]
        var catalog = DirectorySearchCatalog()
        switch category {
        case .functions: return []
        case .temples, .masters:
            async let metadata = directoryCatalog()
            records = try await NativePublicSearch.allPages({ page in
                category == .temples
                    ? .temples(sect: nil, type: nil, serviceCode: nil, page: page, size: 100)
                    : .masters(type: nil, templeId: nil, manageBy: nil, serviceCode: nil, page: page, size: 100)
            }, fetch: fetch)
            catalog = try await metadata
        case .products:
            records = try await NativePublicSearch.allPages({ .products(categoryId: nil, keyword: nil, page: $0, size: 100, sort: "newest", inStock: false) }, fetch: fetch)
        case .designs:
            records = try await NativePublicSearch.allPages({ .diyDesigns(page: $0, size: 100) }, fetch: fetch)
        case .posts:
            records = try await NativePublicSearch.allPages({ .communityFeed(type: nil, beliefCode: nil, page: $0, size: 100, following: false, keyword: nil, sort: "latest") }, fetch: fetch)
        case .services:
            async let services = fetch(.serviceTypes)
            async let intentions = fetch(.intentionTags)
            let pages = try await (services, intentions)
            let serviceResults = pages.0.list.filter { NativePublicSearch.matches(query, fields: [$0.text("name"), $0.text("code")]) }.map { record in
                NativeSearchResult(id: "service-" + record.text("code", "id"), title: record.text("name"), summary: "服务", route: "/c/services/" + record.text("code", "id"))
            }
            let intentionsResults = try pages.1.list.filter { NativePublicSearch.matches(query, fields: [$0.text("name"), $0.text("description")]) }.map { record in
                NativeSearchResult(id: "intention-" + record.text("code", "id"), title: record.text("name"), summary: "心愿", route: "/c/intentions/" + record.text("code", "id"), intention: try record.decode(IntentionTag.self))
            }
            return serviceResults + intentionsResults
        case .promotions:
            let page = try await fetch(.homePromotions)
            return try page.list.compactMap { record in
                let promotion = try record.decode(HomePromotion.self)
                guard promotion.isVisible, NativePublicSearch.matches(query, fields: [promotion.title]), let route = promotion.route else { return nil }
                return NativeSearchResult(id: record.id, title: promotion.title, summary: "", route: route)
            }
        }
        return try records.compactMap { record in
            let title = record.text("name", "dharmaName", "title")
            guard !title.isEmpty else { return nil }
            let content = record.text("description", "content").replacingOccurrences(of: "<[^>]*>", with: " ", options: .regularExpression)
            let raw: [String]
            if category == .temples { raw = DirectorySearch.fields(temple: try record.decode(Temple.self), catalog: catalog) }
            else if category == .masters { raw = DirectorySearch.fields(master: try record.decode(Master.self), catalog: catalog) }
            else { raw = [title, content, record.text("categoryName")] + (record.fields["tags"]?.strings ?? []) }
            guard NativePublicSearch.matches(query, fields: raw) else { return nil }
            let summary: String
            if category == .temples { summary = [record.text("regionName"), record.text("region")].filter { !$0.isEmpty }.joined(separator: " · ") }
            else if category == .masters { summary = [record.text("templeName"), record.text("regionName"), record.text("position")].filter { !$0.isEmpty }.joined(separator: " · ") }
            else { summary = content.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression) }
            let route: String
            switch category {
            case .temples: route = "/c/temples/" + record.id
            case .masters: route = "/c/masters/" + record.id
            case .products: route = "/c/shop/" + record.id
            case .designs: route = "/c/diy/designs/" + record.id
            case .posts: route = "/c/community/posts/" + record.id
            default: return nil
            }
            return NativeSearchResult(id: record.id, title: title, summary: summary, route: route)
        }
    }
}
