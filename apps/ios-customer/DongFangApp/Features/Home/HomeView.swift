//
//  HomeView.swift
//  DongFangApp
//
//  首页：
//  广告 + 找寺庙 / 找师傅 + 心愿横滑 + DIY 与广场 + 积分 + 热门推荐。
//

import SwiftUI

struct HomeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .headline) private var entryTitleLineHeight: CGFloat = 25
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject private var authStore: AuthStore
    @State private var currentBanner: Int = 0

    private let pageInset: CGFloat = 16
    private let columnSpacing: CGFloat = 12
    private let sectionSpacing: CGFloat = 28
    private let sectionTitleSpacing: CGFloat = 12
    private let contentCardMinHeight: CGFloat = 88

    var body: some View {
        GeometryReader { geometry in
            let viewportWidth = geometry.size.width

            ScrollView(showsIndicators: false) {
                VStack(spacing: sectionSpacing) {
                    if !viewModel.banners.isEmpty { bannerSection }
                    entryCardsSection(width: viewportWidth)
                    if viewModel.isLoading && viewModel.intentionEntries.isEmpty { ProgressView(L10n.text("正在加载首页")) }
                    if let error = viewModel.errorMessage {
                        HStack { Text(L10n.lookup(L10n.text("部分内容加载失败：") + error)).font(AppTypography.caption); Spacer(); Button(L10n.text("重试")) { Task { await viewModel.load() } } }.padding(16).appCardSurface(cornerRadius: 12).padding(.horizontal, pageInset)
                    }
                    intentionSection(width: viewportWidth)
                    diySection
                    pointsSection
                    hotTemplesSection(width: viewportWidth)
                    hotMastersSection(width: viewportWidth)
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
            .safeAreaInset(edge: .top, spacing: 0) {
                headerSection
                    .frame(width: viewportWidth)
                    .background(Color.bgPrimary)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(Color.borderDivider)
                            .frame(height: 0.5)
                    }
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .navigationDestination(for: HomePromotion.self) { NativePromotionDestination(promotion: $0) }
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
                        title: L10n.text("登录后使用此服务"),
                        subtitle: L10n.text("祈福 / 供灯 / 上香 / 超度 / 开光 / 化太岁"),
                        isPresented: .constant(false)
                    )
                }
            case .diyBracelet:
                DiyBraceletView()
            case .booking(let master):
                // 预约法师需要登录
                if authStore.isLoggedIn {
                    BookingView(master: master)
                } else {
                    LoginRequiredView(
                        icon: "calendar.badge.plus",
                        title: L10n.text("登录后预约法师"),
                        subtitle: L10n.text("在线预约，法师确认"),
                        isPresented: .constant(false)
                    )
                }
            case .belief(let entry):
                BeliefTopicView(entry: entry)
            case .templeBelief(let code):
                TempleListView(initialBeliefCode: code)
            case .masterBelief(let code):
                MasterListView(initialBeliefCode: code)
            case .intention(let entry):
                IntentionHubView(entry: entry)
            }
        }
    }

    // MARK: - 顶部品牌 + 搜索
    private var headerSection: some View {
        HStack(spacing: 8) {
            Image("brand-logo")
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            Text(L10n.text("问玄东方"))
                .font(AppTypography.title(18))
                .foregroundStyle(Color.accentDefault)
                .lineLimit(1)

            Spacer()

            NavigationLink { NativeGlobalSearchView() } label: {
                Image(systemName: "magnifyingglass")
                    .font(AppTypography.reading.weight(.medium))
                    .foregroundStyle(Color.accentDefault)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(CardPressButtonStyle())
            .accessibilityLabel(L10n.text("全站搜索"))
            .accessibilityIdentifier("home-global-search")
        }
        .padding(.horizontal, pageInset)
        .frame(height: 52)
    }

    // MARK: - 后台推荐，原生分页与导航
    private var bannerSection: some View {
        TabView(selection: $currentBanner) {
            ForEach(Array(viewModel.banners.enumerated()), id: \.element.id) { index, banner in
                NavigationLink(value: banner) {
                    GeometryReader { geometry in
                    ZStack(alignment: .bottomLeading) {
                        RemoteImage(urlString: banner.imageUrl, placeholderIcon: "photo")
                            .frame(width: geometry.size.width, height: 184).clipped()
                        LinearGradient(colors: [.clear, .black.opacity(0.72)], startPoint: .top, endPoint: .bottom)
                        VStack(alignment: .leading, spacing: 10) {
                            Text(L10n.text("精选推荐")).font(AppTypography.title(12, weight: .regular)).tracking(2)
                            Text(L10n.lookup(banner.title)).font(AppTypography.title(25)).lineLimit(2)
                            Label(L10n.text("查看详情"), systemImage: "arrow.up.right").font(AppTypography.title(12, weight: .regular))
                        }.foregroundStyle(.white).padding(20).padding(.bottom, viewModel.banners.count > 1 ? 12 : 0)
                    }.frame(width: geometry.size.width, height: 184).clipShape(RoundedRectangle(cornerRadius: 12))
                    }.frame(height: 184)
                }.buttonStyle(CardPressButtonStyle()).tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: viewModel.banners.count > 1 ? .automatic : .never))
        .frame(height: 184).padding(.horizontal, pageInset)
    }

    private func entryCardsSection(width: CGFloat) -> some View {
        let cardWidth = columnWidth(in: width)
        return HStack(spacing: columnSpacing) {
            NavigationLink(value: HomeRoute.templeList) {
                entryCard(icon: "building.columns", title: "找寺庙", detail: "访寺院，了解文化与服务", pattern: .temple, width: cardWidth)
            }.accessibilityIdentifier("home-temples")
            NavigationLink(value: HomeRoute.masterList) {
                entryCard(icon: "person.crop.circle", title: "找师傅", detail: "按心愿，寻找合适的师傅", pattern: .master, width: cardWidth)
            }.accessibilityIdentifier("home-masters")
        }
        .fixedSize(horizontal: false, vertical: true)
        .buttonStyle(CardPressButtonStyle())
        .padding(.horizontal, pageInset)
    }

    private func entryCard(icon: String, title: String, detail: String, pattern: HomeEntryPattern.Kind, width: CGFloat) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(Color.brandDefault).accessibilityHidden(true)
            Text(L10n.lookup(title)).font(AppTypography.title(18)).foregroundStyle(Color.textPrimary)
            Text(L10n.lookup(detail)).font(AppTypography.caption).foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 12)
        .frame(width: width)
        .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? max(184, entryTitleLineHeight * 3 + 84) : 164, maxHeight: .infinity)
        .background(alignment: .trailing) {
            HomeEntryPattern(kind: pattern)
                .stroke(Color.accentDefault.opacity(colorScheme == .dark ? 0.12 : 0.07), lineWidth: 1.5)
                .frame(width: min(132, width), height: 116).allowsHitTesting(false).accessibilityHidden(true)
        }
        .appCardSurface(cornerRadius: 12)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private func columnWidth(in viewportWidth: CGFloat) -> CGFloat {
        max(0, (viewportWidth - pageInset * 2 - columnSpacing) / 2)
    }

    private func intentionSection(width: CGFloat) -> some View {
        let regularCardWidth = max(0, (width - pageInset * 2 - columnSpacing * 3) / 4)
        let cardWidth = dynamicTypeSize.isAccessibilitySize ? max(116, regularCardWidth) : regularCardWidth
        return VStack(alignment: .leading, spacing: sectionTitleSpacing) {
            Text(L10n.text("按心愿办")).font(AppTypography.section).foregroundStyle(Color.textPrimary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: columnSpacing) {
                    ForEach(viewModel.intentionEntries) { entry in
                        NavigationLink(value: HomeRoute.intention(entry)) { intentionItem(entry, width: cardWidth) }
                            .buttonStyle(CardPressButtonStyle())
                            .accessibilityIdentifier("home-intention-" + entry.id)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityIdentifier("home-intention-entries")
        }
        .padding(.horizontal, pageInset)
    }

    private func intentionItem(_ entry: IntentionEntry, width: CGFloat) -> some View {
        VStack(spacing: 6) {
            IntentionLineIcon(code: entry.id)
                .frame(width: 24, height: 24).foregroundStyle(Color.accentDefault)
            Text(L10n.lookup(entry.title)).font(AppTypography.title(14, weight: .regular))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Color.textPrimary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 8).padding(.vertical, 12)
        .frame(width: width)
        .frame(minHeight: contentCardMinHeight, maxHeight: .infinity)
        .appCardSurface(cornerRadius: 12)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private var diySection: some View {
        VStack(alignment: .leading, spacing: sectionTitleSpacing) {
            let headingLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
            headingLayout {
                Text(L10n.text("DIY 手串")).font(AppTypography.section).foregroundStyle(Color.textPrimary)
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                HStack(spacing: 16) {
                    NavigationLink {
                        DiyBraceletView(initialSection: .plaza)
                    } label: {
                        Text(L10n.text("设计广场")).fixedSize(horizontal: false, vertical: true).frame(minHeight: 44)
                    }
                    .accessibilityIdentifier("home-diy-plaza")
                    NavigationLink {
                        DiyMyDesignsView().requireAuth(title: L10n.text("登录后查看我的设计"), subtitle: L10n.text("登录后同步和管理你的手串设计"))
                    } label: {
                        Text(L10n.text("我的设计")).fixedSize(horizontal: false, vertical: true).frame(minHeight: 44)
                    }
                    .accessibilityIdentifier("home-diy-mine")
                }
                .font(AppTypography.caption).foregroundStyle(Color.accentDefault)
                .buttonStyle(CardPressButtonStyle())
            }
            NavigationLink { DiyDesignView() } label: {
                HStack(spacing: 12) {
                    Image(systemName: "circle.dotted")
                        .font(.system(size: 32)).foregroundStyle(Color.accentDefault).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 10) {
                                Text(L10n.text("开始设计")).font(AppTypography.title(18))
                                creatorRewardLabel
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Text(L10n.text("开始设计")).font(AppTypography.title(18))
                                creatorRewardLabel
                            }
                        }
                        Text(L10n.text("发布原创设计，被采用成交可获奖励"))
                            .font(AppTypography.caption).foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right").font(AppTypography.body).foregroundStyle(Color.accentDefault)
                        .accessibilityHidden(true)
                }
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, 14).padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: contentCardMinHeight, alignment: .leading)
                .background(LinearGradient(colors: [Color.brandDefault.opacity(0.10), Color.accentDefault.opacity(0.05)], startPoint: .leading, endPoint: .trailing))
                .appCardSurface(cornerRadius: 12)
                .contentShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(CardPressButtonStyle())
            .accessibilityIdentifier("home-diy")

            if !viewModel.featuredDesigns.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(L10n.text("广场精选")).font(AppTypography.body).foregroundStyle(Color.textPrimary)
                    Spacer(minLength: 0)
                }
                .padding(.top, 4)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: columnSpacing) {
                        ForEach(viewModel.featuredDesigns) { design in
                            NavigationLink { DiyDetailView(designId: design.id) } label: {
                                designPreview(slots: DiyDesignPreview.slots(from: design.designData))
                            }
                            .buttonStyle(CardPressButtonStyle())
                            .accessibilityLabel(Text(verbatim: design.name))
                            .accessibilityIdentifier("home-diy-design-\(design.id)")
                        }
                        NavigationLink { DiyBraceletView(initialSection: .plaza) } label: {
                            VStack(spacing: 10) {
                                Image(systemName: "chevron.right").font(AppTypography.card).accessibilityHidden(true)
                                Text(L10n.text("逛设计广场")).font(AppTypography.caption)
                                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                            }
                            .foregroundStyle(Color.accentDefault)
                            .padding(8)
                            .frame(width: dynamicTypeSize.isAccessibilitySize ? 160 : 104)
                            .frame(minHeight: 104)
                            .appCardSurface(cornerRadius: 12)
                        }
                        .buttonStyle(CardPressButtonStyle())
                        .accessibilityIdentifier("home-diy-plaza-more")
                    }
                }
                .accessibilityIdentifier("home-diy-designs")
            }
        }
        .padding(.horizontal, pageInset)
    }

    private var creatorRewardLabel: some View {
        Label(L10n.text("创作返利"), systemImage: "sparkles")
            .font(AppTypography.caption).foregroundStyle(Color.brandDefault)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Color.brandDefault.opacity(0.10), in: RoundedRectangle(cornerRadius: 4))
    }

    private func designPreview(slots: [DiyBeadSlot]) -> some View {
        DiyMiniBracelet(slots: slots, fallbackCount: 0)
            .frame(width: 104, height: 104)
            .appCardSurface(cornerRadius: 12)
    }

    private var pointsSection: some View {
        VStack(alignment: .leading, spacing: sectionTitleSpacing) {
            Text(L10n.text("积分中心")).font(AppTypography.section).foregroundStyle(Color.textPrimary)
            HStack(spacing: columnSpacing) {
                // Display names follow the explicitly confirmed homepage mapping.
                pointsEntry(title: "商城", detail: "积分转盘", icon: "circle.dotted", mode: 0, identifier: "home-points-wheel")
                pointsEntry(title: "转盘", detail: "积分商城", icon: "bag", mode: 1, identifier: "home-points-mall")
                pointsEntry(title: "乐购", detail: "奖池", icon: "star", mode: 2, identifier: "home-points-pool")
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, pageInset)
    }

    private func pointsEntry(title: String, detail: String, icon: String, mode: Int, identifier: String) -> some View {
        NavigationLink { PointsView(initialMode: mode).requireAuth(title: L10n.text("登录后使用积分中心")) } label: {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 24)).foregroundStyle(Color.accentDefault).accessibilityHidden(true)
                Text(L10n.lookup(title)).font(AppTypography.title(16)).foregroundStyle(Color.textPrimary)
                Text(L10n.lookup(detail)).font(AppTypography.micro).foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8).padding(.vertical, 7)
            .frame(maxWidth: .infinity, minHeight: contentCardMinHeight, maxHeight: .infinity)
            .appCardSurface(cornerRadius: 12)
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(CardPressButtonStyle())
        .accessibilityIdentifier(identifier)
    }

    // MARK: - 热门推荐，使用相同栏宽、留白与圆角背景
    private func hotTemplesSection(width: CGFloat) -> some View {
        let cardWidth = columnWidth(in: width)
        return VStack(alignment: .leading, spacing: sectionTitleSpacing) {
            NavigationLink(value: HomeRoute.templeList) { recommendationHeading("热门寺院") }
                .buttonStyle(CardPressButtonStyle())
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: columnSpacing) {
                    if viewModel.isLoading && viewModel.hotTemples.isEmpty {
                        ForEach(0..<3) { _ in DFLoadingCard().frame(width: cardWidth) }
                    }
                    ForEach(viewModel.hotTemples) { temple in
                        NavigationLink(value: temple) { templeCard(temple, width: cardWidth) }
                            .buttonStyle(CardPressButtonStyle())
                    }
                }
            }
        }
        .padding(.horizontal, pageInset)
    }

    private func templeCard(_ temple: Temple, width: CGFloat) -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                RemoteImage(urlString: temple.coverImage, placeholderIcon: "building.columns")
                    .frame(width: width, height: width * 0.62).clipped()
                Text(L10n.lookup(temple.type))
                    .font(AppTypography.micro.weight(.medium)).foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Color.brandDefault.opacity(0.85), in: Capsule()).padding(8)
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Text(verbatim: temple.name).font(AppTypography.title(16)).foregroundStyle(Color.textPrimary)
                        .lineLimit(1).minimumScaleFactor(0.85)
                    Spacer(minLength: 0)
                    Text("★ \(temple.ratingText)").font(AppTypography.micro).foregroundStyle(Color.accentDefault)
                }
                Label(temple.region, systemImage: "mappin.circle")
                    .font(AppTypography.micro).foregroundStyle(Color.textSecondary).lineLimit(1)
                HStack(spacing: 4) {
                    Text(verbatim: temple.serviceTagsText).font(AppTypography.micro)
                        .foregroundStyle(Color.textSecondary).lineLimit(1)
                    Spacer(minLength: 0)
                    if let countText = temple.serviceCountText {
                        Text(L10n.lookup(countText)).font(AppTypography.micro).foregroundStyle(Color.brandDefault)
                            .lineLimit(1).minimumScaleFactor(0.85)
                    }
                }
                .padding(.top, 6)
                .overlay(alignment: .top) { Rectangle().fill(Color.borderDivider).frame(height: 1) }
            }
            .padding(12).frame(maxWidth: .infinity, minHeight: 102, alignment: .topLeading)
        }
        .frame(width: width).appCardSurface(cornerRadius: 12)
    }

    private func hotMastersSection(width: CGFloat) -> some View {
        let cardWidth = columnWidth(in: width)
        return VStack(alignment: .leading, spacing: sectionTitleSpacing) {
            NavigationLink(value: HomeRoute.masterList) { recommendationHeading("热门师傅") }
                .buttonStyle(CardPressButtonStyle())
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: columnSpacing) {
                    if viewModel.isLoading && viewModel.hotMasters.isEmpty {
                        ForEach(0..<3) { _ in DFLoadingCard(avatar: true).frame(width: cardWidth) }
                    }
                    ForEach(viewModel.hotMasters) { master in
                        NavigationLink(value: master) { masterCard(master, width: cardWidth) }
                            .buttonStyle(CardPressButtonStyle())
                    }
                }
            }
        }
        .padding(.horizontal, pageInset)
    }

    private func masterCard(_ master: Master, width: CGFloat) -> some View {
        VStack(spacing: 0) {
            RemoteImage(urlString: master.avatar, placeholderIcon: "person.crop.rectangle")
                .frame(width: width, height: width * 0.62).clipped()
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Text(verbatim: master.dharmaName).font(AppTypography.title(16)).foregroundStyle(Color.textPrimary)
                        .lineLimit(1).minimumScaleFactor(0.85)
                    Spacer(minLength: 0)
                    Text("★ " + master.ratingText).font(AppTypography.micro).foregroundStyle(Color.accentDefault)
                }
                Text(verbatim: [master.sect, master.templeName].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(AppTypography.micro).foregroundStyle(Color.textSecondary).lineLimit(1)
                HStack(spacing: 4) {
                    Text(verbatim: master.specialtiesText).font(AppTypography.micro)
                        .foregroundStyle(Color.textSecondary).lineLimit(1)
                    Spacer(minLength: 0)
                    if let price = master.startPriceText {
                        Text(L10n.lookup(price)).font(AppTypography.micro).foregroundStyle(Color.brandDefault)
                            .lineLimit(1).minimumScaleFactor(0.85)
                    }
                }
                .padding(.top, 6)
                .overlay(alignment: .top) { Rectangle().fill(Color.borderDivider).frame(height: 1) }
            }
            .padding(12).frame(maxWidth: .infinity, minHeight: 102, alignment: .topLeading)
        }
        .frame(width: width).appCardSurface(cornerRadius: 12)
    }

    private func recommendationHeading(_ title: String) -> some View {
        HStack {
            Text(L10n.lookup(title)).font(AppTypography.section).foregroundStyle(Color.textPrimary)
            Spacer()
            HStack(spacing: 2) {
                Text(L10n.text("更多"))
                Image(systemName: "chevron.right").accessibilityHidden(true)
            }.font(AppTypography.caption).foregroundStyle(Color.accentDefault)
        }
        .frame(minHeight: 28)
        .contentShape(Rectangle())
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
        case .love, .wealth, .career, .fengshui, .health, .study:
            ServiceContainerView(serviceType: type)
        case .diy:          DiyBraceletView()
        }
    }
}

