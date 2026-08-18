//
//  ServiceBlessingView.swift
//  DongFangApp
//
//  祈福服务页：服务介绍 + 套餐选择 + 法师列表 + 底部预约入口。
//  本文件同时定义共享的 ServiceContainerView，供其余 6 个服务页复用。
//

import SwiftUI

/// 祈福服务页（使用共享容器）
struct ServiceBlessingView: View {
    var body: some View {
        ServiceContainerView(serviceType: .blessing)
    }
}

// MARK: - 服务详情共享容器
/// 13 种平台标准服务共享的服务详情布局。
/// 从寺院详情进入时携带寺院上下文：本寺价格 + 本寺法师可选指定 + 立即预约（全寺执行）。
struct ServiceContainerView: View {
    let serviceType: ServiceType
    let templeId: String?
    let templeName: String?

    @StateObject private var viewModel: ServiceViewModel
    @Environment(\.dismiss) private var dismiss
    /// 立即预约：程序化导航（避免 Button 嵌套在 NavigationLink label 内吞掉点击）
    @State private var showBooking = false

    init(serviceType: ServiceType, templeId: String? = nil, templeName: String? = nil) {
        self.serviceType = serviceType
        self.templeId = templeId
        self.templeName = templeName
        _viewModel = StateObject(wrappedValue: ServiceViewModel(serviceType: serviceType, templeId: templeId, templeName: templeName))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                    introSection
                    packagesSection
                    designatedMasterSection
                    noticeSection
                    Spacer(minLength: 100)
                }
            }
            .ignoresSafeArea(edges: .top)

            bottomActionBar
        }
        .background(Color.bgPrimary)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if viewModel.blessingServices.isEmpty { await viewModel.load() }
        }
        .refreshable { await viewModel.load() }
        .navigationDestination(for: HomeRoute.self) { route in
            switch route {
            case .booking(let master): BookingView(master: master)
            default: EmptyView()
            }
        }
        .navigationDestination(isPresented: $showBooking) {
            BookingView(master: viewModel.selectedTempleMaster,
                        templeId: viewModel.resolvedTempleId ?? "",
                        templeName: viewModel.resolvedTempleName ?? "",
                        serviceType: serviceType)
        }
    }

    // MARK: - Hero
    private var heroSection: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [Color.brandDark.opacity(0.7), Color.bgPrimary],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 220)

            HStack {
                DFBackButton(style: .circle)
                Spacer()
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, 56)

            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.brandDefault.opacity(0.3), Color.accentDefault.opacity(0.2)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .overlay(Circle().stroke(Color.borderDefault, lineWidth: 1))
                    Image(systemName: serviceType.iconName)
                        .font(.system(size: 40))
                        .foregroundStyle(Color.accentDefault)
                }
                .frame(width: 80, height: 80)
                .padding(.top, 80)

                Text(serviceType.rawValue)
                    .font(.custom(AppFont.serif[0], size: 22).weight(.bold))
                    .foregroundStyle(Color.accentDefault)
                Text(serviceType.subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .frame(height: 220)
    }

    // MARK: - 服务介绍
    private var introSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "text.book.closed")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.accentDefault)
                Text("服务介绍")
                    .font(.cardTitle)
                    .foregroundStyle(Color.textPrimary)
            }

            Text(serviceType.detail)
                .font(.body)
                .foregroundStyle(Color.textSecondary)
                .lineSpacing(5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.lg)
        .background(Color.bgSecondary)
        .cornerRadius(AppRadius.lg)
        .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.lg)
    }

    // MARK: - 套餐列表
    private var packagesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("服务套餐")
                    .font(.cardTitle)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Text(viewModel.priceRangeText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.brandDefault)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.lg)

            if viewModel.blessingServices.isEmpty {
                Text("暂无可选套餐，请稍后再试")
                    .font(.caption)
                    .foregroundStyle(Color.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.lg)
            } else {
                ForEach(viewModel.blessingServices) { service in
                    packageRow(service)
                }
            }
        }
    }

    private func packageRow(_ service: BlessingService) -> some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .fill(Color.brandDefault.opacity(0.12))
                Image(systemName: serviceType.iconName)
                    .font(.system(size: 18))
                    .foregroundStyle(Color.brandDefault)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(service.serviceName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                if !service.description.isEmpty {
                    Text(service.description)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textTertiary)
                        .lineLimit(2)
                }
                HStack(spacing: 6) {
                    if !service.templeName.isEmpty {
                        Text(service.templeName)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.textTertiary)
                    }
                    if !service.masterName.isEmpty {
                        Text("· \(service.masterName)")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }

            Spacer()

            Text(service.priceText)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.brandDefault)
        }
        .padding(AppSpacing.md)
        .background(Color.bgSecondary)
        .cornerRadius(AppRadius.lg)
        .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
        .padding(.horizontal, AppSpacing.lg)
    }

    // MARK: - 指定法师（可选，仅本寺法师）
    /// 双轨制：寺院服务默认全寺执行；如本寺有可按该服务执行的大师，可指定其一（附加分流）。
    /// 仅展示本寺法师（templeId 过滤），不推荐跨寺院法师。
    private var designatedMasterSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("指定法师（可选）")
                    .font(.cardTitle)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Text("不指定则为全寺执行")
                    .font(.caption)
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.lg)

            if viewModel.masters.isEmpty {
                Text(viewModel.templeId == nil ? "暂无可指定法师" : "本寺暂无可执行该服务的法师，默认全寺执行")
                    .font(.caption)
                    .foregroundStyle(Color.textTertiary)
                    .padding(.horizontal, AppSpacing.lg)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.md) {
                        masterOption(nil)
                        ForEach(viewModel.masters) { master in
                            masterOption(master)
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                }
            }
        }
    }

    private func masterOption(_ master: Master?) -> some View {
        let isSelected = (master == nil && viewModel.selectedTempleMasterId == nil) || (master != nil && viewModel.selectedTempleMasterId == master?.id)
        return Button {
            viewModel.selectedTempleMasterId = master?.id
        } label: {
            VStack(spacing: 6) {
                if let master {
                    ZStack {
                        RemoteAvatar(urlString: master.avatar, size: 52)
                        if master.isOnlineDisplay {
                            Circle()
                                .fill(Color.stateSuccess)
                                .frame(width: 10, height: 10)
                                .overlay(Circle().stroke(Color.bgSecondary, lineWidth: 2))
                                .offset(x: 19, y: 19)
                        }
                    }
                    Text(master.dharmaName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                    Text("可指定执行")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.textTertiary)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 26)
                            .fill(Color.bgTertiary)
                            .frame(width: 52, height: 52)
                        Image(systemName: "building.columns")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.textSecondary)
                    }
                    Text("全寺执行")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Text("不指定法师")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.textTertiary)
                }
            }
            .frame(width: 88)
            .padding(.vertical, AppSpacing.sm)
            .background(isSelected ? Color.brandDefault.opacity(0.12) : Color.bgSecondary)
            .cornerRadius(AppRadius.lg)
            .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(isSelected ? Color.brandDefault : Color.borderDefault, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 须知
    private var noticeSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.stateWarning)
                Text("服务须知")
                    .font(.cardTitle)
                    .foregroundStyle(Color.textPrimary)
            }

            VStack(alignment: .leading, spacing: 6) {
                noticeItem("线上预约后，法师将在约定时间于寺院内代为举行仪式。")
                noticeItem("仪式完成后，可将功德回向给指定对象，请在备注中注明。")
                noticeItem("如需取消或改期，请提前 24 小时联系客服。")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.lg)
        .background(Color.bgSecondary)
        .cornerRadius(AppRadius.lg)
        .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.lg)
    }

    private func noticeItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("·")
                .font(.system(size: 12))
                .foregroundStyle(Color.accentDefault)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)
                .lineSpacing(3)
        }
    }

    // MARK: - 底部操作栏
    /// 立即预约：直接进入预约下单（可指定法师或不指定=全寺执行）
    private var bottomActionBar: some View {
        HStack(spacing: AppSpacing.md) {
            DFPrimaryButton(title: "立即预约", icon: "calendar.badge.plus") {
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
        .overlay(alignment: .top) { Rectangle().fill(Color.borderDivider).frame(height: 1) }
    }
}

#Preview {
    NavigationStack { ServiceBlessingView() }
        .preferredColorScheme(.dark)
}
