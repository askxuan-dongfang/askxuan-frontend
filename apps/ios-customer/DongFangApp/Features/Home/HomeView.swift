//
//  HomeView.swift
//  DongFangApp
//
//  首页：
//  品牌名「问玄东方」+ 搜索 + Banner轮播 + 双入口 + 信仰/意图入口 + 热门寺院 + 热门师傅。
//

import SwiftUI

struct HomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject private var authStore: AuthStore
    @State private var currentBanner: Int = 0

    var body: some View {
        GeometryReader { geometry in
            let viewportWidth = geometry.size.width

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    if !viewModel.banners.isEmpty { bannerSection }
                    entryCardsSection
                    if viewModel.isLoading && viewModel.beliefEntries.isEmpty { ProgressView("正在加载首页") }
                    if let error = viewModel.errorMessage {
                        HStack { Text("部分内容加载失败：" + error).font(AppTypography.caption); Spacer(); Button("重试") { Task { await viewModel.load() } } }.padding(16).background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12)).padding(.horizontal, 20)
                    }
                    if authStore.isLoggedIn { JourneyEntryView(home: true).padding(.horizontal, AppSpacing.lg) }
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
        .task {
            if viewModel.hotTemples.isEmpty {
                await viewModel.load()
            }
        }
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
                        title: "登录后使用此服务",
                        subtitle: "祈福 / 供灯 / 上香 / 超度 / 开光 / 化太岁",
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
                        title: "登录后预约法师",
                        subtitle: "在线预约，法师确认",
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

            Text("问玄东方")
                .font(AppTypography.title(18))
                .foregroundStyle(Color.accentDefault)
                .lineLimit(1)

            Spacer()

            NavigationLink(value: HomeRoute.templeList) {
                Image(systemName: "magnifyingglass")
                    .font(AppTypography.reading.weight(.medium))
                    .foregroundStyle(Color.accentDefault)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(CardPressButtonStyle())
        }
        .padding(.horizontal, 20)
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
                            Text("精选推荐").font(AppTypography.caption).tracking(2)
                            Text(banner.title).font(AppTypography.title(25)).lineLimit(2)
                            Label("查看详情", systemImage: "arrow.up.right").font(AppTypography.caption)
                        }.foregroundStyle(.white).padding(20).padding(.bottom, viewModel.banners.count > 1 ? 12 : 0)
                    }.frame(width: geometry.size.width, height: 184).clipShape(RoundedRectangle(cornerRadius: 16))
                    }.frame(height: 184)
                }.buttonStyle(CardPressButtonStyle()).tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: viewModel.banners.count > 1 ? .automatic : .never))
        .frame(height: 184).padding(.horizontal, 20)
    }

    private var entryCardsSection: some View {
        HStack(spacing: 10) {
            NavigationLink(value: HomeRoute.templeList) { entryCard(icon: "building.2", title: "找寺院", detail: "探访与服务") }.accessibilityIdentifier("home-temples")
            NavigationLink(value: HomeRoute.masterList) { entryCard(icon: "person.crop.circle", title: "找师傅", detail: "咨询与交流") }.accessibilityIdentifier("home-masters")
        }.buttonStyle(CardPressButtonStyle()).padding(.horizontal, 20)
    }

    private func entryCard(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 23, weight: .regular)).foregroundStyle(Color.accentDefault)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(AppTypography.title(18)).foregroundStyle(Color.textPrimary)
                Text(detail).font(AppTypography.micro).foregroundStyle(Color.textSecondary)
            }.lineLimit(1).minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(Color.textTertiary)
        }.padding(.horizontal, 12).padding(.vertical, 14).frame(maxWidth: .infinity, minHeight: 68)
            .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.borderDefault, lineWidth: 1))
    }

    private var beliefSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("信仰流派").font(AppTypography.section).foregroundStyle(Color.textPrimary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 2), spacing: 1) {
                ForEach(viewModel.beliefEntries.prefix(4)) { entry in
                    NavigationLink(value: HomeRoute.templeBelief(entry.id)) { beliefItem(entry) }
                        .buttonStyle(CardPressButtonStyle())
                }
            }.background(Color.borderDivider).clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.borderDefault, lineWidth: 1))
        }.padding(.horizontal, 20)
    }

    private func beliefItem(_ entry: BeliefEntry) -> some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title).font(AppTypography.title(16)).foregroundStyle(Color.textPrimary)
                Text(entry.subtitle).font(AppTypography.micro).foregroundStyle(Color.textSecondary).lineLimit(2)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Text(String(entry.title.prefix(1))).font(AppTypography.title(16)).foregroundStyle(Color.accentDefault)
                .frame(width: 26, height: 32).overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.accentDefault.opacity(0.25)))
        }.padding(12).frame(maxWidth: .infinity, minHeight: 76, alignment: .leading).background(Color.bgSecondary)
    }

    private var intentionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("按心愿办").font(AppTypography.section).foregroundStyle(Color.textPrimary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 4), spacing: 1) {
                ForEach(viewModel.intentionEntries) { entry in
                    NavigationLink(value: entry.landingType == "diy" ? HomeRoute.diyBracelet : HomeRoute.intention(entry)) {
                        intentionItem(entry)
                    }.buttonStyle(CardPressButtonStyle()).accessibilityIdentifier("home-intention-" + entry.id)
                }
            }.background(Color.borderDivider).clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderDefault, lineWidth: 1))
        }.padding(.horizontal, 20)
    }

    private func intentionItem(_ entry: IntentionEntry) -> some View {
        HStack(spacing: 4) {
            IntentionLineIcon(code: entry.landingType == "diy" ? "diy" : entry.id)
                .frame(width: 20, height: 22).foregroundStyle(entry.landingType == "diy" ? Color.brandDefault : Color.accentDefault)
            Text(entry.landingType == "diy" ? "DIY手串" : entry.title)
                .font(.system(size: 12, weight: .medium)).lineLimit(1).minimumScaleFactor(0.8)
        }.foregroundStyle(Color.textPrimary).frame(maxWidth: .infinity, minHeight: 48)
            .background(entry.landingType == "diy" ? Color.brandDefault.opacity(0.08) : Color.bgSecondary)
            .accessibilityElement(children: .combine)
    }

    // MARK: - 热门寺院（横滑，标题可点击进完整列表）
    private var hotTemplesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            NavigationLink(value: HomeRoute.templeList) {
                HStack {
                    Text("热门寺院")
                        .font(AppTypography.reading.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(AppTypography.caption.weight(.semibold))
                        .foregroundStyle(Color.accentDefault)
                }
                .padding(.horizontal, 20)
            }
            .buttonStyle(CardPressButtonStyle())

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.md) {
                    if viewModel.isLoading && viewModel.hotTemples.isEmpty {
                        ForEach(0..<3) { _ in DFLoadingCard().frame(width: 168) }
                    }
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
                    .font(AppTypography.micro.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(templeTypeColor(temple.type).opacity(0.85))
                    .clipShape(Capsule())
                    .padding(8)
            }

            VStack(spacing: 4) {
                HStack {
                    Text(temple.name)
                        .font(AppTypography.body.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer()
                    Text("★ \(temple.ratingText)")
                        .font(AppTypography.micro.weight(.medium))
                        .foregroundStyle(Color.accentDefault)
                }
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(AppTypography.micro)
                        .foregroundStyle(Color.textTertiary)
                    Text(temple.region)
                        .font(AppTypography.micro)
                        .foregroundStyle(Color.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer()
                }
                if !temple.serviceTagsText.isEmpty || temple.serviceCountText != nil {
                    HStack {
                        if !temple.serviceTagsText.isEmpty {
                            Text(temple.serviceTagsText)
                                .font(AppTypography.micro)
                                .foregroundStyle(Color.textSecondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        if let countText = temple.serviceCountText {
                            Text(countText)
                                .font(AppTypography.micro.weight(.medium))
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
        .appCardSurface(cornerRadius: 12)
    }

    /// 寺院类型标签颜色：道教用紫色，其他用品牌色
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
                        .font(AppTypography.reading.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(AppTypography.caption.weight(.semibold))
                        .foregroundStyle(Color.accentDefault)
                }
                .padding(.horizontal, 20)
            }
            .buttonStyle(CardPressButtonStyle())

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.md) {
                    if viewModel.isLoading && viewModel.hotMasters.isEmpty {
                        ForEach(0..<3) { _ in DFLoadingCard(avatar: true).frame(width: 188) }
                    }
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
                .font(AppTypography.body.weight(.semibold))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            // 宗派标签 + 寺院
            HStack(spacing: 4) {
                if !master.sect.isEmpty {
                    Text(master.sect)
                        .font(AppTypography.micro)
                        .foregroundStyle(Color.accentDefault)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .overlay(Capsule().stroke(Color.accentDefault.opacity(0.25), lineWidth: 1))
                }
                Text(master.templeName)
                    .font(AppTypography.micro)
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            // 专长标签
            Text(master.specialtiesText)
                .font(AppTypography.micro)
                .foregroundStyle(Color.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            // 评分
            HStack(spacing: 2) {
                Image(systemName: "star.fill")
                    .font(AppTypography.micro)
                    .foregroundStyle(Color.accentDefault)
                Text(master.ratingText)
                    .font(AppTypography.micro.weight(.medium))
                    .foregroundStyle(Color.accentDefault)
            }

            // 底部：专长 + 价格
            if !master.specialtiesText.isEmpty || master.startPriceText != nil {
                HStack {
                    if !master.specialtiesText.isEmpty {
                        Text(master.specialtiesText)
                            .font(AppTypography.micro)
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    if let price = master.startPriceText {
                        Text(price)
                            .font(AppTypography.micro.weight(.semibold))
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
        .appCardSurface(cornerRadius: 12)
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
                    ContentUnavailableView("暂时无法读取", systemImage: "wifi.exclamationmark", description: Text(message))
                    Button("重试") { Task { await viewModel.load() } }
                        .buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
                } else if viewModel.resources.isEmpty {
                    ContentUnavailableView("暂无匹配内容", systemImage: "square.grid.2x2")
                } else {
                    Text("相关寺院服务与大师服务")
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
        .navigationTitle(entry.title)
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
                    Text(heroTitle)
                        .font(AppTypography.title(22))
                        .foregroundStyle(Color.textPrimary)
                    Text(heroSummary)
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
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderDefault, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 20)
    }

    private var actionLabel: some View {
        Label(heroActionTitle, systemImage: "arrow.right.circle.fill")
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
                Text(resourceTypeLabel(item.resourceType))
                    .font(AppTypography.micro.weight(.semibold)).foregroundStyle(Color.accentDefault)
                Text(item.title).font(AppTypography.body.weight(.semibold)).foregroundStyle(Color.textPrimary).lineLimit(2)
                Text(item.subtitle).font(AppTypography.caption).foregroundStyle(Color.textSecondary).lineLimit(1)
                Text("¥\(Int(item.price))").font(AppTypography.body.weight(.semibold)).foregroundStyle(Color.brandDefault)
            }
            Spacer()
            Image(systemName: "chevron.right").font(AppTypography.caption).foregroundStyle(Color.textTertiary)
        }
        .padding(10).background(Color.bgSecondary)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderDefault, lineWidth: 1))
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
            MasterProfileView(masterId: item.masterCode ?? "")
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
                    Text(viewModel.profile?.name ?? entry.title)
                        .font(AppTypography.title(28))
                    Text(viewModel.profile?.summary ?? entry.subtitle)
                        .font(AppTypography.body.weight(.semibold))
                        .foregroundStyle(Color.accentDefault)
                    Text(viewModel.profile?.description ?? "正在读取流派简介")
                        .font(AppTypography.body)
                        .foregroundStyle(Color.textSecondary)
                        .lineSpacing(5)
                }
                .padding(.horizontal, 20)

                topicSection(title: "该流派大师", more: .masterBelief(entry.id)) {
                    ForEach(viewModel.masters.prefix(4)) { master in
                        NavigationLink(value: master) {
                            HStack(spacing: 12) {
                                RemoteImage(urlString: master.avatar, placeholderIcon: "person.fill")
                                    .frame(width: 52, height: 52).clipShape(Circle())
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(master.dharmaName).font(AppTypography.body.weight(.semibold))
                                    Text("\(master.sect) · \(master.templeName)").font(AppTypography.caption).foregroundStyle(Color.textTertiary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(Color.textTertiary)
                            }.padding(.vertical, 6)
                        }.buttonStyle(CardPressButtonStyle())
                    }
                }

                topicSection(title: "该流派寺庙", more: .templeBelief(entry.id)) {
                    ForEach(viewModel.temples.prefix(4)) { temple in
                        NavigationLink(value: temple) {
                            HStack(spacing: 12) {
                                RemoteImage(urlString: temple.coverImage, placeholderIcon: "building.2.fill")
                                    .frame(width: 72, height: 52).clipShape(RoundedRectangle(cornerRadius: 6))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(temple.name).font(AppTypography.body.weight(.semibold))
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
        .navigationTitle(entry.title)
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if viewModel.isLoading { ProgressView() } }
        .task { await viewModel.load(code: entry.id) }
    }

    private func topicSection<Content: View>(title: String, more: HomeRoute, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(AppTypography.title(19))
                Spacer()
                NavigationLink(value: more) { Text("更多").font(AppTypography.supporting).foregroundStyle(Color.accentDefault) }
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
    private var parts: [String] { route.split(separator: "/").map(String.init) }
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
            case "ai": AiDivinationView().requireAuth(title: "登录后开启 AI 问事")
            case "shop":
                if identifier == nil { ShopView() }
                else if let product { ShopProductDetailView(product: product) }
                else { VStack { DFTopNavBar(title); Spacer(); if loading { ProgressView() } else { Text(error ?? "商品暂时无法加载"); Button("重试") { Task { await loadProduct() } } }; Spacer() } }
            case "services":
                if let id = identifier, let type = ServiceType.from(serviceCode: id) { ServiceContainerView(serviceType: type) }
                else { ScrollView { VStack { DFTopNavBar("预约服务"); ForEach(ServiceType.allCases, id: \.self) { type in NavigationLink { ServiceContainerView(serviceType: type) } label: { HStack { Text(type.rawValue); Spacer(); Image(systemName: "chevron.right") }.padding(18).background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12)) } } }.padding(.horizontal, 16) } }
            case "rewards":
                if let id = identifier.flatMap(Int64.init) { RewardDetailView(id: id) } else { RewardsView() }
            case "activities":
                if let id = identifier { NativeMarketingActivityView(id: id) }
            default: DFEmptyState(icon: "link", title: "推荐已更新", subtitle: "请返回首页刷新后查看")
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
                        Text(activity.name).font(AppTypography.title(28))
                        Text("活动时间（北京时间）\n\(activity.startTime.isEmpty ? "即日起" : activity.startTime) — \(activity.endTime.isEmpty ? "长期有效" : activity.endTime)").font(AppTypography.supporting).foregroundStyle(Color.textSecondary)
                        if let location = details?.location { Text("活动地点：" + location) }
                        Text(details?.description ?? "活动具体安排请以主办方公布的信息为准。").lineSpacing(6)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
                }
            } else if let error { ContentUnavailableView { Label("活动暂时无法加载", systemImage: "wifi.exclamationmark") } description: { Text(error) } actions: { Button("重试") { Task { await load() } } } }
            else { Spacer(); ProgressView(); Spacer() }
        }.background(Color.bgPrimary).toolbar(.hidden, for: .navigationBar).task { await load() }
    }
    private func load() async {
        error = nil
        do { activity = try await APIClient.shared.request(.marketingActivity(id)) }
        catch { self.error = error.localizedDescription }
    }
}
