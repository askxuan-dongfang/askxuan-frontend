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
    let conversationId: String
    let sourceType: String
    let sourceId: String
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
    let expiresAt: String

    var id: String { conversationId }

    enum CodingKeys: String, CodingKey {
        case conversationId, sourceType, sourceId, bookingId, peerId, peerName, peerAvatar
        case templeName, serviceName, bookingDate, lastMessage, lastMessageAt, canChat, expiresAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bookingId = try c.decodeIfPresent(String.self, forKey: .bookingId) ?? ""
        sourceId = try c.decodeIfPresent(String.self, forKey: .sourceId) ?? bookingId
        conversationId = try c.decodeIfPresent(String.self, forKey: .conversationId) ?? sourceId
        sourceType = try c.decodeIfPresent(String.self, forKey: .sourceType) ?? "booking"
        peerId = try c.decodeIfPresent(String.self, forKey: .peerId) ?? ""
        peerName = try c.decodeIfPresent(String.self, forKey: .peerName) ?? "咨询用户"
        peerAvatar = try c.decodeIfPresent(String.self, forKey: .peerAvatar) ?? ""
        templeName = try c.decodeIfPresent(String.self, forKey: .templeName) ?? ""
        serviceName = try c.decodeIfPresent(String.self, forKey: .serviceName) ?? ""
        bookingDate = try c.decodeIfPresent(String.self, forKey: .bookingDate) ?? ""
        lastMessage = try c.decodeIfPresent(String.self, forKey: .lastMessage) ?? ""
        lastMessageAt = try c.decodeIfPresent(String.self, forKey: .lastMessageAt) ?? ""
        canChat = try c.decodeIfPresent(Bool.self, forKey: .canChat) ?? false
        expiresAt = try c.decodeIfPresent(String.self, forKey: .expiresAt) ?? ""
    }

    init(bookingId: String, peerId: String, peerName: String, peerAvatar: String,
         templeName: String, serviceName: String, bookingDate: String,
         lastMessage: String, lastMessageAt: String, canChat: Bool,
         conversationId: String? = nil, sourceType: String = "booking", expiresAt: String = "") {
        self.conversationId = conversationId ?? bookingId
        self.sourceType = sourceType
        self.sourceId = conversationId ?? bookingId
        self.bookingId = bookingId
        self.peerId = peerId
        self.peerName = peerName
        self.peerAvatar = peerAvatar
        self.templeName = templeName
        self.serviceName = serviceName
        self.bookingDate = bookingDate
        self.lastMessage = lastMessage
        self.lastMessageAt = lastMessageAt
        self.canChat = canChat
        self.expiresAt = expiresAt
    }
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
