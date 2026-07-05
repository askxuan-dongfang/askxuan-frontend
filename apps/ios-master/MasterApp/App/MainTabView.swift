//
//  MainTabView.swift
//  MasterApp
//
//  主 TabView 容器：4 个 Tab（工作台/预约/消息/我的），每个 Tab 内部用 NavigationStack。
//  使用 SwiftUI 原生 TabView，push 到二级页面时 TabBar 自动隐藏。
//  通过 UITabBarAppearance 配置深色样式，对齐产品原型 master-app.css 的 .bottom-tabs。
//  预约/消息 Tab 支持角标 badge。
//

import SwiftUI

struct MainTabView: View {
    // 支持通过 launch argument 设置初始 Tab（用于截图）：xcrun simctl launch booted com.askxuan.master -tab 2
    @State private var selectedTab: Int = {
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-tab"), idx + 1 < args.count,
           let tab = Int(args[idx + 1]), (0...3).contains(tab) {
            return tab
        }
        return 0
    }()

    init() {
        let appearance = UITabBarAppearance()
        if #available(iOS 26.0, *) {
            // iOS 26+ 使用原生液态玻璃 TabBar
            appearance.configureWithTransparentBackground()
        } else {
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(Color.bgPrimary).withAlphaComponent(0.92)
        }
        appearance.shadowColor = UIColor(Color.borderDivider)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { WorkspaceView() }
                .tabItem { Label("工作台", systemImage: "square.grid.2x2") }
                .tag(0)

            NavigationStack { BookingsView() }
                .tabItem { Label("预约", systemImage: "calendar.badge.plus") }
                .badge(3)
                .tag(1)

            NavigationStack { MessagesView() }
                .tabItem { Label("消息", systemImage: "bubble.left.and.bubble.right") }
                .badge(5)
                .tag(2)

            NavigationStack { ProfileView() }
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
                .tag(3)
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
