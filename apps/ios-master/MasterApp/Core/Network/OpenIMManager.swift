//
//  OpenIMManager.swift
//  MasterApp
//
//  OpenIM SDK 封装单例。
//  - App 启动时调用 initialize() 初始化 SDK
//  - 登录成功后用 imToken 调用 login(userID:token:)
//  - 提供发送文本消息、拉取历史消息、标记已读等能力
//  - 通过 OpenIMManagerDelegate 回调收到的消息与会话列表变更
//
//  ⚠️ 注意：本文件基于 OpenIM iOS SDK 3.8.x 的 API 编写，
//     OpenIMSDKiOS 的实际类名/协议名/方法签名可能略有差异
//     （如 `OpenIMSDK` vs `OpenIMSDKManager`、`OpenIMMessage` vs `Message`、
//     `OpenIMConversation` vs `Conversation`）。需在 Xcode 中编译验证后调整 API 名称。
//     官方文档：https://doc.rentsoft.cn/zh-hans/sdks/quickstart/ios
//

import Foundation
import OpenIMSDKiOS

/// OpenIM 消息回调代理
protocol OpenIMManagerDelegate: AnyObject {
    func onRecvC2CMessage(_ message: OpenIMMessage)
    func onConversationListUpdated(_ conversations: [OpenIMConversation])
}

/// OpenIM SDK 封装单例
final class OpenIMManager: NSObject {
    static let shared = OpenIMManager()

    weak var delegate: OpenIMManagerDelegate?

    private let wsURL = "ws://127.0.0.1:10001"
    private let apiURL = "http://127.0.0.1:10002"
    private var isInitialized = false

    private override init() {
        super.init()
    }

    /// 初始化 SDK（App 启动时调用一次）
    func initialize() {
        guard !isInitialized else { return }
        OpenIMSDK.shared.initSDK(
            wsAddr: wsURL,
            apiAddr: apiURL,
            logLevel: 3,
            platformID: 1
        )
        OpenIMSDK.shared.addAdvanceMsgListener(self)
        OpenIMSDK.shared.setConversationListener(self)
        isInitialized = true
    }

    /// 用 imToken 登录
    func login(userID: String, token: String, completion: @escaping (Bool, Error?) -> Void) {
        guard isInitialized else {
            completion(false, NSError(domain: "OpenIM", code: -1,
                                      userInfo: [NSLocalizedDescriptionKey: "SDK 未初始化"]))
            return
        }
        OpenIMSDK.shared.login(userID: userID, token: token) { success, error in
            DispatchQueue.main.async { completion(success, error) }
        }
    }

    /// 登出
    func logout(completion: @escaping (Bool) -> Void) {
        OpenIMSDK.shared.logout { success, _ in
            DispatchQueue.main.async { completion(success) }
        }
    }

    /// 发送文本消息
    func sendMessage(text: String, to recvID: String, completion: @escaping (Bool) -> Void) {
        let message = OpenIMSDK.shared.createTextMessage(text: text)
        OpenIMSDK.shared.sendMessage(message, to: recvID, sessionType: 1) { success, _, error in
            DispatchQueue.main.async { completion(success && error == nil) }
        }
    }

    /// 拉取历史消息
    func getHistoryMessages(conversationID: String, startMsg: OpenIMMessage?,
                            count: Int, completion: @escaping ([OpenIMMessage]) -> Void) {
        OpenIMSDK.shared.getAdvancedHistoryMessageList(
            conversationID: conversationID,
            startMsg: startMsg,
            count: count
        ) { messages in
            DispatchQueue.main.async { completion(messages ?? []) }
        }
    }

    /// 标记消息已读
    func markMessageRead(conversationID: String) {
        OpenIMSDK.shared.markSingleMessageHasRead(conversationID: conversationID)
    }
}

// MARK: - 消息监听
extension OpenIMManager: OpenIMSDKAdvanceMsgListener {
    func onRecvC2CMessage(_ message: OpenIMMessage?) {
        guard let msg = message else { return }
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.onRecvC2CMessage(msg)
        }
    }

    func onRecvGroupMessage(_ message: OpenIMMessage?) {}
    func onRecvMessageRevoked(_ msgID: String?) {}
}

// MARK: - 会话监听
extension OpenIMManager: OpenIMSDKConversationListener {
    func onConversationListChanged(_ list: [OpenIMConversation]?) {
        let conversations = list ?? []
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.onConversationListUpdated(conversations)
        }
    }

    func onTotalUnreadMessageCountChanged(_ count: Int32) {}
    func onSyncServerProgress(_ progress: Int) {}
    func onSyncServerFinish() {}
    func onSyncServerFailed() {}
}
