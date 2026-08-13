//
//  OpenIMManager.swift
//  DongFangApp
//
//  OpenIM SDK 封装单例（真实 SDK 版本）。
//
//  依赖：CocoaPods pod 'OpenIMSDK', '~> 3.8.3'
//  真实 SDK 主类：OIMManager.manager / OIMManager.callbacker
//  对外接口保持不变，调用点（ChatViewModel/ChatView）无需修改。
//

import Foundation
import Combine
import OpenIMSDK
import UIKit

// MARK: - 业务模型（对上层暴露，隔离 SDK 类型）

/// OpenIM 消息业务模型
struct OpenIMMessage {
    var text: String?
    var msgID: String?
    var sendID: String?
    var recvID: String?
}

/// OpenIM 会话业务模型
struct OpenIMConversation {
    var conversationID: String?
    var userID: String?
    var lastMessage: String?
}

// MARK: - OpenIM 消息回调代理

@MainActor
protocol OpenIMManagerDelegate: AnyObject {
    func onRecvC2CMessage(_ message: OpenIMMessage)
    func onConversationListUpdated(_ conversations: [OpenIMConversation])
}

// MARK: - OpenIM SDK 封装单例

final class OpenIMManager: NSObject, ObservableObject {
    static let shared = OpenIMManager()

    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
    }

    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var onlineUserIDs: Set<String> = []

    weak var delegate: OpenIMManagerDelegate?

    private let wsURL = AppConfig.openIMWebSocketURL
    private let apiURL = AppConfig.openIMAPIURL
    private var isInitialized = false
    private var loginUserID: String?
    private var loginToken: String?
    private var reconnectAttempt = 0
    private var reconnectWorkItem: DispatchWorkItem?
    private var watchedUserIDs: Set<String> = []

    private override init() {
        super.init()
    }

    /// 初始化 SDK（App 启动时调用一次）
    func initialize() {
        guard !isInitialized else { return }

        let config = OIMInitConfig()
        config.apiAddr = apiURL
        config.wsAddr = wsURL
        config.logLevel = 6

        OIMManager.manager.initSDK(with: config) { [weak self] in
            self?.publishConnectionState(.connecting)
        } onConnectFailure: { [weak self] _, _ in
            self?.publishConnectionState(.disconnected)
            self?.scheduleReconnect()
        } onConnectSuccess: { [weak self] in
            self?.publishConnectionState(.connected)
            self?.resetReconnect()
            self?.refreshWatchedUsers()
        } onKickedOffline: { [weak self] in
            self?.publishConnectionState(.disconnected)
        } onUserTokenExpired: { [weak self] in
            self?.publishConnectionState(.disconnected)
        } onUserTokenInvalid: { [weak self] _ in
            self?.publishConnectionState(.disconnected)
        }

        OIMManager.callbacker.addAdvancedMsgListener(listener: self)
        OIMManager.callbacker.addConversationListener(listener: self)
        OIMManager.callbacker.addUserListener(listener: self)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        isInitialized = true
    }

    /// 用 imToken 登录
    func login(userID: String, token: String, completion: @escaping (Bool, Error?) -> Void) {
        guard isInitialized else {
            completion(false, NSError(domain: "OpenIM", code: -1,
                                      userInfo: [NSLocalizedDescriptionKey: "SDK 未初始化"]))
            return
        }
        loginUserID = userID
        loginToken = token
        reconnectWorkItem?.cancel()
        performLogin(completion: completion)
    }

    private func performLogin(completion: ((Bool, Error?) -> Void)? = nil) {
        guard let userID = loginUserID, let token = loginToken else { return }
        let status = OIMManager.manager.getLoginStatus()
        if status.rawValue == 3, OIMManager.manager.getLoginUserID() == userID {
            publishConnectionState(.connected)
            resetReconnect()
            refreshWatchedUsers()
            DispatchQueue.main.async { completion?(true, nil) }
            return
        }
        if status.rawValue == 2 {
            publishConnectionState(.connecting)
            scheduleReconnect()
            return
        }
        if status.rawValue == 3 {
            OIMManager.manager.logoutWith(onSuccess: { _ in
                self.startLogin(userID: userID, token: token, completion: completion)
            }, onFailure: { _, _ in
                self.startLogin(userID: userID, token: token, completion: completion)
            })
            return
        }
        startLogin(userID: userID, token: token, completion: completion)
    }

    private func startLogin(userID: String, token: String,
                            completion: ((Bool, Error?) -> Void)? = nil) {
        publishConnectionState(.connecting)
        OIMManager.manager.login(userID, token: token, onSuccess: { _ in
            self.publishConnectionState(.connected)
            self.resetReconnect()
            self.refreshWatchedUsers()
            DispatchQueue.main.async { completion?(true, nil) }
        }, onFailure: { code, msg in
            self.publishConnectionState(.disconnected)
            self.scheduleReconnect()
            let error = NSError(domain: "OpenIM", code: Int(code),
                                userInfo: [NSLocalizedDescriptionKey: msg ?? "登录失败"])
            DispatchQueue.main.async { completion?(false, error) }
        })
    }

    private func scheduleReconnect(immediate: Bool = false) {
        guard loginUserID != nil, loginToken != nil else { return }
        reconnectWorkItem?.cancel()
        let delay = immediate ? 0 : min(pow(2, Double(reconnectAttempt)), 30)
        reconnectAttempt += 1
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.connectionState == .disconnected else { return }
            self.performLogin()
        }
        reconnectWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func resetReconnect() {
        reconnectAttempt = 0
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
    }

    @objc private func applicationDidBecomeActive() {
        guard connectionState == .disconnected else { return }
        scheduleReconnect(immediate: true)
    }

    /// 登出
    func logout(completion: @escaping (Bool) -> Void) {
        loginUserID = nil
        loginToken = nil
        resetReconnect()
        OIMManager.manager.logoutWith(onSuccess: { _ in
            self.publishConnectionState(.disconnected)
            DispatchQueue.main.async { completion(true) }
        }, onFailure: { _, _ in
            DispatchQueue.main.async { completion(false) }
        })
    }

    private func publishConnectionState(_ state: ConnectionState) {
        DispatchQueue.main.async { [weak self] in self?.connectionState = state }
    }

    func watchUsers(_ userIDs: [String]) {
        watchedUserIDs.formUnion(userIDs.filter { !$0.isEmpty })
        refreshWatchedUsers()
    }

    private func refreshWatchedUsers() {
        let userIDs = Array(watchedUserIDs)
        guard !userIDs.isEmpty, OIMManager.manager.getLoginStatus().rawValue == 3 else { return }
        OIMManager.manager.subscribeUsersStatus(userIDs, onSuccess: { statuses in
            self.applyUserStatuses(statuses ?? [])
        }, onFailure: { _, _ in
            OIMManager.manager.getUserStatus(userIDs, onSuccess: { statuses in
                self.applyUserStatuses(statuses ?? [])
            }, onFailure: { _, _ in })
        })
    }

    private func applyUserStatuses(_ statuses: [OIMUserStatusInfo]) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            var updated = self.onlineUserIDs
            for status in statuses {
                guard let userID = status.userID else { continue }
                if status.status == 1 {
                    updated.insert(userID)
                } else {
                    updated.remove(userID)
                }
            }
            self.onlineUserIDs = updated
        }
    }

    /// 发送文本消息
    func sendMessage(text: String, to recvID: String, completion: @escaping (Bool) -> Void) {
        let message = OIMMessageInfo.createTextMessage(text)
        OIMManager.manager.sendMessage(message, recvID: recvID, groupID: nil,
            offlinePushInfo: nil,
            onSuccess: { _ in
                DispatchQueue.main.async { completion(true) }
            },
            onProgress: { _ in },
            onFailure: { code, msg in
                DispatchQueue.main.async { completion(false) }
            }
        )
    }

    func sendGroupMessage(text: String, groupID: String, completion: @escaping (Bool) -> Void) {
        let message = OIMMessageInfo.createTextMessage(text)
        OIMManager.manager.sendMessage(message, recvID: nil, groupID: groupID,
            offlinePushInfo: nil,
            onSuccess: { _ in DispatchQueue.main.async { completion(true) } },
            onProgress: { _ in },
            onFailure: { _, _ in DispatchQueue.main.async { completion(false) } }
        )
    }

    /// 拉取历史消息
    func getHistoryMessages(conversationID: String, startMsg: OpenIMMessage?,
                            count: Int, completion: @escaping ([OpenIMMessage]) -> Void) {
        let param = OIMGetAdvancedHistoryMessageListParam()
        param.conversationID = conversationID
        param.count = count

        OIMManager.manager.getAdvancedHistoryMessageList(param) { result in
            guard let result = result else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            let messages = result.messageList
            let converted = messages.map { msg in
                OpenIMMessage(text: msg.textElem?.content ?? msg.content, msgID: msg.clientMsgID,
                              sendID: msg.sendID, recvID: msg.recvID)
            }
            DispatchQueue.main.async { completion(converted) }
        } onFailure: { _, _ in
            DispatchQueue.main.async { completion([]) }
        }
    }

    /// 标记会话消息已读
    func markMessageRead(conversationID: String) {
        OIMManager.manager.markConversationMessage(asRead: conversationID,
            onSuccess: nil, onFailure: nil)
    }

    // MARK: - 类型转换工具

    /// OIMMessageInfo → OpenIMMessage
    private func toBusinessMessage(_ msg: OIMMessageInfo?) -> OpenIMMessage? {
        guard let msg = msg else { return nil }
        return OpenIMMessage(text: msg.textElem?.content ?? msg.content, msgID: msg.clientMsgID,
                             sendID: msg.sendID, recvID: msg.recvID)
    }

    /// OIMConversationInfo → OpenIMConversation
    private func toBusinessConversation(_ conv: OIMConversationInfo?) -> OpenIMConversation? {
        guard let conv = conv else { return nil }
        return OpenIMConversation(conversationID: conv.conversationID,
                                  userID: conv.userID,
                                  lastMessage: conv.latestMsg?.content)
    }
}

// MARK: - 消息监听（OIMAdvancedMsgListener）

extension OpenIMManager: OIMAdvancedMsgListener {
    /// 接收新消息（C2C 和 Group 都会触发）
    func onRecvNewMessage(_ msg: OIMMessageInfo) {
        guard let message = toBusinessMessage(msg) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.onRecvC2CMessage(message)
        }
    }
}

// MARK: - 会话监听（OIMConversationListener）

extension OpenIMManager: OIMConversationListener {
    /// 会话变更
    func onConversationChanged(_ conversations: [OIMConversationInfo]) {
        let converted = conversations.compactMap { toBusinessConversation($0) }
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.onConversationListUpdated(converted)
        }
    }

    /// 新会话
    func onNewConversation(_ conversations: [OIMConversationInfo]) {
        let converted = conversations.compactMap { toBusinessConversation($0) }
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.onConversationListUpdated(converted)
        }
    }
}

extension OpenIMManager: OIMUserListener {
    func onUserStatusChanged(_ info: OIMUserStatusInfo) {
        applyUserStatuses([info])
    }
}
