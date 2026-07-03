//
//  StatCard.swift
//  MasterApp
//
//  统计卡片：数值 + 标题 + 可选图标，用于工作台/收益概览。
//

import SwiftUI

/// 统计卡片
struct StatCard: View {
    let title: String
    let value: String
    var icon: String? = nil
    var tint: Color = .accentDefault

    var body: some View {
        MasterCard(padding: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack(spacing: AppSpacing.xs) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(tint)
                    }
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.textSecondary)
                }
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        StatCard(title: "今日待办", value: "5", icon: "list.clipboard", tint: .brandDefault)
        StatCard(title: "本月收益", value: "¥8,640", icon: "yensign.circle", tint: .accentDefault)
    }
    .padding()
    .background(Color.bgPrimary)
    .preferredColorScheme(.dark)
}