@MainActor
private final class IntentionHubViewModel: ObservableObject {
    @Published var tags: [IntentionTag] = []
    @Published var resources: [IntentionResource] = []
    @Published var selectedCode: String
    @Published var isLoading = false
    @Published var errorMessage: String?

    init(code: String) { selectedCode = code }

    /// 当前选中诉求名称（筛选按钮展示用）
    var selectedTagName: String {
        tags.first { $0.code == selectedCode }?.name ?? "全部"
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response: IntentionHubResponse = try await APIClient.shared.request(.intentionHub(code: selectedCode, page: 1, size: 30))
            tags = response.tags
            resources = response.list
        } catch {
            errorMessage = error.localizedDescription
            resources = []
        }
    }
}

private struct IntentionHubView: View {
    let entry: IntentionEntry
    @StateObject private var viewModel: IntentionHubViewModel

    init(entry: IntentionEntry) {
        self.entry = entry
        _viewModel = StateObject(wrappedValue: IntentionHubViewModel(code: entry.id))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.isLoading && viewModel.resources.isEmpty {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 60)
                } else if let message = viewModel.errorMessage {
                    ContentUnavailableView(L10n.text("暂时无法读取"), systemImage: "wifi.exclamationmark", description: Text(L10n.lookup(message)))
                    Button(L10n.text("重试")) { Task { await viewModel.load() } }
                        .buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
                } else if viewModel.resources.isEmpty {
                    ContentUnavailableView(L10n.text("暂无匹配内容"), systemImage: "square.grid.2x2")
                } else {
                    Text(L10n.text("相关寺院服务与大师服务"))
                        .font(AppTypography.reading.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)
                        .padding(.horizontal, 20)

                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.resources) { item in
                            NavigationLink { destination(for: item) } label: { resourceRow(item) }
                                .buttonStyle(CardPressButtonStyle())
                        }
                    }.padding(.horizontal, 20)
                }
            }.padding(.vertical, 12)
        }
        .navigationTitle(L10n.lookup(entry.title))
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }

    /// 当前选中诉求（跟随筛选切换；未加载到 tags 时回退入口诉求）
    private var currentTag: IntentionTag? {
        viewModel.tags.first { $0.code == viewModel.selectedCode }
    }
    private var heroTitle: String { currentTag?.name ?? entry.title }
    private var heroSummary: String { currentTag?.description ?? entry.summary }
    private var heroIcon: String { currentTag?.icon ?? entry.iconName }
    private var heroLandingType: String { currentTag?.landingType ?? entry.landingType }
    private var heroActionTitle: String { currentTag?.actionTitle ?? entry.actionTitle }
    private var heroService: ServiceType? {
        if let value = currentTag?.landingValue, !value.isEmpty {
            return ServiceType.from(serviceCode: value)
        }
        return entry.service
    }

    private var intentionHero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: heroIcon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.brandDefault)
                    .frame(width: 48, height: 48)
                    .background(Color.brandDefault.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.lookup(heroTitle))
                        .font(AppTypography.title(22))
                        .foregroundStyle(Color.textPrimary)
                    Text(L10n.lookup(heroSummary))
                        .font(AppTypography.supporting)
                        .foregroundStyle(Color.textSecondary)
                        .lineSpacing(4)
                }
            }

            if heroLandingType == "diy" {
                NavigationLink(value: HomeRoute.diyBracelet) {
                    actionLabel
                }
                .buttonStyle(CardPressButtonStyle())
            } else if let service = heroService {
                NavigationLink(value: HomeRoute.service(service)) {
                    actionLabel
                }
                .buttonStyle(CardPressButtonStyle())
            }
        }
        .padding(16)
        .background(Color.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 20)
    }

    private var actionLabel: some View {
        Label(L10n.lookup(heroActionTitle), systemImage: "arrow.right.circle.fill")
            .font(AppTypography.body.weight(.semibold))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.brandDefault)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func resourceRow(_ item: IntentionResource) -> some View {
        HStack(spacing: 12) {
            Group {
                if item.resourceType == "master" {
                    RemoteImage(urlString: item.image, placeholderIcon: "person.circle.fill")
                        .frame(width: 72, height: 72)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.accentDefault, lineWidth: 2))
                } else {
                    RemoteImage(urlString: item.image, placeholderIcon: "building.columns")
                        .frame(width: 86, height: 86)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.lookup(resourceTypeLabel(item.resourceType)))
                    .font(AppTypography.micro.weight(.semibold)).foregroundStyle(Color.accentDefault)
                Text(L10n.lookup(item.title)).font(AppTypography.body.weight(.semibold)).foregroundStyle(Color.textPrimary).lineLimit(2)
                Text(L10n.lookup(item.subtitle)).font(AppTypography.caption).foregroundStyle(Color.textSecondary).lineLimit(1)
                Text("¥\(Int(item.price))").font(AppTypography.body.weight(.semibold)).foregroundStyle(Color.brandDefault)
            }
            Spacer()
            Image(systemName: "chevron.right").font(AppTypography.caption).foregroundStyle(Color.textTertiary)
        }
        .padding(10).background(Color.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func resourceTypeLabel(_ type: String) -> String {
        switch type {
        case "master": return "大师服务"
        default: return "寺院服务"
        }
    }

    @ViewBuilder
    private func destination(for item: IntentionResource) -> some View {
        if item.resourceType == "master" {
            MasterProfileView(masterId: item.masterCode ?? "", initialServiceCode: item.serviceCode)
        } else {
            serviceView(for: item.serviceCode)
        }
    }

    @ViewBuilder
    private func serviceView(for code: String?) -> some View {
        switch code {
        case "S002": ServiceLampView()
        case "S003": ServiceIncenseView()
        case "S004": ServiceVowView()
        case "S005": ServiceRiteView()
        case "S006": ServiceConsecrationView()
        case "S007": ServiceTaisuiView()
        case "S008": ServiceContainerView(serviceType: .love)
        case "S009": ServiceContainerView(serviceType: .wealth)
        case "S010": ServiceContainerView(serviceType: .career)
        case "S011": ServiceContainerView(serviceType: .fengshui)
        case "S012": ServiceContainerView(serviceType: .health)
        case "S013": ServiceContainerView(serviceType: .study)
        case "DIY": DiyBraceletView()
        default: ServiceBlessingView()
        }
    }
}

