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

private struct ProfileMenuItem {
    let icon: String
    let label: String
    let iconColor: Color
    let iconBgColor: Color
    let extra: String?
}

struct ProfileView: View {
    /// 从工作台「个人主页」push 进入时为 true（Tab 根页面为 false，无需返回）
    var showsBackButton: Bool = false

    @StateObject private var viewModel = ProfileViewModel()

    private let menuItems: [ProfileMenuItem] = [
        ProfileMenuItem(icon: "person.fill", label: L10n.text("个人资料"),
                     iconColor: .accentDefault,
                     iconBgColor: Color.accentDefault.opacity(0.12),
                     extra: nil),
        ProfileMenuItem(icon: "star.fill", label: L10n.text("专长管理"),
                     iconColor: Color(hex: "5B7AAA"),
                     iconBgColor: Color(hex: "5B7AAA").opacity(0.12),
                     extra: nil),
        ProfileMenuItem(icon: "tag.fill", label: L10n.text("服务标签"),
                     iconColor: Color(hex: "7A8FA6"),
                     iconBgColor: Color(hex: "7A8FA6").opacity(0.12),
                     extra: nil),
        ProfileMenuItem(icon: "yensign", label: L10n.text("服务定价"),
                     iconColor: .brandDefault,
                     iconBgColor: Color.brandDefault.opacity(0.12),
                     extra: nil),
        ProfileMenuItem(icon: "creditcard.fill", label: L10n.text("我的钱包"),
                     iconColor: .stateWarning,
                     iconBgColor: Color.stateWarning.opacity(0.12),
                     extra: nil),
        ProfileMenuItem(icon: "bubble.left.fill", label: L10n.text("评价管理"),
                     iconColor: .stateSuccess,
                     iconBgColor: Color.stateSuccess.opacity(0.12),
                     extra: nil),
        ProfileMenuItem(icon: "gearshape.fill", label: L10n.text("设置"),
                     iconColor: .textTertiary,
                     iconBgColor: Color.textTertiary.opacity(0.15),
                     extra: nil)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                profileCard
                NavigationLink { MediaStudioView() } label: {
                    Label(L10n.text("内容与直播"), systemImage: "video.badge.waveform")
                        .frame(maxWidth: .infinity, alignment: .leading).padding(20)
                        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: AppRadius.lg))
                }.buttonStyle(CardPressButtonStyle()).padding(.horizontal, AppSpacing.lg).padding(.top, AppSpacing.lg)
                menuGroup
            }
            .padding(.bottom, 70)
        }
        .softScrollEdge(.bottom)
        .background(Color.bgPrimary)
        .toolbar(showsBackButton ? .visible : .hidden, for: .navigationBar)
        .navigationTitle(L10n.lookup(showsBackButton ? L10n.text("个人主页") : ""))
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    // MARK: - 法师资料卡片

    private var profileCard: some View {
        VStack(spacing: 0) {
            // 头像
            AvatarPhotoButton(url: viewModel.profile?.avatar ?? "", size: 72) { url in
                let updated: MasterProfile = try await APIClient.shared.request(.masterProfileUpdate(MasterProfileUpdateRequest(avatar: url)))
                viewModel.profile = updated
            }.disabled(viewModel.profile == nil)

            // 名字
            Text(L10n.lookup(viewModel.profile?.dharmaName ?? L10n.text("法师资料")))
                .font(.pageTitle)
                .foregroundStyle(.textPrimary)
                .padding(.top, AppSpacing.md)

            // 寺院 + 已认证 badge
            HStack(spacing: AppSpacing.sm) {
                Text(L10n.lookup(viewModel.profile?.manageBy == "platform" ? L10n.text("独立执业") : viewModel.profile?.templeId.isEmpty == false ? L10n.text("寺院纳管") : L10n.text("未关联寺院")))
                    .font(AppTypography.caption)
                    .foregroundStyle(.textSecondary)
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(AppTypography.micro)
                        .foregroundStyle(.accentDefault)
                    Text(L10n.lookup(viewModel.profile?.authStatusText ?? L10n.text("未认证")))
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
            Text(L10n.lookup(viewModel.profile?.position ?? ""))
                .font(AppTypography.caption)
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
            ForEach(menuItems.indices, id: \.self) { index in
                let item = menuItems[index]
                menuRow(item, isLast: index == menuItems.count - 1, index: index)
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

    private func menuRow(_ item: ProfileMenuItem, isLast: Bool, index: Int) -> some View {
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
                Text(L10n.lookup(item.label))
                    .font(AppTypography.body.weight(.medium))
                    .foregroundStyle(.textPrimary)

                Spacer()

                // 额外信息
                if let extra = item.extra {
                    Text(L10n.lookup(extra))
                        .font(AppTypography.caption)
                        .foregroundStyle(.textTertiary)
                        .padding(.trailing, AppSpacing.sm)
                }

                // 箭头
                Image(systemName: "chevron.right")
                    .font(AppTypography.caption.weight(.medium))
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
        .buttonStyle(CardPressButtonStyle())
    }

    // MARK: - 菜单导航目标

    @ViewBuilder
    private func menuDestination(for index: Int) -> some View {
        switch index {
        case 0:
            ProfileEditView(profile: viewModel.profile)
        case 1:
            ProfileEditView(profile: viewModel.profile)
        case 2:
            ServiceTagsView()
        case 3:
            PricingView()
        case 4:
            EarningsView()
        case 5:
            ReviewsView()
        case 6:
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
