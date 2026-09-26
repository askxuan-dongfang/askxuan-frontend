//
//  ProfileView.swift
//  DongFangApp
//
//  我的页面：个人资料、业务记录与设置入口。
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
        let points = viewModel.pointsBalance.map { String($0) } ?? "—"
        let coupons = viewModel.couponsLoaded ? "\(viewModel.availableCouponCount)" : "—"
        return [("功德值", merit), ("积分", points), ("优惠券", coupons)]
    }

    /// 订单中心入口：角标来自 viewModel.recentBookings 的真实状态计数
    private var orderEntries: [(icon: String, title: String, badge: String?)] {
        let pending = viewModel.pendingBookingCount
        return [
            ("doc.text", "服务订单", pending > 0 ? "\(pending)待确认" : nil),
            ("bag", "商城订单", nil),
            ("circle.grid.2x1", "DIY手串", nil),
            ("bell", "消息", nil)
        ]
    }

    /// 我的服务：收货地址行展示真实地址数量，其余为导航入口（无假数据）
    private var serviceItems: [(icon: String, title: String, trailing: String?)] {
        let addressTrailing: String? = viewModel.addressCount > 0
            ? "已存\(viewModel.addressCount)条"
            : nil
        return [
            ("heart", "我的收藏", nil),
            ("bell", "消息", nil),
            ("star", "我的评价", nil),
            ("mappin.and.ellipse", "收货地址", addressTrailing),
            ("bell", "帮助与客服", nil)
        ]
    }

    /// 系统功能：纯导航入口（无数据）
    private let systemItems: [(icon: String, title: String)] = [
        ("person", "个人资料"),
        ("bell", "消息通知"),
        ("circle.lefthalf.filled", "外观"),
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
        .onChange(of: authStore.isLoggedIn) { _, isLoggedIn in
            if !isLoggedIn {
                viewModel.reset()
            }
        }
    }

    // MARK: - 未登录：登录引导
    private var guestContent: some View {
        VStack(spacing: 32) {
            Spacer()

            // 品牌 Logo
            VStack(spacing: 16) {
                Image("brand-logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 104, height: 104)
                    .accessibilityHidden(true)

                Text("问玄东方")
                    .font(AppTypography.title(24))
                    .foregroundStyle(Color.accentDefault)

                Text("登录后即可管理您的预约、订单和地址")
                    .font(AppTypography.body)
                    .foregroundStyle(Color.textTertiary)
            }

            VStack(spacing: 12) {
                NavigationLink(value: AuthRoute.login) {
                    Text("立即登录 / 注册")
                        .font(AppTypography.reading.weight(.semibold))
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

                NavigationLink { AppearanceSettingsView() } label: {
                    Label("外观", systemImage: "circle.lefthalf.filled")
                        .font(AppTypography.body)
                        .foregroundStyle(Color.accentDefault)
                        .padding(.vertical, 8)
                }

                Text("新用户可通过邮箱验证创建账户")
                    .font(AppTypography.caption)
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
                Text("功德值用于记录个人成长，不用于支付或兑换；成长记录开放后展示。")
                    .font(AppTypography.caption)
                    .foregroundStyle(Color.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, 10)
                NavigationLink { WalletView().id(authStore.sessionID) } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "wallet.bifold").font(.title2).foregroundStyle(Color.accentDefault)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("我的钱包").font(AppTypography.body).foregroundStyle(Color.textPrimary)
                            Text("消费账单 · 退款进度").font(AppTypography.caption).foregroundStyle(Color.textSecondary)
                        }
                        Spacer(); Image(systemName: "chevron.right").foregroundStyle(Color.textTertiary)
                    }.padding(18).background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 16))
                }.padding(.horizontal, AppSpacing.lg).padding(.top, 16)
                JourneyEntryView().padding(.horizontal, AppSpacing.lg).padding(.top, 16)
                orderCenterSection
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
                .font(AppTypography.supporting)
                .foregroundStyle(Color.textSecondary)
            Spacer()
            Button {
                Task { await viewModel.load() }
            } label: {
                Text("重试")
                    .font(AppTypography.supporting.weight(.medium))
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
                    Text("我的账户").font(AppTypography.micro).foregroundStyle(Color.textTertiary)
                    Text(viewModel.displayName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Text(viewModel.maskedMobile == "—" ? "用户 ID: " + authStore.userId : viewModel.maskedMobile)
                        .font(AppTypography.supporting)
                        .foregroundStyle(Color.textTertiary)
                }

                Spacer()

                NavigationLink { ProfileEditView() } label: {
                    HStack(spacing: 3) { Text("编辑资料"); Image(systemName: "chevron.right") }
                        .font(AppTypography.caption).foregroundStyle(Color.accentDefault).frame(minHeight: 44)
                }.buttonStyle(CardPressButtonStyle())
            }
            .padding(.top, 18)
            .padding(.bottom, AppSpacing.lg)

            // 统计行
            HStack(spacing: 0) {
                ForEach(Array(stats.enumerated()), id: \.offset) { index, item in
                    NavigationLink {
                        if item.label == "优惠券" { CouponView() } else { PointsView() }
                    } label: {
                    VStack(spacing: 2) {
                        Text(item.value)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.accentDefault)
                            .monospacedDigit()
                        Text(item.label).font(AppTypography.caption).foregroundStyle(Color.textSecondary)
                        Text(item.label == "功德值" ? "成长记录待开放" : item.label == "积分" ? "查看积分明细" : "查看可用优惠")
                            .font(.system(size: 10)).foregroundStyle(Color.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    }
                    .disabled(item.label == "功德值")

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
        .padding(.horizontal, 16)
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.borderDefault, lineWidth: 1))
        .padding(.horizontal, AppSpacing.lg).padding(.top, 16)
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
                            .font(AppTypography.supporting)
                            .foregroundStyle(Color.textTertiary)
                        Image(systemName: "chevron.right")
                            .font(AppTypography.caption)
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }

            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(orderEntries.enumerated()), id: \.offset) { _, entry in
                    NavigationLink {
                        if entry.title == "消息" { NativeMessageCenterView() } else { OrderListView(initialStatus: orderTab(for: entry.title)) }
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
                                        .font(AppTypography.micro.weight(.medium))
                                        .foregroundStyle(Color.white)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Color.brandDefault)
                                        .clipShape(Capsule())
                                        .offset(x: 8, y: -4)
                                }
                            }
                            Text(entry.title)
                                .font(AppTypography.caption)
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
        .padding(.top, 20)
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
                            .font(AppTypography.body)
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        if let trailing = item.trailing {
                            Text(trailing)
                                .font(AppTypography.supporting)
                                .foregroundStyle(Color.textTertiary)
                        }
                        Image(systemName: "chevron.right")
                            .font(AppTypography.body)
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
        .padding(.top, 20)
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
                            .font(AppTypography.body)
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(AppTypography.body)
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
                        .font(AppTypography.body)
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
        .padding(.top, 20)
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
    private func serviceDestination(_ title: String) -> some View {
        switch title {
        case "我的收藏": FavoritesView()
        case "消息": NativeMessageCenterView()
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
        case "外观": AppearanceSettingsView()
        case "账号安全": SecurityView()
        default: AboutView()
        }
    }
}

#Preview {
    NavigationStack { ProfileView() }
        .preferredColorScheme(.dark)
}
