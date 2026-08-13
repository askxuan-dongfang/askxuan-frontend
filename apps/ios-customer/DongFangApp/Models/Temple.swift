//
//  Temple.swift
//  DongFangApp
//
//  寺院数据模型（对齐 temple-service）。
//

import Foundation

struct ServiceCatalogItem: Codable, Identifiable, Hashable {
    let code: String
    let name: String
    let category: String
    let priceRange: String

    var id: String { code }
}

struct ServiceCatalogResponse: Codable {
    let list: [ServiceCatalogItem]
}

struct Temple: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let region: String
    let type: String       // 汉传佛教/藏传佛教/道教
    let beliefCode: String // 一级信仰流派
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
        case id, name, region, type, beliefCode, sect, status, address, rating, description, images
        case coverImage, serviceTags, serviceCount, serviceCodes
    }

    init(id: String, name: String, region: String, type: String, beliefCode: String? = nil, sect: String,
         status: String, address: String, coverImage: String, rating: Double,
         description: String, images: [String]? = nil,
         serviceTags: [String]? = nil, serviceCount: Int? = nil,
         serviceCodes: [String]? = nil) {
        self.id = id
        self.name = name
        self.region = region
        self.type = type
        self.beliefCode = beliefCode ?? Self.inferBelief(type: type, sect: sect)
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
        self.beliefCode = try c.decodeIfPresent(String.self, forKey: .beliefCode) ?? Self.inferBelief(type: type, sect: sect)
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

    private static func inferBelief(type: String, sect: String) -> String {
        if type.contains("藏") || sect.contains("格鲁") { return "tibetan_buddhism" }
        if type.contains("道") || sect.contains("全真") || sect.contains("正一") { return "daoism" }
        if type.contains("民间") { return "folk" }
        return "han_buddhism"
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
    /// 离线预览数据；在线页面以 temple-service 返回值为准。
    static let mockData: [Temple] = [
        Temple(id: "T001", name: "灵隐寺", region: "浙江杭州", type: "汉传佛教",
               sect: "禅宗", status: "正常", address: "浙江省杭州市西湖区灵隐路法云弄1号",
               coverImage: "https://101.96.228.71/objects/askxuan/temp/20260813173807_T001.jpg", rating: 4.9,
               description: "灵隐寺创建于东晋咸和元年（326年），是杭州历史悠久的佛教寺院。",
               serviceTags: ["祈福", "供灯", "开光", "求姻缘", "求健康"], serviceCount: 5),
        Temple(id: "T002", name: "北京白云观", region: "北京西城", type: "道教",
               sect: "全真派", status: "正常", address: "北京市西城区白云观街9号",
               coverImage: "https://101.96.228.71/objects/askxuan/temp/20260813173756_T002.jpg", rating: 4.7,
               description: "北京白云观始建于唐代，是全真道重要祖庭和龙门派祖庭。",
               serviceTags: ["祈福", "上香", "化太岁", "求财运", "求风水"], serviceCount: 5),
        Temple(id: "T003", name: "嵩山少林寺", region: "河南登封", type: "汉传佛教",
               sect: "禅宗", status: "正常", address: "河南省郑州市登封市嵩山少林景区",
               coverImage: "https://101.96.228.71/objects/askxuan/temp/20260813174105_T003.jpg", rating: 4.8,
               description: "嵩山少林寺始建于北魏太和十九年（495年），是禅宗与少林文化的重要场所。",
               serviceTags: ["祈福", "超度", "开光", "求事业", "求学业"], serviceCount: 5),
        Temple(id: "T004", name: "大昭寺", region: "西藏拉萨", type: "藏传佛教",
               sect: "各派共尊", status: "正常", address: "西藏自治区拉萨市城关区八廓西街2号",
               coverImage: "https://101.96.228.71/objects/askxuan/temp/20260813173802_T004.jpg", rating: 4.9,
               description: "大昭寺始建于公元7世纪，是藏传佛教各教派共同尊崇的寺院。",
               serviceTags: ["祈福", "供灯", "超度", "求健康"], serviceCount: 4),
        Temple(id: "T005", name: "普济禅寺", region: "浙江舟山", type: "汉传佛教",
               sect: "禅宗", status: "待审核", address: "浙江省舟山市普陀区普陀山镇香华街",
               coverImage: "https://101.96.228.71/objects/askxuan/temp/20260813173810_T005.jpg", rating: 4.6,
               description: "普济禅寺位于普陀山白华顶南麓，是普陀山佛教活动的重要场所。",
               serviceTags: ["祈福", "供灯", "求姻缘", "求学业"], serviceCount: 4),
        Temple(id: "T006", name: "武当山紫霄宫", region: "湖北十堰", type: "道教",
               sect: "武当道教", status: "正常", address: "湖北省十堰市丹江口市武当山特区紫霄村",
               coverImage: "https://101.96.228.71/objects/askxuan/temp/20260813173804_T006.jpg", rating: 4.7,
               description: "紫霄宫位于武当山展旗峰下，是武当山古建筑群的重要组成部分。",
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
	let slots: [TempleServiceSlot]?
    let status: String
    let createTime: String?
}

struct TempleServiceSlot: Codable, Identifiable, Hashable {
	let code: String
	let label: String
	let startTime: String
	let endTime: String
	let capacity: Int
	let status: String
	let sort: Int

	var id: String { code }
	var timeRange: String { "\(startTime)-\(endTime)" }
}

struct TempleServiceListResponse: Codable {
	let list: [TempleServiceInfo]
}
