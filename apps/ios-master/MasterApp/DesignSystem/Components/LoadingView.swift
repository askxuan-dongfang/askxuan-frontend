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
            ZStack {
                Image("brand-logo").resizable().scaledToFit()
                    .frame(width: 36, height: 36).accessibilityHidden(true)
                ProgressView().controlSize(.large).tint(.accentDefault)
                    .frame(width: 64, height: 64).offset(y: 44).accessibilityHidden(true)
            }.padding(.bottom, 38)
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
