//
//  TopNavBar.swift
//  DongFangApp
//
//  DFTopNavBar 通用顶部导航栏：毛玻璃 + 返回 + 居中标题。
//

import SwiftUI

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
        HStack(spacing: 8) {
            if showsBackButton {
                BackButton()
            } else {
                leading
                    .frame(width: 32, height: 32)
            }

            Spacer()

            Text(title)
                .font(.custom(AppFont.serif[0], size: 17).weight(.bold))
                .foregroundStyle(Color.accentDefault)
                .lineLimit(1)

            Spacer()

            trailing
                .frame(width: 32, height: 32)
        }
        .padding(.horizontal, AppSpacing.lg)
        .frame(height: AppSpacing.navTop)
        .liquidGlassBackground(0.85)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.borderDivider)
                .frame(height: 1)
        }
    }
}

private struct BackButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        DFBackButton()
    }
}

/// 统一返回按钮（双客户端统一规范，NavigationStack 原生滑动返回手势默认可用）：
/// - plain：透明底，用于普通导航栏
/// - circle：毛玻璃圆底带描边，用于 Hero 大图悬浮
struct DFBackButton: View {
    enum Style {
        case plain
        case circle
    }

    var style: Style = .plain
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            dismiss()
        } label: {
            ZStack {
                if style == .circle {
                    Circle()
                        .fill(Color.bgPrimary.opacity(0.6))
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                    Circle()
                        .stroke(Color.borderDefault, lineWidth: 1)
                }
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.accentDefault)
            }
            .frame(width: 36, height: 36)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("返回")
    }
}

extension DFTopNavBar where Leading == EmptyView, Trailing == EmptyView {
    init(_ title: String, showsBackButton: Bool = true) {
        self.init(title, showsBackButton: showsBackButton,
                  leading: { EmptyView() },
                  trailing: { EmptyView() })
    }
}
