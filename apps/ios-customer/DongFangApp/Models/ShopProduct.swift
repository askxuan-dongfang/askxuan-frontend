//
//  ShopProduct.swift
//  DongFangApp
//
//  商城商品数据模型（对齐 product-service）。
//

import Foundation

/// 商品
struct ShopProduct: Codable, Identifiable, Hashable {
    let id: Int64
    let productNo: String?
    let name: String
    let categoryId: Int64?
    var categoryName: String?
    let description: String
    let mainImage: String
    let status: String          // draft/on_shelf/off_shelf
    let price: Double
    let marketPrice: Double?
    let stock: Int
    let tags: String?
    var skus: [ProductSku]?
    var images: [ProductImage]?
    let createTime: String?
    let updateTime: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description, mainImage, status, price, stock, tags, skus, images
        case productNo, categoryId, categoryName, marketPrice, createTime, updateTime
    }

    var priceText: String { "¥\(String(format: "%.0f", price))" }
    var marketPriceText: String? {
        guard let mp = marketPrice, mp > price else { return nil }
        return "¥\(String(format: "%.0f", mp))"
    }
}

/// 商品 SKU
struct ProductSku: Codable, Identifiable, Hashable {
    let id: Int64
    let productId: Int64?
    let specName: String
    let specValue: String
    let price: Double
    let stock: Int
    let skuNo: String?
}

/// 商品图片
struct ProductImage: Codable, Identifiable, Hashable {
    let id: Int64
    let productId: Int64?
    let imageUrl: String
    let sort: Int
    let type: String            // main/detail
}

/// 商品分类
struct ProductCategory: Codable, Identifiable, Hashable {
    let id: Int64
    let parentId: Int64?
    let name: String
    let level: Int
    let sort: Int?
    var children: [ProductCategory]?
}

extension ShopProduct {
    static let mockProducts: [ShopProduct] = [
        ShopProduct(id: 1, productNo: "P001", name: "天然星月菩提手串",
                    categoryId: 1, categoryName: "手串",
                    description: "精选天然星月菩提子，配南红玛瑙隔珠，法师开光加持。",
                    mainImage: "", status: "on_shelf", price: 388, marketPrice: 588,
                    stock: 100, tags: "开光,菩提", skus: nil, images: nil,
                    createTime: "2026-06-01", updateTime: "2026-06-01"),
        ShopProduct(id: 2, productNo: "P002", name: "檀香线香礼盒",
                    categoryId: 2, categoryName: "香品",
                    description: "老山檀香线香，礼盒装，适合居家供养。",
                    mainImage: "", status: "on_shelf", price: 168, marketPrice: 268,
                    stock: 200, tags: "檀香,供养", skus: nil, images: nil,
                    createTime: "2026-06-01", updateTime: "2026-06-01"),
        ShopProduct(id: 3, productNo: "P003", name: "黄铜莲花酥油灯",
                    categoryId: 3, categoryName: "供灯",
                    description: "黄铜莲花灯盏，配酥油灯芯，供灯专用。",
                    mainImage: "", status: "on_shelf", price: 88, marketPrice: 128,
                    stock: 300, tags: "供灯", skus: nil, images: nil,
                    createTime: "2026-06-01", updateTime: "2026-06-01"),
        ShopProduct(id: 4, productNo: "P004", name: "和田玉平安扣",
                    categoryId: 1, categoryName: "挂件",
                    description: "和田玉平安扣，寓意平安吉祥，开光加持。",
                    mainImage: "", status: "on_shelf", price: 1280, marketPrice: 1880,
                    stock: 30, tags: "开光,和田玉", skus: nil, images: nil,
                    createTime: "2026-06-01", updateTime: "2026-06-01")
    ]
}
