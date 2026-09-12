import Foundation

// Compile each production APIClient/APIResponse with a deterministic in-memory session and URLProtocol.
enum AppConfig {
    static let baseURL = URL(string: "https://auth-regression.invalid/api/v1")!
    static let requestTimeout: TimeInterval = 3
    static let clientType = "test", clientVersion = "test"
    static let keychainService = "test", tokenKey = "test", refreshTokenKey = "test"
}
final class KeychainHelper {
    static let shared = KeychainHelper()
    static func readString(service: String, key: String) -> String? { nil }
    func read(service: String, key: String) -> String? { nil }
}
enum HTTPMethod: String { case GET, POST }
struct RefreshResponse: Decodable { let accessToken: String }
struct AnyEncodable: Encodable {
    let value: [String: String]
    func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
}
enum Endpoint {
    case data, login, authRefresh(refreshToken: String)
    var path: String { switch self { case .data: return "data"; case .login: return "auth/login"; case .authRefresh: return "auth/refresh" } }
    var httpMethod: HTTPMethod { if case .data = self { return .GET }; return .POST }
    var queryItems: [URLQueryItem]? { nil }
    var usesSessionAuthorization: Bool { if case .data = self { return true }; return false }
    var shouldAttemptTokenRefresh: Bool { usesSessionAuthorization }
    var body: AnyEncodable? { if case .authRefresh(let token) = self { return AnyEncodable(value: ["refreshToken": token]) }; return nil }
}
@MainActor final class AuthStore {
    static let shared = AuthStore()
    var requestSession = AuthRequestSession(id: UUID(), accessToken: nil, refreshToken: nil, isAuthenticated: false)
    var expirationCount = 0
    func signIn(_ token: String? = "old", refresh: String? = nil) {
        requestSession = AuthRequestSession(id: UUID(), accessToken: token, refreshToken: refresh, isAuthenticated: token != nil)
        expirationCount = 0
    }
    func advanceToken(_ token: String) {
        requestSession = AuthRequestSession(id: requestSession.id, accessToken: token, refreshToken: requestSession.refreshToken, isAuthenticated: true)
    }
    func expireSession(_ failed: AuthRequestSession) -> Bool {
        guard requestSession.isAuthenticated, requestSession.id == failed.id, requestSession.accessToken == failed.accessToken else { return false }
        expirationCount += 1
        requestSession = AuthRequestSession(id: UUID(), accessToken: nil, refreshToken: nil, isAuthenticated: false)
        return true
    }
    func acceptRefreshedAccessToken(_ value: String, for expected: AuthRequestSession) -> AuthRequestSession? {
        guard requestSession.isAuthenticated, requestSession.id == expected.id else { return nil }
        if requestSession.accessToken != expected.accessToken { return requestSession }
        guard requestSession.refreshToken == expected.refreshToken else { return nil }
        advanceToken(value)
        return requestSession
    }
}
struct Reply {
    var status = 200
    var body: String
    var contentType = "application/json"
    static func failure(_ code: Int, status: Int = 200) -> Reply { Reply(status: status, body: "{\"code\":\(code),\"message\":\"failure\",\"data\":{\"different\":true}}") }
    static let ok = Reply(body: "{\"code\":0,\"message\":\"ok\",\"data\":{\"value\":\"ok\"}}")
    static let fresh = Reply(body: "{\"code\":0,\"message\":\"ok\",\"data\":{\"accessToken\":\"fresh\"}}")
}
final class StubProtocol: URLProtocol, @unchecked Sendable {
    static var respond: (URLRequest) async throws -> Reply = { _ in .ok }
    private var responseTask: Task<Void, Never>?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        responseTask = Task {
            do {
                let reply = try await Self.respond(request)
                guard !Task.isCancelled else { return }
                let response = HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": reply.contentType])!
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: Data(reply.body.utf8))
                client?.urlProtocolDidFinishLoading(self)
            } catch { if !Task.isCancelled { client?.urlProtocol(self, didFailWithError: error) } }
        }
    }
    override func stopLoading() { responseTask?.cancel() }
}
actor Gate {
    private var open = false
    private var pending: [CheckedContinuation<Void, Never>] = []
    func wait() async { if open { return }; await withCheckedContinuation { pending.append($0) } }
    func release() { open = true; let all = pending; pending.removeAll(); all.forEach { $0.resume() } }
}
actor Counts {
    var values: [String: Int] = [:]
    func add(_ key: String) -> Int { values[key, default: 0] += 1; return values[key]! }
    func get(_ key: String) -> Int { values[key, default: 0] }
}
struct Value: Decodable { let value: String }
struct Failure: Error { let message: String }
func expect(_ value: Bool, _ message: String) throws { if !value { throw Failure(message: message) } }
@MainActor func request(_ client: APIClient, _ endpoint: Endpoint = .data) async -> Result<Value, Error> {
    do { return .success(try await client.request(endpoint)) } catch { return .failure(error) }
}
func unauthorized(_ result: Result<Value, Error>) -> Bool {
    if case .failure(APIError.unauthorized) = result { return true }; return false
}
func cancelled(_ result: Result<Value, Error>) -> Bool {
    if case .failure(let error) = result { return error is CancellationError || (error as? APIError)?.isCancellation == true }; return false
}
@main struct AuthExpiryRegression {
    static func main() async {
        do { try await run() }
        catch { FileHandle.standardError.write(Data("Auth regression failed: \(error)\n".utf8)); exit(1) }
    }
    @MainActor static func run() async throws {
        var passed: [String] = []
        let store = AuthStore.shared
        func client() -> APIClient {
            let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [StubProtocol.self]
            return APIClient(session: URLSession(configuration: config))
        }
        func check(_ name: String, _ condition: Bool) throws { try expect(condition, name); passed.append(name) }
        for code in [40101, 40102, 40103, 40105] {
            store.signIn(); StubProtocol.respond = { _ in .failure(code) }
            let result = await request(client())
            try check("business \(code) expires authenticated session", unauthorized(result) && store.expirationCount == 1 && !store.requestSession.isAuthenticated)
        }
        store.signIn(); StubProtocol.respond = { _ in Reply(status: 401, body: "unauthorized", contentType: "text/plain") }
        try check("HTTP 401 expires authenticated session", unauthorized(await request(client())) && store.expirationCount == 1)
        for failure in [40104, 40301, 40304, 40401] {
            store.signIn(refresh: "refresh")
            StubProtocol.respond = { _ in .failure(failure, status: failure == 40104 ? 401 : failure == 40301 ? 403 : 200) }
            _ = await request(client(), failure == 40104 ? .login : .data)
            try check("business \(failure) preserves session", store.expirationCount == 0 && store.requestSession.accessToken == "old")
        }
        store.signIn(); let loginHeaders = Counts()
        StubProtocol.respond = { req in if req.value(forHTTPHeaderField: "Authorization") != nil { _ = await loginHeaders.add("auth") }; return .failure(40101, status: 401) }
        _ = await request(client(), .login)
        try check("login never sends stale bearer or expires current login", await loginHeaders.get("auth") == 0 && store.expirationCount == 0)
        store.signIn(nil); StubProtocol.respond = { _ in .failure(40102) }; _ = await request(client())
        try check("anonymous failure never initiates logout", store.expirationCount == 0)

        store.signIn(refresh: "refresh"); let one = Counts()
        StubProtocol.respond = { req in
            if req.url!.path.hasSuffix("refresh") { _ = await one.add("refresh"); return .fresh }
            _ = await one.add("data")
            return req.value(forHTTPHeaderField: "Authorization") == "Bearer fresh" ? .ok : .failure(40102)
        }
        let success = await request(client())
        let refreshRequestCount = await one.get("refresh")
        let protectedRequestCount = await one.get("data")
        try check("invalid access token refreshes and retries once", (try? success.get().value) == "ok" && store.requestSession.accessToken == "fresh" && store.expirationCount == 0 && refreshRequestCount == 1 && protectedRequestCount == 2)

        for code in [40102, 40103, 40105] {
            store.signIn(refresh: "refresh")
            StubProtocol.respond = { req in .failure(req.url!.path.hasSuffix("refresh") ? code : 40103) }
            let result = await request(client())
            try check("refresh \(code) expires exactly once", unauthorized(result) && store.expirationCount == 1)
        }
        store.signIn(refresh: "refresh"); let retryCounts = Counts()
        StubProtocol.respond = { req in if req.url!.path.hasSuffix("refresh") { _ = await retryCounts.add("refresh"); return .fresh }; return .failure(40102) }
        let retryResult = await request(client())
        let retryRefreshCount = await retryCounts.get("refresh")
        try check("unauthorized refreshed retry clears refreshed credentials", unauthorized(retryResult) && store.expirationCount == 1 && retryRefreshCount == 1)

        store.signIn(refresh: "refresh"); let concurrent = Counts(); let ready = Gate(); let shared = client()
        StubProtocol.respond = { req in
            if req.url!.path.hasSuffix("refresh") { _ = await concurrent.add("refresh"); try await Task.sleep(for: .milliseconds(30)); return .fresh }
            if req.value(forHTTPHeaderField: "Authorization") == "Bearer fresh" { return .ok }
            if await concurrent.add("old") == 8 { await ready.release() }
            await ready.wait(); return .failure(40102)
        }
        let values = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<8 { group.addTask { let result = await request(shared); return (try? result.get().value) == "ok" } }
            var values: [Bool] = []; for await result in group { values.append(result) }; return values
        }
        let concurrentRefreshCount = await concurrent.get("refresh")
        try check("eight simultaneous failures share one refresh", values.allSatisfy { $0 } && concurrentRefreshCount == 1 && store.expirationCount == 0)

