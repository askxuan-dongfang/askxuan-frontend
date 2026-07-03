//
//  TagPill.swift
//  DongFangApp
//
//  DFTagPill 胶囊标签：
//  - 选中态：朱砂红背景 + 白字
//  - 默认态：#3A2C25 背景 + 辅助文字色
//  - 9999px 圆角（全圆角胶囊）
//

import SwiftUI

/// 胶囊标签（用于教派筛选、服务类型等）
struct DFTagPill: View {
    let title: String
    var isSelected: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? Color.white : Color.textTertiary)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(isSelected ? Color.brandDefault : Color.bgTertiary)
            .clipShape(Capsule())
            .contentShape(Capsule())
            .onTapGesture {
                action?()
            }
    }
}

#Preview {
    HStack(spacing: 8) {
        DFTagPill(title: "全部", isSelected: true)
        DFTagPill(title: "汉传佛教")
        DFTagPill(title: "藏传佛教")
        DFTagPill(title: "道教")
    }
    .padding()
    .background(Color.bgPrimary)
    .preferredColorScheme(.dark)
}
