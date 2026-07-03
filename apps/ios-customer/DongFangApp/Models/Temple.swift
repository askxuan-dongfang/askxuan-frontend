//
//  Temple.swift
//  DongFangApp
//
//  寺院数据模型（对齐 temple-service）。
//

import Foundation

struct Temple: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let region: String
    let type: String       // 汉传佛教/藏传佛教/道教
    let sect: String       // 禅宗/全真派/格鲁派
    let status: String
    let address: String
    var coverImage: String
    let rating: Double
    let description: String
    var images: [String]?
    /// 服务标签列表（对齐原型 home.html 寺院卡片底部「法事·祈福·供灯·开光」）
    var serviceTags: [String]?
    /// 服务数量（对齐原型 home.html 寺院卡片「5项服务」）
    var serviceCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, region, type, sect, status, address, rating, description, images
        case coverImage, serviceTags, serviceCount
    }

    init(id: String, name: String, region: String, type: String, sect: String,
         status: String, address: String, coverImage: String, rating: Double,
         description: String, images: [String]? = nil,
         serviceTags: [String]? = nil, serviceCount: Int? = nil) {
        self.id = id
        self.name = name
        self.region = region
        self.type = type
        self.sect = sect
        self.status = status
        self.address = address
        self.coverImage = coverImage
        self.rating = rating
        self.description = description
        self.images = images
        self.serviceTags = serviceTags
        self.serviceCount = serviceCount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.region = try c.decodeIfPresent(String.self, forKey: .region) ?? ""
        self.type = try c.decodeIfPresent(String.self, forKey: .type) ?? ""
        self.sect = try c.decodeIfPresent(String.self, forKey: .sect) ?? ""
        self.status = try c.decodeIfPresent(String.self, forKey: .status) ?? "正常"
        self.address = try c.decodeIfPresent(String.self, forKey: .address) ?? ""
        self.coverImage = try c.decodeIfPresent(String.self, forKey: .coverImage) ?? ""
        self.rating = try c.decodeIfPresent(Double.self, forKey: .rating) ?? 0
        self.description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.images = try c.decodeIfPresent([String].self, forKey: .images)
        self.serviceTags = try c.decodeIfPresent([String].self, forKey: .serviceTags)
        self.serviceCount = try c.decodeIfPresent(Int.self, forKey: .serviceCount)
    }

    /// 评分展示文本
    var ratingText: String { String(format: "%.1f", rating) }
    /// 服务标签展示（如「法事·祈福·供灯·开光」）
    var serviceTagsText: String {
        (serviceTags ?? []).joined(separator: "·")
    }
    /// 服务数量展示（如「5项服务」）
    var serviceCountText: String? {
        guard let count = serviceCount, count > 0 else { return nil }
        return "\(count)项服务"
    }
}

extension Temple {
    /// 对齐原型 home.html 热门寺院（白马寺/少林寺/灵隐寺/青羊宫/法门寺/大昭寺）
    static let mockData: [Temple] = [
        Temple(id: "T001", name: "白马寺", region: "洛阳·河南", type: "汉传佛教",
               sect: "禅宗", status: "正常", address: "河南省洛阳市洛龙区白马寺路",
               coverImage: "temple-card-baimasi", rating: 4.9,
               description: "中国第一古刹，佛教传入中国后兴建的第一座官办寺院，有「中国第一古刹」之称。",
               serviceTags: ["法事", "祈福", "供灯", "开光"], serviceCount: 5),
        Temple(id: "T002", name: "少林寺", region: "登封·河南", type: "汉传佛教",
               sect: "禅宗", status: "正常", address: "河南省郑州市登封市嵩山少林景区",
               coverImage: "temple-card-shaolinsi", rating: 4.8,
               description: "禅宗祖庭，少林武术发源地，以禅修、武术、超度、开光法事闻名。",
               serviceTags: ["法事", "禅修", "开光", "超度"], serviceCount: 6),
        Temple(id: "T003", name: "灵隐寺", region: "杭州·浙江", type: "汉传佛教",
               sect: "禅宗", status: "正常", address: "杭州市西湖区灵隐路法云弄1号",
               coverImage: "temple-card-lingyinsi", rating: 4.9,
               description: "杭州最早的名刹，江南禅宗五大名山之一，以禅修、祈福、开光法事闻名。",
               serviceTags: ["祈福", "供灯", "开光", "法事"], serviceCount: 5),
        Temple(id: "T004", name: "青羊宫", region: "成都·四川", type: "道教",
               sect: "全真派", status: "正常", address: "四川省成都市青羊区一环路西二段",
               coverImage: "temple-card-qingyanggong", rating: 4.7,
               description: "道教全真派圣地，成都历史最悠久的道观之一，以道教科仪、化太岁闻名。",
               serviceTags: ["祈福", "法事", "供灯"], serviceCount: 4),
        Temple(id: "T005", name: "法门寺", region: "宝鸡·陕西", type: "汉传佛教",
               sect: "净土宗", status: "正常", address: "陕西省宝鸡市扶风县法门镇",
               coverImage: "temple-card-famensi", rating: 4.8,
               description: "供奉释迦牟尼佛指骨舍利的佛教圣地，以祈福、开光、法事闻名。",
               serviceTags: ["祈福", "开光", "法事"], serviceCount: 4),
        Temple(id: "T006", name: "大昭寺", region: "拉萨·西藏", type: "藏传佛教",
               sect: "格鲁派", status: "正常", address: "拉萨市城关区八廓街",
               coverImage: "temple-card-dazhaosi", rating: 4.9,
               description: "藏传佛教圣地，以藏密仪轨、灌顶、超度、祈福闻名。",
               serviceTags: ["灌顶", "加持", "祈福"], serviceCount: 4)
    ]
}

/// 寺院详情聚合（/temples/{id}）
struct TempleDetail: Codable {
    let temple: Temple
    let images: [TempleImage]?
    let services: [TempleServiceInfo]?
}

struct TempleImage: Codable, Identifiable, Hashable {
    let id: Int64
    let templeCode: String?
    let url: String
    let type: String
    let sort: Int
}

struct TempleServiceInfo: Codable, Identifiable, Hashable {
    let id: Int64
    let templeCode: String?
    let serviceCode: String
    let serviceName: String
    let price: Double
    let timeSlots: [String]?
    let status: String
    let createTime: String?
}