        for oldSuccess in [false, true] {
            store.signIn(refresh: "refresh"); let started = Gate(); let release = Gate(); let oldRequests = Counts()
            StubProtocol.respond = { _ in _ = await oldRequests.add("requests"); await started.release(); await release.wait(); return oldSuccess ? .ok : .failure(40102) }
            let active = client(); let task = Task { await request(active) }; await started.wait()
            store.signIn("new-login", refresh: "new-refresh"); await release.release()
            let oldRequestCount = await oldRequests.get("requests")
            try check("old \(oldSuccess ? "success" : "401") cannot affect new login", cancelled(await task.value) && store.requestSession.accessToken == "new-login" && store.expirationCount == 0 && oldRequestCount == 1)
        }
        for mode in ["logout", "new-login", "same-token-login", "failed-refresh"] {
            store.signIn(refresh: "refresh"); let started = Gate(); let release = Gate()
            StubProtocol.respond = { req in
                if req.url!.path.hasSuffix("refresh") { await started.release(); await release.wait(); return mode == "failed-refresh" ? .failure(40105) : .fresh }
                return .failure(40102)
            }
            let active = client(); let task = Task { await request(active) }; await started.wait()
            let expected = mode == "logout" ? nil : mode == "same-token-login" ? "old" : "new-login"
            store.signIn(expected, refresh: expected == nil ? nil : "new-refresh"); await release.release()
            try check("late refresh after \(mode) cannot restore/erase credentials", cancelled(await task.value) && store.requestSession.accessToken == expected && store.expirationCount == 0)
        }
        store.signIn(refresh: "refresh"); let started = Gate(); let release = Gate(); let refreshed = client()
        StubProtocol.respond = { req in if req.value(forHTTPHeaderField: "Authorization") == "Bearer fresh" { return .ok }; await started.release(); await release.wait(); return .failure(40102) }
        let delayed = Task { await request(refreshed) }; await started.wait(); store.advanceToken("fresh"); await release.release()
        try check("delayed 401 safely retries same-login refreshed token", (try? await delayed.value.get().value) == "ok" && store.expirationCount == 0)

