//
//  LoginRequiredView.swift
//  DongFangApp
//
//  通用未登录引导组件：
//  - 游客访问需要登录的功能时展示
//  - 提供登录/注册入口（跳转 LoginView）
//  - 支持自定义标题、描述、图标
//

import SwiftUI

/// 未登录引导视图
struct LoginRequiredView: View {
    var icon: String = "lock.circle.fill"
    var title: String = "登录后即可使用"
    var subtitle: String = "登录问玄东方，开启您的祈福之旅"
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // 图标
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.accentDefault.opacity(0.6), Color.accentDefault],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textTertiary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                // 登录按钮
                NavigationLink(value: AuthRoute.login) {
                    Text("立即登录")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color.brandDefault, Color.brandLight],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(AppRadius.md)
                }

                // 注册提示
                Text("未注册手机号将自动创建账号")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, 40)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgPrimary)
    }
}

/// 鉴权路由
enum AuthRoute: Hashable {
    case login
}

/// 鉴权守卫 ViewModifier：未登录时展示 LoginRequiredView
struct AuthGate: ViewModifier {
    @EnvironmentObject private var authStore: AuthStore
    var icon: String = "lock.circle.fill"
    var title: String = "登录后即可使用"
    var subtitle: String = "登录问玄东方，开启您的祈福之旅"

    func body(content: Content) -> some View {
        if authStore.isLoggedIn {
            content
        } else {
            LoginRequiredView(
                icon: icon,
                title: title,
                subtitle: subtitle,
                isPresented: .constant(false)
            )
        }
    }
}

extension View {
    /// 登录守卫：未登录时显示引导页，已登录时显示原始内容
    func requireAuth(
        icon: String = "lock.circle.fill",
        title: String = "登录后即可使用",
        subtitle: String = "登录问玄东方，开启您的祈福之旅"
    ) -> some View {
        modifier(AuthGate(icon: icon, title: title, subtitle: subtitle))
    }
}
