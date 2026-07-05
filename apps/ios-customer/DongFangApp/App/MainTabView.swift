//
//  MainTabView.swift
//  DongFangApp
//
//  主 TabView 容器：5 个 Tab（首页/对话/AI问事/商城/我的），每个 Tab 内部用 NavigationStack。
//  使用 SwiftUI 原生 TabView，push 到二级页面时 TabBar 自动隐藏。
//  通过 UITabBarAppearance 配置深色样式，对齐产品原型 home.html 底部导航。
//

import SwiftUI

struct MainTabView: View {
    // 支持通过 launch argument 设置初始 Tab（用于截图）：xcrun simctl launch booted com.dongfang.customer -tab 3
    @State private var selectedTab: Int = {
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-tab"), idx + 1 < args.count,
           let tab = Int(args[idx + 1]), (0...4).contains(tab) {
            return tab
        }
        return 0
    }()
    @StateObject private var authStore = AuthStore.shared

    init() {
        let appearance = UITabBarAppearance()
        if #available(iOS 26.0, *) {
            // iOS 26+ 使用原生液态玻璃 TabBar
            appearance.configureWithTransparentBackground()
        } else {
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(Color.bgPrimary.opacity(0.92))
        }
        appearance.shadowColor = UIColor(Color.borderDivider)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // 首页：游客可访问（公共信息）
            NavigationStack {
                HomeView()
                    .navigationDestination(for: AuthRoute.self) { _ in LoginView() }
            }
            .tabItem { Label("首页", systemImage: "house") }
            .tag(0)

            // 对话：需要登录
            NavigationStack {
                ChatView()
                    .requireAuth(
                        icon: "bubble.left.and.bubble.right.fill",
                        title: "登录后查看对话",
                        subtitle: "与法师一对一咨询，接收预约通知"
                    )
                    .navigationDestination(for: AuthRoute.self) { _ in LoginView() }
            }
            .tabItem { Label("对话", systemImage: "bubble.left.and.bubble.right") }
            .tag(1)

            // AI问事：需要登录
            NavigationStack {
                AiDivinationView()
                    .requireAuth(
                        icon: "sparkles",
                        title: "登录后开启 AI 问事",
                        subtitle: "玄学大模型，即问即答"
                    )
                    .navigationDestination(for: AuthRoute.self) { _ in LoginView() }
            }
            .tabItem { Label("AI问事", systemImage: "sparkles") }
            .tag(2)

            // 商城：游客可浏览，下单时拦截
            NavigationStack {
                ShopView()
                    .navigationDestination(for: AuthRoute.self) { _ in LoginView() }
            }
            .tabItem { Label("商城", systemImage: "bag") }
            .tag(3)

            // 我的：未登录显示登录引导
            NavigationStack {
                ProfileView()
                    .navigationDestination(for: AuthRoute.self) { _ in LoginView() }
            }
            .tabItem { Label("我的", systemImage: "person.crop.circle") }
            .tag(4)
        }
        .tint(.brandDefault)
        .animation(.easeInOut(duration: 0.25), value: selectedTab)
        // 特性 7：iOS 26+ 滚动时液态玻璃 TabBar 自动最小化为浮动 dock
        .tabBarMinimizeOnScroll()
    }
}

#Preview {
    MainTabView()
        .preferredColorScheme(.dark)
}
