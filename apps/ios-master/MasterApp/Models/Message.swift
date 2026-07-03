//
//  Message.swift
//  MasterApp
//
//  站内消息模型（message-service，master-scoped from JWT）。
//

import Foundation

/// 站内消息
struct MasterMessage: Identifiable, Decodable {
    let id: Int64
    let userId: String
    let title: String
    let content: String
    let bizType: String
    let bizId: String
    let isRead: Int
    let createdAt: String
}

/// 消息列表响应
struct MessageListResponse: Decodable {
    let total: Int64
    let list: [MasterMessage]
    let page: Int
    let size: Int
}

/// 已读响应
struct MessageReadResponse: Decodable {
    let id: Int64
    let isRead: Int
}

extension MasterMessage {
    var isReadBool: Bool { isRead == 1 }

    /// 业务类型文案
    var bizTypeText: String {
        switch bizType {
        case "booking":  return "预约"
        case "system":   return "系统"
        case "consult":  return "咨询"
        case "income":   return "收益"
        case "audit":    return "审核"
        default:         return bizType
        }
    }
}
