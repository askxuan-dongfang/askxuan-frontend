//
//  ChatViewModel.swift
//  DongFangApp
//
//  对话共享 ViewModel：
//  - 对话列表（ChatView）：来源于站内消息（message-service），不再使用 mock
//  - 单聊消息流（ChatDetailView）：以站内消息作为会话上下文
//  - 站内消息（message-service）
//  - 实时消息：通过 WebSocketManager（HTTP 轮询，后端暂无 WS）拉取未读数并刷新
//

import SwiftUI
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    // MARK: - 对话列表
    @Published var conversations: [ChatConversation] = []

    // MARK: - 当前会话消息
    @Published var messages: [ChatBubble] = []
    @Published var currentConversation: ChatConversation? = nil
    @Published var inputText: String = ""

    // MARK: - 站内消息
    @Published var notifications: [ChatMessage] = []
    @Published var unreadCount: Int = 0

    // MARK: - 实时连接状态
    @Published var connectionState: WebSocketManager.ConnectionState = .disconnected

    // MARK: - UI 状态
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private let apiClient: APIClient
    private let authStore: AuthStore
    let socketManager: WebSocketManager

    init(apiClient: APIClient = .shared,
         authStore: AuthStore = .shared) {
        self.apiClient = apiClient
        self.authStore = authStore
        self.socketManager = WebSocketManager(apiClient: apiClient, authStore: authStore)

        // 将 WebSocketManager 的状态 / 未读数同步到本 VM
        socketManager.$connectionState.assign(to: &$connectionState)
        socketManager.$unreadCount.assign(to: &$unreadCount)

        // 轮询到新数据时静默刷新会话 / 通知列表
        socketManager.onDataRefresh = { [weak self] in
            await self?.loadConversations(silent: true)
            await self?.loadNotifications(silent: true)
        }

        // 设置 OpenIM 消息接收代理（修复 delegate 缺失，确保 SDK 接入后能收到消息）
        OpenIMManager.shared.delegate = self

        // 启动实时消息（HTTP 轮询）
        socketManager.connect()
    }

    // MARK: - 加载对话列表（来源于站内消息）
    /// - Parameter silent: 静默模式（轮询触发），不切换 isLoading / errorMessage
    func loadConversations(silent: Bool = false) async {
        if !silent {
            isLoading = true
            errorMessage = nil
        }
        do {
            let resp: PageResponse<ChatMessage> = try await apiClient.request(
                .messages(userId: authStore.userId, isRead: -1, page: 1, size: 20))
            self.conversations = resp.list.map { ChatConversation(from: $0) }
        } catch {
            self.conversations = []
            if !silent { self.errorMessage = error.localizedDescription }
        }
        if !silent { isLoading = false }
    }

    // MARK: - 进入会话（以站内消息内容作为会话上下文）
    func enterConversation(_ conversation: ChatConversation) {
        currentConversation = conversation
        // 后端无 IM 历史接口，以该会话对应的站内消息作为起始消息
        messages = [ChatBubble(id: UUID().uuidString,
                               text: conversation.lastMessage,
                               isFromMe: false,
                               time: conversation.lastTime,
                               status: .sent)]
    }

    // MARK: - 发送消息（通过 OpenIM SDK 发送给法师）
    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let conversation = currentConversation else { return }

        let bubbleId = UUID().uuidString
        let bubble = ChatBubble(id: bubbleId,
                                text: text,
                                isFromMe: true,
                                time: AppDateFormatter.time.string(from: Date()),
                                status: .pending)
        messages.append(bubble)
        inputText = ""

        // 通过 OpenIM SDK 发送（法师 OpenIM userID 约定为 "m_" + masterId）
        let recvID = "m_" + conversation.masterId
        OpenIMManager.shared.sendMessage(text: text, to: recvID) { [weak self] success in
            guard let self else { return }
            self.updateBubbleStatus(bubbleId, success ? .sent : .failed)
            if !success {
                self.errorMessage = "发送失败"
            }
        }
    }

    /// 更新某条消息的发送状态
    private func updateBubbleStatus(_ id: String, _ status: SendStatus) {
        if let idx = messages.firstIndex(where: { $0.id == id }) {
            messages[idx].status = status
        }
    }

    // MARK: - 站内消息
    func loadNotifications(silent: Bool = false) async {
        if !silent {
            isLoading = true
            errorMessage = nil
        }
        do {
            let resp: PageResponse<ChatMessage> = try await apiClient.request(
                .messages(userId: authStore.userId, isRead: 0, page: 1, size: 20))
            self.notifications = resp.list
        } catch {
            self.notifications = []
            if !silent { self.errorMessage = error.localizedDescription }
        }
        if !silent { isLoading = false }
    }

    func loadUnreadCount() async {
        do {
            let resp: UnreadCountResponse = try await apiClient.request(
                .unreadCount(userId: authStore.userId))
            self.unreadCount = Int(resp.count)
        } catch {
            // 静默失败，轮询会持续重试
        }
    }

    func markAsRead(_ message: ChatMessage) async {
        do {
            let _: ChatMessage = try await apiClient.request(.messageRead("\(message.id)"))
            await loadNotifications(silent: true)
            await loadUnreadCount()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func markAllAsRead() async {
        do {
            let _: EmptyResponse = try await apiClient.request(
                .readAllMessages(userId: authStore.userId))
            await loadNotifications(silent: true)
            await loadUnreadCount()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}

/// 空响应占位
struct EmptyResponse: Decodable {}

// MARK: - OpenIM 消息接收
extension ChatViewModel: OpenIMManagerDelegate {
    func onRecvC2CMessage(_ message: OpenIMMessage) {
        let bubble = ChatBubble(id: UUID().uuidString,
                                text: message.text ?? "",
                                isFromMe: false,
                                time: AppDateFormatter.time.string(from: Date()),
                                status: .sent)
        messages.append(bubble)
    }

    func onConversationListUpdated(_ conversations: [OpenIMConversation]) {
        // 预留：后续可在此刷新会话列表
    }
}
