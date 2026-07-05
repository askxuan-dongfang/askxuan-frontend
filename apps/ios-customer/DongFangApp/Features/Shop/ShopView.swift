//
//  ShopView.swift
//  DongFangApp
//
//  商城列表页：顶部搜索栏 + promo banner + 分类图标横滑 + 商品瀑布网格。
//  对齐产品原型 shop.html。作为主 Tab 之一。
//

import SwiftUI

struct ShopView: View {
    @StateObject private var viewModel = ShopViewModel()

    var body: some View {
        VStack(spacing: 0) {
            topBar
            searchBar
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    promoBanner
                    categoryBar
                    content
                }
                .padding(.bottom, AppSpacing.navBottom)
            }
            .softScrollEdge(.bottom)
        }
        .background(Color.bgPrimary)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if viewModel.products.isEmpty { await viewModel.load() }
        }
        .refreshable { await viewModel.load() }
    }

    // MARK: - 顶部栏（标题 + 购物车）
    private var topBar: some View {
        ZStack {
            Text("商城")
                .font(.custom(AppFont.serif[0], size: 17).weight(.bold))
                .foregroundStyle(.accentDefault)

            HStack {
                Spacer()
                cartButton
            }
        }
        .frame(height: 44)
        .padding(.horizontal, AppSpacing.lg)
    }

    private var cartButton: some View {
        Button {
            // TODO: 跳转购物车
        } label: {
            Image(systemName: "cart")
                .font(.system(size: 20))
                .foregroundStyle(.textPrimary)
                .overlay(alignment: .topTrailing) {
                    if viewModel.cartCount > 0 {
                        Text("\(viewModel.cartCount)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 16, minHeight: 16)
                            .padding(.horizontal, 3)
                            .background(Color.brandDefault)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.bgPrimary, lineWidth: 1.5))
                            .offset(x: 10, y: -8)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 搜索栏
    private var searchBar: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(.textTertiary)
            TextField("搜索佛珠/香道/护身符...", text: $viewModel.keyword)
                .font(.system(size: 13))
                .foregroundStyle(.textPrimary)
                .submitLabel(.search)
                .onSubmit { viewModel.search() }
            if !viewModel.keyword.isEmpty {
                Button {
                    viewModel.keyword = ""
                    viewModel.search()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .frame(height: 36)
        .background(Color.bgSecondary)
        .overlay(Capsule().stroke(Color.borderDefault, lineWidth: 1))
        .clipShape(Capsule())
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.sm)
    }

    // MARK: - Promo Banner
    private var promoBanner: some View {
        Button {
            // TODO: 跳转促销落地页
        } label: {
            ZStack(alignment: .leading) {
                LinearGradient(
                    colors: [Color.brandDefault, Color(hex: "7A2E1A"), Color(hex: "3A1A10")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text("新春福运礼盒")
                        .font(.custom(AppFont.serif[0], size: 20).weight(.bold))
                        .foregroundStyle(.white)
                    Text("精选开光好物 · 福泽满堂")
                        .font(.system(size: 13))
                        .foregroundStyle(.accentDefault)
                    Text("立即抢购")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.2))
                        .overlay(Capsule().stroke(Color.white.opacity(0.4), lineWidth: 1))
                        .clipShape(Capsule())
                        .padding(.top, 6)
                }
                .padding(.horizontal, 20)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
        }
        .buttonStyle(.plain)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.sm)
    }

    // MARK: - 分类图标横滑
    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(viewModel.shopCategories) { cat in
                    let isSelected = viewModel.selectedCategoryId == cat.id
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            viewModel.selectCategory(cat.id)
                        }
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(isSelected ? Color.brandDefault : Color.bgSecondary)
                                    .frame(width: 44, height: 44)
                                Image(systemName: cat.icon)
                                    .font(.system(size: 20))
                                    .foregroundStyle(isSelected ? Color.white : Color.textTertiary)
                            }
                            Text(cat.name)
                                .font(.system(size: 11))
                                .foregroundStyle(isSelected ? Color.brandDefault : Color.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.lg)
        }
    }

    // MARK: - 内容区
    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.products.isEmpty {
            DFLoadingView()
                .frame(height: 240)
        } else if viewModel.products.isEmpty {
            DFEmptyState(icon: "bag", title: "暂无商品", subtitle: "下拉刷新试试")
                .frame(height: 240)
        } else {
            productGrid
        }
    }

    // MARK: - 商品瀑布网格（2列）
    private var productGrid: some View {
        let left = viewModel.products.indices.filter { $0 % 2 == 0 }.map { viewModel.products[$0] }
        let right = viewModel.products.indices.filter { $0 % 2 != 0 }.map { viewModel.products[$0] }

        return HStack(alignment: .top, spacing: AppSpacing.lg) {
            LazyVStack(spacing: AppSpacing.lg) {
                ForEach(left) { productCard($0) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            LazyVStack(spacing: AppSpacing.lg) {
                ForEach(right) { productCard($0) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.sm)
    }

    // MARK: - 商品卡片
    private func productCard(_ product: ShopProduct) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 图片（正方形）+ 标签
            ZStack(alignment: .topLeading) {
                RemoteImage(urlString: imageAsset(for: product),
                            placeholderIcon: "bag.fill",
                            contentMode: .fill)
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipped()

                if let tag = firstTag(product) {
                    Text(tag)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.brandDefault)
                        .clipShape(Capsule())
                        .padding(8)
                }
            }

            // 名称 + 价格 + 销量
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.system(size: 13))
                    .foregroundStyle(.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(height: 36, alignment: .top)

                HStack(alignment: .bottom) {
                    Text(product.priceText)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.brandDefault)
                    Spacer()
                    Text(salesText(product.stock))
                        .font(.system(size: 11))
                        .foregroundStyle(.textTertiary)
                }
            }
            .padding(10)
        }
        .background(Color.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .contentShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .onTapGesture {
            // TODO: 跳转商品详情
        }
    }

    // MARK: - 辅助方法

    /// 商品图片：优先用 ImageMapper 映射本地 asset，否则使用 mainImage（URL 或 asset 名）
    private func imageAsset(for product: ShopProduct) -> String {
        if product.mainImage.hasPrefix("http") { return product.mainImage }
        if let mapped = ImageMapper.productImage(for: product.name) { return mapped }
        return product.mainImage
    }

    /// 取首个标签
    private func firstTag(_ product: ShopProduct) -> String? {
        guard let tags = product.tags, !tags.isEmpty else { return nil }
        return tags.split(separator: ",").first.map(String.init)
    }

    /// 格式化销量（千分位）
    private func salesText(_ count: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return "已售 \(f.string(from: NSNumber(value: count)) ?? "\(count)")"
    }
}

#Preview {
    NavigationStack { ShopView() }
        .preferredColorScheme(.dark)
}
