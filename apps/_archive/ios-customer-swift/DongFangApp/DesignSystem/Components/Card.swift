//
//  Card.swift
//  DongFangApp
//
//  DFCard 通用卡片组件：#2A1E1A 背景 + 金色微妙边框 + 12px 圆角 + padding。
//

import SwiftUI

/// 问玄东方通用卡片
/// - 深色卡片背景 + 琉璃金微妙描边 + 12pt 圆角
struct DFCard<Content: View>: View {
    /// 内边距
    var padding: CGFloat = AppSpacing.md
    /// 圆角
    var cornerRadius: CGFloat = AppRadius.lg
    /// 内容
    private let content: Content

    init(padding: CGFloat = AppSpacing.md,
         cornerRadius: CGFloat = AppRadius.lg,
         @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(Color.bgSecondary)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.borderDefault, lineWidth: 1)
            )
    }
}

#Preview {
    VStack(spacing: 12) {
        DFCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("灵隐寺")
                    .font(.cardTitle)
                    .foregroundStyle(.textPrimary)
                Text("禅宗 · 杭州")
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    .padding()
    .background(Color.bgPrimary)
    .preferredColorScheme(.dark)
}
