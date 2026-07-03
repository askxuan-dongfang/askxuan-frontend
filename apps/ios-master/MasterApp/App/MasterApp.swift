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
}
