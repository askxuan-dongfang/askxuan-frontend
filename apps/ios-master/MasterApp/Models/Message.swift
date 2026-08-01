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

struct MasterBookingChatConversation: Identifiable, Decodable {
    let bookingId: String
    let peerId: String
    let peerName: String
    let peerAvatar: String
    let templeName: String
    let serviceName: String
    let bookingDate: String
    let lastMessage: String
    let lastMessageAt: String
    let canChat: Bool

    var id: String { bookingId }
}

struct MasterBookingChatListResponse: Decodable {
    let total: Int64
    let list: [MasterBookingChatConversation]
    let page: Int
    let size: Int
}

struct MasterBookingChatMessage: Decodable, Identifiable {
    let id: Int64
    let bookingId: String
    let clientMessageId: String
    let senderType: String
    let senderId: String
    let receiverId: String
    let content: String
    let status: String
    let createTime: String
}

struct MasterBookingChatMessageListResponse: Decodable {
    let total: Int64
    let list: [MasterBookingChatMessage]
    let page: Int
    let size: Int
}

struct MasterBookingChatSendRequest: Encodable {
    let clientMessageId: String
    let content: String
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
