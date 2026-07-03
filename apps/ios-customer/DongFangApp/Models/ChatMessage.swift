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
struct ChatConversation: Identifiable, Hashable {
    let id: String
    let masterId: String
    let masterName: String
    let masterAvatar: String
    let templeName: String
    var lastMessage: String
    var lastTime: String
    var unreadCount: Int
    var isOnline: Bool
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
        ChatConversation(id: "C001", masterId: "M001", masterName: "智海法师",
                         masterAvatar: "master-avatar-zhihai", templeName: "灵隐寺",
                         lastMessage: "阿弥陀佛，施主有何疑问？", lastTime: "10:23",
                         unreadCount: 2, isOnline: true),
        ChatConversation(id: "C002", masterId: "M002", masterName: "清风道长",
                         masterAvatar: "master-avatar-qingfeng", templeName: "白云观",
                         lastMessage: "贫道已为您安排祈福法事", lastTime: "昨天",
                         unreadCount: 0, isOnline: true),
        ChatConversation(id: "C003", masterId: "M004", masterName: "扎西多吉活佛",
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

extension ChatConversation {
    /// 由站内消息构造会话项
    /// 说明：后端 message-service 无独立 IM 会话接口，
    /// 这里以站内消息作为会话来源（每条消息对应一个会话行）。
    init(from m: ChatMessage) {
        self.init(id: "msg-\(m.id)",
                  masterId: m.bizId ?? "",
                  masterName: m.title,
                  masterAvatar: "",
                  templeName: m.bizType ?? "",
                  lastMessage: m.content,
                  lastTime: AppDateFormatter.friendly(m.createdAt),
                  unreadCount: m.isRead == 0 ? 1 : 0,
                  isOnline: false)
    }
}
