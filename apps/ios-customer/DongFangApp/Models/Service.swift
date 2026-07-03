//
//  Service.swift
//  DongFangApp
//
//  服务数据模型：7 种法事/供养服务 + DIY 手串加持服务。
//

import Foundation

/// 服务类型枚举（用户端 7 种核心服务 + DIY 手串）
enum ServiceType: String, Codable, CaseIterable, Identifiable {
    case blessing      = "祈福"
    case lamp          = "供灯"
    case incense       = "上香"
    case vow           = "还愿"
    case rite          = "超度"
    case consecration  = "开光"
    case taisui        = "化太岁"
    case diy           = "DIY手串"

    var id: String { rawValue }

    /// 对应的 SF Symbol 图标
    var iconName: String {
        switch self {
        case .blessing:     return "hands.and.sparkles"
        case .lamp:         return "lightbulb.fill"
        case .incense:      return "leaf.fill"
        case .vow:          return "checkmark.seal.fill"
        case .rite:         return "flame.fill"
        case .consecration: return "sparkles"
        case .taisui:       return "shield.lefthalf.filled"
        case .diy:          return "circle.grid.2x1.fill"
        }
    }

    /// 服务详情副标题
    var subtitle: String {
        switch self {
        case .blessing:     return "祈福消灾 · 福泽绵长"
        case .lamp:         return "供灯续明 · 破除无明"
        case .incense:      return "敬香供养 · 心诚则灵"
        case .vow:          return "还愿酬神 · 信守誓约"
        case .rite:         return "超度亡灵 · 往生净土"
        case .consecration: return "开光加持 · 灵气贯注"
        case .taisui:       return "化解太岁 · 安康顺遂"
        case .diy:          return "手串定制 · 法师加持"
        }
    }

    /// 详情介绍
    var detail: String {
        switch self {
        case .blessing:     return "由法师主持祈福法事，为信众及家人祈求平安健康、消灾延寿。可通过线上预约，法师在寺院内代为祈福，并将祈福过程回向功德主。"
        case .lamp:         return "在佛前供奉明灯，象征智慧光明、破除无明。供灯功德可回向给在世亲人（延寿增慧）或亡者（引路超度）。"
        case .incense:      return "敬香是佛教基本供养，表示对三宝的恭敬。法师代为敬香，将功德回向给供养者。"
        case .vow:          return "心愿实现后到寺院还愿酬神，感恩佛菩萨加持。法师代为举行还愿仪式，圆满誓约。"
        case .rite:         return "为亡者举行超度法事，助其往生善道。由法师依仪轨诵经回向，普利冥阳两界。"
        case .consecration: return "为新购法器、佛像、手串等举行开光加持仪式，注入灵气。法师诵经咒加持，使法物更具灵性。"
        case .taisui:       return "本命年或冲太岁者，拜太岁、化太岁，祈求一年安康顺遂、化解口舌是非。"
        case .diy:          return "自定义手串材料，由法师开光加持，定制专属法物。"
        }
    }
}

/// 用户端服务项
struct Service: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let type: String
    let priceRange: String
    let description: String
    let masterIds: [String]

    enum CodingKeys: String, CodingKey {
        case id, name, type, description
        case priceRange, masterIds
    }

    init(id: String, name: String, type: String, priceRange: String,
         description: String, masterIds: [String]) {
        self.id = id
        self.name = name
        self.type = type
        self.priceRange = priceRange
        self.description = description
        self.masterIds = masterIds
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.type = try c.decodeIfPresent(String.self, forKey: .type) ?? ""
        self.priceRange = try c.decodeIfPresent(String.self, forKey: .priceRange) ?? ""
        self.description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.masterIds = try c.decodeIfPresent([String].self, forKey: .masterIds) ?? []
    }
}

/// 加持服务（DIY 手串开光加持）
struct BlessingService: Codable, Identifiable, Hashable {
    let id: Int64
    let serviceCode: String?
    let serviceName: String
    let templeCode: String?
    let templeName: String
    let masterCode: String?
    let masterName: String
    let price: Double
    let description: String
    let status: String?

    enum CodingKeys: String, CodingKey {
        case id, serviceName, price, description, status
        case serviceCode, templeCode, templeName, masterCode, masterName
    }

    init(id: Int64, serviceCode: String?, serviceName: String, templeCode: String?,
         templeName: String, masterCode: String?, masterName: String,
         price: Double, description: String, status: String?) {
        self.id = id
        self.serviceCode = serviceCode
        self.serviceName = serviceName
        self.templeCode = templeCode
        self.templeName = templeName
        self.masterCode = masterCode
        self.masterName = masterName
        self.price = price
        self.description = description
        self.status = status
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(Int64.self, forKey: .id) ?? 0
        self.serviceCode = try c.decodeIfPresent(String.self, forKey: .serviceCode)
        self.serviceName = try c.decodeIfPresent(String.self, forKey: .serviceName) ?? ""
        self.templeCode = try c.decodeIfPresent(String.self, forKey: .templeCode)
        self.templeName = try c.decodeIfPresent(String.self, forKey: .templeName) ?? ""
        self.masterCode = try c.decodeIfPresent(String.self, forKey: .masterCode)
        self.masterName = try c.decodeIfPresent(String.self, forKey: .masterName) ?? ""
        self.price = try c.decodeIfPresent(Double.self, forKey: .price) ?? 0
        self.description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.status = try c.decodeIfPresent(String.self, forKey: .status)
    }

    var priceText: String { "¥\(Int(price))" }
}
