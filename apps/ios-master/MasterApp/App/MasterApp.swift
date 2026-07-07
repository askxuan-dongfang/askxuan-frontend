//
//  MasterApp.swift
//  MasterApp
//
//  问玄东方 P03 法师工作台 App 入口。
//  SwiftUI App，根视图根据登录态切换 LoginView / MainTabView。
//

import SwiftUI

@main
struct MasterApp: App {
    /// 全局鉴权状态（登录态、JWT、法师身份），通过 environmentObject 注入
    @StateObject private var authStore = AuthStore.shared

    init() {
        // 配置 APIClient 的 BaseURL
        APIClient.shared.configureBaseURL(AppConfig.baseURL)
        // 配置 401 未授权回调：登出并回到登录页
        APIClient.shared.onUnauthorized = {
            AuthStore.shared.logout()
        }
        // 配置深色禅意外观
        configureAppearance()
        configureSmokeCredentials()
        // 初始化 OpenIM SDK（App 启动一次）
        OpenIMManager.shared.initialize()
        // 如果已登录且有持久化的 imToken，自动恢复 OpenIM SDK 登录
        // 避免 app 重启后 WS 连接断开导致消息收发失败
        restoreOpenIMLoginIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authStore)
                .preferredColorScheme(.dark)
        }
    }

    /// 根视图：根据登录态切换
    @ViewBuilder
    private func RootView() -> some View {
        if authStore.isLoggedIn {
            MainTabView()
        } else {
            NavigationStack {
                LoginView()
            }
        }
    }

    /// 统一配置全局外观（TabBar / NavigationBar 等系统组件深色化）
    private func configureAppearance() {
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(Color.bgPrimary).withAlphaComponent(0.95)
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(Color.bgPrimary)
        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(Color.accentDefault),
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
            token: accessToken,
            refreshToken: value(after: "--smoke-refresh-token", in: args)
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
    /// 大师端 OpenIM userID 约定为 "m_" + masterId
    private func restoreOpenIMLoginIfNeeded() {
        guard AuthStore.shared.isLoggedIn,
              let imToken = AuthStore.shared.imToken, !imToken.isEmpty,
              let masterID = AuthStore.shared.masterId, !masterID.isEmpty else {
            return
        }
        let openimUserID = "m_" + masterID
        OpenIMManager.shared.login(userID: openimUserID, token: imToken) { success, error in
            if success {
                print("✅ OpenIM 登录恢复成功")
            } else {
                print("⚠️ OpenIM 登录恢复失败: \(error?.localizedDescription ?? "")，需重新登录")
            }
        }
    }
}
