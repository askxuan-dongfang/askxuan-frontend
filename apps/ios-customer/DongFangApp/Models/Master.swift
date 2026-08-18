//
//  Master.swift
//  DongFangApp
//
//  法师/道长数据模型（对齐 master-service）。
//

import Foundation

struct Master: Codable, Identifiable, Hashable {
    let id: String
    let dharmaName: String
    let layName: String
    let templeId: String
    let templeName: String
    let position: String
    let beliefCode: String
    let sect: String
    let type: String          // 佛教/道教
    let authStatus: String
    let specialties: [String]
    var avatar: String
    let rating: Double
    var isOnline: Bool?
    var startPrice: Double?
    var consultEnabled: Bool
    var consultFee: Double
    var consultValidHours: Int
    var consultResponseMinutes: Int
    /// 管理方：temple=寺庙绑定 / platform=平台(野生)
    var manageBy: String?
    /// 大师服务标签（大师所提供，S001-S013）
    var serviceTags: [MasterServiceTag]?
    /// 上下架状态（对齐 master-service ShelfStatus，on_shelf/off_shelf）
    var shelfStatus: String?

    enum CodingKeys: String, CodingKey {
        case id, dharmaName, layName, templeId, templeName, position, beliefCode, sect, type
        case authStatus, specialties, avatar, rating, isOnline, startPrice, shelfStatus
        case consultEnabled, consultFee, consultValidHours, consultResponseMinutes
        case manageBy, serviceTags
    }

    init(id: String, dharmaName: String, layName: String, templeId: String,
         templeName: String, position: String, beliefCode: String? = nil, sect: String, type: String,
         authStatus: String, specialties: [String], avatar: String, rating: Double,
         isOnline: Bool? = true, startPrice: Double? = nil,
         shelfStatus: String? = nil, consultEnabled: Bool = true, consultFee: Double = 39,
         consultValidHours: Int = 72, consultResponseMinutes: Int = 30) {
        self.id = id
        self.dharmaName = dharmaName
        self.layName = layName
        self.templeId = templeId
        self.templeName = templeName
        self.position = position
        self.beliefCode = beliefCode ?? Self.inferBelief(type: type, sect: sect)
        self.sect = sect
        self.type = type
        self.authStatus = authStatus
        self.specialties = specialties
        self.avatar = avatar
        self.rating = rating
        self.isOnline = isOnline
        self.startPrice = startPrice
        self.shelfStatus = shelfStatus
        self.consultEnabled = consultEnabled
        self.consultFee = consultFee
        self.consultValidHours = consultValidHours
        self.consultResponseMinutes = consultResponseMinutes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.dharmaName = try c.decodeIfPresent(String.self, forKey: .dharmaName) ?? ""
        self.layName = try c.decodeIfPresent(String.self, forKey: .layName) ?? ""
        self.templeId = try c.decodeIfPresent(String.self, forKey: .templeId) ?? ""
        self.templeName = try c.decodeIfPresent(String.self, forKey: .templeName) ?? ""
        self.position = try c.decodeIfPresent(String.self, forKey: .position) ?? ""
        self.sect = try c.decodeIfPresent(String.self, forKey: .sect) ?? ""
        self.type = try c.decodeIfPresent(String.self, forKey: .type) ?? ""
        self.beliefCode = try c.decodeIfPresent(String.self, forKey: .beliefCode) ?? Self.inferBelief(type: type, sect: sect)
        self.authStatus = try c.decodeIfPresent(String.self, forKey: .authStatus) ?? "已认证"
        self.specialties = try c.decodeIfPresent([String].self, forKey: .specialties) ?? []
        self.avatar = try c.decodeIfPresent(String.self, forKey: .avatar) ?? ""
        self.rating = try c.decodeIfPresent(Double.self, forKey: .rating) ?? 0
        self.isOnline = try c.decodeIfPresent(Bool.self, forKey: .isOnline) ?? true
        self.startPrice = try c.decodeIfPresent(Double.self, forKey: .startPrice)
        self.shelfStatus = try c.decodeIfPresent(String.self, forKey: .shelfStatus)
        self.consultEnabled = try c.decodeIfPresent(Bool.self, forKey: .consultEnabled) ?? false
        self.consultFee = try c.decodeIfPresent(Double.self, forKey: .consultFee) ?? 0
        self.consultValidHours = try c.decodeIfPresent(Int.self, forKey: .consultValidHours) ?? 72
        self.consultResponseMinutes = try c.decodeIfPresent(Int.self, forKey: .consultResponseMinutes) ?? 30
        // 双轨制字段：管理方（temple/platform）与大师服务标签（可提供服务）
        self.manageBy = try c.decodeIfPresent(String.self, forKey: .manageBy)
        self.serviceTags = try c.decodeIfPresent([MasterServiceTag].self, forKey: .serviceTags)
    }