@MainActor
private final class BeliefTopicViewModel: ObservableObject {
    @Published var profile: BeliefProfile?
    @Published var temples: [Temple] = []
    @Published var masters: [Master] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(code: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let profileRequest: BeliefProfile = APIClient.shared.request(.belief(code))
            async let templeRequest: PageResponse<Temple> = APIClient.shared.request(.templesByBelief(code, page: 1, size: 6))
            async let masterRequest: PageResponse<Master> = APIClient.shared.request(.mastersByBelief(code, page: 1, size: 6))
            let (profile, templePage, masterPage) = try await (profileRequest, templeRequest, masterRequest)
            self.profile = profile
            temples = templePage.list
            masters = masterPage.list
        } catch {
            errorMessage = error.localizedDescription
            profile = nil
            temples = []
            masters = []
        }
    }
}

private struct BeliefTopicView: View {
    let entry: BeliefEntry
    @StateObject private var viewModel = BeliefTopicViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Image(systemName: entry.iconName)
                        .font(.system(size: 30))
                        .foregroundStyle(Color.accentDefault)
                    Text(L10n.lookup(viewModel.profile?.name ?? entry.title))
                        .font(AppTypography.title(28))
                    Text(L10n.lookup(viewModel.profile?.summary ?? entry.subtitle))
                        .font(AppTypography.body.weight(.semibold))
                        .foregroundStyle(Color.accentDefault)
                    Text(L10n.lookup(viewModel.profile?.description ?? L10n.text("正在读取流派简介")))
                        .font(AppTypography.body)
                        .foregroundStyle(Color.textSecondary)
                        .lineSpacing(5)
                }
                .padding(.horizontal, 20)

                topicSection(title: L10n.text("该流派大师"), more: .masterBelief(entry.id)) {
                    ForEach(viewModel.masters.prefix(4)) { master in
                        NavigationLink(value: master) {
                            HStack(spacing: 12) {
                                RemoteImage(urlString: master.avatar, placeholderIcon: "person.fill")
                                    .frame(width: 52, height: 52).clipShape(Circle())
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(L10n.lookup(master.dharmaName)).font(AppTypography.body.weight(.semibold))
                                    Text("\(master.sect) · \(master.templeName)").font(AppTypography.caption).foregroundStyle(Color.textTertiary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(Color.textTertiary)
                            }.padding(.vertical, 6)
                        }.buttonStyle(CardPressButtonStyle())
                    }
                }

                topicSection(title: L10n.text("该流派寺庙"), more: .templeBelief(entry.id)) {
                    ForEach(viewModel.temples.prefix(4)) { temple in
                        NavigationLink(value: temple) {
                            HStack(spacing: 12) {
                                RemoteImage(urlString: temple.coverImage, placeholderIcon: "building.columns.fill")
                                    .frame(width: 72, height: 52).clipShape(RoundedRectangle(cornerRadius: 6))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(L10n.lookup(temple.name)).font(AppTypography.body.weight(.semibold))
                                    Text("\(temple.region) · \(temple.sect)").font(AppTypography.caption).foregroundStyle(Color.textTertiary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(Color.textTertiary)
                            }.padding(.vertical, 6)
                        }.buttonStyle(CardPressButtonStyle())
                    }
                }
            }.padding(.vertical, 20)
        }
        .background(Color.bgPrimary)
        .navigationTitle(L10n.lookup(entry.title))
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if viewModel.isLoading { ProgressView() } }
        .task { await viewModel.load(code: entry.id) }
    }

    private func topicSection<Content: View>(title: String, more: HomeRoute, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.lookup(title)).font(AppTypography.title(19))
                Spacer()
                NavigationLink(value: more) { Text(L10n.text("更多")).font(AppTypography.supporting).foregroundStyle(Color.accentDefault) }
            }
            content()
        }.padding(.horizontal, 20)
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
    case templeBelief(String)
    case masterBelief(String)
    case intention(IntentionEntry)
}

