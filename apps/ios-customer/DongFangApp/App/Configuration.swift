//
//  Configuration.swift
//  DongFangApp
//
//  环境与全局配置：构建设置指向公网 IP HTTPS Demo。
//

import Foundation

/// App 运行环境
enum AppEnvironment {
    case debug
    case release

    static var current: AppEnvironment {
        #if DEBUG
        return .debug
        #else
        return .release
        #endif
    }

    var displayName: String {
        switch self {
        case .debug:   return "Debug（公网 IP Demo）"
        case .release: return "Release（公网 IP）"
        }
    }
}

/// 全局配置
enum AppConfig {
    /// API BaseURL（已包含版本前缀 /api/v1）
    /// - Debug/Release：构建设置中的公网 IP HTTPS 地址
    static let baseURL: URL = {
        if let value = Bundle.main.object(forInfoDictionaryKey: "ASKXUAN_API_BASE_URL") as? String,
           let url = URL(string: value), !value.isEmpty {
            return url
        }
        #if DEBUG
        return URL(string: "http://localhost:8080/api/v1")!
        #else
        return URL(string: "https://101.96.228.71/api/v1")!
        #endif
    }()

    static let openIMAPIURL: String = {
        if let value = Bundle.main.object(forInfoDictionaryKey: "OPENIM_API_URL") as? String, !value.isEmpty {
            return value
        }
        #if DEBUG
        return "http://localhost:10002"
        #else
        return "https://101.96.228.71/openim-api"
        #endif
    }()

    static let openIMWebSocketURL: String = {
        if let value = Bundle.main.object(forInfoDictionaryKey: "OPENIM_WS_URL") as? String, !value.isEmpty {
            return value
        }
        #if DEBUG
        return "ws://localhost:10001"
        #else
        return "wss://101.96.228.71/openim-ws"
        #endif
    }()

    /// WebSocket BaseURL（预留）
    /// 注意：后端 message-service 暂未提供 WebSocket 接口，
    /// 当前实时消息通过 HTTP 轮询实现（见 WebSocketManager）。
    /// 此配置待后端支持 WS 后启用。
    static let wsBaseURL: String = {
        #if DEBUG
        return "ws://localhost:8080/ws"
        #else
        return "wss://101.96.228.71/ws"
        #endif
    }()

    /// 是否为 Debug 环境
    static var isDebug: Bool { AppEnvironment.current == .debug }

    /// 是否启用本地 Mock 数据回退（网络失败时使用内置占位数据）
    /// 默认关闭：API 失败时直接展示错误/空状态，避免假数据掩盖后端不可用问题
    static let enableMockFallback: Bool = {
        #if DEBUG
        return false
        #else
        return false
        #endif
    }()

    /// Keychain 中存储 JWT Token 的 Service 名
    static let keychainService = "com.dongfang.customer"

    /// Keychain 中存储 JWT Token 的 Key
    static let tokenKey = "df_jwt_token"

    /// Keychain 中存储 RefreshToken 的 Key
    static let refreshTokenKey = "df_refresh_token"

    /// 默认用户 ID（未登录态下使用的占位）
    static let defaultUserId = "U001"

    /// 请求超时时间（秒）
    static let requestTimeout: TimeInterval = 30

    /// API 客户端识别头
    static let clientType = "customer"
    static let clientVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
}
