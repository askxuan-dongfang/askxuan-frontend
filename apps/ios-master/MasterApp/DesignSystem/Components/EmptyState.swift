//
//  EmptyState.swift
//  MasterApp
//
//  空状态占位组件。
//

import SwiftUI

/// 空状态视图
struct EmptyState: View {
    var icon: String = "tray"
    var title: String = "暂无数据"
    var message: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.accentDefault)
                .frame(width: 72, height: 72)
                .background(Color.accentDefault.opacity(0.07), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Color.accentDefault.opacity(0.12)))
                .accessibilityHidden(true)

            Text(title)
                .font(.cardTitle)
                .foregroundStyle(.textSecondary)

            if let message {
                Text(message)
                    .font(AppTypography.caption)
                    .foregroundStyle(.textTertiary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action {
                SecondaryButton(title: actionTitle, action: action)
                    .frame(maxWidth: 200)
            }
        }
        .appEntrance()
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.xl)
    }
}

#Preview {
    EmptyState(icon: "calendar.badge.exclamationmark",
               title: "暂无预约",
               message: "当前没有待处理的预约单")
        .background(Color.bgPrimary)
        .preferredColorScheme(.dark)
}
