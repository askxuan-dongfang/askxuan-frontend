//
//  PrimaryButton.swift
//  DongFangApp
//
//  主/次按钮组件：
//  - DFPrimaryButton：主题品牌色 + 白色文字 + 圆角 + 至少 48pt 触控高度
//  - DFSecondaryButton：描边琉璃金 + 透明背景 + 金色文字
//

import SwiftUI

/// 主按钮：与 H5 一致的实色品牌背景 + 白色文字
struct DFPrimaryButton: View {
    let title: String
    var icon: String? = nil
    var isEnabled: Bool = true
    var isLoading: Bool = false
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: {
            guard isEnabled, !isLoading else { return }
            action()
        }) {
            ZStack {
                HStack(spacing: 6) {
                    if let icon { Image(systemName: icon) }
                    Text(L10n.lookup(title))
                }
                .opacity(isLoading ? 0 : 1)
                if isLoading {
                    HStack(spacing: 8) {
                        ProgressView().tint(.white)
                        Text(L10n.text("处理中…"))
                    }
                    .transition(.opacity)
                }
            }
            .font(AppTypography.control)
            .animation(reduceMotion ? nil : AppMotion.selection, value: isLoading)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .frame(minHeight: 48)
            .background(Color.brandDefault)
            .cornerRadius(AppRadius.lg)
            .opacity(isEnabled ? 1.0 : 0.5)
        }
        .buttonStyle(CardPressButtonStyle(prominent: true))
        .accessibilityLabel(L10n.lookup(title))
        .accessibilityValue(isLoading ? L10n.text("正在处理") : "")
        .disabled(!isEnabled || isLoading)
    }
}

/// 次按钮：描边琉璃金 + 透明背景 + 金色文字
struct DFSecondaryButton: View {
    let title: String
    var icon: String? = nil
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: {
            guard isEnabled else { return }
            action()
        }) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(AppTypography.control)
                }
                Text(L10n.lookup(title))
                    .font(AppTypography.control)
            }
            .foregroundStyle(Color.accentDefault)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .frame(minHeight: 48)
            .background(Color.clear)
            .cornerRadius(AppRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(Color.accentDefault.opacity(0.25), lineWidth: 1)
            )
            .opacity(isEnabled ? 1.0 : 0.5)
        }
        .buttonStyle(CardPressButtonStyle())
        .disabled(!isEnabled)
    }
}
