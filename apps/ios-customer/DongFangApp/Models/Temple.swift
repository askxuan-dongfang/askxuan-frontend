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
    /// 服务编码列表（对齐 temple-service ServiceCodes []string）
    var serviceCodes: [String]?

    enum CodingKeys: String, CodingKey {
        case id, name, region, type, sect, status, address, rating, description, images
        case coverImage, serviceTags, serviceCount, serviceCodes
    }

    init(id: String, name: String, region: String, type: String, sect: String,
         status: String, address: String, coverImage: String, rating: Double,
         description: String, images: [String]? = nil,
         serviceTags: [String]? = nil, serviceCount: Int? = nil,
         serviceCodes: [String]? = nil) {
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
        self.serviceCodes = serviceCodes
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
        self.serviceCodes = try c.decodeIfPresent([String].self, forKey: .serviceCodes)
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
    /// 对齐后端统一寺院字典（T001~T006）和 temple_service 服务标签。
    static let mockData: [Temple] = [
        Temple(id: "T001", name: "灵隐寺", region: "浙江杭州", type: "汉传佛教",
               sect: "禅宗", status: "正常", address: "杭州市西湖区灵隐路法云弄1号",
               coverImage: "temple-card-lingyinsi", rating: 4.9,
               description: "杭州最早的名刹，江南禅宗五大名山之一，以禅修、祈福、开光法事闻名。",
               serviceTags: ["祈福", "供灯", "开光", "求姻缘", "求健康"], serviceCount: 5),
        Temple(id: "T002", name: "白云观", region: "北京", type: "道教",
               sect: "全真派", status: "正常", address: "北京市西城区白云观街1号",
               coverImage: "temple-card-baimasi", rating: 4.7,
               description: "道教全真派三大祖庭之一，北京最大道观，以道教科仪、祈福、化太岁闻名。",
               serviceTags: ["祈福", "上香", "化太岁", "求财运", "求风水"], serviceCount: 5),
        Temple(id: "T003", name: "少林寺", region: "河南嵩山", type: "汉传佛教",
               sect: "禅宗", status: "正常", address: "河南省郑州市登封市嵩山少林景区",
               coverImage: "temple-card-shaolinsi", rating: 4.8,
               description: "禅宗祖庭，少林武术发源地，以禅修、武术、超度、开光法事闻名。",
               serviceTags: ["祈福", "超度", "开光", "求事业", "求学业"], serviceCount: 5),
        Temple(id: "T004", name: "大昭寺", region: "西藏拉萨", type: "藏传佛教",
               sect: "格鲁派", status: "正常", address: "拉萨市城关区八廓街",
               coverImage: "temple-card-dazhaosi", rating: 4.9,
               description: "藏传佛教圣地，以藏密仪轨、灌顶、超度、祈福闻名。",
               serviceTags: ["祈福", "供灯", "超度", "求健康"], serviceCount: 4),
        Temple(id: "T005", name: "普陀山", region: "浙江舟山", type: "汉传佛教",
               sect: "禅宗", status: "待审核", address: "舟山市普陀区普陀山",
               coverImage: "temple-card-famensi", rating: 4.6,
               description: "观音菩萨道场，佛教四大名山之一，以净土法门、观音法门、祈福闻名。",
               serviceTags: ["祈福", "供灯", "求姻缘", "求学业"], serviceCount: 4),
        Temple(id: "T006", name: "武当山", region: "湖北十堰", type: "道教",
               sect: "正一派", status: "正常", address: "十堰市丹江口市武当山特区",
               coverImage: "temple-card-qingyanggong", rating: 4.7,
               description: "道教圣地，真武大帝道场，以内丹、太极、风水、化太岁闻名。",
               serviceTags: ["祈福", "上香", "化太岁", "求事业", "求风水"], serviceCount: 5)
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
