//
//  Configuration.swift
//  MasterApp
//
//  环境与全局配置：DEBUG 指向本地后端（localhost:8080），Release 指向生产环境。
//

import Foundation

/// App 运行环境
enum AppEnvironment {
    case debug
    case release

    /// 当前环境（由编译条件决定）
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
        if let value = Bundle.main.object(forInfoDictionaryKey: "ASKXUAN_API_BASE_URL") as? String,
           let url = URL(string: value), !value.isEmpty {
            return url
        }
        #if DEBUG
        return URL(string: "http://localhost:8080/api/v1")!
        #else
        return URL(string: "https://api.askxuan.com/api/v1")!
        #endif
    }()

    static let openIMAPIURL: String = {
        if let value = Bundle.main.object(forInfoDictionaryKey: "OPENIM_API_URL") as? String, !value.isEmpty {
            return value
        }
        #if DEBUG
        return "http://localhost:10002"
        #else
        return "https://im-api.askxuan.com"
        #endif
    }()

    static let openIMWebSocketURL: String = {
        if let value = Bundle.main.object(forInfoDictionaryKey: "OPENIM_WS_URL") as? String, !value.isEmpty {
            return value
        }
        #if DEBUG
        return "ws://localhost:10001"
        #else
        return "wss://im-ws.askxuan.com"
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

    /// 请求超时时间（秒）
    static let requestTimeout: TimeInterval = 30

    /// API 客户端识别头
    static let clientType = "master"
    static let clientVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
}
