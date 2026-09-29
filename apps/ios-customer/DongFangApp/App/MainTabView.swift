//
//  MainTabView.swift
//  DongFangApp
//
//  主 TabView 容器：5 个 Tab（首页/对话/AI问事/商城/我的），每个 Tab 内部用 NavigationStack。
//  使用 SwiftUI 原生 TabView，Dock 仅在五个根页面显示。
//  通过 UITabBarAppearance 配置当前主题的原生底部导航。
//

import SwiftUI

struct MainTabView: View {
    @State private var navigationPaths = Array(repeating: NavigationPath(), count: 5)
    @ObservedObject private var chatNotifications=NativeChatNotifications.shared
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
        UIScrollView.appearance().keyboardDismissMode = .interactive
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // 首页：游客可访问（公共信息）
            NavigationStack(path: $navigationPaths[0]) {
                HomeView()
                    .rootTabPage()
                    .navigationDestination(for: AuthRoute.self) { _ in LoginView() }
            }
            .tabItem { Label("首页", systemImage: "house") }
            .tag(0)

            // 对话：需要登录
            NavigationStack(path: $navigationPaths[1]) {
                ChatView()
                    .rootTabPage()
                    .requireAuth(
                        icon: "bubble.left.and.bubble.right.fill",
                        title: "登录后查看对话",
                        subtitle: "与法师一对一咨询，接收预约通知"
                    )
                    .navigationDestination(for: AuthRoute.self) { _ in LoginView() }
            }
            .tabItem { Label("对话", systemImage: "bubble.left.and.bubble.right") }
            .badge(chatNotifications.chatUnread)
            .tag(1)

            // 专题与示例公开；个人报告和问事按入口校验登录
            NavigationStack(path: $navigationPaths[2]) {
                AiDivinationView()
                    .navigationDestination(for: AiNativeRoute.self) { route in
                        switch route {
                        case .topic(let code): AiReportTopicEntry(code: code)
                        case .example(let code): if let sample = AiReportCatalog.examples.first(where: { $0.code == code }) { AiReportExampleView(example: sample) }
                        case .report(let id): AiReportWorkspace(reportID: id).requireAuth(title: "登录后查看报告")
                        }
                    }
                    .id(authStore.sessionID)
                    .rootTabPage()
                    .navigationDestination(for: AuthRoute.self) { _ in LoginView() }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("AskXuanReportConversation"))) { _ in navigationPaths[2] = NavigationPath() }
            .tabItem { Label("AI问事", systemImage: "sparkles") }
            .tag(2)

            // 商城：游客可浏览，下单时拦截
            NavigationStack(path: $navigationPaths[3]) {
                ShopView()
                    .rootTabPage()
                    .navigationDestination(for: AuthRoute.self) { _ in LoginView() }
            }
            .tabItem { Label("商城", systemImage: "bag") }
            .tag(3)

            // 我的：未登录显示登录引导
            NavigationStack(path: $navigationPaths[4]) {
                ProfileView()
                    .rootTabPage()
                    .navigationDestination(for: AuthRoute.self) { _ in LoginView() }
            }
            .tabItem { Label("我的", systemImage: "person.crop.circle") }
            .tag(4)
        }
        .tint(.brandDefault)
        .sensoryFeedback(.selection, trigger: selectedTab)
        // 特性 7：iOS 26+ 滚动时液态玻璃 TabBar 自动最小化为浮动 dock
        .tabBarMinimizeOnScroll()
    }
}

#Preview {
    MainTabView()
        .preferredColorScheme(.dark)
}
