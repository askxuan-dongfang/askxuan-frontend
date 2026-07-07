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
    @StateObject private var authStore = AuthStore.shared

    init() {
        APIClient.shared.configureBaseURL(AppConfig.baseURL)
        APIClient.shared.tokenProvider = {
            KeychainHelper.readString(service: AppConfig.keychainService, key: AppConfig.tokenKey)
        }
        configureAppearance()
        configureSmokeCredentials()
        // 初始化 OpenIM SDK（App 启动一次）
        OpenIMManager.shared.initialize()
        // 如果已登录且有持久化的 imToken，自动恢复 OpenIM SDK 登录
        // 避免 app 重启后 WS 连接断开导致消息发送失败
        restoreOpenIMLoginIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            // 始终显示 MainTabView，游客可浏览首页/商城公共信息
            // 需要登录的 Tab（对话/AI/我的）内部通过 requireAuth 拦截
            MainTabView()
                .environmentObject(authStore)
                .preferredColorScheme(.dark)
        }
    }

    /// 统一配置全局外观（TabBar / NavigationBar 深色化）
    /// 注意：在 App.init() 阶段不能使用 UIColor(Color.bgPrimary)（SwiftUI Color 尚未就绪），
    /// 需用直接 UIColor 值（与 Tokens.swift 中 bgPrimary 的 hex 1C1210 对齐）。
    private func configureAppearance() {
        let bgPrimaryUIColor = UIColor(red: 28/255, green: 18/255, blue: 16/255, alpha: 1.0)
        let accentUIColor = UIColor(red: 200/255, green: 169/255, blue: 110/255, alpha: 1.0)

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = bgPrimaryUIColor.withAlphaComponent(0.95)
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = bgPrimaryUIColor
        navAppearance.titleTextAttributes = [
            .foregroundColor: accentUIColor,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
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
            mobile: value(after: "--smoke-mobile", in: args)
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
