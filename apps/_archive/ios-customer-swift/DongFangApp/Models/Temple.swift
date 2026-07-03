//
//  Temple.swift
//  DongFangApp
//
//  寺院数据模型。
//

import Foundation

/// 寺院模型
struct Temple: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    /// 地区，如「浙江杭州」
    let region: String
    /// 类型，如「汉传佛教」「道教」「藏传佛教」
    let type: String
    /// 教派/宗派，如「禅宗」「全真派」「格鲁派」
    let sect: String
    /// 状态：正常/待审核
    let status: String
    /// 详细地址
    let address: String
    /// 封面图资源名
    let coverImage: String
    /// 评分
    let rating: Double
    /// 简介
    let description: String
    /// 图集（可选，详情页轮播）
    var images: [String]?

    enum CodingKeys: String, CodingKey {
        case id, name, region, type, sect, status, address, rating, description, images
        case coverImage
    }

    init(id: String, name: String, region: String, type: String, sect: String,
         status: String, address: String, coverImage: String, rating: Double,
         description: String, images: [String]? = nil) {
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
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.region = try c.decodeIfPresent(String.self, forKey: .region) ?? ""
        self.type = try c.decodeIfPresent(String.self, forKey: .type) ?? ""
        self.sect = try c.decodeIfPresent(String.self, forKey: .sect) ?? ""
        self.status = try c.decodeIfPresent(String.self, forKey: .status) ?? "正常"
        self.address = try c.decodeIfPresent(String.self, forKey: .address) ?? ""
        self.coverImage = try c.decodeIfPresent(String.self, forKey: .coverImage) ?? ""
        self.rating = try c.decodeIfPresent(Double.self, forKey: .rating) ?? 0
        self.description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.images = try c.decodeIfPresent([String].self, forKey: .images)
    }

    /// 兼容 Assets 中的图片名（mock 返回 /assets/xxx.jpg，这里转成不带后缀的资源名）
    var assetImageName: String {
        // /assets/temple-card-lingyinsi.jpg -> temple-card-lingyinsi
        let lastComponent = (coverImage as NSString).lastPathComponent
        return (lastComponent as NSString).deletingPathExtension
    }

    /// 评分展示文本
    var ratingText: String {
        String(format: "%.1f", rating)
    }
}

// MARK: - 本地 Mock 数据（网络失败或 Preview 时回退）
extension Temple {
    static let mockData: [Temple] = [
        Temple(id: "T001", name: "灵隐寺", region: "浙江杭州", type: "汉传佛教",
               sect: "禅宗", status: "正常", address: "杭州市西湖区灵隐路法云弄1号",
               coverImage: "temple-card-lingyinsi", rating: 4.9,
               description: "杭州最早的名刹，江南禅宗五大名山之一，以禅修、祈福、开光法事闻名。"),
        Temple(id: "T002", name: "白云观", region: "北京", type: "道教",
               sect: "全真派", status: "正常", address: "北京市西城区白云观街1号",
               coverImage: "temple-card-baimasi", rating: 4.7,
               description: "道教全真派三大祖庭之一，北京最大道观，以道教科仪、祈福、化太岁闻名。"),
        Temple(id: "T003", name: "少林寺", region: "河南嵩山", type: "汉传佛教",
               sect: "禅宗", status: "正常", address: "河南省郑州市登封市嵩山少林景区",
               coverImage: "temple-card-shaolinsi", rating: 4.8,
               description: "禅宗祖庭，少林武术发源地，以禅修、武术、超度、开光法事闻名。"),
        Temple(id: "T004", name: "大昭寺", region: "西藏拉萨", type: "藏传佛教",
               sect: "格鲁派", status: "正常", address: "拉萨市城关区八廓街",
               coverImage: "temple-card-dazhaosi", rating: 4.9,
               description: "藏传佛教圣地，拉萨城市中心，以藏密仪轨、灌顶、超度、祈福闻名。")
    ]
}
