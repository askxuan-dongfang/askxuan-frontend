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
import OpenIMSDK

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

protocol OpenIMManagerDelegate: AnyObject {
    func onRecvC2CMessage(_ message: OpenIMMessage)
    func onConversationListUpdated(_ conversations: [OpenIMConversation])
}

// MARK: - OpenIM SDK 封装单例

final class OpenIMManager: NSObject {
    static let shared = OpenIMManager()

    weak var delegate: OpenIMManagerDelegate?

    private let wsURL = AppConfig.openIMWebSocketURL
    private let apiURL = AppConfig.openIMAPIURL
    private var isInitialized = false

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

        OIMManager.manager.initSDK(with: config) {
            // onConnecting: SDK 正在连接 IM 服务器
        } onConnectFailure: { code, msg in
            // 连接失败
        } onConnectSuccess: {
            // 连接成功
        } onKickedOffline: {
            // 被踢下线
        } onUserTokenExpired: {
            // Token 过期，需重新登录
        } onUserTokenInvalid: { errMsg in
            // Token 无效
        }

        OIMManager.callbacker.addAdvancedMsgListener(listener: self)
        OIMManager.callbacker.addConversationListener(listener: self)
        isInitialized = true
    }

    /// 用 imToken 登录
    func login(userID: String, token: String, completion: @escaping (Bool, Error?) -> Void) {
        guard isInitialized else {
            completion(false, NSError(domain: "OpenIM", code: -1,
                                      userInfo: [NSLocalizedDescriptionKey: "SDK 未初始化"]))
            return
        }
        OIMManager.manager.login(userID, token: token, onSuccess: { _ in
            DispatchQueue.main.async { completion(true, nil) }
        }, onFailure: { code, msg in
            let error = NSError(domain: "OpenIM", code: Int(code),
                                userInfo: [NSLocalizedDescriptionKey: msg ?? "登录失败"])
            DispatchQueue.main.async { completion(false, error) }
        })
    }

    /// 登出
    func logout(completion: @escaping (Bool) -> Void) {
        OIMManager.manager.logoutWith(onSuccess: { _ in
            DispatchQueue.main.async { completion(true) }
        }, onFailure: { _, _ in
            DispatchQueue.main.async { completion(false) }
        })
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
                OpenIMMessage(text: msg.content, msgID: msg.clientMsgID,
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
        return OpenIMMessage(text: msg.content, msgID: msg.clientMsgID,
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
    func onRecvNewMessage(_ msg: OIMMessageInfo!) {
        guard let message = toBusinessMessage(msg) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.onRecvC2CMessage(message)
        }
    }
}

// MARK: - 会话监听（OIMConversationListener）

extension OpenIMManager: OIMConversationListener {
    /// 会话变更
    func onConversationChanged(_ conversations: [OIMConversationInfo]!) {
        let converted = conversations?.compactMap { toBusinessConversation($0) } ?? []
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.onConversationListUpdated(converted)
        }
    }

    /// 新会话
    func onNewConversation(_ conversations: [OIMConversationInfo]!) {
        let converted = conversations?.compactMap { toBusinessConversation($0) } ?? []
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.onConversationListUpdated(converted)
        }
    }
}
