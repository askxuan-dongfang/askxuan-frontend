//
//  AuthStore.swift
//  MasterApp
//
//  鉴权存储：
//  - JWT Token 存 Keychain（key 区分法师端：df_master_token）
//  - 法师身份（masterId / userId / nickname）从 JWT Claims 解析，禁止 URL 传参
//  - 提供 tokenProvider 供 APIClient 注入 Authorization 头
//

import Foundation

/// 鉴权存储（单例）
@MainActor
final class AuthStore: ObservableObject {

    static let shared = AuthStore()

    // MARK: - 发布状态

    /// 当前 JWT Token
    @Published private(set) var token: String? {
        didSet { saveToken() }
    }

    /// 是否已登录
    @Published private(set) var isLoggedIn: Bool = false

    /// 法师 ID（从 JWT Claims 解析）
    @Published private(set) var masterId: String? = nil

    /// 用户 ID（从 JWT Claims 解析）
    @Published private(set) var userId: String? = nil

    /// 昵称（从 JWT Claims 解析，可选）
    @Published private(set) var nickname: String? = nil

    /// RefreshToken
    @Published private(set) var refreshToken: String? = nil

    /// OpenIM IM Token（用于 SDK 登录，持久化到 Keychain 以便 app 重启后恢复）
    @Published private(set) var imToken: String? = nil

    // MARK: - Keychain

    private let service = "com.askxuan.master"
    private let tokenKey = "df_master_token"
    private let refreshTokenKey = "df_master_refresh_token"
    private let imTokenKey = "df_master_im_token"

    private init() {
        if let saved = readToken() {
            self.token = saved
            self.refreshToken = readRefreshToken()
            self.applyClaims(from: saved)
            self.imToken = readIMToken()
            self.isLoggedIn = (saved.isEmpty == false && masterId != nil)
        }
    }

    /// 登录成功后保存 Token 并解析 Claims
    /// - Parameters:
    ///   - token: 后端返回的 accessToken
    ///   - refreshToken: 后端返回的 refreshToken
    ///   - imToken: OpenIM 登录用的 IM Token（可选，默认 nil 保持向后兼容）
    func didLogin(token: String, refreshToken: String?, imToken: String? = nil) {
        self.token = token
        self.refreshToken = refreshToken
        saveRefreshToken(refreshToken)
        self.applyClaims(from: token)
        self.imToken = imToken
        saveIMToken(imToken)
        self.isLoggedIn = (masterId != nil)
    }

    /// refresh 成功后仅更新 access token
    func updateAccessToken(_ token: String) {
        self.token = token
        self.applyClaims(from: token)
        self.isLoggedIn = (masterId != nil)
    }

    /// 登出：清除 Token 与身份信息
    func logout() {
        self.token = nil
        self.refreshToken = nil
        self.masterId = nil
        self.userId = nil
        self.nickname = nil
        self.imToken = nil
        self.isLoggedIn = false
        deleteToken()
        deleteRefreshToken()
        deleteIMToken()
    }

    /// APIClient 注入用 token 提供者（非 isolated 读取，避免 MainActor 跨界）
    /// 注意：APIClient 在后台线程读取，此处直接读 Keychain 不依赖 @Published。
    nonisolated func tokenProvider() -> String? {
        return readToken()
    }

    nonisolated func refreshTokenProvider() -> String? {
        return readRefreshToken()
    }

    // MARK: - JWT Claims 解析

    /// 解析 JWT Payload（中间段，Base64URL 解码），提取 masterId/userId/nickname。
    private func applyClaims(from jwt: String) {
        guard let payload = JWTDecoder.payload(of: jwt) else { return }
        // 后端 Claims 字段名兼容多种命名：masterId / MasterID / master_id
        self.masterId = payload["masterId"] as? String
            ?? payload["MasterID"] as? String
            ?? payload["master_id"] as? String
            ?? (payload["masterId"] as? Int).map(String.init)
            ?? (payload["MasterID"] as? Int).map(String.init)
        self.userId = payload["userId"] as? String
            ?? (payload["userId"] as? Int).map(String.init)
            ?? (payload["uid"] as? String)
        self.nickname = payload["nickname"] as? String
            ?? payload["name"] as? String
    }

    // MARK: - Keychain 读写

    private func saveToken() {
        if let token, !token.isEmpty {
            KeychainHelper.shared.set(token, service: service, key: tokenKey)
        } else {
            KeychainHelper.shared.delete(service: service, key: tokenKey)
        }
    }

    nonisolated private func readToken() -> String? {
        KeychainHelper.shared.read(service: service, key: tokenKey)
    }

    nonisolated private func readRefreshToken() -> String? {
        KeychainHelper.shared.read(service: service, key: refreshTokenKey)
    }

    private func deleteToken() {
        KeychainHelper.shared.delete(service: service, key: tokenKey)
    }

    private func saveRefreshToken(_ token: String?) {
        if let token, !token.isEmpty {
            KeychainHelper.shared.set(token, service: service, key: refreshTokenKey)
        } else {
            deleteRefreshToken()
        }
    }

    private func deleteRefreshToken() {
        KeychainHelper.shared.delete(service: service, key: refreshTokenKey)
    }

    private func saveIMToken(_ token: String?) {
        if let token, !token.isEmpty {
            KeychainHelper.shared.set(token, service: service, key: imTokenKey)
        } else {
            deleteIMToken()
        }
    }

    nonisolated private func readIMToken() -> String? {
        KeychainHelper.shared.read(service: service, key: imTokenKey)
    }

    private func deleteIMToken() {
        KeychainHelper.shared.delete(service: service, key: imTokenKey)
    }
}

// MARK: - JWT 解码

/// JWT 解码工具：仅解析 Payload（不验签），用于读取 Claims。
enum JWTDecoder {
    /// 返回 payload 段对应的字典（失败返回 nil）
    static func payload(of jwt: String) -> [String: Any]? {
        let segments = jwt.split(separator: ".")
        guard segments.count >= 2 else { return nil }
        var payload = String(segments[1])
        // Base64URL -> Base64
        payload = payload.replacingOccurrences(of: "-", with: "+")
                         .replacingOccurrences(of: "_", with: "/")
        // 补齐填充
        let needed = payload.count % 4
        if needed > 0 {
            payload.append(String(repeating: "=", count: 4 - needed))
        }
        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }
}

// MARK: - Keychain 辅助

/// 轻量 Keychain 封装
final class KeychainHelper {
    static let shared = KeychainHelper()
    private init() {}

    func set(_ value: String, service: String, key: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }

    func read(service: String, key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
           let data = item as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    func delete(service: String, key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
