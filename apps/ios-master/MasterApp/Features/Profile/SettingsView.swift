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

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // 账号信息
                MasterCard(padding: AppSpacing.md) {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        settingRow(icon: "person.circle", title: "当前账号",
                                   value: authStore.nickname ?? "法师", tint: .accentDefault)
                        Divider().background(Color.borderDivider)
                        settingRow(icon: "number", title: "法师 ID",
                                   value: authStore.masterId ?? "—", tint: .brandDefault)
                    }
                }

                // 通用
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("通用")
                        .font(.caption)
                        .foregroundStyle(.textTertiary)
                        .padding(.leading, AppSpacing.xs)
                    MasterCard(padding: AppSpacing.md) {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            settingRow(icon: "bell.badge", title: "消息通知", value: "已开启",
                                       tint: .accentDefault, showArrow: true)
                            Divider().background(Color.borderDivider)
                            settingRow(icon: "wifi", title: "网络环境",
                                       value: AppConfig.isDebug ? "Debug" : "Release",
                                       tint: .stateSuccess, showArrow: true)
                            Divider().background(Color.borderDivider)
                            settingRow(icon: "lock.shield", title: "本地网络",
                                       value: "已允许", tint: .stateSuccess, showArrow: true)
                        }
                    }
                }

                // 关于
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("关于")
                        .font(.caption)
                        .foregroundStyle(.textTertiary)
                        .padding(.leading, AppSpacing.xs)
                    MasterCard(padding: AppSpacing.md) {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            settingRow(icon: "info.circle", title: "应用版本",
                                       value: "1.0.0", tint: .accentDefault)
                            Divider().background(Color.borderDivider)
                            settingRow(icon: "doc.text", title: "服务协议",
                                       value: nil, tint: .textSecondary, showArrow: true)
                            Divider().background(Color.borderDivider)
                            settingRow(icon: "shield.lefthalf.filled", title: "隐私政策",
                                       value: nil, tint: .textSecondary, showArrow: true)
                        }
                    }
                }

                // 登出
                PrimaryButton(title: "退出登录", icon: "arrow.right.square.fill") {
                    showLogoutConfirm = true
                }

                Text("问玄东方 · 法师工作台")
                    .font(.micro)
                    .foregroundStyle(.textTertiary)
                    .padding(.top, AppSpacing.md)
            }
            .padding(.horizontal, AppSpacing.pageHorizontal)
            .padding(.top, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(Color.bgPrimary)
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .alert("确认退出登录？", isPresented: $showLogoutConfirm) {
            Button("取消", role: .cancel) {}
            Button("退出", role: .destructive) {
                authStore.logout()
            }
        } message: {
            Text("退出后需重新登录才能使用法师工作台")
        }
    }

    private func settingRow(icon: String, title: String, value: String?,
                            tint: Color, showArrow: Bool = false) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(tint)
                .frame(width: 24)
            Text(title)
                .font(.body)
                .foregroundStyle(.textPrimary)
            Spacer()
            if let value {
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
            }
            if showArrow {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
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
