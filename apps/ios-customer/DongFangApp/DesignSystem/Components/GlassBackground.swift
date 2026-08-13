//
//  GlassBackground.swift
//  DongFangApp
//
//  液态玻璃背景封装：iOS 26+ 使用 glassEffect，低版本回退 ultraThinMaterial。
//  另提供 CardPressButtonStyle 卡片点击缩放反馈。
//

import SwiftUI
import UIKit

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

private struct RootTabVisibilityObserver: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        RootTabVisibilityViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

private final class RootTabVisibilityViewController: UIViewController {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabBarController?.tabBar.isHidden = false
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard let navigationController, navigationController.viewControllers.count > 1 else { return }
        tabBarController?.tabBar.isHidden = true
    }
}

extension View {
    /// 标记 Tab 根页面。push 离开根页面时隐藏 Dock，返回根页面时恢复。
    func rootTabPage() -> some View {
        background(RootTabVisibilityObserver().frame(width: 0, height: 0))
    }

    /// 二级及更深页面显式隐藏 Dock。
    func secondaryPage() -> some View {
        toolbar(.hidden, for: .tabBar)
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

// MARK: - iOS 26 新特性适配扩展
extension View {
    /// 特性 7：TabBar 滚动最小化（iOS 26+）。
    /// 向下滚动内容时，液态玻璃 TabBar 自动收缩为浮动 dock 小球，腾出阅读空间。
    @ViewBuilder
    func tabBarMinimizeOnScroll() -> some View {
        if #available(iOS 26.0, *) {
            self.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
    }

    /// 特性 8：ScrollView 边缘柔化效果（iOS 26+）。
    /// 在指定边缘（默认底部）添加柔和渐变，让滚动内容与浮动 TabBar 自然过渡，避免硬切。
    @ViewBuilder
    func softScrollEdge(_ edge: Edge.Set = .bottom) -> some View {
        if #available(iOS 26.0, *) {
            self.scrollEdgeEffectStyle(.soft, for: edge)
        } else {
            self
        }
    }
}
