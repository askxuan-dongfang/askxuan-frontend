//
//  EmptyState.swift
//  DongFangApp
//
//  DFEmptyState 空状态占位组件。
//

import SwiftUI

/// 空状态视图：图标 + 标题 + 副标题
struct DFEmptyState: View {
    var icon: String = "tray"
    var title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(.textTertiary)
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.textSecondary)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppSpacing.xl)
        .background(Color.bgPrimary)
    }
}

#Preview {
    DFEmptyState(icon: "building.2", title: "暂无寺院", subtitle: "下拉刷新试试")
        .preferredColorScheme(.dark)
}
