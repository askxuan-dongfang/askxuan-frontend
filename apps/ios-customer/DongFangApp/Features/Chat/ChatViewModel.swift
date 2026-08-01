//
//  ChatViewModel.swift
//  DongFangApp
//
//  对话共享 ViewModel：
//  - 对话列表：仅来源于已支付预约
//  - 单聊消息流：booking-service 持久化，OpenIM 实时通知
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
    @Published var connectionState: OpenIMManager.ConnectionState = .disconnected

    // MARK: - UI 状态
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private let apiClient: APIClient
    private let authStore: AuthStore
    let socketManager: WebSocketManager

    init(apiClient: APIClient = .shared,
         authStore: AuthStore? = nil) {
        self.apiClient = apiClient
        let resolvedAuthStore = authStore ?? .shared
        self.authStore = resolvedAuthStore
        self.socketManager = WebSocketManager(apiClient: apiClient, authStore: resolvedAuthStore)

        // 顶部连接指示使用真实 OpenIM WebSocket 状态。
        OpenIMManager.shared.$connectionState.assign(to: &$connectionState)
        // 站内通知未读数仍由 message-service 轮询。
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

    // MARK: - 加载已支付预约会话
    /// - Parameter silent: 静默模式（轮询触发），不切换 isLoading / errorMessage
    func loadConversations(silent: Bool = false) async {
        if !silent {
            isLoading = true
            errorMessage = nil
        }
        do {
            let resp: BookingChatListResponse = try await apiClient.request(.bookingChats(page: 1, size: 20))
            self.conversations = resp.list
        } catch {
            self.conversations = []
            if !silent { self.errorMessage = error.localizedDescription }
        }
        if !silent { isLoading = false }
    }

    // MARK: - 进入会话
    func enterConversation(_ conversation: ChatConversation) {
        currentConversation = conversation
        messages = []
        Task { await loadChatMessages(bookingId: conversation.bookingId) }
    }

    func loadChatMessages(bookingId: String) async {
        do {
            let resp: BookingChatMessageListResponse = try await apiClient.request(
                .bookingChatMessages(id: bookingId, page: 1, size: 100))
            guard currentConversation?.bookingId == bookingId else { return }
            messages = resp.list.map {
                ChatBubble(id: $0.clientMessageId,
                           text: $0.content,
                           isFromMe: $0.senderType == "customer",
                           time: AppDateFormatter.friendly($0.createTime),
                           status: $0.status == "sent" ? .sent : .failed)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 发送消息（后端校验付费资格并由 OpenIM 实时投递）
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

        Task {
            do {
                let _: BookingChatMessage = try await apiClient.request(
                    .bookingChatSend(id: conversation.bookingId,
                                     BookingChatMessageSendRequest(clientMessageId: bubbleId, content: text)))
                updateBubbleStatus(bubbleId, .sent)
                await loadConversations(silent: true)
            } catch {
                updateBubbleStatus(bubbleId, .failed)
                errorMessage = error.localizedDescription
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
        guard let bookingId = currentConversation?.bookingId else {
            Task { await loadConversations(silent: true) }
            return
        }
        Task {
            await loadChatMessages(bookingId: bookingId)
            await loadConversations(silent: true)
        }
    }

    func onConversationListUpdated(_ conversations: [OpenIMConversation]) {
        // 预留：后续可在此刷新会话列表
    }
}
