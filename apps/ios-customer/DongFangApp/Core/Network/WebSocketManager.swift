//
//  WebSocketManager.swift
//  DongFangApp
//
//  实时消息管理器。
//
//  ⚠️ 重要说明：后端 message-service 当前未提供 WebSocket 接口（仅有站内消息 REST API）。
//  为满足「实时通信 / 未读消息实时提示」的需求，本管理器使用 HTTP 轮询模拟实时消息：
//  - 每 5 秒轮询一次未读消息数（GET /messages/unread-count）
//  - 轮询成功后回调 onDataRefresh，由 ChatViewModel 刷新会话列表 / 通知列表
//  - 通过 connectionState 发布连接状态（已连接 / 断开 / 重连中）
//  待后端支持 WebSocket 后，可将 tick() 替换为真正的 WS 监听，对外 API 保持不变。
//

import Foundation
import Combine

@MainActor
final class WebSocketManager: ObservableObject {

    /// 连接状态
    enum ConnectionState: Equatable {
        case connected       // 已连接（轮询正常）
        case disconnected    // 已断开
        case reconnecting    // 重连中（连续失败）
    }

    /// 当前连接状态
    @Published private(set) var connectionState: ConnectionState = .disconnected

    /// 最新未读消息数（由轮询实时更新）
    @Published private(set) var unreadCount: Int = 0

    /// 轮询到新数据时的回调，ViewModel 据此刷新会话 / 通知列表
    var onDataRefresh: (() async -> Void)?

    /// 轮询间隔（秒）
    private let pollInterval: TimeInterval = 5.0

    /// 连续失败次数达到该阈值后状态切换为 reconnecting
    private let failThreshold: Int = 2

    private let apiClient: APIClient
    private let authStore: AuthStore
    private var pollTask: Task<Void, Never>?
    private var failStreak: Int = 0

    init(apiClient: APIClient = .shared, authStore: AuthStore = .shared) {
        self.apiClient = apiClient
        self.authStore = authStore
    }

    /// 启动实时消息（HTTP 轮询）
    func connect() {
        guard pollTask == nil else { return }
        connectionState = .connected
        let interval = pollInterval
        pollTask = Task { [weak self] in
            // 立即执行一次，随后按间隔轮询
            await self?.tick()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard !Task.isCancelled else { break }
                await self?.tick()
            }
        }
    }

    /// 停止实时消息
    func disconnect() {
        pollTask?.cancel()
        pollTask = nil
        connectionState = .disconnected
    }

    /// 单次轮询：拉取未读数并触发数据刷新
    private func tick() async {
        do {
            let resp: UnreadCountResponse = try await apiClient.request(
                .unreadCount(userId: authStore.userId))
            unreadCount = Int(resp.count)
            failStreak = 0
            connectionState = .connected
            await onDataRefresh?()
        } catch {
            failStreak += 1
            if failStreak >= failThreshold {
                connectionState = .reconnecting
            }
        }
    }
}
