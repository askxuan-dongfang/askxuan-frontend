//
//  SettingsView.swift
//  MasterApp
//
//  设置（辅助页面，并入 Profile 模块）。
//  提供登出、关于、版本信息等。
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var showLogoutConfirm: Bool = false
    @AppStorage(AppTheme.storageKey) private var themeValue = AppTheme.system.rawValue

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // 账号信息
                MasterCard(padding: AppSpacing.md) {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        settingRow(icon: "person.circle", title: L10n.text("当前账号"),
                                   value: authStore.nickname ?? "法师", tint: .accentDefault)
                        Divider().background(Color.borderDivider)
                        settingRow(icon: "number", title: L10n.text("法师 ID"),
                                   value: authStore.masterId ?? "—", tint: .brandDefault)
                    }
                }

                // 通用
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text(L10n.text("通用"))
                        .font(AppTypography.caption)
                        .foregroundStyle(.textTertiary)
                        .padding(.leading, AppSpacing.xs)
                    MasterCard(padding: AppSpacing.md) {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            NavigationLink { AppearanceSettingsView() } label: {
                                settingRow(icon: "circle.lefthalf.filled", title: L10n.text("外观与语言"),
                                           value: AppTheme(rawValue: themeValue)?.title ?? AppTheme.system.title,
                                           tint: .accentDefault, showArrow: true)
                            }
                            .buttonStyle(CardPressButtonStyle())
                            Divider().background(Color.borderDivider)
                            settingRow(icon: "bell.badge", title: L10n.text("消息通知"), value: "已开启",
                                       tint: .accentDefault, showArrow: true)
                            Divider().background(Color.borderDivider)
                            settingRow(icon: "wifi", title: L10n.text("网络环境"),
                                       value: AppConfig.isDebug ? "Debug" : "Release",
                                       tint: .stateSuccess, showArrow: true)
                            Divider().background(Color.borderDivider)
                            settingRow(icon: "lock.shield", title: L10n.text("本地网络"),
                                       value: "已允许", tint: .stateSuccess, showArrow: true)
                        }
                    }
                }

                // 关于
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text(L10n.text("关于"))
                        .font(AppTypography.caption)
                        .foregroundStyle(.textTertiary)
                        .padding(.leading, AppSpacing.xs)
                    MasterCard(padding: AppSpacing.md) {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            settingRow(icon: "info.circle", title: L10n.text("应用版本"),
                                       value: AppConfig.clientVersion, tint: .accentDefault)
                            Divider().background(Color.borderDivider)
                            settingRow(icon: "doc.text", title: L10n.text("服务协议"),
                                       value: nil, tint: .textSecondary, showArrow: true)
                            Divider().background(Color.borderDivider)
                            settingRow(icon: "shield.lefthalf.filled", title: L10n.text("隐私政策"),
                                       value: nil, tint: .textSecondary, showArrow: true)
                        }
                    }
                }

                // 登出
                PrimaryButton(title: L10n.text("退出登录"), icon: "arrow.right.square.fill") {
                    showLogoutConfirm = true
                }

                Text(L10n.text("问玄东方 · 法师工作台"))
                    .font(.micro)
                    .foregroundStyle(.textTertiary)
                    .padding(.top, AppSpacing.md)
            }
            .padding(.horizontal, AppSpacing.pageHorizontal)
            .padding(.top, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(Color.bgPrimary)
        .navigationTitle(L10n.text("设置"))
        .navigationBarTitleDisplayMode(.large)

        .alert(L10n.text("确认退出登录？"), isPresented: $showLogoutConfirm) {
            Button(L10n.text("取消"), role: .cancel) {}
            Button(L10n.text("退出"), role: .destructive) {
                authStore.logout()
            }
        } message: {
            Text(L10n.text("退出后需重新登录才能使用法师工作台"))
        }
    }

    private func settingRow(icon: String, title: String, value: String?,
                            tint: Color, showArrow: Bool = false) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(AppTypography.reading)
                .foregroundStyle(tint)
                .frame(width: 24)
            Text(L10n.lookup(title))
                .font(AppTypography.body)
                .foregroundStyle(.textPrimary)
            Spacer()
            if let value {
                Text(L10n.lookup(value))
                    .font(AppTypography.caption)
                    .foregroundStyle(.textSecondary)
            }
            if showArrow {
                Image(systemName: "chevron.right")
                    .font(AppTypography.caption)
                    .foregroundStyle(.textTertiary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AuthStore.shared)
    }
    .preferredColorScheme(.dark)
}
