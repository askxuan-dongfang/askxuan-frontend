//
//  HomeView.swift
//  DongFangApp
//
//  首页：顶部品牌名 + 搜索框 + Banner 轮播 + 双入口 + 热门服务 + 热门寺院 + 热门师傅。
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var searchText: String = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.lg) {
                // 1. 顶部品牌名 + 搜索框
                headerSection

                // 2. Banner 轮播
                DFBannerCarousel(banners: viewModel.banners)
                    .padding(.horizontal, AppSpacing.lg)

                // 3. 找寺院 / 找师傅 双入口
                entryCardsSection
                    .padding(.horizontal, AppSpacing.lg)

                // 4. 热门服务 8 宫格
                hotServicesSection

                // 5. 热门寺院横向滚动
                hotTemplesSection

                // 6. 热门师傅横向滚动
                hotMastersSection

                Spacer(minLength: AppSpacing.xl)
            }
            .padding(.top, AppSpacing.sm)
        }
        .background(Color.bgPrimary)
        .navigationBarHidden(true)
        .task {
            if viewModel.hotTemples.isEmpty {
                await viewModel.load()
            }
        }
        .refreshable {
            await viewModel.load()
        }
        // 导航路由：寺院详情 / 师傅详情 / 寺院列表 / 师傅列表
        .navigationDestination(for: Temple.self) { temple in
            TempleDetailView(templeId: temple.id, templeName: temple.name)
        }
        .navigationDestination(for: Master.self) { master in
            MasterProfileView(masterId: master.id)
        }
        .navigationDestination(for: HomeRoute.self) { route in
            switch route {
            case .templeList:
                TempleListView()
            case .masterList:
                MasterListView()
            }
        }
    }

    // MARK: - 顶部品牌 + 搜索
    private var headerSection: some View {
        HStack(spacing: 12) {
            Text("问玄东方")
                .font(.brandTitle)
                .foregroundStyle(Color.accentDefault)

            Spacer()

            // 搜索按钮样式（MVP-1 仅样式，不实现搜索页）
            Button {} label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.accentDefault)
                    .frame(width: 36, height: 36)
                    .background(Color.clear)
                    .overlay(
                        Circle().stroke(Color.accentDefault, lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.sm)
    }

    // MARK: - 双入口卡片
    private var entryCardsSection: some View {
        HStack(spacing: AppSpacing.md) {
            NavigationLink(value: HomeRoute.templeList) {
                entryCard(imageName: "entry-temple", title: "找寺院", icon: "building.2.fill")
            }
            NavigationLink(value: HomeRoute.masterList) {
                entryCard(imageName: "entry-master", title: "找师傅", icon: "person.circle.fill")
            }
        }
    }

    private func entryCard(imageName: String, title: String, icon: String) -> some View {
        ZStack {
            // 背景图
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 120)
                .clipped()

            // 半透明渐变叠加
            LinearGradient(
                colors: [
                    Color.bgPrimary.opacity(0.65),
                    Color.bgPrimary.opacity(0.35)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // 图标 + 标题
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundStyle(Color.accentDefault)
                Text(title)
                    .font(.custom(AppFont.serif, size: 16).weight(.semibold))
                    .foregroundStyle(Color.accentDefault)
            }
        }
        .frame(height: 120)
        .cornerRadius(AppRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(Color.borderDefault, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }

    // MARK: - 热门服务 8 宫格
    private var hotServicesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("热门服务")
                    .font(.sectionTitle)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                NavigationLink(value: HomeRoute.masterList) {
                    HStack(spacing: 2) {
                        Text("更多")
                            .font(.caption)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(Color.accentDefault)
                }
            }
            .padding(.horizontal, AppSpacing.lg)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.md), count: 4),
                      spacing: AppSpacing.lg) {
                ForEach(viewModel.hotServices) { service in
                    serviceItem(service)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
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
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(Circle().stroke(Color.borderDefault, lineWidth: 1))

                Image(systemName: service.iconName)
                    .font(.system(size: 18))
                    .foregroundStyle(Color.accentDefault)
            }
            .frame(width: 48, height: 48)

            Text(service.rawValue)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 热门寺院横向滚动
    private var hotTemplesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("热门寺院")
                .font(.sectionTitle)
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, AppSpacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.md) {
                    ForEach(viewModel.hotTemples) { temple in
                        NavigationLink(value: temple) {
                            templeCard(temple)
                        }
                    }
                    // 查看更多
                    NavigationLink(value: HomeRoute.templeList) {
                        moreCard
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
            }
        }
    }

    private func templeCard(_ temple: Temple) -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                Image(temple.assetImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 180, height: 110)
                    .clipped()

                Text(temple.type)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.brandDefault.opacity(0.85))
                    .clipShape(Capsule())
                    .padding(8)
            }

            VStack(spacing: 4) {
                HStack {
                    Text(temple.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
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
            }
            .padding(AppSpacing.sm)
        }
        .frame(width: 180)
        .background(Color.bgSecondary)
        .cornerRadius(AppRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(Color.borderDefault, lineWidth: 1)
        )
    }

    // MARK: - 热门师傅横向滚动
    private var hotMastersSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("热门师傅")
                .font(.sectionTitle)
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, AppSpacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.md) {
                    ForEach(viewModel.hotMasters) { master in
                        NavigationLink(value: master) {
                            masterCard(master)
                        }
                    }
                    NavigationLink(value: HomeRoute.masterList) {
                        moreCard
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
            }
        }
    }

    private func masterCard(_ master: Master) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Image(master.avatarAssetName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(Color.accentDefault, lineWidth: 2)
                    )
                if master.isOnlineDisplay {
                    Circle()
                        .fill(Color.stateSuccess)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.bgSecondary, lineWidth: 2))
                        .offset(x: 20, y: 20)
                }
            }
            .padding(.top, 4)

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
        .frame(width: 80)
        .padding(.vertical, AppSpacing.sm)
        .background(Color.bgSecondary)
        .cornerRadius(AppRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(Color.borderDefault, lineWidth: 1)
        )
    }

    // 查看更多卡片
    private var moreCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "chevron.right")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.brandDefault)
            Text("查看更多")
                .font(.system(size: 12))
                .foregroundStyle(Color.brandDefault)
        }
        .frame(width: 70, height: 160)
        .background(Color.bgSecondary)
        .cornerRadius(AppRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(Color.borderDefault, lineWidth: 1)
        )
    }
}

/// 首页导航路由
enum HomeRoute: Hashable {
    case templeList
    case masterList
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .preferredColorScheme(.dark)
}
