//
//  ChatMessage.swift
//  DongFangApp
//
//  对话/消息数据模型（对齐 message-service）。
//

import Foundation

/// 站内消息（message-service）
struct ChatMessage: Codable, Identifiable, Hashable {
    let id: Int64
    let userId: String?
    let title: String
    let content: String
    let bizType: String?         // booking/system
    let bizId: String?
    let isRead: Int              // 0未读 1已读
    let createdAt: String?

    var isReadBool: Bool { isRead == 1 }
    var unreadBadge: Bool { isRead == 0 }

    enum CodingKeys: String, CodingKey {
        case id, userId, title, content, bizType, bizId, isRead, createdAt
    }
}

/// 对话会话（C端 IM 简化模型，用于对话列表）
struct ChatConversation: Identifiable, Hashable, Decodable {
    let conversationId: String
    let sourceType: String
    let sourceId: String
    let bookingId: String
    let masterId: String
    let peerOpenIMId: String
    let masterName: String
    let masterAvatar: String
    let templeName: String
    var lastMessage: String
    var lastTime: String
    var unreadCount: Int
    var isOnline: Bool
    let serviceName: String
    let bookingDate: String
    let canChat: Bool
    let expiresAt: String

    var id: String { conversationId }

    enum CodingKeys: String, CodingKey {
        case conversationId, sourceType, sourceId, bookingId, peerId, peerOpenIMId, peerName, peerAvatar, templeName
        case lastMessage, lastMessageAt, serviceName, bookingDate, canChat, expiresAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bookingId = try container.decodeIfPresent(String.self, forKey: .bookingId) ?? ""
        sourceId = try container.decodeIfPresent(String.self, forKey: .sourceId) ?? bookingId
        conversationId = try container.decodeIfPresent(String.self, forKey: .conversationId) ?? sourceId
        sourceType = try container.decodeIfPresent(String.self, forKey: .sourceType) ?? "booking"
        masterId = try container.decode(String.self, forKey: .peerId)
        peerOpenIMId = try container.decodeIfPresent(String.self, forKey: .peerOpenIMId) ?? ""
        masterName = try container.decode(String.self, forKey: .peerName)
        masterAvatar = try container.decodeIfPresent(String.self, forKey: .peerAvatar) ?? ""
        templeName = try container.decodeIfPresent(String.self, forKey: .templeName) ?? ""
        lastMessage = try container.decode(String.self, forKey: .lastMessage)
        lastTime = AppDateFormatter.friendly(try container.decodeIfPresent(String.self, forKey: .lastMessageAt))
        unreadCount = 0
        isOnline = false
        serviceName = try container.decodeIfPresent(String.self, forKey: .serviceName) ?? ""
        bookingDate = try container.decodeIfPresent(String.self, forKey: .bookingDate) ?? ""
        canChat = try container.decodeIfPresent(Bool.self, forKey: .canChat) ?? false
        expiresAt = try container.decodeIfPresent(String.self, forKey: .expiresAt) ?? ""
    }

    init(bookingId: String, masterId: String, peerOpenIMId: String = "", masterName: String, masterAvatar: String,
         templeName: String, lastMessage: String, lastTime: String, unreadCount: Int,
         isOnline: Bool, serviceName: String = "", bookingDate: String = "", canChat: Bool = true,
         conversationId: String? = nil, sourceType: String = "booking", expiresAt: String = "") {
        self.conversationId = conversationId ?? bookingId
        self.sourceType = sourceType
        self.sourceId = conversationId ?? bookingId
        self.bookingId = bookingId
        self.masterId = masterId
        self.peerOpenIMId = peerOpenIMId
        self.masterName = masterName
        self.masterAvatar = masterAvatar
        self.templeName = templeName
        self.lastMessage = lastMessage
        self.lastTime = lastTime
        self.unreadCount = unreadCount
        self.isOnline = isOnline
        self.serviceName = serviceName
        self.bookingDate = bookingDate
        self.canChat = canChat
        self.expiresAt = expiresAt
    }

    var entitlementDescription: String {
        sourceType == "consultation" ? "即时咨询" : serviceName
    }
}

struct BookingChatListResponse: Decodable {
    let total: Int64
    let list: [ChatConversation]
    let page: Int
    let size: Int
}

struct BookingChatMessage: Decodable, Identifiable {
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

struct BookingChatMessageListResponse: Decodable {
    let total: Int64
    let list: [BookingChatMessage]
    let page: Int
    let size: Int
}

struct BookingChatMessageSendRequest: Encodable {
    let clientMessageId: String
    let content: String
}

struct ConsultationQuote: Decodable {
    let masterId: String
    let masterName: String
    let templeId: String
    let templeName: String
    let enabled: Bool
    let consultFee: Double
    let validHours: Int
    let responseMinutes: Int
}

struct ConsultationCreateRequest: Encodable {
    let requestId: String
    let masterId: String
    let question: String
}

struct ConsultationOrder: Decodable, Identifiable {
    let id: String
    let masterId: String
    let masterName: String
    let templeId: String
    let templeName: String
    let consultFee: Double
    let validHours: Int
    let responseMinutes: Int
    let question: String
    let paymentNo: String
    let paymentStatus: String
    let status: String
    let validFrom: String
    let expiresAt: String
    let simulated: Bool
    let conversationId: String
    let createdAt: String
}

/// 单条聊天消息（UI 用）
struct ChatBubble: Identifiable, Hashable {
    let id: String
    let text: String
    let isFromMe: Bool
    let time: String
    var aiResult: AiResult?     // AI 问事结果（可选）
    var status: SendStatus = .sent
}

/// 消息发送状态
enum SendStatus: Hashable {
    case pending    // 发送中
    case sent       // 已发送
    case failed     // 发送失败
}

extension ChatConversation {
    static let mockConversations: [ChatConversation] = [
        ChatConversation(bookingId: "C001", masterId: "M001", masterName: "明觉法师（演示）",
                         masterAvatar: "master-avatar-zhihai", templeName: "灵隐寺",
                         lastMessage: "阿弥陀佛，施主有何疑问？", lastTime: "10:23",
                         unreadCount: 2, isOnline: true),
        ChatConversation(bookingId: "C002", masterId: "M002", masterName: "玄和道长（演示）",
                         masterAvatar: "master-avatar-qingfeng", templeName: "白云观",
                         lastMessage: "贫道已为您安排祈福法事", lastTime: "昨天",
                         unreadCount: 0, isOnline: true),
        ChatConversation(bookingId: "C003", masterId: "M004", masterName: "嘉措讲师（演示）",
                         masterAvatar: "master-avatar-zhaxiduoji", templeName: "大昭寺",
                         lastMessage: "愿佛法加持，吉祥如意", lastTime: "06-28",
                         unreadCount: 0, isOnline: false)
    ]
}

extension ChatBubble {
    static let mockBubbles: [ChatBubble] = [
        ChatBubble(id: "m1", text: "阿弥陀佛，施主请讲", isFromMe: false, time: "10:20"),
        ChatBubble(id: "m2", text: "法师您好，我想咨询禅修入定之法", isFromMe: true, time: "10:21"),
        ChatBubble(id: "m3", text: "禅修重在调息调心，初学者可从数息观入手。先端坐放松，专注呼吸，从一数到十，反复循环。", isFromMe: false, time: "10:22"),
        ChatBubble(id: "m4", text: "明白，多谢法师指点", isFromMe: true, time: "10:23")
    ]
}
