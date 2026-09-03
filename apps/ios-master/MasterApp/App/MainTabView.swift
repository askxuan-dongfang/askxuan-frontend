//
//  MainTabView.swift
//  MasterApp
//
//  主 TabView 容器：4 个 Tab（工作台/预约/消息/我的），每个 Tab 内部用 NavigationStack。
//  使用 SwiftUI 原生 TabView，Dock 仅在四个根页面显示。
//  通过 UITabBarAppearance 配置深色样式，对齐产品原型 master-app.css 的 .bottom-tabs。
//  预约/消息 Tab 支持角标 badge。
//

import SwiftUI

@MainActor
private final class MainTabBadgeViewModel: ObservableObject {
    @Published private(set) var pendingBookingCount = 0
    @Published private(set) var unreadMessageCount = 0

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func refresh() async {
        async let bookings: BookingListResponse = apiClient.request(
            .masterBookings(status: BookingStatus.pending.rawValue, page: 1, size: 1)
        )
        async let messages: MessageListResponse = apiClient.request(
            .masterMessages(isRead: 0, page: 1, size: 1)
        )

        if let response = try? await bookings {
            pendingBookingCount = Int(response.total)
        }
        if let response = try? await messages {
            unreadMessageCount = Int(response.total)
        }
    }

    func monitor() async {
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(for: .seconds(15))
        }
    }
}

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
    @StateObject private var badgeViewModel = MainTabBadgeViewModel()
    @Environment(\.scenePhase) private var scenePhase

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
        UIScrollView.appearance().keyboardDismissMode = .interactive
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { WorkspaceView().rootTabPage() }
                .tabItem { Label("工作台", systemImage: "square.grid.2x2") }
                .tag(0)

            NavigationStack { BookingsView().rootTabPage() }
                .tabItem { Label("预约", systemImage: "calendar.badge.plus") }
                .badge(badgeViewModel.pendingBookingCount)
                .tag(1)

            NavigationStack { MessagesView().rootTabPage() }
                .tabItem { Label("消息", systemImage: "bubble.left.and.bubble.right") }
                .badge(badgeViewModel.unreadMessageCount)
                .tag(2)

            NavigationStack { ProfileView().rootTabPage() }
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
                .tag(3)
        }
        .tint(.brandDefault)
        .animation(.easeInOut(duration: 0.25), value: selectedTab)
        .task { await badgeViewModel.monitor() }
        .onChange(of: selectedTab) { _, _ in
            Task { await badgeViewModel.refresh() }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await badgeViewModel.refresh() }
        }
        // 特性 7：iOS 26+ 滚动时液态玻璃 TabBar 自动最小化为浮动 dock
        .tabBarMinimizeOnScroll()
    }
}

#Preview {
    MainTabView()
        .preferredColorScheme(.dark)
}