#Preview {
    NavigationStack { HomeView() }
}

// Same 24-point artwork as H5, rendered by the native asset catalog.
struct IntentionLineIcon: View {
    let code: String
    var body: some View {
        Image("intention-" + (["diy", "peace", "wealth", "love", "career", "study", "taisui", "rite"].contains(code) ? code : "peace"))
            .resizable().renderingMode(.template).scaledToFit().accessibilityHidden(true)
    }
}

struct HomePromotionList: Decodable { let list: [HomePromotion] }
struct HomePromotion: Decodable, Hashable, Identifiable {
    let id: Int
    let title, placement, imageUrl, linkType, linkValue, status, startTime, endTime: String
    let sort: Int

    var route: String? {
        if ["ai", "diy"].contains(linkType) { return linkValue.isEmpty ? "/c/" + linkType : nil }
        if linkType == "ad_landing" {
            return ["/c/ai", "/c/diy", "/c/shop", "/c/rewards", "/c/temples", "/c/masters", "/c/services"].contains(linkValue) ? linkValue : nil
        }
        let roots = ["temple": "/c/temples/", "master": "/c/masters/", "product": "/c/shop/", "service": "/c/services/", "activity": "/c/activities/", "reward": "/c/rewards/"]
        guard let root = roots[linkType], !linkValue.isEmpty,
              linkValue.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil else { return nil }
        return root + linkValue
    }