        store.signIn(refresh: "refresh")
        StubProtocol.respond = { req in if req.url!.path.hasSuffix("refresh") { throw URLError(.notConnectedToInternet) }; return .failure(40103) }
        _ = await request(client())
        try check("temporary refresh network failure preserves refresh credentials", store.requestSession.accessToken == "old" && store.requestSession.refreshToken == "refresh" && store.expirationCount == 0)
        store.signIn(refresh: "refresh")
        StubProtocol.respond = { req in if req.url!.path.hasSuffix("refresh") { return Reply(body: "{\"code\":0,\"data\":{\"accessToken\":\"\"},\"message\":\"ok\"}") }; return .failure(40103) }
        try check("empty refreshed access token expires session", unauthorized(await request(client())) && store.expirationCount == 1)
        store.signIn(refresh: "refresh"); let terminal = Counts()
        StubProtocol.respond = { req in if req.url!.path.hasSuffix("refresh") { _ = await terminal.add("refresh") }; return .failure(40105) }
        _ = await request(client())
        let terminalRefreshCount = await terminal.get("refresh")
        try check("40105 skips nonrecoverable refresh", store.expirationCount == 1 && terminalRefreshCount == 0)
        store.signIn(refresh: "refresh"); let cancelledStarted = Gate(); let cancelledRelease = Gate()
        StubProtocol.respond = { _ in await cancelledStarted.release(); await cancelledRelease.wait(); return .failure(40102) }
        let cancelledClient = client(); let cancelledTask = Task { await request(cancelledClient) }
        await cancelledStarted.wait(); cancelledTask.cancel(); await cancelledRelease.release()
        try check("cancelled request preserves current credentials", cancelled(await cancelledTask.value) && store.expirationCount == 0 && store.requestSession.accessToken == "old")

