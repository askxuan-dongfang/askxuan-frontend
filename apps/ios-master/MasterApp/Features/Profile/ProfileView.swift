//
//  ProfileView.swift
//  MasterApp
//
//  法师主页（页面 12）：资料展示 + 功能入口。
//  GET admin/masters/profile
//

import SwiftUI

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var profile: MasterProfile?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let profile: MasterProfile = try await apiClient.request(.masterProfile)
            self.profile = profile
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
        isLoading = false
    }
}

// MARK: - Mock 数据

private struct MockMenuItem {
    let icon: String
    let label: String
    let iconColor: Color
    let iconBgColor: Color
    let extra: String?
}

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()

    private let mockMenuItems: [MockMenuItem] = [
        MockMenuItem(icon: "person.fill", label: "个人资料",
                     iconColor: .accentDefault,
                     iconBgColor: Color.accentDefault.opacity(0.12),
                     extra: nil),
        MockMenuItem(icon: "star.fill", label: "专长管理",
                     iconColor: Color(hex: "5B7AAA"),
                     iconBgColor: Color(hex: "5B7AAA").opacity(0.12),
                     extra: nil),
        MockMenuItem(icon: "yensign", label: "服务定价",
                     iconColor: .brandDefault,
                     iconBgColor: Color.brandDefault.opacity(0.12),
                     extra: nil),
        MockMenuItem(icon: "creditcard.fill", label: "收入管理",
                     iconColor: .stateWarning,
                     iconBgColor: Color.stateWarning.opacity(0.12),
                     extra: "¥8,560"),
        MockMenuItem(icon: "bubble.left.fill", label: "评价管理",
                     iconColor: .stateSuccess,
                     iconBgColor: Color.stateSuccess.opacity(0.12),
                     extra: "98.5%"),
        MockMenuItem(icon: "gearshape.fill", label: "设置",
                     iconColor: .textTertiary,
                     iconBgColor: Color.textTertiary.opacity(0.15),
                     extra: nil)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                profileCard
                menuGroup
            }
            .padding(.bottom, 70)
        }
        .background(Color.bgPrimary)
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    // MARK: - 法师资料卡片

    private var profileCard: some View {
        VStack(spacing: 0) {
            // 头像
            Image(systemName: "person.fill")
                .font(.system(size: 36))
                .foregroundStyle(.accentDefault)
                .frame(width: 80, height: 80)
                .background(Color.bgTertiary)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.accentDefault, lineWidth: 3)
                )

            // 名字
            Text("智海法师")
                .font(.pageTitle)
                .foregroundStyle(.textPrimary)
                .padding(.top, AppSpacing.md)

            // 寺院 + 已认证 badge
            HStack(spacing: AppSpacing.sm) {
                Text("灵隐寺")
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.accentDefault)
                    Text("已认证")
                        .font(.micro)
                        .foregroundStyle(.accentDefault)
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, 2)
                .background(
                    LinearGradient(colors: [Color.accentDefault.opacity(0.2),
                                             Color.accentDefault.opacity(0.1)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.sm)
                        .stroke(Color.accentDefault.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(AppRadius.sm)
            }
            .padding(.top, AppSpacing.sm)

            // 角色
            Text("住持")
                .font(.caption)
                .foregroundStyle(.textSecondary)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, AppSpacing.lg)
        .background(Color.bgSecondary)
        .cornerRadius(AppRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(Color.borderDefault, lineWidth: 1)
        )
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.lg)
    }

    // MARK: - 菜单列表

    private var menuGroup: some View {
        VStack(spacing: 0) {
            ForEach(mockMenuItems.indices, id: \.self) { index in
                let item = mockMenuItems[index]
                menuRow(item, isLast: index == mockMenuItems.count - 1, index: index)
            }
        }
        .background(Color.bgSecondary)
        .cornerRadius(AppRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(Color.borderDefault, lineWidth: 1)
        )
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.lg)
    }

    private func menuRow(_ item: MockMenuItem, isLast: Bool, index: Int) -> some View {
        NavigationLink {
            menuDestination(for: index)
        } label: {
            HStack(spacing: AppSpacing.md) {
                // 图标
                Image(systemName: item.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(item.iconColor)
                    .frame(width: 36, height: 36)
                    .background(item.iconBgColor)
                    .cornerRadius(AppRadius.md)

                // 标签
                Text(item.label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.textPrimary)

                Spacer()

                // 额外信息
                if let extra = item.extra {
                    Text(extra)
                        .font(.caption)
                        .foregroundStyle(.textTertiary)
                        .padding(.trailing, AppSpacing.sm)
                }

                // 箭头
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.textTertiary)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, 14)
            .background(Color.bgSecondary)
            .overlay(alignment: .bottom) {
                if !isLast {
                    Rectangle()
                        .fill(Color.borderDefault)
                        .frame(height: 1)
                        .padding(.leading, 60)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 菜单导航目标

    @ViewBuilder
    private func menuDestination(for index: Int) -> some View {
        switch index {
        case 0:
            ProfileEditView(profile: viewModel.profile)
        case 1:
            // 专长管理 - 暂用占位
            Text("功能开发中")
                .navigationTitle("专长管理")
                .foregroundStyle(.textSecondary)
        case 2:
            PricingView()
        case 3:
            EarningsView()
        case 4:
            ReviewsView()
        case 5:
            SettingsView()
        default:
            EmptyView()
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
    .preferredColorScheme(.dark)
}
