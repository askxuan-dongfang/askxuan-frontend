//
//  DongFangApp.swift
//  DongFangApp
//
//  问玄东方 C端 App 入口。SwiftUI App，根视图为 MainTabView。
//  Token 从 AuthStore（Keychain）读取并注入到 APIClient。
//

import SwiftUI

@main
struct DongFangApp: App {
    @UIApplicationDelegateAdaptor(ChatAppDelegate.self) private var chatDelegate
    @StateObject private var chatNotifications = NativeChatNotifications.shared
    @StateObject private var authStore = AuthStore.shared
    @AppStorage(AppTheme.storageKey) private var themeValue = AppTheme.system.rawValue

    init() {
        NativeChatNotifications.shared.configure {
            let a=AuthStore.shared
            guard a.isLoggedIn,let token=a.accessToken else{return nil}
            return ChatNotificationIdentity(role:"customer",accountID:a.userId,userID:a.userId,token:token,nickname:a.nickname)
        }
        APIClient.shared.configureBaseURL(AppConfig.baseURL)
        APIClient.shared.tokenProvider = {
            KeychainHelper.readString(service: AppConfig.keychainService, key: AppConfig.tokenKey)
        }
        AppTheme.configureAppearance()
        configureSmokeCredentials()
        // 初始化 OpenIM SDK（App 启动一次）
        OpenIMManager.shared.initialize()
        // 如果已登录且有持久化的 imToken，自动恢复 OpenIM SDK 登录
        // 避免 app 重启后 WS 连接断开导致消息发送失败
        restoreOpenIMLoginIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authStore.requiresLogin {
                    NavigationStack { LoginView() }
                } else {
                    MainTabView()
                }
            }
            .id(authStore.sessionID)
            .environmentObject(authStore)
            .preferredColorScheme(AppTheme(rawValue: themeValue)?.colorScheme)
                .appVisualDefaults()
                .tint(Color.brandDefault)
                .task { await chatNotifications.refresh(); await chatNotifications.monitor() }
                .onChange(of: authStore.isLoggedIn) { _,_ in Task { await chatNotifications.refresh() } }
                .fullScreenCover(item: $chatNotifications.destination) { destination in
                    if let who=chatNotifications.identity() {
                        ChatExperienceView(conversationID:destination.id,role:who.role,accountID:who.accountID,userID:who.userID,token:who.token,nickname:who.nickname)
                            .appVisualDefaults()
                    }
                }
        }
    }

    private func configureSmokeCredentials() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard let accessToken = value(after: "--smoke-token", in: args), !accessToken.isEmpty else {
            return
        }
        AuthStore.shared.didLogin(
            accessToken: accessToken,
            refreshToken: value(after: "--smoke-refresh-token", in: args),
            userId: value(after: "--smoke-user-id", in: args) ?? AppConfig.defaultUserId,
            nickname: value(after: "--smoke-nickname", in: args) ?? "问玄用户",
            avatar: nil,
            mobile: value(after: "--smoke-mobile", in: args),
            imToken: value(after: "--smoke-im-token", in: args) ?? AuthStore.shared.imToken
        )
        #endif
    }

    private func value(after key: String, in args: [String]) -> String? {
        guard let index = args.firstIndex(of: key), index + 1 < args.count else {
            return nil
        }
        return args[index + 1]
    }

    /// app 重启后自动恢复 OpenIM SDK 登录（如有持久化的 imToken）
    private func restoreOpenIMLoginIfNeeded() {
        guard AuthStore.shared.isLoggedIn,
              let imToken = AuthStore.shared.imToken, !imToken.isEmpty,
              AuthStore.shared.userId != AppConfig.defaultUserId else {
            return
        }
        let openimUserID = "u_" + AuthStore.shared.userId
        OpenIMManager.shared.login(userID: openimUserID, token: imToken) { success, error in
            if success {
                print("✅ OpenIM 登录恢复成功")
            } else {
                print("⚠️ OpenIM 登录恢复失败: \(error?.localizedDescription ?? "")，需重新登录")
            }
        }
    }
}
