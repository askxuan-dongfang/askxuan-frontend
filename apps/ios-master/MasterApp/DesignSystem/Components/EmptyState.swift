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
                .font(.system(size: 44))
                .foregroundStyle(.textTertiary)

            Text(title)
                .font(.cardTitle)
                .foregroundStyle(.textSecondary)

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.textTertiary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action {
                SecondaryButton(title: actionTitle, action: action)
                    .frame(maxWidth: 200)
            }
        }
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
