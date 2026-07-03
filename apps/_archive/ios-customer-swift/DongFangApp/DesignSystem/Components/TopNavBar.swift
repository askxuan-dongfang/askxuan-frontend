//
//  TopNavBar.swift
//  DongFangApp
//
//  DFTopNavBar 顶部导航栏：
//  - 毛玻璃效果(.ultraThinMaterial)
//  - 44px 高度
//  - 左侧返回按钮 + 居中标题
//  - sticky（悬浮在内容之上）
//

import SwiftUI

/// 通用顶部导航栏（毛玻璃 + 返回 + 居中标题）
struct DFTopNavBar<Leading: View, Trailing: View>: View {
    let title: String
    let showsBackButton: Bool
    let leading: Leading
    let trailing: Trailing

    init(_ title: String,
         showsBackButton: Bool = true,
         @ViewBuilder leading: () -> Leading,
         @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.showsBackButton = showsBackButton
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        ZStack {
            // 毛玻璃背景（对应 backdrop-filter: blur(12px)）
            Color.bgPrimary.opacity(0.85)
                .background(.ultraThinMaterial)
                .ignoresSafeArea(edges: .top)

            HStack(spacing: 8) {
                // 左侧：返回按钮
                if showsBackButton {
                    BackButton()
                } else {
                    leading
                        .frame(width: 32, height: 32)
                }

                Spacer()

                // 居中标题
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.accentDefault)
                    .lineLimit(1)

                Spacer()

                // 右侧：自定义操作区
                trailing
                    .frame(width: 32, height: 32)
            }
            .padding(.horizontal, AppSpacing.lg)
            .frame(height: AppSpacing.navTop)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.borderDivider)
                .frame(height: 1)
        }
    }
}

/// 返回按钮（金色箭头）
private struct BackButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.accentDefault)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// 便捷构造：仅标题
extension DFTopNavBar where Leading == EmptyView, Trailing == EmptyView {
    init(_ title: String, showsBackButton: Bool = true) {
        self.init(title, showsBackButton: showsBackButton,
                  leading: { EmptyView() },
                  trailing: { EmptyView() })
    }
}

#Preview {
    VStack(spacing: 0) {
        DFTopNavBar("找寺院")
        Spacer()
            .frame(maxWidth: .infinity)
            .background(Color.bgPrimary)
    }
    .preferredColorScheme(.dark)
}
