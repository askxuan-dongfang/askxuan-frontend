//
//  Configuration.swift
//  DongFangApp
//
//  环境与全局配置：DEBUG 指向本地 Mock Server，Release 指向生产环境。
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
        case .debug:   return "Debug（本地 Mock）"
        case .release: return "Release（生产）"
        }
    }
}

/// 全局配置
enum AppConfig {
    /// API BaseURL（已包含版本前缀 /api/v1）
    /// - Debug：本地 Mock Server（模拟器走 localhost，真机联调需改为 Mac 局域网 IP）
    /// - Release：线上生产域名
    static let baseURL: URL = {
        #if DEBUG
        return URL(string: "http://localhost:3001/api/v1")!
        #else
        return URL(string: "https://api.dongfang.com/api/v1")!
        #endif
    }()

    /// 是否为 Debug 环境
    static var isDebug: Bool { AppEnvironment.current == .debug }

    /// 是否启用本地 Mock 数据回退（网络失败时使用内置占位数据）
    static let enableMockFallback: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()

    /// UserDefaults 中存储 JWT Token 的 Key
    static let tokenKey = "df_jwt_token"

    /// 请求超时时间（秒）
    static let requestTimeout: TimeInterval = 30
}
