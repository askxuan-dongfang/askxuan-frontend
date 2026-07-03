//
//  MainTabView.swift
//  DongFangApp
//
//  主 TabView 容器：5 个 Tab（首页/对话/AI问事/商城/我的），首页为完整功能，其余为占位。
//  自定义底部 DFBottomTabBar 样式，每个 Tab 内部用 NavigationStack。
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Int = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // 各 Tab 内容
            Group {
                switch selectedTab {
                case 0:
                    NavigationStack {
                        HomeView()
                    }
                case 1:
                    NavigationStack {
                        PlaceholderTabView(title: "对话", icon: "bubble.left.and.bubble.right.fill")
                    }
                case 2:
                    NavigationStack {
                        PlaceholderTabView(title: "AI问事", icon: "sparkles")
                    }
                case 3:
                    NavigationStack {
                        PlaceholderTabView(title: "商城", icon: "bag.fill")
                    }
                case 4:
                    NavigationStack {
                        PlaceholderTabView(title: "我的", icon: "person.crop.circle.fill")
                    }
                default:
                    EmptyView()
                }
            }
            .ignoresSafeArea(edges: .bottom)

            // 自定义底部 TabBar
            DFBottomTabBar(selectedTab: $selectedTab)
        }
        .tint(.brandDefault)
    }
}

/// 占位 Tab 视图（MVP-1 范围外模块的临时占位）
struct PlaceholderTabView: View {
    let title: String
    let icon: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.accentDefault)
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.textPrimary)
            Text("敬请期待")
                .font(.subheadline)
                .foregroundStyle(.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgPrimary)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

#Preview {
    MainTabView()
        .preferredColorScheme(.dark)
}
