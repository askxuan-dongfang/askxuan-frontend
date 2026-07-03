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
/// 7 种法事/供养服务（祈福/开光/敬香/点灯/法事/太岁/许愿）共享的服务详情布局。
struct ServiceContainerView: View {
    let serviceType: ServiceType

    @StateObject private var viewModel: ServiceViewModel
    @Environment(\.dismiss) private var dismiss

    init(serviceType: ServiceType) {
        self.serviceType = serviceType
        _viewModel = StateObject(wrappedValue: ServiceViewModel(serviceType: serviceType))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                    introSection
                    packagesSection
                    mastersSection
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
        .navigationDestination(for: Master.self) { master in
            MasterProfileView(masterId: master.id)
        }
        .navigationDestination(for: HomeRoute.self) { route in
            switch route {
            case .booking(let master): BookingView(master: master)
            default: EmptyView()
            }
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
                Button { dismiss() } label: {
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

    // MARK: - 法师列表
    private var mastersSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("推荐法师")
                    .font(.cardTitle)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.md) {
                    ForEach(viewModel.masters) { master in
                        NavigationLink(value: master) { masterCard(master) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
            }
        }
    }

    private func masterCard(_ master: Master) -> some View {
        VStack(spacing: 6) {
            ZStack {
                RemoteAvatar(urlString: master.avatar, size: 60)
                if master.isOnlineDisplay {
                    Circle()
                        .fill(Color.stateSuccess)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.bgSecondary, lineWidth: 2))
                        .offset(x: 22, y: 22)
                }
            }
            Text(master.dharmaName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
            Text(master.templeName)
                .font(.system(size: 10))
                .foregroundStyle(Color.textTertiary)
                .lineLimit(1)
            HStack(spacing: 2) {
                Image(systemName: "star.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.accentDefault)
                Text(master.ratingText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.accentDefault)
            }
        }
        .frame(width: 88)
        .padding(.vertical, AppSpacing.sm)
        .background(Color.bgSecondary)
        .cornerRadius(AppRadius.lg)
        .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
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
    private var bottomActionBar: some View {
        HStack(spacing: AppSpacing.md) {
            if let master = viewModel.masters.first {
                NavigationLink(value: HomeRoute.booking(master)) {
                    DFPrimaryButton(title: "立即预约", icon: "calendar.badge.plus") {}
                }
                .buttonStyle(.plain)
            } else {
                DFPrimaryButton(title: "立即预约", icon: "calendar.badge.plus") {}
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
