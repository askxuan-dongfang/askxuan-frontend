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
                    // 显式指定矩形形状：默认 capsule 会在大幅面（如顶部导航栏）上
                    // 呈现出胶囊弧线与边缘折射，导致状态栏区域出现异常圆弧并扭曲图标。
                    .glassEffect(.regular, in: .rect)
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

private final class RootTabVisibilityViewController: UIViewController, UIGestureRecognizerDelegate {
    private weak var observedNavigationController: UINavigationController?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabBarController?.tabBar.isHidden = false
        enableInteractivePopGesture()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        enableInteractivePopGesture()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard let navigationController, navigationController.viewControllers.count > 1 else { return }
        tabBarController?.tabBar.isHidden = true
    }

    deinit {
        guard observedNavigationController?.interactivePopGestureRecognizer?.delegate === self else { return }
        observedNavigationController?.interactivePopGestureRecognizer?.delegate = nil
    }

    private func enableInteractivePopGesture() {
        guard let navigationController,
              let gesture = navigationController.interactivePopGestureRecognizer else { return }
        observedNavigationController = navigationController
        gesture.delegate = self
        gesture.isEnabled = true
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let navigationController = observedNavigationController else { return false }
        return navigationController.viewControllers.count > 1 && navigationController.transitionCoordinator == nil
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

// MARK: - Shared motion
/// Short, non-bouncy feedback. UIKit's live preference is read for action-driven changes.
enum AppMotion {
    static let press = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.12)
    static let selection = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.20)
    static let reveal = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.28)

    static func perform(_ animation: Animation = selection, _ changes: () -> Void) {
        withAnimation(UIAccessibility.isReduceMotionEnabled ? nil : animation, changes)
    }
}

private struct AppVisualDefaults: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .font(AppTypography.body)
            .transaction { transaction in
                if reduceMotion {
                    transaction.animation = nil
                    transaction.disablesAnimations = true
                }
            }
    }
}

extension View {
    /// Inherit the same body typography and honor reduced motion in all presented screens.
    func appVisualDefaults() -> some View { modifier(AppVisualDefaults()) }
}

/// Keep feedback inside the pressed control so scroll and navigation gestures remain native.
struct CardPressButtonStyle: ButtonStyle {
    var prominent = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = isEnabled && configuration.isPressed
        configuration.label
            .scaleEffect(pressed && !reduceMotion ? (prominent ? 0.975 : 0.985) : 1)
            .offset(y: pressed && !reduceMotion ? 1 : 0)
            .opacity(pressed ? 0.94 : 1)
            .brightness(pressed ? -0.025 : 0)
            .animation(reduceMotion ? nil : (pressed ? AppMotion.press : AppMotion.selection), value: pressed)
    }
}

private struct AppEntrance: ViewModifier {
    var order: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared || reduceMotion ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 8)
            .onAppear {
                guard !appeared else { return }
                // This state is never reset on scroll or a return from a detail page.
                withAnimation(reduceMotion ? nil : AppMotion.reveal.delay(Double(min(max(order, 0), 4)) * 0.035)) {
                    appeared = true
                }
            }
    }
}

private struct AppCardSurface: ViewModifier {
    var cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(Color.bgSecondary, in: shape)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.borderDefault, lineWidth: 1))
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.12 : 0.035), radius: 10, x: 0, y: 3)
    }
}

private struct AppNumericTransition<Value: Equatable>: ViewModifier {
    let value: Value
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .contentTransition(reduceMotion ? .identity : .numericText())
            .animation(reduceMotion ? nil : AppMotion.selection, value: value)
    }
}

extension View {
    /// A single quiet reveal for a small section, without animating the whole page tree.
    func appEntrance(order: Int = 0) -> some View { modifier(AppEntrance(order: order)) }
    func appCardSurface(cornerRadius: CGFloat = AppRadius.lg) -> some View { modifier(AppCardSurface(cornerRadius: cornerRadius)) }
    func appNumericTransition<Value: Equatable>(value: Value) -> some View { modifier(AppNumericTransition(value: value)) }
    /// Retain the system sheet gesture, detents, keyboard avoidance and dismissal behavior.
    func appSheetSurface() -> some View {
        presentationBackground(Color.bgPrimary)
            .presentationCornerRadius(28)
            .presentationDragIndicator(.visible)
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
