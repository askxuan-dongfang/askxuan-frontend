//
//  APIClient.swift
//  DongFangApp
//
//  网络客户端：
//  - 基于 URLSession + async/await
//  - JWT Token 自动注入（从 AuthStore / Keychain 读取）
//  - 统一解析 APIResponse<T> 包装（{code,message,data}）
//  - 兼容 message-service 等返回原始 JSON（无包装）的接口
//  - 统一错误处理
//  - BaseURL 从 Configuration 获取（http://localhost:8080/api/v1）
//

import Foundation

private actor AccessTokenRefreshCoordinator {
    private var inFlight: Task<String?, Error>?

    func refresh(using operation: @escaping @Sendable () async throws -> String?) async throws -> String? {
        if let inFlight {
            return try await inFlight.value
        }

        let task = Task { try await operation() }
        inFlight = task
        defer { inFlight = nil }
        return try await task.value
    }
}

/// 网络客户端（非 MainActor，网络请求在后台执行，结果交由 ViewModel 在主线程消费）
final class APIClient {
    static let shared = APIClient()

    /// BaseURL（包含 /api/v1 前缀）
    private(set) var baseURL: URL = AppConfig.baseURL

    /// URLSession
    private let session: URLSession

    /// JSON 解码器（统一使用 snake_case 解码策略，与后端字段对齐）
    private let decoder: JSONDecoder

    /// JSON 编码器
    private let encoder: JSONEncoder

    /// 合并多个接口同时遇到 401 时的刷新请求，避免 refresh token 被并发消费。
    private let refreshCoordinator = AccessTokenRefreshCoordinator()

    /// JWT Token 提供者（默认从 Keychain 读取）
    var tokenProvider: () -> String? = {
        KeychainHelper.readString(service: AppConfig.keychainService, key: AppConfig.tokenKey)
    }

    var refreshTokenProvider: () -> String? = {
        KeychainHelper.readString(service: AppConfig.keychainService, key: AppConfig.refreshTokenKey)
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

    /// 核心请求方法（解包 {code,message,data}）
    /// - Parameter endpoint: 端点定义
    /// - Returns: 解析后的业务数据 T
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        let request = try buildRequest(endpoint)
        do {
            return try await perform(request: request)
        } catch APIError.unauthorized {
            if endpoint.shouldAttemptTokenRefresh {
                // 另一个请求可能已完成刷新，优先使用当前新 token 重试。
                if let currentToken = tokenProvider(),
                   authorizationToken(in: request) != currentToken {
                    return try await perform(request: authorizedCopy(of: request, token: currentToken))
                }

                if let newToken = try? await refreshCoordinator.refresh(using: { [weak self] in
                    guard let self else { return nil }
                    return try await self.refreshAccessToken()
                }) {
                    return try await perform(request: authorizedCopy(of: request, token: newToken))
                }

                // 刷新等待期间若凭据已被其他请求更新，不能用旧请求的失败覆盖新登录态。
                if let currentToken = tokenProvider(),
                   authorizationToken(in: request) != currentToken {
                    return try await perform(request: authorizedCopy(of: request, token: currentToken))
                }
            }
            // 只清理由这次失败请求携带的凭据，不能让旧请求覆盖后续的新登录态。
            let failedToken = authorizationToken(in: request)
            await MainActor.run {
                if AuthStore.shared.accessToken == failedToken {
                    AuthStore.shared.logout()
                }
            }
            throw APIError.unauthorized
        }
    }

    struct AIStreamEvent: Decodable {
        let event: String
        let messageId: Int64?
        let content: String?
        let snapshot: String?
        let status: String?
        let message: String?
        let retryable: Bool?
    }

    /// AI SSE 流。模型密钥只在后端，本请求沿用当前用户 JWT。
    func streamAIMessage(
        sessionId: Int64,
        messageId: Int64,
        onEvent: @escaping (AIStreamEvent) async -> Void
    ) async throws {
        let path = "ai/sessions/\(sessionId)/messages/\(messageId)/stream"
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = HTTPMethod.GET.rawValue
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue(AppConfig.clientType, forHTTPHeaderField: "X-Client-Type")
        request.setValue(AppConfig.clientVersion, forHTTPHeaderField: "X-Client-Version")
        if let token = tokenProvider(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }
        if http.statusCode == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.serverError(http.statusCode, "AI 流式连接失败")
        }

        var eventName = "delta"
        var dataLines: [String] = []
        for try await line in bytes.lines {
            if line.isEmpty {
                guard !dataLines.isEmpty else { continue }
                let data = Data(dataLines.joined().utf8)
                var payload = try decoder.decode(AIStreamEvent.self, from: data)
                payload = AIStreamEvent(
                    event: eventName,
                    messageId: payload.messageId,
                    content: payload.content,
                    snapshot: payload.snapshot,
                    status: payload.status,
                    message: payload.message,
                    retryable: payload.retryable
                )
                await onEvent(payload)
                eventName = "delta"
                dataLines.removeAll(keepingCapacity: true)
            } else if line.hasPrefix("event:") {
                eventName = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                dataLines.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
            }
        }
    }

    func upload(_ data: Data, to url: URL, headers: [String: String]) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        let (_, response) = try await session.upload(for: request, from: data)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.networkError(URLError(.cannotWriteToFile))
        }
    }

    private func perform<T: Decodable>(request: URLRequest) async throws -> T {
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
            // 业务码 40101：未登录或登录已过期 → 触发登出
            if apiResponse.code == 40101 {
                throw APIError.unauthorized
            }
            // code 非 0：业务错误
            throw APIError.serverError(apiResponse.code, apiResponse.message)
        } catch let error as APIError {
            throw error
        } catch {
            // 兼容某些接口直接返回裸数据（未包装，如 message-service）
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }
        }
    }

    private func refreshAccessToken() async throws -> String? {
        guard let refreshToken = refreshTokenProvider(), !refreshToken.isEmpty else {
            return nil
        }
        var request = try buildRequest(.authRefresh(refreshToken: refreshToken))
        request.setValue(nil, forHTTPHeaderField: "Authorization")
        let resp: RefreshResponse = try await perform(request: request)
        await MainActor.run {
            AuthStore.shared.updateAccessToken(resp.accessToken)
        }
        return resp.accessToken
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
        request.setValue(AppConfig.clientType, forHTTPHeaderField: "X-Client-Type")
        request.setValue(AppConfig.clientVersion, forHTTPHeaderField: "X-Client-Version")

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

    private func authorizationToken(in request: URLRequest) -> String? {
        request.value(forHTTPHeaderField: "Authorization")?
            .replacingOccurrences(of: "Bearer ", with: "")
    }

    private func authorizedCopy(of request: URLRequest, token: String) -> URLRequest {
        var copy = request
        copy.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return copy
    }
}

/// 空数据占位（用于解析仅含 code/message 的错误响应）
private struct EmptyData: Decodable {}
