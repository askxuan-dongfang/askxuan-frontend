//
//  AuthStore.swift
//  DongFangApp
//
//  JWT Token 安全存储：基于 Keychain 的 AuthStore。
//  - AccessToken / RefreshToken 持久化到 Keychain
//  - 登录态、用户信息发布为 @Published
//  - APIClient 通过 tokenProvider 读取
//

import Foundation

/// Keychain 简易封装
enum KeychainHelper {
    static func save(_ data: Data, service: String, key: String) {
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

    static func save(string: String, service: String, key: String) {
        guard let data = string.data(using: .utf8) else { return }
        save(data, service: service, key: key)
    }

    static func read(service: String, key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        return result as? Data
    }

    static func readString(service: String, key: String) -> String? {
        guard let data = read(service: service, key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(service: String, key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

/// 鉴权状态管理（@MainActor ObservableObject）
@MainActor
final class AuthStore: ObservableObject {
    static let shared = AuthStore()

    /// 是否已登录
    @Published private(set) var isLoggedIn: Bool = false
    /// 用户 ID
    @Published private(set) var userId: String = AppConfig.defaultUserId
    /// 用户昵称
    @Published private(set) var nickname: String = ""
    /// 用户头像 URL
    @Published private(set) var avatar: String = ""
    /// 手机号
    @Published private(set) var mobile: String = ""

    /// JWT AccessToken（内存缓存，便于高频读取）
    private(set) var accessToken: String? {
        didSet { accessTokenChanged() }
    }

    /// RefreshToken
    private(set) var refreshToken: String?

    private init() {
        self.accessToken = KeychainHelper.readString(service: AppConfig.keychainService,
                                                     key: AppConfig.tokenKey)
        self.refreshToken = KeychainHelper.readString(service: AppConfig.keychainService,
                                                      key: AppConfig.refreshTokenKey)
        self.isLoggedIn = self.accessToken != nil
    }

    /// APIClient 读取 Token 的闭包
    var tokenProvider: () -> String? = {
        KeychainHelper.readString(service: AppConfig.keychainService, key: AppConfig.tokenKey)
    }

    /// 登录成功后保存 Token
    func didLogin(accessToken: String, refreshToken: String?, userId: String,
                  nickname: String?, avatar: String?, mobile: String?) {
        KeychainHelper.save(string: accessToken,
                            service: AppConfig.keychainService,
                            key: AppConfig.tokenKey)
        if let refresh = refreshToken {
            KeychainHelper.save(string: refresh,
                                service: AppConfig.keychainService,
                                key: AppConfig.refreshTokenKey)
            self.refreshToken = refresh
        }
        self.accessToken = accessToken
        self.isLoggedIn = true
        self.userId = userId
        self.nickname = nickname ?? ""
        self.avatar = avatar ?? ""
        self.mobile = mobile ?? ""
    }

    /// 更新 AccessToken（刷新后调用）
    func updateAccessToken(_ token: String) {
        KeychainHelper.save(string: token,
                            service: AppConfig.keychainService,
                            key: AppConfig.tokenKey)
        self.accessToken = token
    }

    /// 登出：清除所有凭据
    func logout() {
        KeychainHelper.delete(service: AppConfig.keychainService, key: AppConfig.tokenKey)
        KeychainHelper.delete(service: AppConfig.keychainService, key: AppConfig.refreshTokenKey)
        self.accessToken = nil
        self.refreshToken = nil
        self.isLoggedIn = false
        self.userId = AppConfig.defaultUserId
        self.nickname = ""
        self.avatar = ""
        self.mobile = ""
    }

    private func accessTokenChanged() {
        // 占位：可用于触发通知或刷新请求
    }
}
