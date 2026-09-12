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
                .frame(width: 52, height: 52)
                .background(Color.accentDefault.opacity(0.08), in: Circle())
                .overlay(Circle().strokeBorder(Color.accentDefault.opacity(0.14), lineWidth: 1))
                .accessibilityHidden(true)
            Text(text)
                .font(AppTypography.caption)
                .foregroundStyle(.textTertiary)
        }
        .accessibilityElement(children: .combine)
        .appEntrance()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgPrimary)
    }
}

#Preview {
    DFLoadingView()
        .preferredColorScheme(.dark)
}

/// Stable, non-shimmering placeholders keep collection geometry clear while data arrives.
struct DFLoadingCard: View {
    var avatar = false
    var body: some View {
        VStack(alignment: avatar ? .center : .leading, spacing: 12) {
            if avatar {
                Circle().fill(Color.borderDefault.opacity(0.55)).frame(width: 56, height: 56)
            } else {
                RoundedRectangle(cornerRadius: 8).fill(Color.borderDefault.opacity(0.55)).frame(height: 96)
            }
            Capsule().fill(Color.borderDefault.opacity(0.65)).frame(height: 10)
            Capsule().fill(Color.borderDefault.opacity(0.45)).frame(width: 70, height: 8)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .appCardSurface()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
