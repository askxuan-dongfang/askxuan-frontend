//
//  Service.swift
//  DongFangApp
//
//  服务数据模型：用户端 7 种服务 + DIY 手串加持服务。
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

    /// 跳转路由标识
    var routeId: String {
        switch self {
        case .blessing:     return "service-blessing"
        case .lamp:         return "service-lamp"
        case .incense:      return "service-incense"
        case .vow:          return "service-vow"
        case .rite:         return "service-rite"
        case .consecration: return "service-consecration"
        case .taisui:       return "service-taisui"
        case .diy:          return "diy-bracelet"
        }
    }
}

/// 用户端服务（7 种法事/供养服务）
struct Service: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    /// 分类：法事/供养
    let type: String
    /// 价格区间，如「¥100-500」
    let priceRange: String
    /// 描述
    let description: String
    /// 可提供该服务的师傅 ID 列表
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

/// 加持服务（DIY 手串开光加持，价格精确）
struct BlessingService: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let templeId: String
    let templeName: String
    let masterId: String
    let masterName: String
    /// 加持价格（元）
    let price: Double
    let description: String

    enum CodingKeys: String, CodingKey {
        case id, name, price, description
        case templeId, templeName, masterId, masterName
    }

    init(id: String, name: String, templeId: String, templeName: String,
         masterId: String, masterName: String, price: Double, description: String) {
        self.id = id
        self.name = name
        self.templeId = templeId
        self.templeName = templeName
        self.masterId = masterId
        self.masterName = masterName
        self.price = price
        self.description = description
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.templeId = try c.decodeIfPresent(String.self, forKey: .templeId) ?? ""
        self.templeName = try c.decodeIfPresent(String.self, forKey: .templeName) ?? ""
        self.masterId = try c.decodeIfPresent(String.self, forKey: .masterId) ?? ""
        self.masterName = try c.decodeIfPresent(String.self, forKey: .masterName) ?? ""
        self.price = try c.decodeIfPresent(Double.self, forKey: .price) ?? 0
        self.description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
    }

    var priceText: String {
        "¥\(Int(price))"
    }
}

/// 功德金档位
struct MeritMoneyTier: Codable, Identifiable, Hashable {
    let tier: String
    let amount: Int
    let description: String

    var id: String { tier }

    /// 是否为自定义档位（amount = -1）
    var isCustom: Bool { amount < 0 }

    var displayText: String {
        if isCustom { return "自定义" }
        return "¥\(amount)"
    }
}

/// /services 接口的聚合响应
struct ServiceBundle: Codable {
    let services: [Service]
    let blessingServices: [BlessingService]
    let meritMoneyTiers: [MeritMoneyTier]
}
