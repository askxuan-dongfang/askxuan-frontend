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
    @State private var selectedTab: Int = 0

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
            NavigationStack { HomeView() }
                .tabItem { Label("首页", systemImage: "house") }
                .tag(0)

            NavigationStack { ChatView() }
                .tabItem { Label("对话", systemImage: "bubble.left.and.bubble.right") }
                .tag(1)

            NavigationStack { AiDivinationView() }
                .tabItem { Label("AI问事", systemImage: "sparkles") }
                .tag(2)

            NavigationStack { ShopView() }
                .tabItem { Label("商城", systemImage: "bag") }
                .tag(3)

            NavigationStack { ProfileView() }
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
                .tag(4)
        }
        .tint(.brandDefault)
        .animation(.easeInOut(duration: 0.25), value: selectedTab)
    }
}

#Preview {
    MainTabView()
        .preferredColorScheme(.dark)
}
