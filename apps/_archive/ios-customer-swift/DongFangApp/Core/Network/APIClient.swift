//
//  APIClient.swift
//  DongFangApp
//
//  网络客户端：
//  - 基于 URLSession + async/await
//  - JWT Token 自动注入（从 UserDefaults 读取）
//  - 统一解析 APIResponse<T> 包装
//  - 统一错误处理
//  - BaseURL 从 Configuration 获取
//

import Foundation

/// 网络客户端（非 MainActor，网络请求在后台执行，结果交由 ViewModel 在主线程消费）
final class APIClient {
    static let shared = APIClient()

    /// BaseURL（包含 /api/v1 前缀）
    private(set) var baseURL: URL = AppConfig.baseURL

    /// URLSession
    private let session: URLSession

    /// JSON 解码器
    private let decoder: JSONDecoder

    /// JSON 编码器
    private let encoder: JSONEncoder

    /// JWT Token 提供者（可被外部替换，默认从 UserDefaults 读取）
    var tokenProvider: () -> String? = {
        UserDefaults.standard.string(forKey: AppConfig.tokenKey)
    }

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = AppConfig.requestTimeout
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.withoutEscapingSlashes]
    }

    /// 配置 BaseURL（App 启动时调用）
    func configureBaseURL(_ url: URL) {
        self.baseURL = url
    }

    /// 核心请求方法
    /// - Parameter endpoint: 端点定义
    /// - Returns: 解析后的业务数据 T
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        let request = try buildRequest(endpoint)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        // 401 鉴权失败
        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        // 非 2xx 错误
        guard (200..<300).contains(httpResponse.statusCode) else {
            // 尝试解析错误消息
            let message = (try? decoder.decode(APIResponse<EmptyData>.self, from: data))?.message
                ?? String(data: data, encoding: .utf8)
                ?? "未知错误"
            throw APIError.serverError(httpResponse.statusCode, message)
        }

        // 解析统一响应格式 { code, message, data }
        do {
            let apiResponse = try decoder.decode(APIResponse<T>.self, from: data)
            if apiResponse.isSuccess, let result = apiResponse.data {
                return result
            }
            // code 非 0：业务错误
            throw APIError.serverError(apiResponse.code, apiResponse.message)
        } catch let error as APIError {
            throw error
        } catch {
            // 兼容某些接口直接返回裸数据（未包装）的情况
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }
        }
    }

    /// 构造 URLRequest
    private func buildRequest(_ endpoint: Endpoint) throws -> URLRequest {
        let url = baseURL.appendingPathComponent(endpoint.path)
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        // 拼接查询参数
        if let queryItems = endpoint.queryItems, !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        guard let finalURL = components?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: finalURL)
        request.httpMethod = endpoint.httpMethod.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // 注入 JWT Token
        if let token = tokenProvider(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // 注入请求体
        if let body = endpoint.body {
            do {
                request.httpBody = try encoder.encode(body)
            } catch {
                throw APIError.decodingError(error)
            }
        }

        return request
    }
}

/// 空数据占位（用于解析仅含 code/message 的错误响应）
private struct EmptyData: Decodable {}