    var ratingText: String { String(format: "%.1f", rating) }

    private static func inferBelief(type: String, sect: String) -> String {
        if type.contains("藏") || sect.contains("格鲁") || sect.contains("藏") { return "tibetan_buddhism" }
        if type.contains("道") || sect.contains("全真") || sect.contains("正一") { return "daoism" }
        if type.contains("民间") { return "folk" }
        return "han_buddhism"
    }
    var startPriceText: String? {
        guard let price = startPrice, price > 0 else { return nil }
        return "¥\(Int(price))起"
    }
    var specialtiesText: String { specialties.joined(separator: "·") }
    var isOnlineDisplay: Bool { isOnline ?? true }
    /// 是否已上架
    var isOnShelf: Bool { (shelfStatus ?? "on_shelf") == "on_shelf" }
    var consultFeeText: String? {
        guard consultEnabled, consultFee > 0 else { return nil }
        return "¥\(Int(consultFee))"
    }
}

extension Master {
    /// 对齐后端统一师傅字典；每位师傅只归属一个寺院。
    static let mockData: [Master] = [
        Master(id: "M001", dharmaName: "明觉法师（演示）", layName: "林知远", templeId: "T001",
               templeName: "灵隐寺", position: "客堂法师", sect: "禅宗", type: "佛教",
               authStatus: "已认证", specialties: ["禅修入门", "佛教文化", "祈愿礼仪"],
               avatar: "master-avatar-zhihai", rating: 4.9, isOnline: true, startPrice: 328,
               shelfStatus: "on_shelf"),
        Master(id: "M002", dharmaName: "玄和道长（演示）", layName: "赵清远", templeId: "T002",
               templeName: "北京白云观", position: "经师", sect: "全真派", type: "道教",
               authStatus: "已认证", specialties: ["道教文化", "科仪讲解", "养生导引"],
               avatar: "master-avatar-qingfeng", rating: 4.8, isOnline: true, startPrice: 288,
               shelfStatus: "on_shelf"),
        Master(id: "M003", dharmaName: "延澄法师（演示）", layName: "周安行", templeId: "T003",
               templeName: "嵩山少林寺", position: "禅修讲师", sect: "禅宗", type: "佛教",
               authStatus: "已认证", specialties: ["禅修指导", "少林文化", "静心课程"],
               avatar: "master-avatar-shimingyuan", rating: 4.8, isOnline: true, startPrice: 388,
               shelfStatus: "on_shelf"),
        Master(id: "M004", dharmaName: "嘉措讲师（演示）", layName: "", templeId: "T004",
               templeName: "大昭寺", position: "文化讲师", sect: "各派共尊", type: "佛教",
               authStatus: "已认证", specialties: ["藏传佛教文化", "寺院历史", "祈愿礼仪"],
               avatar: "master-avatar-zhaxiduoji", rating: 5.0, isOnline: true, startPrice: 458,
               shelfStatus: "on_shelf"),
        Master(id: "M005", dharmaName: "慧闻法师（演示）", layName: "孙明远", templeId: "T005",
               templeName: "普济禅寺", position: "客堂法师", sect: "禅宗", type: "佛教",
               authStatus: "待审核", specialties: ["观音文化", "佛教礼仪", "静心交流"],
               avatar: "master-avatar-miaoyin", rating: 4.5, isOnline: false, startPrice: 268,
               shelfStatus: "off_shelf"),
        Master(id: "M006", dharmaName: "守一道长（演示）", layName: "张云舟", templeId: "T006",
               templeName: "武当山紫霄宫", position: "经师", sect: "武当道教", type: "道教",
               authStatus: "已认证", specialties: ["武当文化", "太极养生", "道教礼仪"],
               avatar: "master-avatar-zhangzhishun", rating: 4.9, isOnline: false, startPrice: 518,
               shelfStatus: "on_shelf")
    ]
}

/// 大师服务标签
struct MasterServiceTag: Codable, Hashable {
    let serviceCode: String
    let price: Double
    let status: String?
}
