//
//  APIClient.swift
//  MasterApp
//
//  网络客户端：
//  - 基于 URLSession + async/await
//  - JWT Token 自动注入（从 AuthStore/Keychain 读取）
//  - 统一解析 APIResponse<T> 包装 {code,message,data}
//  - 统一错误处理，401 触发登出
//  - BaseURL 从 Configuration 获取
//

import Foundation

private struct AuthenticationFailure: Error {
    let code: Int
    let message: String
    var canRefresh: Bool { code != 40105 }
}

private struct ResponseStatus: Decodable {
    let code: Int
    let message: String?
}

private actor AccessTokenRefreshCoordinator {
    private var inFlight: [AuthRequestSession: Task<AuthRequestSession, Error>] = [:]

    func refresh(for session: AuthRequestSession, using operation: @escaping @Sendable () async throws -> AuthRequestSession) async throws -> AuthRequestSession {
        if let pending = inFlight[session] { return try await pending.value }
        let task = Task { try await operation() }
        inFlight[session] = task
        defer { inFlight[session] = nil }
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

    /// JSON 解码器
    private let decoder: JSONDecoder

    /// JSON 编码器
    private let encoder: JSONEncoder

    /// JWT Token 提供者（从 AuthStore/Keychain 读取，线程安全）
    var tokenProvider: () -> String? = {
        KeychainHelper.shared.read(service: "com.askxuan.master", key: "df_master_token")
    }

    var refreshTokenProvider: () -> String? = {
        KeychainHelper.shared.read(service: "com.askxuan.master", key: "df_master_refresh_token")
    }

    private let refreshCoordinator = AccessTokenRefreshCoordinator()

    init(session: URLSession? = nil) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = AppConfig.requestTimeout
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = session ?? URLSession(configuration: config)

        self.decoder = JSONDecoder()
        // 后端 go-zero JSON tag 为 camelCase（如 bookingDate / masterName / certificateUrls），
        // Swift 属性名同为 camelCase，无需 keyDecodingStrategy 转换。
        // 注意：状态「值」为 snake_case（如 in_progress / reviewed），属 String 字面量，不影响键名映射。
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.withoutEscapingSlashes]
    }

    /// 配置 BaseURL（App 启动时调用）
    func configureBaseURL(_ url: URL) {
        self.baseURL = url
    }

    /// Recover only within the login that sent this request. Never replay a write as another account.
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        let context = await MainActor.run { AuthStore.shared.requestSession }
        let request = try buildRequest(endpoint)
        return try await withSessionRecovery(context, usesSession: endpoint.usesSessionAuthorization, allowsRefresh: endpoint.shouldAttemptTokenRefresh) { [self] current in
            let authorized = authorizedCopy(of: request, token: endpoint.usesSessionAuthorization ? current.accessToken : nil)
            return try await perform(request: authorized)
        }
    }

    /// Same-origin native chat endpoints and attachment downloads share the main JWT policy.
    func sessionData(for request: URLRequest, context supplied: AuthRequestSession? = nil) async throws -> (Data, HTTPURLResponse) {
        guard let url = request.url, url.scheme == baseURL.scheme, url.host == baseURL.host,
              url.port == baseURL.port, url.path.hasPrefix(baseURL.path + "/") else { throw APIError.invalidURL }
        let context: AuthRequestSession
        if let supplied { context = supplied }
        else { context = await MainActor.run { AuthStore.shared.requestSession } }
        guard context.isAuthenticated else { throw CancellationError() }
        try await ensureCurrentLogin(context)
        return try await withSessionRecovery(context) { [self] current in
            let data: Data
            let response: URLResponse
            do { (data, response) = try await session.data(for: authorizedCopy(of: request, token: current.accessToken)) }
            catch { throw APIError.networkError(error) }
            guard let http = response as? HTTPURLResponse else { throw APIError.networkError(URLError(.badServerResponse)) }
            if let error = responseError(http, data: data) { throw error }
            return (data, http)
        }
    }

    /// H5 has already rejected this WebView's token. Refresh once before reloading its bootstrap.
    func recoverEmbeddedSession(_ context: AuthRequestSession, allowsRefresh: Bool) async throws -> AuthRequestSession {
        var initialAttempt = true
        return try await withSessionRecovery(context, allowsRefresh: allowsRefresh) { current in
            if initialAttempt {
                initialAttempt = false
                throw AuthenticationFailure(code: 40102, message: "登录已过期，请重新登录")
            }
            return current
        }
    }

    private func withSessionRecovery<T>(_ context: AuthRequestSession, usesSession: Bool = true, allowsRefresh: Bool = true,
                                         operation: (AuthRequestSession) async throws -> T) async throws -> T {
        do {
            let result = try await operation(context)
            if usesSession && context.isAuthenticated { try await ensureCurrentLogin(context) }
            return result
        } catch let failure as AuthenticationFailure {
            try Task.checkCancellation()
            // Login/register errors and anonymous requests do not expire another session.
            guard usesSession, context.isAuthenticated, context.accessToken?.isEmpty == false else {
                throw APIError.serverError(failure.code, failure.message)
            }
            let current = try await currentLogin(context)
            var retry: AuthRequestSession?
            if current.accessToken != context.accessToken {
                retry = current
            } else if allowsRefresh, failure.canRefresh, context.refreshToken?.isEmpty == false {
                do {
                    retry = try await refreshCoordinator.refresh(for: context) { [self] in
                        try await refreshAccessToken(for: context)
                    }
                } catch is AuthenticationFailure {
                    return try await expire(context)
                } catch {
                    // A cancelled view or temporary network failure cannot erase valid refresh credentials.
                    try await ensureCurrentLogin(context)
                    throw error
                }
            }
            guard let retry else { return try await expire(context) }
            try Task.checkCancellation()
            try await ensureCurrentLogin(retry)
            do {
                let result = try await operation(retry)
                try await ensureCurrentLogin(retry)
                return result
            } catch is AuthenticationFailure {
                return try await expire(retry)
            }
        }
    }

    private func currentLogin(_ context: AuthRequestSession) async throws -> AuthRequestSession {
        // Read and validate atomically: a later login must never become the retry identity.
        try await MainActor.run {
            let current = AuthStore.shared.requestSession
            guard current.id == context.id, current.isAuthenticated else { throw CancellationError() }
            return current
        }
    }

    private func ensureCurrentLogin(_ context: AuthRequestSession) async throws {
        _ = try await currentLogin(context)
    }

    private func expire<T>(_ context: AuthRequestSession) async throws -> T {
        let expired = await MainActor.run { AuthStore.shared.expireSession(context) }
        if !expired { throw CancellationError() }
        throw APIError.unauthorized
    }

    private func refreshAccessToken(for context: AuthRequestSession) async throws -> AuthRequestSession {
        let current = try await currentLogin(context)
        if current.accessToken != context.accessToken { return current }
        guard let refreshToken = context.refreshToken, !refreshToken.isEmpty else {
            throw AuthenticationFailure(code: 40105, message: "登录已过期，请重新登录")
        }
        var request = try buildRequest(.authRefresh(refreshToken: refreshToken))
        request.setValue(nil, forHTTPHeaderField: "Authorization")
        let response: RefreshResponse = try await perform(request: request)
        guard !response.accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AuthenticationFailure(code: 40105, message: "登录已过期，请重新登录")
        }
        let accepted = await MainActor.run {
            AuthStore.shared.acceptRefreshedAccessToken(response.accessToken, for: context)
        }
        guard let accepted else { throw CancellationError() }
        return accepted
    }

    private func responseError(_ http: HTTPURLResponse, data: Data) -> Error? {
        // Permission failures are never a request to replace the current login.
        if http.statusCode == 403 { return APIError.serverError(403, "暂无访问权限") }
        // Inspect the envelope before decoding T: error responses may contain null or a different data shape.
        if let status = try? decoder.decode(ResponseStatus.self, from: data), status.code != 0 {
            let message = status.message ?? "请求失败"
            if [40101, 40102, 40103, 40105].contains(status.code) {
                return AuthenticationFailure(code: status.code, message: message)
            }
            return APIError.serverError(status.code, message)
        }
        if http.statusCode == 401 {
            return AuthenticationFailure(code: 401, message: "登录已过期，请重新登录")
        }
        if !(200..<300).contains(http.statusCode) {
            return APIError.serverError(http.statusCode, String(data: data, encoding: .utf8) ?? "未知错误")
        }
        return nil
    }

    private func perform<T: Decodable>(request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch { throw APIError.networkError(error) }
        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }
        if let error = responseError(http, data: data) { throw error }
        do {
            if let envelope = try? decoder.decode(APIResponse<T>.self, from: data), envelope.isSuccess, let result = envelope.data {
                return result
            }
            return try decoder.decode(T.self, from: data)
        } catch { throw APIError.decodingError(error) }
    }

    private func authorizedCopy(of request: URLRequest, token: String?) -> URLRequest {
        var copy = request
        copy.setValue(token.flatMap { $0.isEmpty ? nil : "Bearer \($0)" }, forHTTPHeaderField: "Authorization")
        return copy
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

        // 注入 JWT Token（Authorization: Bearer <token>）
        if endpoint.usesSessionAuthorization, let token = tokenProvider(), !token.isEmpty {
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
