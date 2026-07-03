//
//  PrimaryButton.swift
//  MasterApp
//
//  主/次按钮组件：
//  - PrimaryButton：朱砂渐变(#C45A3C→#D97B4A) + 白色文字 + 圆角 + 44px 高度
//  - SecondaryButton：描边琉璃金 + 透明背景 + 金色文字
//

import SwiftUI

/// 主按钮：朱砂渐变背景 + 白色文字
struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var isEnabled: Bool = true
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: {
            guard isEnabled, !isLoading else { return }
            action()
        }) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.9)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                LinearGradient(
                    colors: [Color.brandDefault, Color(hex: "D97B4A")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(AppRadius.lg)
            .opacity(isEnabled ? 1.0 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
    }
}

/// 次按钮：描边琉璃金 + 透明背景 + 金色文字
struct SecondaryButton: View {
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
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(Color.accentDefault)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.clear)
            .cornerRadius(AppRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(Color.accentDefault, lineWidth: 1.5)
            )
            .opacity(isEnabled ? 1.0 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

#Preview {
    VStack(spacing: 16) {
        PrimaryButton(title: "确认接单") {}
        PrimaryButton(title: "提交", icon: "checkmark.circle.fill") {}
        PrimaryButton(title: "加载中...", isLoading: true) {}
        PrimaryButton(title: "不可用", isEnabled: false) {}
        SecondaryButton(title: "查看详情") {}
    }
    .padding()
    .background(Color.bgPrimary)
    .preferredColorScheme(.dark)
}
