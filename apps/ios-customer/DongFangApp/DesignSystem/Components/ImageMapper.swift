//
//  ImageMapper.swift
//  DongFangApp
//
//  本地图片资源映射：根据寺院/法师/商品名称查找对应的原型 asset。
//  原型图片位于「产品原型/问玄东方App/assets/」，已打包进 Assets.xcassets。
//

import Foundation

enum ImageMapper {
    /// 寺院名称 → 本地 asset 名
    static let templeImages: [String: String] = [
        "灵隐寺": "temple-card-lingyinsi",
        "白云观": "temple-card-baimasi",
        "少林寺": "temple-card-shaolinsi",
        "大昭寺": "temple-card-dazhaosi",
        "普陀山": "temple-card-famensi",
        "武当山": "temple-card-qingyanggong",
    ]

    /// 法师法名 → 本地 asset 名
    static let masterAvatars: [String: String] = [
        "智海": "master-avatar-zhihai",
        "清风道长": "master-avatar-qingfeng",
        "释延心": "master-avatar-shimingyuan",
        "扎西多吉活佛": "master-avatar-zhaxiduoji",
        "慧明": "master-avatar-miaoyin",
        "真武道长": "master-avatar-zhangzhishun",
    ]

    /// 商品关键词 → 本地 asset 名
    static let productImages: [String: String] = [
        "护身符": "product-hushenfu",
        "经书": "product-jingshu",
        "手串": "product-shuzhu",
        "珠": "product-shuzhu",
        "香": "product-xiangdao",
    ]

    /// Banner asset（对齐原型 home.html 三张 Banner）
    static let banners: [String] = ["banner-ad-1", "banner-ad-2", "banner-ad-3"]

    /// 双入口卡片背景
    static let entryTemple = "entry-temple"
    static let entryMaster = "entry-master"

    /// 灵隐寺大图（寺院详情 Hero）
    static let templeHeroLingyinsi = "temple-hero-lingyinsi"

    /// 法师资料页背景
    static let masterProfileBg = "master-profile-bg"

    /// 视频缩略图
    static let videoThumbs: [String] = ["video-thumb-chanxiu", "video-thumb-fashi", "video-thumb-jiangjing"]

    // MARK: - 查找

    /// 根据寺院名称查找本地 asset（精确 + 模糊匹配）
    static func templeImage(for name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return nil }
        if let asset = templeImages[trimmed] { return asset }
        for (key, asset) in templeImages where trimmed.contains(key) || key.contains(trimmed) {
            return asset
        }
        return nil
    }

    /// 根据法师法名查找本地 asset（精确 + 模糊匹配）
    static func masterAvatar(for dharmaName: String) -> String? {
        let trimmed = dharmaName.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return nil }
        if let asset = masterAvatars[trimmed] { return asset }
        for (key, asset) in masterAvatars where trimmed.contains(key) || key.contains(trimmed) {
            return asset
        }
        return nil
    }

    /// 根据商品名称查找本地 asset
    static func productImage(for name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return nil }
        if let asset = productImages[trimmed] { return asset }
        for (key, asset) in productImages where trimmed.contains(key) {
            return asset
        }
        return nil
    }
}
