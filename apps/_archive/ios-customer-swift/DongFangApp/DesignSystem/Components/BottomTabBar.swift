//
//  BottomTabBar.swift
//  DongFangApp
//
//  DFBottomTabBar 底部 TabBar：
//  - 5 个 Tab（首页/对话/AI问事/商城/我的）
//  - 毛玻璃背景 + 安全区适配
//  - 选中态朱砂色
//

import SwiftUI

/// 底部 TabBar 数据项
struct DFTabItem: Identifiable {
    let id: Int
    let title: String
    let icon: String      // SF Symbol 名称
    let selectedIcon: String
}

private let tabItems: [DFTabItem] = [
    DFTabItem(id: 0, title: "首页", icon: "house", selectedIcon: "house.fill"),
    DFTabItem(id: 1, title: "对话", icon: "bubble.left.and.bubble.right", selectedIcon: "bubble.left.and.bubble.right.fill"),
    DFTabItem(id: 2, title: "AI问事", icon: "sparkles", selectedIcon: "sparkles"),
    DFTabItem(id: 3, title: "商城", icon: "bag", selectedIcon: "bag.fill"),
    DFTabItem(id: 4, title: "我的", icon: "person.crop.circle", selectedIcon: "person.crop.circle.fill")
]

/// 自定义底部 TabBar（毛玻璃 + 安全区适配）
struct DFBottomTabBar: View {
    @Binding var selectedTab: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabItems) { item in
                tabButton(for: item)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 8) // safeArea 会额外补齐
        .background(
            Color.bgPrimary.opacity(0.92)
                .background(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.borderDivider)
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private func tabButton(for item: DFTabItem) -> some View {
        let isSelected = selectedTab == item.id
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTab = item.id
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: isSelected ? item.selectedIcon : item.icon)
                    .font(.system(size: item.id == 2 ? 22 : 20, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.brandDefault : Color.textTertiary)
                    .frame(height: 24)

                Text(item.title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.brandDefault : Color.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack {
        Spacer()
        DFBottomTabBar(selectedTab: .constant(0))
    }
    .background(Color.bgPrimary)
    .preferredColorScheme(.dark)
}
