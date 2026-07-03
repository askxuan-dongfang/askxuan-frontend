//
//  Configuration.swift
//  DongFangApp
//
//  环境与全局配置：DEBUG 指向本地后端，Release 指向生产环境。
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
        case .debug:   return "Debug（本地后端）"
        case .release: return "Release（生产）"
        }
    }
}

/// 全局配置
enum AppConfig {
    /// API BaseURL（已包含版本前缀 /api/v1）
    /// - Debug：本地后端（模拟器走 localhost，真机联调需改为 Mac 局域网 IP）
    /// - Release：线上生产域名
    static let baseURL: URL = {
        #if DEBUG
        return URL(string: "http://localhost:8080/api/v1")!
        #else
        return URL(string: "https://api.askxuan.com/api/v1")!
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
        return "wss://api.askxuan.com/ws"
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
