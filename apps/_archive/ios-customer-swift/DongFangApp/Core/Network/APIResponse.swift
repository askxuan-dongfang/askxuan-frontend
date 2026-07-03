//
//  APIResponse.swift
//  DongFangApp
//
//  统一响应模型与错误类型。
//

import Foundation

/// 后端统一响应格式
/// - code: 0 表示成功，非 0 表示业务错误
/// - message: 提示信息
/// - data: 业务数据（成功时有值，失败时为 null）
struct APIResponse<T: Decodable>: Decodable {
    let code: Int
    let message: String
    let data: T?

    var isSuccess: Bool { code == 0 }
}

/// API 错误类型
enum APIError: Error, LocalizedError {
    case invalidURL                 // URL 非法
    case decodingError(Error)       // JSON 解析失败
    case serverError(Int, String)   // 服务端错误（状态码 + 消息）
    case unauthorized               // 401 鉴权失败
    case networkError(Error)        // 网络异常

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "请求地址错误"
        case .decodingError(let error):
            return "数据解析失败：\(error.localizedDescription)"
        case .serverError(let code, let message):
            return "服务异常（\(code)）：\(message)"
        case .unauthorized:
            return "登录已过期，请重新登录"
        case .networkError(let error):
            return "网络异常：\(error.localizedDescription)"
        }
    }
}