    var isVisible: Bool {
        guard placement == "customer_home", status == "enabled", route != nil else { return false }
        let image = URL(string: imageUrl)
        guard (imageUrl.hasPrefix("/") && !imageUrl.hasPrefix("//")) || (image?.scheme == "https" && image?.host != nil && image?.user == nil && image?.password == nil),
              !imageUrl.contains("\\"), !imageUrl.contains("\n"), !imageUrl.contains("\r") else { return false }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 8 * 3600)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.isLenient = false
        func date(_ value: String, end: Bool) -> Date? {
            if value.isEmpty { return end ? .distantFuture : .distantPast }
            return formatter.date(from: value.count == 10 ? value + (end ? " 23:59:59" : " 00:00:00") : value)
        }
        guard let start = date(startTime, end: false), let end = date(endTime, end: true) else { return false }
        return start <= Date() && Date() <= end
    }
}

struct NativePromotionDestination: View {
    let promotion: HomePromotion
    var body: some View {
        NativeDiscoveryDestination(route: promotion.route ?? "", title: promotion.title)
    }
}

struct NativeDiscoveryDestination: View {
    let route: String
    var title: String = "推荐详情"
    @State private var product: ShopProduct?
    @State private var error: String?
    @State private var loading = false
    private var parts: [String] { (URLComponents(string: route)?.path ?? route).split(separator: "/").map(String.init) }
    private var routeTab: String? { URLComponents(string: route)?.queryItems?.first(where: { $0.name == "tab" })?.value }
    private var kind: String { parts.count > 1 ? parts[1] : "" }
    private var identifier: String? { parts.count > 2 ? parts[2] : nil }
    var body: some View {
        Group {
            switch kind {
            case "temples":
                if let id = identifier { TempleDetailView(templeId: id, templeName: title) } else { TempleListView() }
            case "masters":
                if let id = identifier { MasterProfileView(masterId: id) } else { MasterListView() }
            case "diy": DiyBraceletView()
            case "growth":
                if routeTab == "rules" { GrowthView(initialTab: "rules", publicRead: true) }
                else { GrowthView(initialTab: routeTab ?? "overview").requireAuth(title: L10n.text("登录后查看我的成长")) }
            case "ai": AiDivinationView().requireAuth(title: L10n.text("登录后开启 AI 问事"))
            case "shop":
                if identifier == nil { ShopView() }
                else if let product { ShopProductDetailView(product: product) }
                else { VStack { DFTopNavBar(title); Spacer(); if loading { ProgressView() } else { Text(L10n.lookup(error ?? L10n.text("商品暂时无法加载"))); Button(L10n.text("重试")) { Task { await loadProduct() } } }; Spacer() } }
            case "services":
                if let id = identifier, let type = ServiceType.from(serviceCode: id) { ServiceContainerView(serviceType: type) }
                else { ScrollView { VStack { DFTopNavBar("预约服务"); ForEach(ServiceType.allCases, id: \.self) { type in NavigationLink { ServiceContainerView(serviceType: type) } label: { HStack { Text(L10n.lookup(type.rawValue)); Spacer(); Image(systemName: "chevron.right") }.padding(18).background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12)) } } }.padding(.horizontal, 16) } }
            case "rewards":
                if let id = identifier.flatMap(Int64.init) { RewardDetailView(id: id) } else { RewardsView() }
            case "activities":
                if let id = identifier { NativeMarketingActivityView(id: id) }
            default: DFEmptyState(icon: "link", title: L10n.text("推荐已更新"), subtitle: L10n.text("请返回首页刷新后查看"))
            }
        }.background(Color.bgPrimary).toolbar(.hidden, for: .navigationBar)
            .task(id: route) { if kind == "shop", identifier != nil { await loadProduct() } }
    }
    private func loadProduct() async {
        guard let id = identifier.flatMap(Int64.init) else { error = "商品编号无效"; return }
        loading = true; defer { loading = false }
        do { product = try await APIClient.shared.request(.productById(id)); error = nil }
        catch { self.error = error.localizedDescription }
    }
}

