//
//  MasterProfile.swift
//  MasterApp
//
//  法师资料模型（master-service MasterProfileResp）。
//

import Foundation

/// 法师资料
struct MasterProfile: Identifiable, Decodable {
    let id: String
    let dharmaName: String
    let layName: String
    let templeId: String
    let position: String
    let sect: String
    let type: String
    let authStatus: String
    let specialties: [String]
    let avatar: String
    let bio: String
    let pricing: String
    let rating: Double
}

extension MasterProfile {
    /// 评分格式化
    var ratingText: String {
        String(format: "%.1f", rating)
    }

    /// 认证状态文案
    var authStatusText: String {
        switch authStatus {
        case "verified", "pass", "approved": return "已认证"
        case "pending":                       return "认证中"
        case "rejected":                      return "未通过"
        default:                              return authStatus
        }
    }
}
