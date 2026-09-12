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
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.accentDefault)
                .frame(width: 72, height: 72)
                .background(Color.accentDefault.opacity(0.07), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Color.accentDefault.opacity(0.12)))
                .accessibilityHidden(true)
            Text(title)
                .font(AppTypography.body.weight(.medium))
                .foregroundStyle(.textSecondary)
            if let subtitle {
                Text(subtitle)
                    .font(AppTypography.caption)
                    .foregroundStyle(.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .appEntrance()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppSpacing.xl)
        .background(Color.bgPrimary)
    }
}

#Preview {
    DFEmptyState(icon: "building.2", title: "暂无寺院", subtitle: "下拉刷新试试")
        .preferredColorScheme(.dark)
}
