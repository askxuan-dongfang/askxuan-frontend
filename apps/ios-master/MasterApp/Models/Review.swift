//
//  Review.swift
//  MasterApp
//
//  评价模型（review-service）。
//

import Foundation

/// 评价
struct Review: Identifiable, Decodable {
    let id: Int64
    let reviewNo: String
    let userId: String
    let targetType: String
    let targetId: String
    let rating: Int
    let content: String
    let images: String       // JSON 数组字符串
    let status: String
    let createTime: String
}

/// 评价列表响应
struct ReviewListResponse: Decodable {
    let total: Int64
    let list: [Review]
    let page: Int
    let size: Int
}

extension Review {
    /// 星级文案
    var ratingText: String {
        String(repeating: "★", count: max(0, min(5, rating)))
        + String(repeating: "☆", count: max(0, 5 - rating))
    }

    /// 解析 images JSON 字符串为 URL 数组
    var imageUrls: [String] {
        guard let data = images.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [String] else {
            return []
        }
        return arr
    }

    /// 目标类型文案
    var targetTypeText: String {
        switch targetType {
        case "booking":    return "预约"
        case "diy_order":  return "DIY 订单"
        case "shop_order": return "商城订单"
        default:           return targetType
        }
    }
}