        store.signIn(refresh: "refresh"); let forbidden = Counts()
        StubProtocol.respond = { req in if req.url!.path.hasSuffix("refresh") { _ = await forbidden.add("refresh") }; return .failure(40102, status: 403) }
        _ = await request(client())
        try check("HTTP403 takes precedence over misleading auth business code", await forbidden.get("refresh") == 0 && store.expirationCount == 0)

        store.signIn(refresh: "refresh"); let rawClient = client()
        StubProtocol.respond = { req in
            if req.url!.path.hasSuffix("refresh") { return .fresh }
            if req.value(forHTTPHeaderField: "Authorization") == "Bearer fresh" { return Reply(body: "attachment bytes", contentType: "application/octet-stream") }
            return .failure(40102)
        }
        let (rawData, _) = try await rawClient.sessionData(for: URLRequest(url: AppConfig.baseURL.appendingPathComponent("chats/attachment")))
        try check("native raw chat attachment refreshes through central client", String(decoding: rawData, as: UTF8.self) == "attachment bytes" && store.requestSession.accessToken == "fresh")
        store.signIn(); StubProtocol.respond = { _ in .failure(40103) }
        do { _ = try await client().sessionData(for: URLRequest(url: AppConfig.baseURL.appendingPathComponent("chats/unread"))) } catch { }
        try check("native unread/attachment terminal expiry clears session", store.expirationCount == 1)
        store.signIn(); let rawContext = store.requestSession; store.signIn("new-login")
        let blockedRaw = Counts(); StubProtocol.respond = { _ in _ = await blockedRaw.add("sent"); return .ok }
        do { _ = try await client().sessionData(for: URLRequest(url: AppConfig.baseURL.appendingPathComponent("chats/write")), context: rawContext) } catch { }
        try check("captured old native session cannot send under later login", await blockedRaw.get("sent") == 0 && store.requestSession.accessToken == "new-login")
        do { _ = try await client().sessionData(for: URLRequest(url: URL(string: "https://other.invalid/attachment")!)) } catch { }
        try check("raw chat client refuses bearer transmission to other origin", await blockedRaw.get("sent") == 0)

        store.signIn(refresh: "refresh"); StubProtocol.respond = { _ in .fresh }
        let bridge = client(); let embedded = try await bridge.recoverEmbeddedSession(store.requestSession, allowsRefresh: true)
        try check("embedded session expiry refreshes host credentials once", embedded.accessToken == "fresh" && store.expirationCount == 0)
        do { _ = try await bridge.recoverEmbeddedSession(embedded, allowsRefresh: false) } catch { }
        try check("second embedded expiry goes directly to login", store.expirationCount == 1)
        store.signIn(refresh: "refresh"); let oldEmbedded = store.requestSession; store.signIn("new-login")
        do { _ = try await client().recoverEmbeddedSession(oldEmbedded, allowsRefresh: true) } catch { }
        try check("stale WebView expiry cannot clear new login", store.expirationCount == 0 && store.requestSession.accessToken == "new-login")

        #if !MASTER
        store.signIn(); StubProtocol.respond = { _ in .failure(40102) }
        do { try await client().streamAIMessage(sessionId: 1, messageId: 1, onEvent: { _ in }) } catch { }
        try check("SSE HTTP200 JSON token failure expires session", store.expirationCount == 1)
        store.signIn(refresh: "refresh"); let events = Counts()
        StubProtocol.respond = { req in
            if req.url!.path.hasSuffix("refresh") { return .fresh }
            if req.value(forHTTPHeaderField: "Authorization") == "Bearer fresh" { return Reply(body: "event: done\ndata: {\"event\":\"done\",\"status\":\"done\"}\n\n", contentType: "text/event-stream") }
            return .failure(40103)
        }
        try await client().streamAIMessage(sessionId: 1, messageId: 1, onEvent: { _ in _ = await events.add("events") })
        try check("SSE refresh preserves event delivery", await events.get("events") == 1 && store.requestSession.accessToken == "fresh" && store.expirationCount == 0)
        #endif
        let output: [String: Any] = ["passed": passed.count, "checks": passed]
        print(String(data: try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys]), encoding: .utf8)!)
    }
}