struct NativeMarketingActivityView: View {
    let id: String
    struct Activity: Decodable { let name, startTime, endTime, config: String }
    struct Details: Decodable { let description: String?; let imageUrl: String?; let location: String? }
    @State private var activity: Activity?
    @State private var error: String?
    var body: some View {
        VStack(spacing: 0) {
            DFTopNavBar("活动详情")
            if let activity {
                let details = activity.config.data(using: .utf8).flatMap { try? JSONDecoder().decode(Details.self, from: $0) }
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if let image = details?.imageUrl { RemoteImage(urlString: image, placeholderIcon: "photo").frame(height: 200).clipShape(RoundedRectangle(cornerRadius: 16)) }
                        Text(L10n.lookup(activity.name)).font(AppTypography.title(28))
                        Text(L10n.text("活动时间（北京时间）\n\(activity.startTime.isEmpty ? L10n.text("即日起") : activity.startTime) — \(activity.endTime.isEmpty ? L10n.text("长期有效") : activity.endTime)")).font(AppTypography.supporting).foregroundStyle(Color.textSecondary)
                        if let location = details?.location { Text(L10n.lookup(L10n.text("活动地点：") + location)) }
                        Text(L10n.lookup(details?.description ?? L10n.text("活动具体安排请以主办方公布的信息为准。"))).lineSpacing(6)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
                }
            } else if let error { ContentUnavailableView { Label(L10n.text("活动暂时无法加载"), systemImage: "wifi.exclamationmark") } description: { Text(L10n.lookup(error)) } actions: { Button(L10n.text("重试")) { Task { await load() } } } }
            else { Spacer(); ProgressView(); Spacer() }
        }.background(Color.bgPrimary).toolbar(.hidden, for: .navigationBar).task { await load() }
    }
    private func load() async {
        error = nil
        do { activity = try await APIClient.shared.request(.marketingActivity(id)) }
        catch { self.error = error.localizedDescription }
    }
}


