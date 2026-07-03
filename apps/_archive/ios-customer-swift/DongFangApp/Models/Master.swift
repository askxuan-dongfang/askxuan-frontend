//
//  Master.swift
//  DongFangApp
//
//  师傅（法师/道长）数据模型。
//

import Foundation

/// 师傅模型
struct Master: Codable, Identifiable, Hashable {
    let id: String
    /// 法号，如「智海法师」「清风道长」
    let dharmaName: String
    /// 俗名
    let layName: String
    /// 所属寺院 ID
    let templeId: String
    /// 所属寺院名称
    let templeName: String
    /// 职位：住持/监院/首座/活佛/知客 等
    let position: String
    /// 教派
    let sect: String
    /// 类型：佛教/道教
    let type: String
    /// 认证状态：已认证/待审核
    let authStatus: String
    /// 擅长领域
    let specialties: [String]
    /// 头像资源名
    let avatar: String
    /// 评分
    let rating: Double
    /// 是否在线（mock 数据未提供，默认 true）
    var isOnline: Bool?
    /// 起步价（mock 数据未提供，默认 0）
    var startPrice: Double?

    enum CodingKeys: String, CodingKey {
        case id, dharmaName, layName, templeId, templeName, position, sect, type
        case authStatus, specialties, avatar, rating, isOnline, startPrice
    }

    init(id: String, dharmaName: String, layName: String, templeId: String,
         templeName: String, position: String, sect: String, type: String,
         authStatus: String, specialties: [String], avatar: String, rating: Double,
         isOnline: Bool? = true, startPrice: Double? = nil) {
        self.id = id
        self.dharmaName = dharmaName
        self.layName = layName
        self.templeId = templeId
        self.templeName = templeName
        self.position = position
        self.sect = sect
        self.type = type
        self.authStatus = authStatus
        self.specialties = specialties
        self.avatar = avatar
        self.rating = rating
        self.isOnline = isOnline
        self.startPrice = startPrice
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
        self.authStatus = try c.decodeIfPresent(String.self, forKey: .authStatus) ?? "已认证"
        self.specialties = try c.decodeIfPresent([String].self, forKey: .specialties) ?? []
        self.avatar = try c.decodeIfPresent(String.self, forKey: .avatar) ?? ""
        self.rating = try c.decodeIfPresent(Double.self, forKey: .rating) ?? 0
        self.isOnline = try c.decodeIfPresent(Bool.self, forKey: .isOnline) ?? true
        self.startPrice = try c.decodeIfPresent(Double.self, forKey: .startPrice)
    }

    /// 头像资源名（/assets/xxx.jpg -> xxx）
    var avatarAssetName: String {
        let lastComponent = (avatar as NSString).lastPathComponent
        return (lastComponent as NSString).deletingPathExtension
    }

    /// 评分展示文本
    var ratingText: String {
        String(format: "%.1f", rating)
    }

    /// 起步价展示文本（无数据时返回空）
    var startPriceText: String? {
        guard let price = startPrice, price > 0 else { return nil }
        return "¥\(Int(price))起"
    }

    /// 擅长标签拼接文本
    var specialtiesText: String {
        specialties.joined(separator: "·")
    }

    /// 是否在线展示
    var isOnlineDisplay: Bool {
        isOnline ?? true
    }
}

// MARK: - 本地 Mock 数据（网络失败或 Preview 时回退）
extension Master {
    static let mockData: [Master] = [
        Master(id: "M001", dharmaName: "智海法师", layName: "陈建华", templeId: "T001",
               templeName: "灵隐寺", position: "住持", sect: "汉传佛教", type: "佛教",
               authStatus: "已认证", specialties: ["佛学", "禅修", "开光", "祈福"],
               avatar: "master-avatar-zhihai", rating: 4.9, isOnline: true, startPrice: 388),
        Master(id: "M002", dharmaName: "清风道长", layName: "李信军", templeId: "T002",
               templeName: "白云观", position: "监院", sect: "全真道派", type: "道教",
               authStatus: "已认证", specialties: ["道学", "风水", "命理", "祈福"],
               avatar: "master-avatar-qingfeng", rating: 4.8, isOnline: true, startPrice: 268),
        Master(id: "M003", dharmaName: "释延心法师", layName: "王建军", templeId: "T003",
               templeName: "少林寺", position: "首座", sect: "禅宗", type: "佛教",
               authStatus: "已认证", specialties: ["武术", "禅修", "超度", "开光"],
               avatar: "master-avatar-zhihai", rating: 4.8, isOnline: false, startPrice: 328),
        Master(id: "M004", dharmaName: "扎西多吉活佛", layName: "—", templeId: "T004",
               templeName: "大昭寺", position: "活佛", sect: "藏密佛教", type: "佛教",
               authStatus: "已认证", specialties: ["藏密仪轨", "灌顶", "超度", "祈福"],
               avatar: "master-avatar-zhaxiduoji", rating: 5.0, isOnline: true, startPrice: 458)
    ]
}
