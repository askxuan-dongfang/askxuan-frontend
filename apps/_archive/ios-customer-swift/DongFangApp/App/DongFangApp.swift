//
//  DongFangApp.swift
//  DongFangApp
//
//  问玄东方 C端 App 入口。
//  SwiftUI App，根视图为 MainTabView。
//

import SwiftUI

@main
struct DongFangApp: App {
    /// 全局状态（登录态、用户信息等），通过 environmentObject 注入
    @StateObject private var appState = AppState()

    init() {
        // 配置 APIClient 的 BaseURL 与 JWT Token 提供者
        APIClient.shared.configureBaseURL(AppConfig.baseURL)
        APIClient.shared.tokenProvider = {
            UserDefaults.standard.string(forKey: AppConfig.tokenKey)
        }
        // 配置深色禅意外观
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
    }

    /// 统一配置全局外观（TabBar / NavigationBar 等系统组件深色化）
    private func configureAppearance() {
        // UITabBar 深色背景
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(Color.bgPrimary.withAlphaComponent(0.95))
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        // UINavigationBar 深色背景
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

/// 全局应用状态
@MainActor
final class AppState: ObservableObject {
    /// 是否已登录
    @Published var isLoggedIn: Bool = false
    /// 当前用户 ID
    @Published var userId: String? = nil
    /// JWT Token
    @Published var jwtToken: String? {
        didSet {
            if let token = jwtToken {
                UserDefaults.standard.set(token, forKey: AppConfig.tokenKey)
            } else {
                UserDefaults.standard.removeObject(forKey: AppConfig.tokenKey)
            }
        }
    }

    init() {
        self.jwtToken = UserDefaults.standard.string(forKey: AppConfig.tokenKey)
        self.isLoggedIn = self.jwtToken != nil
    }

    /// 登出
    func logout() {
        jwtToken = nil
        userId = nil
        isLoggedIn = false
    }
}
