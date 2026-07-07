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
    let sect: String
    let type: String          // 佛教/道教
    let authStatus: String
    let specialties: [String]
    var avatar: String
    let rating: Double
    var isOnline: Bool?
    var startPrice: Double?
    /// 修行年数（对齐原型 home.html 热门师傅卡片）
    var yearsOfPractice: Int?
    /// 咨询人数（对齐原型 home.html 热门师傅卡片）
    var consultationCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, dharmaName, layName, templeId, templeName, position, sect, type
        case authStatus, specialties, avatar, rating, isOnline, startPrice
        case yearsOfPractice, consultationCount
    }

    init(id: String, dharmaName: String, layName: String, templeId: String,
         templeName: String, position: String, sect: String, type: String,
         authStatus: String, specialties: [String], avatar: String, rating: Double,
         isOnline: Bool? = true, startPrice: Double? = nil,
         yearsOfPractice: Int? = nil, consultationCount: Int? = nil) {
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
        self.yearsOfPractice = yearsOfPractice
        self.consultationCount = consultationCount
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
        self.yearsOfPractice = try c.decodeIfPresent(Int.self, forKey: .yearsOfPractice)
        self.consultationCount = try c.decodeIfPresent(Int.self, forKey: .consultationCount)
    }

    var ratingText: String { String(format: "%.1f", rating) }
    var startPriceText: String? {
        guard let price = startPrice, price > 0 else { return nil }
        return "¥\(Int(price))起"
    }
    var specialtiesText: String { specialties.joined(separator: "·") }
    var isOnlineDisplay: Bool { isOnline ?? true }
    /// 修行年数展示（如「30年修行」）
    var yearsText: String? {
        guard let years = yearsOfPractice, years > 0 else { return nil }
        return "\(years)年修行"
    }
    /// 咨询人数展示（如「12,680人咨询」）
    var consultationText: String? {
        guard let count = consultationCount, count > 0 else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return "\(formatter.string(from: NSNumber(value: count)) ?? "\(count)")人咨询"
    }
}

extension Master {
    /// 对齐后端统一师傅字典；每位师傅只归属一个寺院。
    static let mockData: [Master] = [
        Master(id: "M001", dharmaName: "智海法师", layName: "陈建华", templeId: "T001",
               templeName: "灵隐寺", position: "住持", sect: "汉传佛教", type: "佛教",
               authStatus: "已认证", specialties: ["佛学", "禅修", "开光", "祈福"],
               avatar: "master-avatar-zhihai", rating: 4.9, isOnline: true, startPrice: 328,
               yearsOfPractice: 22, consultationCount: 9150),
        Master(id: "M002", dharmaName: "清风道长", layName: "李信军", templeId: "T002",
               templeName: "白云观", position: "监院", sect: "全真道派", type: "道教",
               authStatus: "已认证", specialties: ["道学", "风水", "命理", "祈福"],
               avatar: "master-avatar-qingfeng", rating: 4.8, isOnline: true, startPrice: 288,
               yearsOfPractice: 25, consultationCount: 8320),
        Master(id: "M003", dharmaName: "释延心法师", layName: "王建军", templeId: "T003",
               templeName: "少林寺", position: "首座", sect: "禅宗", type: "佛教",
               authStatus: "已认证", specialties: ["武术", "禅修", "超度", "开光"],
               avatar: "master-avatar-shimingyuan", rating: 4.8, isOnline: true, startPrice: 388,
               yearsOfPractice: 30, consultationCount: 12680),
        Master(id: "M004", dharmaName: "扎西多吉活佛", layName: "—", templeId: "T004",
               templeName: "大昭寺", position: "活佛", sect: "藏密佛教", type: "佛教",
               authStatus: "已认证", specialties: ["藏密仪轨", "灌顶", "超度", "祈福"],
               avatar: "master-avatar-zhaxiduoji", rating: 5.0, isOnline: true, startPrice: 458,
               yearsOfPractice: 18, consultationCount: 5460),
        Master(id: "M005", dharmaName: "慧明法师", layName: "周明华", templeId: "T005",
               templeName: "普陀山", position: "副住持", sect: "汉传佛教", type: "佛教",
               authStatus: "待审核", specialties: ["净土", "观音法门", "祈福"],
               avatar: "master-avatar-miaoyin", rating: 4.5, isOnline: false, startPrice: 268,
               yearsOfPractice: 20, consultationCount: 6890),
        Master(id: "M006", dharmaName: "真武道长", layName: "张志远", templeId: "T006",
               templeName: "武当山", position: "知客", sect: "正一派", type: "道教",
               authStatus: "已认证", specialties: ["内丹修炼", "太极养生"],
               avatar: "master-avatar-zhangzhishun", rating: 4.9, isOnline: false, startPrice: 518,
               yearsOfPractice: 35, consultationCount: 11200)
    ]
}
