//
//  HomeView.swift
//  DongFangApp
//
//  首页（对齐原型 home.html）：
//  品牌名「问玄东方」+ 搜索 + Banner轮播 + 双入口 + 热门服务横滑 + 热门寺院 + 热门师傅。
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var currentBanner: Int = 0

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.lg) {
                bannerSection
                entryCardsSection
                hotServicesSection
                hotTemplesSection
                hotMastersSection
                Spacer(minLength: AppSpacing.navBottom + 16)
            }
            .padding(.top, AppSpacing.sm)
        }
        .background(Color.bgPrimary)
        .navigationBarHidden(true)
        .safeAreaInset(edge: .top) {
            headerSection
                .liquidGlassBackground(0.92)
        }
        .task {
            if viewModel.hotTemples.isEmpty {
                await viewModel.load()
            }
        }
        .refreshable { await viewModel.load() }
        .navigationDestination(for: Temple.self) { temple in
            TempleDetailView(templeId: temple.id, templeName: temple.name)
        }
        .navigationDestination(for: Master.self) { master in
            MasterProfileView(masterId: master.id)
        }
        .navigationDestination(for: HomeRoute.self) { route in
            switch route {
            case .templeList:  TempleListView()
            case .masterList:  MasterListView()
            case .service(let type):
                serviceDestination(for: type)
            case .diyBracelet:  DiyBraceletView()
            case .booking(let master):
                BookingView(master: master)
            }
        }
    }

    // MARK: - 顶部品牌 + 搜索（对齐原型 header：sticky + blur + 品牌24px serif）
    private var headerSection: some View {
        HStack(spacing: 12) {
            Text("问玄东方")
                .font(.custom(AppFont.serif[0], size: 24).weight(.semibold))
                .foregroundStyle(Color.accentDefault)

            Spacer()

            NavigationLink(value: HomeRoute.templeList) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.accentDefault)
                    .frame(width: 36, height: 36)
                    .background(Color.clear)
                    .overlay(Circle().stroke(Color.accentDefault, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.sm)
    }

    // MARK: - Banner 轮播（对齐原型：200px高 + 图片 + 左侧渐变遮罩 + 圆点指示器）
    private var bannerSection: some View {
        VStack(spacing: 10) {
            TabView(selection: $currentBanner) {
                ForEach(Array(viewModel.banners.enumerated()), id: \.element.id) { index, banner in
                    bannerSlide(banner)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 200)
            .cornerRadius(10)
            .padding(.horizontal, AppSpacing.lg)

            // 圆点指示器（对齐原型：6px圆点，active 18px长条 brand色）
            HStack(spacing: 6) {
                ForEach(0..<viewModel.banners.count, id: \.self) { index in
                    Capsule()
                        .fill(index == currentBanner ? Color.brandDefault : Color.textTertiary)
                        .frame(width: index == currentBanner ? 18 : 6, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: currentBanner)
                }
            }
        }
    }

    private func bannerSlide(_ banner: BannerItem) -> some View {
        ZStack(alignment: .leading) {
            RemoteImage(urlString: banner.imageURL, placeholderIcon: "photo")

            // 左侧渐变遮罩（对齐原型：从左 0.7 → 透明 60%）
            LinearGradient(
                colors: [
                    Color.bgPrimary.opacity(0.7),
                    Color.bgPrimary.opacity(0.3),
                    Color.clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(banner.title)
                    .font(.custom(AppFont.serif[0], size: 18).weight(.bold))
                    .foregroundStyle(Color.textPrimary)
                if let subtitle = banner.subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.accentDefault)
                }
            }
            .padding(.horizontal, 20)
        }
        .clipped()
    }

    // MARK: - 双入口卡片（对齐原型：120px高 + 图片背景 + 渐变遮罩 + 图标+文字居中）
    private var entryCardsSection: some View {
        HStack(spacing: AppSpacing.md) {
            NavigationLink(value: HomeRoute.templeList) {
                entryCard(icon: "building.2.fill", title: "找寺院", asset: ImageMapper.entryTemple)
            }
            .buttonStyle(CardPressButtonStyle())
            NavigationLink(value: HomeRoute.masterList) {
                entryCard(icon: "person.circle.fill", title: "找师傅", asset: ImageMapper.entryMaster)
            }
            .buttonStyle(CardPressButtonStyle())
        }
        .padding(.horizontal, AppSpacing.lg)
    }

    private func entryCard(icon: String, title: String, asset: String) -> some View {
        ZStack {
            RemoteImage(urlString: asset, placeholderIcon: "building.2")

            // 渐变遮罩（对齐原型：135deg 0.65 → 0.35）
            LinearGradient(
                colors: [
                    Color.bgPrimary.opacity(0.65),
                    Color.bgPrimary.opacity(0.35)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(Color.accentDefault)
                Text(title)
                    .font(.custom(AppFont.serif[0], size: 16).weight(.semibold))
                    .foregroundStyle(Color.accentDefault)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .cornerRadius(12)
        .contentShape(Rectangle())
    }

    // MARK: - 热门服务（对齐原型：横向滚动 + 60px宽 + 44px圆形图标）
    private var hotServicesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("热门服务")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                NavigationLink(value: HomeRoute.service(.blessing)) {
                    HStack(spacing: 2) {
                        Text("更多").font(.system(size: 13))
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(Color.accentDefault)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppSpacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.md) {
                    ForEach(viewModel.hotServices) { service in
                        NavigationLink(value: HomeRoute.service(service)) {
                            serviceItem(service)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
            }
        }
    }

    private func serviceItem(_ service: ServiceType) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.brandDefault.opacity(0.2),
                                Color.accentDefault.opacity(0.15)
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .overlay(Circle().stroke(Color.borderDefault, lineWidth: 1))
                Image(systemName: service.iconName)
                    .font(.system(size: 20))
                    .foregroundStyle(Color.accentDefault)
            }
            .frame(width: 44, height: 44)

            Text(service.rawValue)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.textPrimary)
        }
        .frame(width: 60)
    }

    // MARK: - 热门寺院（对齐原型：180x110图片 + 类型标签 + 名称+评分 + 地址 + 服务标签+服务数）
    private var hotTemplesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("热门寺院")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, AppSpacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.md) {
                    ForEach(viewModel.hotTemples) { temple in
                        NavigationLink(value: temple) { templeCard(temple) }
                            .buttonStyle(CardPressButtonStyle())
                    }
                    NavigationLink(value: HomeRoute.templeList) { moreCard(height: 200) }
                        .buttonStyle(.plain)
                }
                .padding(.horizontal, AppSpacing.lg)
            }
        }
    }

    private func templeCard(_ temple: Temple) -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                RemoteImage(urlString: temple.coverImage, placeholderIcon: "building.2")
                    .frame(width: 180, height: 110)
                    .clipped()
                Text(temple.type)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(templeTypeColor(temple.type).opacity(0.85))
                    .clipShape(Capsule())
                    .padding(8)
            }

            VStack(spacing: 4) {
                HStack {
                    Text(temple.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text("★ \(temple.ratingText)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.accentDefault)
                }
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textTertiary)
                    Text(temple.region)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textTertiary)
                    Spacer()
                }
                if !temple.serviceTagsText.isEmpty || temple.serviceCountText != nil {
                    HStack {
                        if !temple.serviceTagsText.isEmpty {
                            Text(temple.serviceTagsText)
                                .font(.system(size: 10))
                                .foregroundStyle(Color.textSecondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        if let countText = temple.serviceCountText {
                            Text(countText)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.brandDefault)
                        }
                    }
                    .padding(.top, 4)
                    .overlay(
                        Rectangle().fill(Color.borderDivider).frame(height: 1),
                        alignment: .top
                    )
                }
            }
            .padding(10)
        }
        .frame(width: 180)
        .background(Color.bgSecondary)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderDefault, lineWidth: 1))
    }

    /// 寺院类型标签颜色：道教用紫色（对齐原型 #9E8FB2），其他用 brand
    private func templeTypeColor(_ type: String) -> Color {
        if type.contains("道") {
            return Color(red: 158/255, green: 143/255, blue: 178/255)
        }
        return Color.brandDefault
    }

    // MARK: - 热门师傅（对齐原型：155px宽 + 56px头像 + 法名+宗派标签+寺院+修行年+咨询数+评分+价格）
    private var hotMastersSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("热门师傅")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, AppSpacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.md) {
                    ForEach(viewModel.hotMasters) { master in
                        NavigationLink(value: master) { masterCard(master) }
                            .buttonStyle(CardPressButtonStyle())
                    }
                    NavigationLink(value: HomeRoute.masterList) { moreCard(height: 220) }
                        .buttonStyle(.plain)
                }
                .padding(.horizontal, AppSpacing.lg)
            }
        }
    }

    private func masterCard(_ master: Master) -> some View {
        VStack(spacing: 4) {
            RemoteAvatar(urlString: master.avatar, size: 56)

            Text(master.dharmaName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)

            // 宗派标签 + 寺院
            HStack(spacing: 4) {
                if !master.sect.isEmpty {
                    Text(master.sect)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.accentDefault)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .overlay(Capsule().stroke(Color.accentDefault.opacity(0.25), lineWidth: 1))
                }
                Text(master.templeName)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(1)
            }

            // 修行年 + 咨询数
            HStack(spacing: 6) {
                if let years = master.yearsText {
                    Text(years)
                }
                if master.yearsText != nil && master.consultationText != nil {
                    Text("|").foregroundStyle(Color.accentDefault.opacity(0.2))
                }
                if let consult = master.consultationText {
                    Text(consult)
                }
            }
            .font(.system(size: 10))
            .foregroundStyle(Color.textSecondary)

            // 评分
            HStack(spacing: 2) {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.accentDefault)
                Text(master.ratingText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.accentDefault)
            }

            // 底部：专长 + 价格
            if !master.specialtiesText.isEmpty || master.startPriceText != nil {
                HStack {
                    if !master.specialtiesText.isEmpty {
                        Text(master.specialtiesText)
                            .font(.system(size: 10))
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    if let price = master.startPriceText {
                        Text(price)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.brandDefault)
                    }
                }
                .padding(.top, 4)
                .overlay(
                    Rectangle().fill(Color.borderDivider).frame(height: 1),
                    alignment: .top
                )
            }
        }
        .frame(width: 155)
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .background(Color.bgSecondary)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderDefault, lineWidth: 1))
    }

    private func moreCard(height: CGFloat) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "chevron.right")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.brandDefault)
            Text("查看更多")
                .font(.system(size: 12))
                .foregroundStyle(Color.brandDefault)
        }
        .frame(width: 80, height: height)
        .background(Color.bgSecondary)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderDefault, lineWidth: 1))
    }

    // MARK: - 服务路由
    @ViewBuilder
    private func serviceDestination(for type: ServiceType) -> some View {
        switch type {
        case .blessing:     ServiceBlessingView()
        case .consecration: ServiceConsecrationView()
        case .incense:      ServiceIncenseView()
        case .lamp:         ServiceLampView()
        case .rite:         ServiceRiteView()
        case .taisui:       ServiceTaisuiView()
        case .vow:          ServiceVowView()
        case .diy:          DiyBraceletView()
        }
    }
}

/// 首页导航路由
enum HomeRoute: Hashable {
    case templeList
    case masterList
    case service(ServiceType)
    case diyBracelet
    case booking(Master)
}

#Preview {
    NavigationStack { HomeView() }
}
