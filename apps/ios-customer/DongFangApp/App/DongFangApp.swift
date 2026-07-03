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
    }

    var body: some Scene {
        WindowGroup {
            if authStore.isLoggedIn {
                MainTabView()
                    .environmentObject(authStore)
                    .preferredColorScheme(.dark)
            } else {
                LoginView()
                    .environmentObject(authStore)
                    .preferredColorScheme(.dark)
            }
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
}
