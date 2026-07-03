//
//  MasterBottomTabBar.swift
//  MasterApp
//
//  法师端底部 TabBar：4 个 Tab（工作台/预约/消息/我的）。
//  对齐产品原型 master-app.css 的 .bottom-tabs 样式：
//  - 高度 64pt + 安全区
//  - 背景 rgba(28,18,16,0.92) + ultraThinMaterial 模糊
//  - 顶部 1px 琉璃金描边
//  - 选中态 brand 色，未选中 text-muted 色
//  - 支持角标（badge）
//

import SwiftUI

struct MasterTabItem: Identifiable {
    let id: Int
    let title: String
    let icon: String
    let selectedIcon: String
    let badge: Int?
}

private let masterTabItems: [MasterTabItem] = [
    MasterTabItem(id: 0, title: "工作台", icon: "square.grid.2x2", selectedIcon: "square.grid.2x2.fill", badge: nil),
    MasterTabItem(id: 1, title: "预约", icon: "calendar", selectedIcon: "calendar.badge.plus.fill", badge: 3),
    MasterTabItem(id: 2, title: "消息", icon: "bubble.left.and.bubble.right", selectedIcon: "bubble.left.and.bubble.right.fill", badge: 5),
    MasterTabItem(id: 3, title: "我的", icon: "person.crop.circle", selectedIcon: "person.crop.circle.fill", badge: nil)
]

struct MasterBottomTabBar: View {
    @Binding var selectedTab: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(masterTabItems) { item in
                tabButton(for: item)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
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
    private func tabButton(for item: MasterTabItem) -> some View {
        let isSelected = selectedTab == item.id
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTab = item.id
            }
        } label: {
            ZStack {
                VStack(spacing: 3) {
                    Image(systemName: isSelected ? item.selectedIcon : item.icon)
                        .font(.system(size: 22, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Color.brandDefault : Color.textTertiary)
                        .frame(height: 24)

                    Text(item.title)
                        .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Color.brandDefault : Color.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .contentShape(Rectangle())

                // 角标
                if let badge = item.badge, badge > 0 {
                    HStack {
                        Spacer()
                        Text("\(badge)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(Color.brandDefault)
                            .clipShape(Capsule())
                            .offset(x: 12, y: -10)
                    }
                    .padding(.trailing, 24)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MasterBottomTabBar(selectedTab: .constant(0))
        .preferredColorScheme(.dark)
}
