//
//  LoadingView.swift
//  DongFangApp
//
//  DFLoadingView 加载占位组件：居中 ProgressView + 可选文案。
//

import SwiftUI

/// 居中加载视图
struct DFLoadingView: View {
    var text: String = "加载中..."

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            ProgressView()
                .tint(.accentDefault)
                .scaleEffect(1.2)
            Text(text)
                .font(.caption)
                .foregroundStyle(.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgPrimary)
    }
}

#Preview {
    DFLoadingView()
        .preferredColorScheme(.dark)
}
