//
//  TempleDetailView.swift
//  DongFangApp
//
//  寺院详情页：Hero 大图 + 信息栏 + 4 Tab 切换 + 底部预约按钮。
//

import SwiftUI

struct TempleDetailView: View {
    let templeId: String
    let templeName: String

    @StateObject private var viewModel = TempleDetailViewModel()
    @State private var isFavorited: Bool = false
    @Environment(\.dismiss) private var dismiss

    private let tabs = ["基础信息", "公共服务", "大师团队", "文创"]

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                    infoBar
                    tabBar
                    tabContent
                    Spacer(minLength: 100)
                }
            }
            .ignoresSafeArea(edges: .top)

            bottomActionBar
        }
        .background(Color.bgPrimary)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if viewModel.temple == nil { await viewModel.load(id: templeId) }
        }
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
            RemoteImage(urlString: viewModel.temple?.coverImage, placeholderIcon: "building.2.fill")
                .frame(height: 220)
                .overlay(
                    LinearGradient(colors: [.clear, Color.bgPrimary],
                                   startPoint: .center, endPoint: .bottom)
                        .frame(height: 220)
                )

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

                Button {
                    isFavorited.toggle()
                } label: {
                    Image(systemName: isFavorited ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isFavorited ? Color.brandDefault : Color.accentDefault)
                        .frame(width: 36, height: 36)
                        .background(Color.bgPrimary.opacity(0.6))
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.borderDefault, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, 56)
        }
        .frame(height: 220)
    }

    // MARK: - 信息栏
    private var infoBar: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(viewModel.temple?.name ?? templeName)
                .font(.custom(AppFont.serif[0], size: 22).weight(.bold))
                .foregroundStyle(Color.accentDefault)

            HStack(spacing: AppSpacing.sm) {
                Text(viewModel.temple?.region ?? "")
                    .font(.caption)
                    .foregroundStyle(Color.textTertiary)
                Text("·").font(.caption).foregroundStyle(Color.textTertiary)
                Text(viewModel.temple?.sect ?? "")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.brandDefault)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Color.brandDefault.opacity(0.15))
                    .clipShape(Capsule())

                Spacer()

                Text("★ \(viewModel.temple?.ratingText ?? "5.0")")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.accentDefault)
            }

            if let desc = viewModel.temple?.description {
                Text(desc)
                    .font(.body)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(3)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.md)
    }

    // MARK: - Tab
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, title in
                let isSelected = viewModel.selectedTab == index
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { viewModel.selectedTab = index }
                } label: {
                    VStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? Color.brandDefault : Color.textTertiary)
                        Capsule()
                            .fill(isSelected ? Color.brandDefault : Color.clear)
                            .frame(width: 24, height: 3)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.bgPrimary)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.borderDivider).frame(height: 1) }
        .padding(.top, AppSpacing.lg)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.selectedTab {
        case 0: basicInfoPanel
        case 1: servicesPanel
        case 2: mastersPanel
        case 3: productsPanel
        default: EmptyView()
        }
    }

    private var basicInfoPanel: some View {
        VStack(spacing: 0) {
            infoRow(label: "寺院名称", value: viewModel.temple?.name ?? templeName)
            infoRow(label: "所属地区", value: viewModel.temple?.region ?? "—")
            infoRow(label: "宗教类型", value: viewModel.temple?.type ?? "—")
            infoRow(label: "所属教派", value: viewModel.temple?.sect ?? "—")
            infoRow(label: "详细地址", value: viewModel.temple?.address ?? "—")
            infoRow(label: "运营状态", value: viewModel.temple?.status ?? "正常", isLast: true)
        }
    }

    private func infoRow(label: String, value: String, isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                Text(label).font(.system(size: 13)).foregroundStyle(Color.textTertiary)
                Spacer()
                Text(value)
                    .font(.body)
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 220, alignment: .trailing)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, 14)

            if !isLast {
                Rectangle().fill(Color.borderDivider).frame(height: 1).padding(.leading, AppSpacing.lg)
            }
        }
        .background(Color.bgSecondary)
        .cornerRadius(AppRadius.md)
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.md)
    }

    private var servicesPanel: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("寺院公共服务")
                .font(.cardTitle)
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.md), count: 2),
                      spacing: AppSpacing.md) {
                ForEach(ServiceType.allCases.filter { $0 != .diy }) { service in
                    serviceGridItem(service)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
        }
    }

    private func serviceGridItem(_ service: ServiceType) -> some View {
        NavigationLink(value: HomeRoute.service(service)) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .fill(Color.brandDefault.opacity(0.12))
                    Image(systemName: service.iconName)
                        .font(.system(size: 18))
                        .foregroundStyle(Color.brandDefault)
                }
                .frame(width: 36, height: 36)

                Text(service.rawValue)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text("立即预约")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.brandDefault)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.lg)
            .background(Color.bgSecondary)
            .cornerRadius(AppRadius.md)
            .overlay(RoundedRectangle(cornerRadius: AppRadius.md).stroke(Color.borderDefault, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var mastersPanel: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("驻寺大师")
                .font(.cardTitle)
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.md) {
                    ForEach(viewModel.masters.isEmpty ? Array(Master.mockData.prefix(4)) : Array(viewModel.masters.prefix(4))) { master in
                        NavigationLink(value: master) {
                            VStack(spacing: 6) {
                                RemoteAvatar(urlString: master.avatar, size: 64)
                                Text(master.dharmaName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.textPrimary)
                                    .lineLimit(1)
                                Text(master.position)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.brandDefault)
                                    .padding(.horizontal, 8).padding(.vertical, 2)
                                    .background(Color.brandDefault.opacity(0.15))
                                    .clipShape(Capsule())
                                Text(master.specialtiesText)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.textTertiary)
                                    .lineLimit(1)
                            }
                            .frame(width: 110)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
            }
        }
    }

    private var productsPanel: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("文创法物")
                .font(.cardTitle)
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)

            Text("敬请期待")
                .font(.caption)
                .foregroundStyle(Color.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.xl)
        }
    }

    // MARK: - 底部操作栏
    private var bottomActionBar: some View {
        HStack(spacing: AppSpacing.md) {
            if let master = viewModel.masters.first {
                NavigationLink(value: HomeRoute.booking(master)) {
                    DFPrimaryButton(title: "预约服务", icon: "calendar.badge.plus") {}
                }
                .buttonStyle(.plain)
            } else {
                DFPrimaryButton(title: "预约服务", icon: "calendar.badge.plus") {}
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
    NavigationStack { TempleDetailView(templeId: "T001", templeName: "灵隐寺") }
        .preferredColorScheme(.dark)
}