private struct HomeEntryPattern: Shape {
    enum Kind { case temple, master, bracelet, points }
    let kind: Kind
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        switch kind {
        case .temple:
            path.move(to: CGPoint(x: rect.minX + 8, y: rect.midY - 10))
            path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY + 9), control: CGPoint(x: rect.midX - 12, y: rect.midY - 14))
            path.addQuadCurve(to: CGPoint(x: rect.maxX - 8, y: rect.midY - 10), control: CGPoint(x: rect.midX + 12, y: rect.midY - 14))
            path.move(to: CGPoint(x: 20,y: rect.midY)); path.addLine(to: CGPoint(x: rect.width-20,y: rect.midY))
            for x in [rect.width*0.3,rect.width*0.5,rect.width*0.7] { path.move(to: CGPoint(x:x,y:rect.midY)); path.addLine(to: CGPoint(x:x,y:rect.maxY-10)) }
            path.move(to: CGPoint(x: 16,y:rect.maxY-10)); path.addLine(to: CGPoint(x:rect.maxX-16,y:rect.maxY-10))
        case .master:
            path.addEllipse(in: CGRect(x:center.x-13,y:center.y-30,width:26,height:26))
            path.move(to: CGPoint(x:center.x-32,y:rect.maxY-6))
            path.addCurve(to: CGPoint(x:center.x+32,y:rect.maxY-6), control1: CGPoint(x:center.x-36,y:center.y-8), control2: CGPoint(x:center.x+36,y:center.y-8))
        case .bracelet:
            let radius = min(rect.width,rect.height)*0.34
            path.addEllipse(in: CGRect(x:center.x-radius,y:center.y-radius,width:radius*2,height:radius*2))
            for i in 0..<10 {
                let angle = Double(i)*Double.pi/5
                path.addEllipse(in: CGRect(x:center.x+cos(angle)*radius-5,y:center.y+sin(angle)*radius-5,width:10,height:10))
            }
        case .points:
            for i in 0..<10 {
                let angle = Double(i)*Double.pi/5-Double.pi/2, radius = i%2 == 0 ? 32.0 : 14.0
                let point = CGPoint(x:center.x+cos(angle)*radius,y:center.y+sin(angle)*radius)
                if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath()
            path.addEllipse(in: CGRect(x:center.x-39,y:center.y-39,width:78,height:78))
        }
        return path
    }
}

