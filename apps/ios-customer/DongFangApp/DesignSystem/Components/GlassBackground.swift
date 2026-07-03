//
//  GlassBackground.swift
//  DongFangApp
//
//  液态玻璃背景封装：iOS 26+ 使用 glassEffect，低版本回退 ultraThinMaterial。
//  另提供 CardPressButtonStyle 卡片点击缩放反馈。
//

import SwiftUI

extension View {
    /// 液态玻璃背景：iOS 26+ 使用 glassEffect，低版本回退 ultraThinMaterial。
    /// - Parameter opacity: 背景色透明度，默认 0.92。
    @ViewBuilder
    func liquidGlassBackground(_ opacity: Double = 0.92) -> some View {
        if #available(iOS 26.0, *) {
            self.background(
                Color.bgPrimary.opacity(opacity)
                    .glassEffect(.regular)
                    .ignoresSafeArea()
            )
        } else {
            self.background(
                Color.bgPrimary.opacity(opacity)
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea()
            )
        }
    }
}

/// 卡片点击缩放反馈 ButtonStyle：按下时 scaleEffect(0.98)，带 0.15s easeInOut 动画。
struct CardPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
