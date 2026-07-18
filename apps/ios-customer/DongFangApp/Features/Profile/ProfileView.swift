//
//  ProfileView.swift
//  DongFangApp
//
//  我的页面：对齐产品原型 profile.html 布局。
//  用户信息卡 + 统计行 + 订单中心 + 资产 + 服务列表 + 系统功能。
//  作为主 Tab 之一。所有展示数据来自 ProfileViewModel 的真实 API 结果，
//  字段缺失或 API 失败时显示占位（"—" / 暂无），不使用假数据。
//

import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject private var authStore: AuthStore

    // MARK: - 从 ViewModel 派生的真实数据（无假数据；字段缺失时显示 "—" 占位）

    /// 统计行：功德值 / 积分 / 优惠券
    /// 注：当前 UserProfile 模型未提供这些字段，故展示 "—" 占位，待后端补齐后接入
    private var stats: [(label: String, value: String)] {
        let merit = viewModel.profile?.meritValueText ?? "—"
        let points = viewModel.profile?.pointsText ?? "—"
        let coupons = "\(viewModel.availableCouponCount)"
        return [("功德值", merit), ("积分", points), ("优惠券", coupons)]
    }

    /// 订单中心入口：角标来自 viewModel.recentBookings 的真实状态计数
    private var orderEntries: [(icon: String, title: String, badge: String?)] {
        let pending = viewModel.pendingBookingCount
        let confirmed = viewModel.confirmedBookingCount
        return [
            ("doc.text", "服务订单", pending > 0 ? "\(pending)待确认" : nil),
            ("bag", "商城订单", nil),
            ("circle.grid.2x1", "DIY手串", nil),
            ("calendar", "预约记录", confirmed > 0 ? "\(confirmed)待进行" : nil)
        ]
    }

    /// 资产：功德金余额 / 优惠券 / 积分明细
    /// 注：UserProfile 模型暂无对应字段，数值显示 "—" 占位
    private var assets: [(label: String, value: String?, icon: String?)] {
        [
            ("功德金余额", viewModel.profile?.meritBalanceText ?? "—", nil),
            ("优惠券", "\(viewModel.availableCouponCount)", nil),
            ("积分明细", nil, "chart.line.uptrend.xyaxis")
        ]
    }

    /// 我的服务：收货地址行展示真实地址数量，其余为导航入口（无假数据）
    private var serviceItems: [(icon: String, title: String, trailing: String?)] {
        let addressTrailing: String? = viewModel.addressCount > 0
            ? "已存\(viewModel.addressCount)条"
            : nil
        return [
            ("heart", "我的收藏", nil),
            ("clock", "浏览记录", nil),
            ("star", "我的评价", nil),
            ("mappin.and.ellipse", "收货地址", addressTrailing),
            ("phone", "通话记录", nil),
            ("bell", "帮助与客服", nil)
        ]
    }

    /// 系统功能：纯导航入口（无数据）
    private let systemItems: [(icon: String, title: String)] = [
        ("person", "个人资料"),
        ("bell", "消息通知"),
        ("lock.shield", "账号安全"),
        ("info.circle", "关于问玄东方")
    ]

    var body: some View {
        Group {
            if authStore.isLoggedIn {
                loggedInContent
            } else {
                guestContent
            }
        }
        .background(Color.bgPrimary)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - 未登录：登录引导
    private var guestContent: some View {
        VStack(spacing: 32) {
            Spacer()

            // 品牌 Logo
            VStack(spacing: 16) {
                Image("brand-logo")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 88, height: 88)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.accentDefault.opacity(0.35), lineWidth: 1.5))

                Text("问玄东方")
                    .font(.custom(AppFont.serif[0], size: 24).weight(.semibold))
                    .foregroundStyle(Color.accentDefault)

                Text("登录后即可管理您的预约、订单和地址")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textTertiary)
            }

            VStack(spacing: 12) {
                NavigationLink(value: AuthRoute.login) {
                    Text("立即登录 / 注册")
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

                Text("未注册手机号将自动创建账号")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, 40)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 已登录：完整个人中心
    private var loggedInContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                if let errorMessage = viewModel.errorMessage, !viewModel.hasAnyData {
                    errorHintView(errorMessage)
                }
                userInfoSection
                orderCenterSection
                assetsSection
                servicesSection
                systemSection
                Color.clear.frame(height: AppSpacing.xl)
            }
            .padding(.bottom, AppSpacing.navBottom)
        }
        .softScrollEdge(.bottom)
        .task {
            if viewModel.profile == nil { await viewModel.load() }
        }
        .refreshable { await viewModel.load() }
    }

    /// 数据加载失败且无任何数据时的错误提示
    private func errorHintView(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.brandDefault)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(Color.textSecondary)
            Spacer()
            Button {
                Task { await viewModel.load() }
            } label: {
                Text("重试")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.brandDefault)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
        .background(Color.bgSecondary)
    }

    // MARK: - Section 1: 用户信息卡 + 统计行
    private var userInfoSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                RemoteAvatar(urlString: viewModel.avatarURL, size: 56)
                    .overlay(Circle().stroke(Color.accentDefault, lineWidth: 2))

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.displayName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                    Text("ID: \(viewModel.maskedMobile)")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.top, AppSpacing.xl)
            .padding(.bottom, AppSpacing.lg)

            // 统计行
            HStack(spacing: 0) {
                ForEach(Array(stats.enumerated()), id: \.offset) { index, item in
                    VStack(spacing: 2) {
                        Text(item.value)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.accentDefault)
                            .monospacedDigit()
                        Text(item.label)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textTertiary)
                    }
                    .frame(maxWidth: .infinity)

                    if index < stats.count - 1 {
                        Rectangle()
                            .fill(Color.borderDivider)
                            .frame(width: 1, height: 28)
                    }
                }
            }
            .padding(.vertical, 14)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.borderDivider).frame(height: 1)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.borderDivider).frame(height: 1)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
    }

    // MARK: - Section 2: 订单中心
    private var orderCenterSection: some View {
        VStack(spacing: 14) {
            HStack {
                NavigationLink {
                    OrderListView()
                } label: {
                    Text("订单中心")
                        .font(.cardTitle)
                        .foregroundStyle(Color.textPrimary)
                }
                Spacer()
                NavigationLink {
                    OrderListView()
                } label: {
                    HStack(spacing: 2) {
                        Text("查看全部")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textTertiary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }

            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(orderEntries.enumerated()), id: \.offset) { _, entry in
                    NavigationLink {
                        OrderListView(initialStatus: orderTab(for: entry.title))
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.bgTertiary)
                                    .frame(width: 40, height: 40)
                                Image(systemName: entry.icon)
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.textTertiary)
                            }
                            .overlay(alignment: .topTrailing) {
                                if let badge = entry.badge {
                                    Text(badge)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(Color.white)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Color.brandDefault)
                                        .clipShape(Capsule())
                                        .offset(x: 8, y: -4)
                                }
                            }
                            Text(entry.title)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 8)
            .background(Color.bgSecondary)
            .cornerRadius(AppRadius.lg)
            .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.xl)
    }

    // MARK: - Section 3: 资产
    private var assetsSection: some View {
        HStack(spacing: 10) {
            ForEach(Array(assets.enumerated()), id: \.offset) { _, asset in
                NavigationLink {
                    assetDestination(asset.label)
                } label: {
                    VStack(spacing: 6) {
                        if let icon = asset.icon {
                            Image(systemName: icon)
                                .font(.system(size: 20))
                                .foregroundStyle(Color.accentDefault)
                        } else if let value = asset.value {
                            Text(value)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Color.accentDefault)
                                .monospacedDigit()
                        }
                        Text(asset.label)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.bgSecondary)
                    .cornerRadius(AppRadius.lg)
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.xl)
    }

    // MARK: - Section 4: 我的服务
    private var servicesSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(serviceItems.enumerated()), id: \.offset) { index, item in
                if index > 0 { rowDivider }
                NavigationLink {
                    serviceDestination(item.title)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: item.icon)
                            .font(.system(size: 18))
                            .foregroundStyle(Color.textTertiary)
                            .frame(width: 24)
                        Text(item.title)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        if let trailing = item.trailing {
                            Text(trailing)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.textTertiary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textTertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.bgSecondary)
        .cornerRadius(AppRadius.lg)
        .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.xl)
    }

    // MARK: - Section 5: 系统功能
    private var systemSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(systemItems.enumerated()), id: \.offset) { index, item in
                if index > 0 { rowDivider }
                NavigationLink {
                    systemDestination(item.title)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: item.icon)
                            .font(.system(size: 18))
                            .foregroundStyle(Color.textTertiary)
                            .frame(width: 24)
                        Text(item.title)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textTertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            rowDivider

            // 退出登录
            Button {
                viewModel.logout()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.right.square")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.brandDefault)
                        .frame(width: 24)
                    Text("退出登录")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.brandDefault)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
        }
        .background(Color.bgSecondary)
        .cornerRadius(AppRadius.lg)
        .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.xl)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.borderDivider)
            .frame(height: 1)
            .padding(.leading, 52)
    }

    private func orderTab(for title: String) -> String {
        switch title {
        case "商城订单": return "shop"
        case "DIY手串": return "diy"
        default: return "booking"
        }
    }

    @ViewBuilder
    private func assetDestination(_ title: String) -> some View {
        switch title {
        case "优惠券": CouponView()
        case "积分明细": PointsView()
        default: WalletView()
        }
    }

    @ViewBuilder
    private func serviceDestination(_ title: String) -> some View {
        switch title {
        case "我的收藏": FavoritesView()
        case "浏览记录": HistoryView()
        case "我的评价": ReviewListView()
        case "收货地址": AddressListView()
        case "通话记录": CallHistoryView()
        default: HelpView()
        }
    }

    @ViewBuilder
    private func systemDestination(_ title: String) -> some View {
        switch title {
        case "个人资料": ProfileEditView()
        case "消息通知": NotificationSettingsView()
        case "账号安全": SecurityView()
        default: AboutView()
        }
    }
}

#Preview {
    NavigationStack { ProfileView() }
        .preferredColorScheme(.dark)
}