struct NativeGlobalSearchView: View {
    @StateObject private var model = NativeGlobalSearchModel()
    @State private var text = ""
    @FocusState private var inputFocused: Bool
    var body: some View {
        VStack(spacing: 0) {
            DFTopNavBar("全站搜索")
            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Color.textSecondary)
                    TextField(L10n.text("搜索功能、名称、服务或内容"), text: $text)
                        .focused($inputFocused).submitLabel(.search)
                        .onSubmit(submit).accessibilityIdentifier("global-search-input")
                    if !text.isEmpty {
                        Button { text = ""; model.submit(""); inputFocused = true } label: { Image(systemName: "xmark.circle.fill") }
                            .accessibilityLabel(L10n.text("清除搜索"))
                    }
                }.padding(12).background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 14))
                Button(L10n.text("搜索"), action: submit).frame(minHeight: 44)
                    .disabled(NativePublicSearch.tokens(text).isEmpty).accessibilityIdentifier("global-search-submit")
            }.padding(.horizontal, 16).padding(.vertical, 12)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    if model.query.isEmpty {
                        Text(L10n.text("搜索全站功能与公开内容"))
                            .foregroundStyle(Color.textSecondary).frame(maxWidth: .infinity).padding(.top, 52)
                    } else {
                        ForEach(NativeSearchCategory.allCases) { category in
                            if let section = model.sections[category] { results(category, section: section) }
                        }
                    }
                }.padding(16).padding(.bottom, 24)
            }.scrollDismissesKeyboard(.interactively)
        }.background(Color.bgPrimary).toolbar(.hidden, for: .navigationBar)
            .onDisappear { model.cancel() }
    }
    private func submit() { inputFocused = false; model.submit(text) }
    private func results(_ category: NativeSearchCategory, section: NativeSearchSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.lookup(category.title)).font(.headline)
                Spacer()
                if !section.loading, section.error == nil { Text("\(section.results.count)").font(.caption).foregroundStyle(Color.textSecondary) }
            }
            if section.loading {
                HStack { ProgressView(); Text(L10n.text("搜索中…")).foregroundStyle(Color.textSecondary) }.padding(.vertical, 10)
            } else if let error = section.error {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.text("本类内容加载失败")).foregroundStyle(Color.stateWarning)
                    Text(L10n.lookup(error)).font(.caption).foregroundStyle(Color.textSecondary)
                    Button(L10n.text("重试")) { model.retry(category) }.frame(minHeight: 44)
                        .accessibilityIdentifier("global-retry-" + category.rawValue)
                }
            } else if section.results.isEmpty {
                Text(L10n.text("暂无匹配结果")).font(.subheadline).foregroundStyle(Color.textSecondary).padding(.vertical, 8)
            } else {
                ForEach(section.results.prefix(section.visibleCount)) { result in
                    NavigationLink { NativeGlobalSearchDestination(result: result) } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(verbatim: category == .functions || category == .services ? L10n.lookup(result.title) : result.title)
                                .font(.subheadline.weight(.semibold)).foregroundStyle(Color.textPrimary).lineLimit(2)
                            if !result.summary.isEmpty {
                                Text(verbatim: category == .services ? L10n.lookup(result.summary) : String(result.summary.prefix(120))).font(.caption).foregroundStyle(Color.textSecondary).lineLimit(1)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 12)
                    }.buttonStyle(.plain).accessibilityIdentifier("global-result-" + category.rawValue + "-" + result.id)
                    Divider()
                }
                if section.results.count > section.visibleCount {
                    Button(L10n.text("显示更多")) { model.showMore(category) }.frame(minHeight: 44)
                        .accessibilityIdentifier("global-more-" + category.rawValue)
                }
            }
        }.accessibilityElement(children: .contain).accessibilityIdentifier("global-category-" + category.rawValue)
    }
}

private struct NativeGlobalSearchDestination: View {
    let result: NativeSearchResult
    private var path: String { URLComponents(string: result.route)?.path ?? result.route }
    private var parts: [String] { path.split(separator: "/").map(String.init) }
    private var tab: String? { URLComponents(string: result.route)?.queryItems?.first(where: { $0.name == "tab" })?.value }
    var body: some View {
        Group {
            if let intention = result.intention {
                IntentionHubView(entry: IntentionEntry(tag: intention))
            } else {
                switch path {
                case "/c/points": PointsView()
                case "/c/growth":
                    if tab == "rules" { GrowthView(initialTab: "rules", publicRead: true) }
                    else { GrowthView(initialTab: tab ?? "overview").requireAuth(title: L10n.text("登录后查看我的成长")) }
                case "/c/bookings": OrderListView(initialStatus: "booking").requireAuth(title: L10n.text("登录后查看预约"))
                case "/c/shop/orders": OrderListView(initialStatus: "shop").requireAuth(title: L10n.text("登录后查看订单"))
                case "/c/diy/orders": OrderListView(initialStatus: "diy").requireAuth(title: L10n.text("登录后查看定制订单"))
                case "/c/addresses": AddressListView().requireAuth(title: L10n.text("登录后管理收货地址"))
                case "/c/favorites": FavoritesView().requireAuth(title: L10n.text("登录后查看收藏"))
                case "/c/wallet": WalletView().requireAuth(title: L10n.text("登录后查看钱包"))
                case "/c/chats": VStack(spacing: 0) { DFTopNavBar(tab == "plaza" ? "大师广场" : "对话"); ChatView(initialTab: tab == "plaza" ? 2 : 1) }
                case "/c/diy" where tab == "mine": DiyMyDesignsView().requireAuth(title: L10n.text("登录后查看我的设计"))
                default:
                    if parts.count == 4, parts[1] == "diy", parts[2] == "designs", let id = Int64(parts[3]) {
                        DiyDetailView(designId: id)
                    } else if parts.count == 4, parts[1] == "community", parts[2] == "posts" {
                        CommunityPostDetailView(postId: parts[3])
                    } else { NativeDiscoveryDestination(route: result.route, title: result.title) }
                }
            }
        }
    }
}
