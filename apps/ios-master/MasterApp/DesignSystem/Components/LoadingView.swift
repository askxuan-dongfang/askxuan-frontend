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
                .scaleEffect(1.2)
            Text(message)
                .font(.caption)
                .foregroundStyle(.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: fullScreen ? .infinity : nil)
        .padding(AppSpacing.xl)
    }
}

#Preview {
    LoadingView()
        .background(Color.bgPrimary)
        .preferredColorScheme(.dark)
}
