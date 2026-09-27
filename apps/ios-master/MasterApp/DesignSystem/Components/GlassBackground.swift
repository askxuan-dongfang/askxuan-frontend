//
//  GlassBackground.swift
//  MasterApp
//
//  液态玻璃背景封装：iOS 26+ 使用 glassEffect，低版本回退 ultraThinMaterial。
//  另提供 CardPressButtonStyle 卡片点击缩放反馈。
//  对齐 C 端 GlassBackground 设计。
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

// One coordinator per navigation controller: SwiftUI owns the transition and tab-bar
// presentation, including interactive cancellation. Only restore the edge gesture
// disabled by custom navigation chrome; never replace the navigation delegate.
private var navigationGestureKey: UInt8 = 0
private final class NativePopGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    weak var navigation: UINavigationController?
    init(_ navigation: UINavigationController) { self.navigation = navigation }
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let navigation else { return false }
        return navigation.viewControllers.count > 1 && navigation.transitionCoordinator == nil
    }
}
struct NativeNavigationBridge: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController { Observer() }
    func updateUIViewController(_ controller: UIViewController, context: Context) {}
    private final class Observer: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard let navigationController,
                  let gesture = navigationController.interactivePopGestureRecognizer else { return }
            let delegate: NativePopGestureDelegate
            if let stored = objc_getAssociatedObject(navigationController, &navigationGestureKey) as? NativePopGestureDelegate {
                delegate = stored
            } else {
                delegate = NativePopGestureDelegate(navigationController)
                objc_setAssociatedObject(navigationController, &navigationGestureKey, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
            gesture.delegate = delegate
            gesture.isEnabled = true
        }
    }
}

extension View {
    func rootTabPage() -> some View {
        toolbar(.visible, for: .tabBar)
            .background(NativeNavigationBridge().frame(width: 0, height: 0))
    }
    func secondaryPage() -> some View {
        toolbar(.hidden, for: .tabBar)
            .background(NativeNavigationBridge().frame(width: 0, height: 0))
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
    // Native push/pop and sheet transitions already explain navigation. Reappearing
    // content must not replay a second delayed entrance over those transitions.
    func body(content: Content) -> some View { content }
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
