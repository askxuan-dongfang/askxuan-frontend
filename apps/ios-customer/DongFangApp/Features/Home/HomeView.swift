//
//  HomeView.swift
//  DongFangApp
//
//  首页（对齐原型 home.html）：
//  品牌名「问玄东方」+ 搜索 + Banner轮播 + 双入口 + 信仰/意图入口 + 热门寺院 + 热门师傅。
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject private var authStore: AuthStore
    @State private var currentBanner: Int = 0

    var body: some View {
        GeometryReader { geometry in
            let viewportWidth = geometry.size.width

            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {
                    bannerSection
                    entryCardsSection
                    beliefSection
                    intentionSection
                    hotTemplesSection
                    hotMastersSection
                    Color.clear.frame(height: AppSpacing.navBottom + 32)
                }
                .padding(.top, AppSpacing.sm)
                .frame(width: viewportWidth, alignment: .top)
            }
            .scrollClipDisabled(false)
            .softScrollEdge(.bottom)
            .background(Color.bgPrimary)
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarHidden(true)
            .navigationBarBackButtonHidden(true)
            .safeAreaInset(edge: .top) {
                headerSection
                    .frame(width: viewportWidth)
                    .liquidGlassBackground(0.92)
            }
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
                // 服务详情页需要登录
                if authStore.isLoggedIn {
                    serviceDestination(for: type)
                } else {
                    LoginRequiredView(
                        icon: "sparkles",
                        title: "登录后使用此服务",
                        subtitle: "祈福 / 供灯 / 上香 / 超度 / 开光 / 化太岁",
                        isPresented: .constant(false)
                    )
                }
            case .diyBracelet:
                // DIY 手串定制需要登录
                if authStore.isLoggedIn {
                    DiyBraceletView()
                } else {
                    LoginRequiredView(
                        icon: "hand.point.up.left.fill",
                        title: "登录后定制手串",
                        subtitle: "选珠搭配，法师开光",
                        isPresented: .constant(false)
                    )
                }
            case .booking(let master):
                // 预约法师需要登录
                if authStore.isLoggedIn {
                    BookingView(master: master)
                } else {
                    LoginRequiredView(
                        icon: "calendar.badge.plus",
                        title: "登录后预约法师",
                        subtitle: "在线预约，法师确认",
                        isPresented: .constant(false)
                    )
                }
            case .belief(let entry):
                TempleListView(initialSect: entry.sect)
            case .intention(let entry):
                if authStore.isLoggedIn {
                    serviceDestination(for: entry.service)
                } else {
                    LoginRequiredView(
                        icon: entry.service.iconName,
                        title: "登录后使用\(entry.title)",
                        subtitle: "从意图入口进入对应服务",
                        isPresented: .constant(false)
                    )
                }
            }
        }
    }

    // MARK: - 顶部品牌 + 搜索（sticky + blur，品牌 18px serif 紧凑）
    private var headerSection: some View {
        HStack(spacing: 8) {
            Text("问玄东方")
                .font(.custom(AppFont.serif[0], size: 18).weight(.semibold))
                .foregroundStyle(Color.accentDefault)
                .lineLimit(1)

            Spacer()

            NavigationLink(value: HomeRoute.templeList) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.accentDefault)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(minHeight: 48)
    }

    // MARK: - Banner 轮播（对齐原型：200px高 + 图片 + 左侧渐变遮罩 + 圆点指示器）
    private var bannerSection: some View {
        VStack(spacing: 10) {
            GeometryReader { proxy in
                TabView(selection: $currentBanner) {
                    ForEach(Array(viewModel.banners.enumerated()), id: \.element.id) { index, banner in
                        bannerSlide(banner)
                            .frame(width: proxy.size.width, height: 200)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(width: proxy.size.width, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .frame(height: 200)
            .padding(.horizontal, 20)

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
        GeometryReader { proxy in
            let horizontalInset: CGFloat = 20
            let cardWidth = (proxy.size.width - horizontalInset * 2 - AppSpacing.md) / 2

            HStack(spacing: AppSpacing.md) {
                NavigationLink(value: HomeRoute.templeList) {
                    entryCard(icon: "building.2.fill", title: "找寺院", asset: ImageMapper.entryTemple)
                        .frame(width: cardWidth)
                }
                .buttonStyle(CardPressButtonStyle())
                NavigationLink(value: HomeRoute.masterList) {
                    entryCard(icon: "person.circle.fill", title: "找师傅", asset: ImageMapper.entryMaster)
                        .frame(width: cardWidth)
                }
                .buttonStyle(CardPressButtonStyle())
            }
            .padding(.horizontal, horizontalInset)
        }
        .frame(height: 120)
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

    // MARK: - 信仰入口
    private var beliefSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("按信仰找")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.md) {
                    ForEach(viewModel.beliefEntries) { entry in
                        NavigationLink(value: HomeRoute.belief(entry)) {
                            beliefItem(entry)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func beliefItem(_ entry: BeliefEntry) -> some View {
        HStack(spacing: 10) {
            Image(systemName: entry.iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.accentDefault)
                .frame(width: 34, height: 34)
                .background(Color.accentDefault.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text(entry.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .frame(width: 132, height: 58, alignment: .leading)
        .padding(.horizontal, 10)
        .background(Color.bgSecondary)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderDefault, lineWidth: 1))
    }

    // MARK: - 意图入口
    private var intentionSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("按心愿办")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, 20)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.sm), count: 4), spacing: AppSpacing.sm) {
                ForEach(viewModel.intentionEntries) { entry in
                    NavigationLink(value: HomeRoute.intention(entry)) {
                        intentionItem(entry)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func intentionItem(_ entry: IntentionEntry) -> some View {
        VStack(spacing: 6) {
            Image(systemName: entry.iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.brandDefault)
                .frame(width: 36, height: 36)
                .background(Color.brandDefault.opacity(0.1))
                .clipShape(Circle())

            Text(entry.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 68)
        .background(Color.bgSecondary)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderDefault, lineWidth: 1))
    }

    // MARK: - 热门寺院（横滑，标题可点击进完整列表）
    private var hotTemplesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            NavigationLink(value: HomeRoute.templeList) {
                HStack {
                    Text("热门寺院")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.accentDefault)
                }
                .padding(.horizontal, 20)
            }
            .buttonStyle(.plain)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.md) {
                    ForEach(viewModel.hotTemples) { temple in
                        NavigationLink(value: temple) { templeCard(temple) }
                            .buttonStyle(CardPressButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func templeCard(_ temple: Temple) -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                RemoteImage(urlString: temple.coverImage, placeholderIcon: "building.2")
                    .frame(width: 168, height: 100)
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
                        .minimumScaleFactor(0.85)
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
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer()
                }
                if !temple.serviceTagsText.isEmpty || temple.serviceCountText != nil {
                    HStack {
                        if !temple.serviceTagsText.isEmpty {
                            Text(temple.serviceTagsText)
                                .font(.system(size: 10))
                                .foregroundStyle(Color.textSecondary)
                                .lineLimit(2)
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
        .frame(width: 168)
        .background(Color.bgSecondary)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderDefault, lineWidth: 1))
    }

    /// 寺院类型标签颜色：道教用紫色（对齐原型 #9E8FB2），其他用 brand
    private func templeTypeColor(_ type: String) -> Color {
        if type.contains("道") {
            return Color(red: 158/255, green: 143/255, blue: 178/255)
        }
        return Color.brandDefault
    }

    // MARK: - 热门师傅（横滑，标题可点击进完整列表）
    private var hotMastersSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            NavigationLink(value: HomeRoute.masterList) {
                HStack {
                    Text("热门师傅")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.accentDefault)
                }
                .padding(.horizontal, 20)
            }
            .buttonStyle(.plain)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.md) {
                    ForEach(viewModel.hotMasters) { master in
                        NavigationLink(value: master) { masterCard(master) }
                            .buttonStyle(CardPressButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
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
                .minimumScaleFactor(0.85)

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
                    .minimumScaleFactor(0.85)
            }

            // 专长标签
            Text(master.specialtiesText)
                .font(.system(size: 10))
                .foregroundStyle(Color.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

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
                            .lineLimit(2)
                    }
                    Spacer()
                    if let price = master.startPriceText {
                        Text(price)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.brandDefault)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }
                .padding(.top, 4)
                .overlay(
                    Rectangle().fill(Color.borderDivider).frame(height: 1),
                    alignment: .top
                )
            }
        }
        .frame(width: 168)
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
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
    case belief(BeliefEntry)
    case intention(IntentionEntry)
}

#Preview {
    NavigationStack { HomeView() }
}
