//
//  LoadingView.swift
//  MasterApp
//
//  加载态组件：居中转圈 + 文案。
//

import SwiftUI

/// 加载中视图
struct LoadingView: View {
    var message: String = "加载中..."
    var fullScreen: Bool = false

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            ProgressView()
                .tint(.accentDefault)
                .frame(width: 52, height: 52)
                .background(Color.accentDefault.opacity(0.08), in: Circle())
                .overlay(Circle().strokeBorder(Color.accentDefault.opacity(0.14), lineWidth: 1))
                .accessibilityHidden(true)
            Text(message)
                .font(AppTypography.caption)
                .foregroundStyle(.textTertiary)
        }
        .accessibilityElement(children: .combine)
        .appEntrance()
        .frame(maxWidth: .infinity, maxHeight: fullScreen ? .infinity : nil)
        .padding(AppSpacing.xl)
    }
}

#Preview {
    LoadingView()
        .background(Color.bgPrimary)
        .preferredColorScheme(.dark)
}
