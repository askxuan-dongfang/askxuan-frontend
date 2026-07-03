//
//  MasterProfileView.swift
//  DongFangApp
//
//  师傅主页：背景区 + 头像 + 法号 + 简介 + 5 Tab + 底部双按钮。
//

import SwiftUI

struct MasterProfileView: View {
    let masterId: String

    @StateObject private var viewModel = MasterProfileViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showBooking = false

    private let tabs = ["资质", "预约", "文创", "视频", "咨询"]

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                    infoSection
                    tabBar
                    tabContent
                    Spacer(minLength: 100)
                }
            }
            .ignoresSafeArea(edges: .top)

            // 底部固定操作栏
            bottomActionBar
        }
        .background(Color.bgPrimary)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if viewModel.master == nil {
                await viewModel.load(id: masterId)
            }
        }
        .sheet(isPresented: $showBooking) {
            if let master = viewModel.master {
                BookingView(master: master)
            }
        }
    }

    // MARK: - 背景区 + 头像
    private var heroSection: some View {
        ZStack(alignment: .top) {
            // 背景图
            Image("master-profile-bg")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 240)
                .clipped()
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.bgPrimary.opacity(0.2),
                            Color.bgPrimary.opacity(0.6),
                            Color.bgPrimary
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 240)
                )

            // 返回按钮
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.accentDefault)
                        .frame(width: 36, height: 36)
                        .background(Color.bgPrimary.opacity(0.6))
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.borderDefault, lineWidth: 1))
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, 56)

            // 头像 + 法号（居中偏下）
            VStack(spacing: 8) {
                Image(viewModel.master?.avatarAssetName ?? "master-avatar-zhihai")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.accentDefault, lineWidth: 2))
                    .padding(.top, 140)

                Text(viewModel.master?.dharmaName ?? "法师")
                    .font(.custom(AppFont.serif, size: 20).weight(.bold))
                    .foregroundStyle(Color.accentDefault)

                if let master = viewModel.master {
                    HStack(spacing: 6) {
                        Text(master.position)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.brandDefault)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.brandDefault.opacity(0.15))
                            .clipShape(Capsule())
                        Text(master.templeName)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }
        }
        .frame(height: 240)
    }

    // MARK: - 简介
    private var infoSection: some View {
        VStack(spacing: AppSpacing.md) {
            // 评分 + 在线状态 + 起步价
            HStack(spacing: AppSpacing.xl) {
                statItem(icon: "star.fill",
                         value: viewModel.master?.ratingText ?? "5.0",
                         label: "评分",
                         color: .accentDefault)
                statItem(icon: "person.badge.clock",
                         value: (viewModel.master?.isOnlineDisplay ?? true) ? "在线" : "离线",
                         label: "状态",
                         color: (viewModel.master?.isOnlineDisplay ?? true) ? .stateSuccess : .textTertiary)
                statItem(icon: "yensign.circle.fill",
                         value: viewModel.master?.startPriceText ?? "—",
                         label: "起步价",
                         color: .brandDefault)
            }
            .padding(.vertical, AppSpacing.md)

            // 擅长领域
            if let master = viewModel.master, !master.specialties.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("擅长领域")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.textTertiary)
                    FlowLayout(spacing: 8) {
                        ForEach(master.specialties, id: \.self) { specialty in
                            Text(specialty)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.accentDefault)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.accentDefault.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.sm)
            }
        }
    }

    private func statItem(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tab 切换栏
    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { index, title in
                    let isSelected = viewModel.selectedTab == index
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectedTab = index
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Text(title)
                                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? Color.brandDefault : Color.textTertiary)
                            Capsule()
                                .fill(isSelected ? Color.brandDefault : Color.clear)
                                .frame(width: 24, height: 3)
                        }
                        .frame(width: 70)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(Color.bgPrimary)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.borderDivider).frame(height: 1)
        }
        .padding(.top, AppSpacing.lg)
    }

    // MARK: - Tab 内容
    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.selectedTab {
        case 0:
            qualificationPanel
        case 1:
            bookingPanel
        case 2:
            wenchuangPanel
        case 3:
            videoPanel
        case 4:
            consultPanel
        default:
            EmptyView()
        }
    }

    /// 资质
    private var qualificationPanel: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 8) {
                Text("法师简介")
                    .font(.cardTitle)
                    .foregroundStyle(Color.textPrimary)
                Text("法师修行多年，深谙佛理，致力于弘法利生，广结善缘。擅长为信众提供禅修指导、祈福法事、开光加持等服务，深受信众敬仰。")
                    .font(.body)
                    .foregroundStyle(Color.textSecondary)
                    .lineSpacing(4)
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.bgSecondary)
            .cornerRadius(AppRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(Color.borderDefault, lineWidth: 1)
            )
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)

            VStack(alignment: .leading, spacing: 8) {
                Text("认证信息")
                    .font(.cardTitle)
                    .foregroundStyle(Color.textPrimary)
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color.stateSuccess)
                    Text(viewModel.master?.authStatus ?? "已认证")
                        .font(.body)
                        .foregroundStyle(Color.textPrimary)
                }
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.bgSecondary)
            .cornerRadius(AppRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(Color.borderDefault, lineWidth: 1)
            )
            .padding(.horizontal, AppSpacing.lg)
        }
    }

    /// 预约
    private var bookingPanel: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("可预约服务")
                .font(.cardTitle)
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)

            ForEach(ServiceType.allCases.filter { $0 != .diy }) { service in
                HStack(spacing: AppSpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .fill(Color.brandDefault.opacity(0.12))
                        Image(systemName: service.iconName)
                            .font(.system(size: 16))
                            .foregroundStyle(Color.brandDefault)
                    }
                    .frame(width: 40, height: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(service.rawValue)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                        Text("可预约")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textTertiary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textTertiary)
                }
                .padding(AppSpacing.md)
                .background(Color.bgSecondary)
                .cornerRadius(AppRadius.lg)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.lg)
                        .stroke(Color.borderDefault, lineWidth: 1)
                )
                .padding(.horizontal, AppSpacing.lg)
            }
        }
    }

    /// 文创
    private var wenchuangPanel: some View {
        VStack(spacing: AppSpacing.sm) {
            Text("敬请期待")
                .font(.caption)
                .foregroundStyle(Color.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.xl)
        }
    }

    /// 视频
    private var videoPanel: some View {
        VStack(spacing: AppSpacing.sm) {
            Text("敬请期待")
                .font(.caption)
                .foregroundStyle(Color.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.xl)
        }
    }

    /// 咨询
    private var consultPanel: some View {
        VStack(spacing: AppSpacing.md) {
            Text("在线咨询")
                .font(.cardTitle)
                .foregroundStyle(Color.textPrimary)
                .padding(.top, AppSpacing.md)
            Text("法师将为您解答佛学疑问、指引修行方向。")
                .font(.body)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 底部固定操作栏
    private var bottomActionBar: some View {
        HStack(spacing: AppSpacing.md) {
            DFSecondaryButton(title: "立即咨询") {}
            DFPrimaryButton(title: "预约服务") {
                showBooking = true
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
        .background(
            Color.bgPrimary.opacity(0.95)
                .background(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Rectangle().fill(Color.borderDivider).frame(height: 1)
        }
    }
}

/// 简单的流式布局（标签自动换行）
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var totalHeight: CGFloat = 0
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if lineWidth + size.width > maxWidth {
                totalHeight += lineHeight + spacing
                lineWidth = size.width
                lineHeight = size.height
            } else {
                lineWidth += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
        }
        totalHeight += lineHeight
        return CGSize(width: maxWidth == .infinity ? lineWidth : maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + maxWidth {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

#Preview {
    NavigationStack {
        MasterProfileView(masterId: "M001")
    }
    .preferredColorScheme(.dark)
}
