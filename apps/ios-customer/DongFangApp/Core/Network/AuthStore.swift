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

    /// UserDefaults 键（持久化非敏感的用户信息：userId/nickname/avatar/mobile/imToken）
    private enum UDKey {
        static let userId   = "auth.userId"
        static let nickname = "auth.nickname"
        static let avatar   = "auth.avatar"
        static let mobile   = "auth.mobile"
        static let imToken  = "auth.imToken"
    }

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
    /// OpenIM IM Token（用于 SDK 登录，持久化到 UserDefaults 以便 app 重启后恢复）
    @Published private(set) var imToken: String? = nil

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
        let ud = UserDefaults.standard
        let persistedUserId = ud.string(forKey: UDKey.userId)
        // 旧版本残留：Keychain 有 token 但 UserDefaults 未持久化 userId
        // → 清除凭据，要求重新登录，避免用错误的占位 userId 发请求
        if self.accessToken != nil && persistedUserId == nil {
            KeychainHelper.delete(service: AppConfig.keychainService, key: AppConfig.tokenKey)
            KeychainHelper.delete(service: AppConfig.keychainService, key: AppConfig.refreshTokenKey)
            self.accessToken = nil
            self.refreshToken = nil
            self.isLoggedIn = false
            return
        }
        self.isLoggedIn = self.accessToken != nil
        // 恢复用户信息（token 存在时一并恢复，避免重启后 userId 退化为默认占位符 U001）
        if self.isLoggedIn {
            self.userId   = persistedUserId ?? AppConfig.defaultUserId
            self.nickname = ud.string(forKey: UDKey.nickname) ?? ""
            self.avatar   = ud.string(forKey: UDKey.avatar)   ?? ""
            self.mobile   = ud.string(forKey: UDKey.mobile)   ?? ""
            self.imToken  = ud.string(forKey: UDKey.imToken)
        }
    }

    /// APIClient 读取 Token 的闭包
    var tokenProvider: () -> String? = {
        KeychainHelper.readString(service: AppConfig.keychainService, key: AppConfig.tokenKey)
    }

    /// 登录成功后保存 Token
    func didLogin(accessToken: String, refreshToken: String?, userId: String,
                  nickname: String?, avatar: String?, mobile: String?, imToken: String? = nil) {
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
        self.imToken = imToken
        // 持久化用户信息到 UserDefaults（token 已在 Keychain；此处补齐非敏感字段，
        // 保证 app 重启后 AuthStore 可恢复完整登录态，避免 userId 退化为 U001）
        let ud = UserDefaults.standard
        ud.set(userId,   forKey: UDKey.userId)
        ud.set(nickname, forKey: UDKey.nickname)
        ud.set(avatar,   forKey: UDKey.avatar)
        ud.set(mobile,   forKey: UDKey.mobile)
        ud.set(imToken,  forKey: UDKey.imToken)
    }

    /// 更新 AccessToken（刷新后调用）
    func updateAccessToken(_ token: String) {
        KeychainHelper.save(string: token,
                            service: AppConfig.keychainService,
                            key: AppConfig.tokenKey)
        self.accessToken = token
    }

    func updateCachedProfile(nickname: String, avatar: String, mobile: String) {
        self.nickname = nickname
        self.avatar = avatar
        self.mobile = mobile
        let ud = UserDefaults.standard
        ud.set(nickname, forKey: UDKey.nickname)
        ud.set(avatar, forKey: UDKey.avatar)
        ud.set(mobile, forKey: UDKey.mobile)
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
        self.imToken = nil
        // 清除 UserDefaults 中的用户信息
        let ud = UserDefaults.standard
        ud.removeObject(forKey: UDKey.userId)
        ud.removeObject(forKey: UDKey.nickname)
        ud.removeObject(forKey: UDKey.avatar)
        ud.removeObject(forKey: UDKey.mobile)
        ud.removeObject(forKey: UDKey.imToken)
    }

    private func accessTokenChanged() {
        // 占位：可用于触发通知或刷新请求
    }
}
