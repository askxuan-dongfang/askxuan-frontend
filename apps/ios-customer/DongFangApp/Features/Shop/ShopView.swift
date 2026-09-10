import SwiftUI

/// 商品导航由后台分类驱动；排序与库存过滤在服务端分页前完成。
struct ShopView: View {
    @StateObject private var viewModel: ShopViewModel
    private let loadsRemoteData: Bool
    init(viewModel: ShopViewModel? = nil, loadsRemoteData: Bool = true) {
        _viewModel = StateObject(wrappedValue: viewModel ?? ShopViewModel())
        self.loadsRemoteData = loadsRemoteData
    }
    @StateObject private var cart = ShopCartStore.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("THE EVERYDAY COLLECTION").font(Font.custom("HelveticaNeue", size: 9, relativeTo: .body)).tracking(1.6).foregroundStyle(Color.textTertiary)
                            Text("好物，有心").font(AppTypography.title(27))
                        }
                        Spacer()
                        NavigationLink { ShopOrderListView() } label: { Text("订单") }
                        NavigationLink { ShopCartView() } label: { Label(cart.itemCount > 0 ? "\(cart.itemCount)" : "购物车", systemImage: "cart") }
                    }.font(Font.custom("HelveticaNeue", size: 13, relativeTo: .body)).foregroundStyle(Color.accentDefault)
                    hero { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { proxy.scrollTo("catalog", anchor: .top) } }
                    HStack(spacing: 12) {
                        NavigationLink { PointsView() } label: { pathway("积分换心意", caption: "日常积累，一份好礼", icon: "gift") }
                        NavigationLink { DiyBraceletView() } label: { pathway("亲手设计一份", caption: "自由选材，随心搭配", icon: "sparkles") }
                    }.buttonStyle(.plain)
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("慢慢逛，好好选").font(AppTypography.title(22))
                            Spacer()
                            Text(viewModel.isLoading ? "寻找好物…" : "\(viewModel.total) 件好物").font(Font.custom("HelveticaNeue", size: 12, relativeTo: .body)).foregroundStyle(Color.textTertiary)
                        }.id("catalog")
                        searchBar
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 9) {
                                ForEach(viewModel.shopCategories) { cat in
                                    Button { viewModel.selectCategory(cat.id) } label: {
                                        Text(cat.name).font(Font.custom("HelveticaNeue", size: 13, relativeTo: .body)).padding(.horizontal, 15).padding(.vertical, 11)
                                            .background(viewModel.selectedCategoryId == cat.id ? Color.accentDefault.opacity(0.2) : Color.bgSecondary)
                                            .clipShape(Capsule()).overlay(Capsule().stroke(viewModel.selectedCategoryId == cat.id ? Color.accentDefault : Color.borderDefault))
                                    }.accessibilityAddTraits(viewModel.selectedCategoryId == cat.id ? .isSelected : [])
                                }
                            }
                        }.buttonStyle(.plain).foregroundStyle(Color.accentDefault)
                        if let message = viewModel.categoryError { Button(message) { Task { await viewModel.loadCategories() } }.font(Font.custom("HelveticaNeue", size: 12, relativeTo: .body)) }
                        HStack {
                            Picker("商品排序", selection: $viewModel.sort) {
                                Text("最新商品").tag("newest"); Text("价格从低到高").tag("price_asc"); Text("价格从高到低").tag("price_desc")
                            }.tint(Color.accentDefault).onChange(of: viewModel.sort) { _, _ in viewModel.search() }
                            Spacer()
                            Toggle("只看有货", isOn: $viewModel.inStock).font(Font.custom("HelveticaNeue", size: 12, relativeTo: .body)).fixedSize().tint(Color.accentDefault)
                                .onChange(of: viewModel.inStock) { _, _ in viewModel.search() }
                        }
                        if let message = viewModel.errorMessage {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(message).font(Font.custom("HelveticaNeue", size: 13, relativeTo: .body))
                                Button("重新加载") { Task { if viewModel.products.isEmpty { await viewModel.load() } else { await viewModel.loadMore() } } }
                            }.foregroundStyle(Color.accentDefault).padding(16).frame(maxWidth: .infinity, alignment: .leading).background(Color.bgSecondary).clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        if viewModel.isLoading { DFLoadingView().frame(maxWidth: .infinity, minHeight: 200) }
                        else if viewModel.products.isEmpty && viewModel.errorMessage == nil {
                            VStack(spacing: 12) { Text("这次还没有找到").font(AppTypography.title(20)); Text("换个关键词，或看看其他分类。").font(Font.custom("HelveticaNeue", size: 13, relativeTo: .body)); Button("查看全部好物") { viewModel.reset() } }.frame(maxWidth: .infinity).padding(.vertical, 42)
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) { ForEach(viewModel.products) { productCard($0) } }
                            if viewModel.hasMore {
                                Button { Task { await viewModel.loadMore() } } label: { Text(viewModel.isLoadingMore ? "正在加载…" : "再看看 · 已展示 \(viewModel.products.count) / \(viewModel.total)").font(Font.custom("HelveticaNeue", size: 13, relativeTo: .body)).frame(maxWidth: .infinity).padding(16) }.disabled(viewModel.isLoadingMore)
                            }
                        }
                    }
                }.padding(18).padding(.bottom, AppSpacing.navBottom)
            }.softScrollEdge(.bottom)
        }.background(Color.bgPrimary).foregroundStyle(Color.textPrimary)
            .toolbar(.hidden, for: .navigationBar)
            .task { if loadsRemoteData { if viewModel.products.isEmpty { await viewModel.load() }; await viewModel.loadCategories() } }
            .refreshable { if loadsRemoteData { await viewModel.load(); await viewModel.loadCategories() } }
    }
    private func hero(action: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 15) {
                Text("一份心意 · 一种日常").font(Font.custom("HelveticaNeue", size: 12, relativeTo: .body)).foregroundStyle(Color.accentDefault)
                Text("把喜欢的，\n留在生活里。").font(AppTypography.title(30))
                Text("从随身小物，到案头清欢。\n慢慢挑选，与心意相逢。").font(Font.custom("HelveticaNeue", size: 13, relativeTo: .body)).lineSpacing(5).foregroundStyle(Color.textSecondary)
                Button(action: action) { Text("逛逛好物 ↓").font(Font.custom("HelveticaNeue", size: 13, relativeTo: .body)).padding(.vertical, 11).padding(.horizontal, 18).overlay(Capsule().stroke(Color.accentDefault.opacity(0.5))) }.tint(Color.accentDefault)
            }
            Spacer(minLength: 0)
            ZStack {
                Circle().stroke(Color.accentDefault.opacity(0.2)).frame(width: 92, height: 92)
                ForEach(0..<12) { i in Circle().fill(Color.accentDefault.opacity(0.6)).frame(width: 14, height: 14).offset(y: -37).rotationEffect(.degrees(Double(i) * 30)) }
                Text("缘").font(AppTypography.title(25)).foregroundStyle(Color.accentDefault)
            }.frame(width: 96).accessibilityHidden(true)
        }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [Color.accentDefault.opacity(0.2), Color.bgSecondary], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 24)).overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.accentDefault.opacity(0.3)))
    }
    private func pathway(_ title: String, caption: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).foregroundStyle(Color.accentDefault)
            Text(title).font(AppTypography.title(17)).foregroundStyle(Color.textPrimary)
            Text(caption).font(Font.custom("HelveticaNeue", size: 11, relativeTo: .body)).foregroundStyle(Color.textTertiary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(16).background(Color.bgSecondary).clipShape(RoundedRectangle(cornerRadius: 18))
    }
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Color.textTertiary)
            TextField("搜一件喜欢的好物", text: $viewModel.keyword).submitLabel(.search).onSubmit { viewModel.search() }
            if !viewModel.keyword.isEmpty { Button { viewModel.keyword = ""; viewModel.search() } label: { Image(systemName: "xmark.circle.fill") }.accessibilityLabel("清除搜索") }
            Button("搜索") { viewModel.search() }.tint(Color.accentDefault)
        }.font(Font.custom("HelveticaNeue", size: 14, relativeTo: .body)).padding(14).background(Color.bgSecondary).clipShape(RoundedRectangle(cornerRadius: 15)).overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.borderDefault))
    }
    private func productCard(_ product: ShopProduct) -> some View {
        NavigationLink { ShopProductDetailView(product: product) } label: {
            VStack(alignment: .leading, spacing: 0) {
                RemoteImage(urlString: product.mainImage, placeholderIcon: "bag", contentMode: .fill)
                    .aspectRatio(1, contentMode: .fit).clipped()
                    .overlay(alignment: .topLeading) {
                        if product.stock <= 0 { badge("暂时售罄") }
                        else if let tag = product.tags?.split(whereSeparator: { $0 == "," || $0 == "，" }).first { badge(String(tag)) }
                    }
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.shopCategories.first(where: { $0.id == product.categoryId })?.name ?? "东方好物").font(Font.custom("HelveticaNeue", size: 10, relativeTo: .body)).foregroundStyle(Color.textTertiary).lineLimit(1)
                    Text(product.name).font(AppTypography.title(17)).lineLimit(2).frame(height: 44, alignment: .top)
                    Text(product.description).font(Font.custom("HelveticaNeue", size: 11, relativeTo: .body)).foregroundStyle(Color.textTertiary).lineLimit(1)
                    Text(product.priceText).font(Font.custom("HelveticaNeue", size: 18, relativeTo: .body).weight(.semibold)).foregroundStyle(Color.accentDefault).monospacedDigit()
                }.padding(13).frame(maxWidth: .infinity, alignment: .leading)
            }.background(Color.bgSecondary).clipShape(RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.borderDefault))
        }.buttonStyle(.plain)
    }
    private func badge(_ text: String) -> some View { Text(text).font(Font.custom("HelveticaNeue", size: 10, relativeTo: .body)).padding(7).background(Color.bgPrimary.opacity(0.85)).clipShape(Capsule()).padding(8) }
}

struct ShopProductDetailView: View {
    @StateObject private var viewModel: ShopProductDetailViewModel
    @StateObject private var cart = ShopCartStore.shared
    @State private var selectedSkuId: Int64?
    @State private var quantity = 1
    @State private var showCart = false
    @State private var added = false
    @State private var isFavorited = false

    init(product: ShopProduct) {
        _viewModel = StateObject(wrappedValue: ShopProductDetailViewModel(product: product))
    }

    // MARK: - 收藏
    private func syncFavoriteState() async {
        if let resp: ProductFavoritesResponse = try? await APIClient.shared.request(.productFavorites) {
            isFavorited = resp.list.contains { $0.id == viewModel.product.id }
        }
    }

    private func toggleFavorite() {
        let target = !isFavorited
        isFavorited = target
        Task {
            do {
                if target {
                    let _: FavoriteResponse = try await APIClient.shared.request(.productFavorite(viewModel.product.id))
                } else {
                    let _: FavoriteResponse = try await APIClient.shared.request(.productUnfavorite(viewModel.product.id))
                }
            } catch {
                isFavorited = !target
            }
        }
    }

    private var selectedSku: ProductSku? {
        guard let selectedSkuId else { return viewModel.product.skus?.first }
        return viewModel.product.skus?.first { $0.id == selectedSkuId }
    }

    private var availableStock: Int { selectedSku?.stock ?? viewModel.product.stock }
    private var unitPrice: Double { selectedSku?.price ?? viewModel.product.price }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                RemoteImage(urlString: imageAsset,
                            placeholderIcon: "bag.fill", contentMode: .fill)
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipped()

                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text(viewModel.product.name)
                        .font(AppTypography.title(24))
                        .foregroundStyle(.textPrimary)
                    HStack(alignment: .firstTextBaseline) {
                        Text("¥\(unitPrice, specifier: "%.2f")")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.brandDefault)
                        if let market = viewModel.product.marketPrice, market > unitPrice {
                            Text("¥\(market, specifier: "%.2f")")
                                .font(.system(size: 13))
                                .foregroundStyle(.textTertiary)
                                .strikethrough()
                        }
                        Spacer()
                        Text(availableStock > 0 ? "库存 \(availableStock)" : "暂时缺货")
                            .font(.system(size: 12))
                            .foregroundStyle(availableStock > 0 ? Color.textTertiary : Color.stateError)
                    }

                    if let skus = viewModel.product.skus, !skus.isEmpty {
                        Text("选择规格")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.textPrimary)
                        FlowLayout(spacing: AppSpacing.sm) {
                            ForEach(skus) { sku in
                                Button {
                                    selectedSkuId = sku.id
                                    quantity = min(quantity, max(1, sku.stock))
                                } label: {
                                    Text("\(sku.specName) · \(sku.specValue)")
                                        .font(.system(size: 12))
                                        .foregroundStyle(selectedSku?.id == sku.id ? Color.white : Color.textSecondary)
                                        .padding(.horizontal, 12).padding(.vertical, 8)
                                        .background(selectedSku?.id == sku.id ? Color.brandDefault : Color.bgTertiary)
                                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                                }
                                .buttonStyle(.plain)
                                .disabled(sku.stock <= 0)
                                .opacity(sku.stock > 0 ? 1 : 0.4)
                            }
                        }
                    }

                    HStack {
                        Text("数量")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.textPrimary)
                        Spacer()
                        quantityStepper
                    }

                    Divider().overlay(Color.borderDefault)
                    Text("商品说明")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.textPrimary)
                    Text(viewModel.product.description)
                        .font(.system(size: 14))
                        .foregroundStyle(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let message = viewModel.errorMessage {
                        Text(message).font(.system(size: 12)).foregroundStyle(.stateWarning)
                        Button("重新加载商品") { Task { await viewModel.load() } }
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, 92)
            }
        }
        .background(Color.bgPrimary)
        .navigationTitle("商品详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    toggleFavorite()
                } label: {
                    Image(systemName: isFavorited ? "heart.fill" : "heart")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isFavorited ? Color.brandDefault : Color.accentDefault)
                }
                .buttonStyle(.plain)
            }
        }
        .task { await syncFavoriteState() }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: AppSpacing.md) {
                Button { showCart = true } label: {
                    Image(systemName: "cart")
                        .font(.system(size: 20))
                        .foregroundStyle(.accentDefault)
                        .frame(width: 44, height: 44)
                        .background(Color.bgTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                        .overlay(alignment: .topTrailing) {
                            if cart.itemCount > 0 {
                                Text("\(cart.itemCount)").font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.white).padding(5).background(Color.brandDefault).clipShape(Circle())
                            }
                        }
                }.buttonStyle(.plain)
                DFPrimaryButton(title: added ? "已加入购物车" : "加入购物车", icon: added ? "checkmark" : "cart.badge.plus",
                                isEnabled: viewModel.verified && !viewModel.isLoading && availableStock > 0 && viewModel.product.status == "on_shelf") {
                    cart.add(product: viewModel.product, sku: selectedSku, quantity: quantity)
                    withAnimation { added = true }
                }
            }
            .padding(.horizontal, AppSpacing.lg).padding(.vertical, AppSpacing.sm)
            .background(.ultraThinMaterial)
        }
        .navigationDestination(isPresented: $showCart) { ShopCartView() }
        .task {
            await viewModel.load()
            selectedSkuId = viewModel.product.skus?.first(where: { $0.stock > 0 })?.id
        }
    }

    private var imageAsset: String {
        if viewModel.product.mainImage.hasPrefix("http") { return viewModel.product.mainImage }
        return ImageMapper.productImage(for: viewModel.product.name) ?? viewModel.product.mainImage
    }

    private var quantityStepper: some View {
        HStack(spacing: 0) {
            Button { quantity = max(1, quantity - 1) } label: {
                Image(systemName: "minus").frame(width: 36, height: 34)
            }
            Text("\(quantity)").frame(width: 42, height: 34).monospacedDigit()
            Button { quantity = min(availableStock, quantity + 1) } label: {
                Image(systemName: "plus").frame(width: 36, height: 34)
            }
        }
        .font(.system(size: 13, weight: .semibold)).foregroundStyle(.textPrimary)
        .background(Color.bgTertiary).clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
    }
}

struct ShopCartView: View {
    @StateObject private var cart = ShopCartStore.shared

    var body: some View {
        Group {
            if cart.items.isEmpty {
                DFEmptyState(icon: "cart", title: "购物车是空的", subtitle: "挑选一件心仪好物吧")
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: AppSpacing.md) {
                        ForEach(cart.items) { item in cartRow(item) }
                    }
                    .padding(AppSpacing.lg).padding(.bottom, 84)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgPrimary)
        .navigationTitle("购物车")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if !cart.items.isEmpty {
                HStack(spacing: AppSpacing.lg) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("合计").font(.system(size: 11)).foregroundStyle(.textTertiary)
                        Text("¥\(cart.total, specifier: "%.2f")")
                            .font(.system(size: 20, weight: .semibold)).foregroundStyle(.brandDefault)
                    }
                    NavigationLink { ShopCheckoutView() } label: {
                        Label("去结算", systemImage: "creditcard")
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 44)
                            .background(Color.brandDefault)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                    }
                }
                .padding(.horizontal, AppSpacing.lg).padding(.vertical, AppSpacing.sm)
                .background(.ultraThinMaterial)
            }
        }
    }

    private func cartRow(_ item: ShopCartItem) -> some View {
        HStack(spacing: AppSpacing.md) {
            RemoteImage(urlString: imageAsset(item), placeholderIcon: "bag.fill", contentMode: .fill)
                .frame(width: 76, height: 76).clipped()
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
            VStack(alignment: .leading, spacing: 5) {
                Text(item.productName).font(.system(size: 14, weight: .semibold)).foregroundStyle(.textPrimary).lineLimit(2)
                Text(item.skuSpec).font(.system(size: 11)).foregroundStyle(.textTertiary)
                Text("¥\(item.unitPrice, specifier: "%.2f")")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(.brandDefault)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing) {
                Button { cart.remove(item) } label: {
                    Image(systemName: "trash").font(.system(size: 13)).foregroundStyle(.textTertiary)
                }.buttonStyle(.plain)
                Spacer()
                HStack(spacing: 0) {
                    Button { cart.setQuantity(for: item.id, quantity: item.quantity - 1) } label: {
                        Image(systemName: "minus").frame(width: 30, height: 30)
                    }
                    Text("\(item.quantity)").font(.system(size: 12)).frame(width: 30).monospacedDigit()
                    Button { cart.setQuantity(for: item.id, quantity: item.quantity + 1) } label: {
                        Image(systemName: "plus").frame(width: 30, height: 30)
                    }.disabled(item.quantity >= item.stock)
                }
                .foregroundStyle(.textPrimary).background(Color.bgTertiary)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
            }
        }
        .padding(AppSpacing.md).background(Color.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
    }

    private func imageAsset(_ item: ShopCartItem) -> String {
        if item.image.hasPrefix("http") { return item.image }
        return ImageMapper.productImage(for: item.productName) ?? item.image
    }
}

struct ShopCheckoutView: View {
    @EnvironmentObject private var authStore: AuthStore
    @StateObject private var cart = ShopCartStore.shared
    @StateObject private var viewModel = ShopCheckoutViewModel()
    @State private var showResult = false

    var body: some View {
        Group {
            if !authStore.isLoggedIn {
                LoginRequiredView(title: "登录后结算", subtitle: "订单和收货地址将保存到你的账户",
                                  isPresented: .constant(false))
            } else {
                checkoutContent
            }
        }
        .background(Color.bgPrimary)
        .navigationTitle("确认订单")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showResult) {
            if let order = viewModel.completedOrder, let payment = viewModel.payment {
                ShopPaymentResultView(order: order, payment: payment)
            }
        }
        .task { await viewModel.loadAddresses() }
    }

    private var checkoutContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                section(title: "收货地址", icon: "mappin.and.ellipse") {
                    if viewModel.isLoading {
                        ProgressView().tint(.accentDefault).frame(maxWidth: .infinity, minHeight: 70)
                    } else if viewModel.addresses.isEmpty {
                        NavigationLink { AddressListView() } label: {
                            Label("请先添加收货地址", systemImage: "plus.circle")
                                .font(.system(size: 14, weight: .medium)).foregroundStyle(.accentDefault)
                                .frame(maxWidth: .infinity, minHeight: 64)
                        }
                    } else {
                        Picker("收货地址", selection: $viewModel.selectedAddressId) {
                            ForEach(viewModel.addresses) { address in
                                Text("\(address.name) · \(address.fullAddress)").tag(Optional(address.id))
                            }
                        }
                        .pickerStyle(.menu).tint(.accentDefault)
                    }
                }

                section(title: "商品清单", icon: "bag") {
                    VStack(spacing: AppSpacing.sm) {
                        ForEach(cart.items) { item in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.productName).font(.system(size: 13, weight: .medium)).foregroundStyle(.textPrimary)
                                    Text("\(item.skuSpec) × \(item.quantity)").font(.system(size: 11)).foregroundStyle(.textTertiary)
                                }
                                Spacer()
                                Text("¥\(item.subtotal, specifier: "%.2f")")
                                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(.textPrimary)
                            }
                        }
                    }
                }

                section(title: "订单备注", icon: "square.and.pencil") {
                    TextField("选填，给商城留言", text: $viewModel.note, axis: .vertical)
                        .font(.system(size: 13)).foregroundStyle(.textPrimary).lineLimit(2...4)
                }

                VStack(spacing: AppSpacing.sm) {
                    HStack { Text("商品金额"); Spacer(); Text("¥\(cart.total, specifier: "%.2f")") }
                    HStack { Text("运费"); Spacer(); Text("以服务端结算为准") }
                }
                .font(.system(size: 13)).foregroundStyle(.textSecondary)
                .padding(AppSpacing.md).background(Color.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))

                if let error = viewModel.errorMessage {
                    Text(error).font(.system(size: 12)).foregroundStyle(.stateError)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(AppSpacing.lg).padding(.bottom, 84)
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: AppSpacing.md) {
                Text("¥\(cart.total, specifier: "%.2f")")
                    .font(.system(size: 20, weight: .semibold)).foregroundStyle(.brandDefault)
                DFPrimaryButton(title: "提交并模拟支付", icon: "creditcard",
                                isEnabled: viewModel.selectedAddressId != nil && !cart.items.isEmpty,
                                isLoading: viewModel.isSubmitting) {
                    Task {
                        if await viewModel.submit(items: cart.items) {
                            cart.clear()
                            showResult = true
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.lg).padding(.vertical, AppSpacing.sm)
            .background(.ultraThinMaterial)
        }
    }

    private func section<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Label(title, systemImage: icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(.textPrimary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md).background(Color.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
    }
}

struct ShopPaymentResultView: View {
    let order: ShopOrder
    let payment: PaymentRecord

    private var succeeded: Bool { payment.status == "success" }

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()
            Image(systemName: succeeded ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 68)).foregroundStyle(succeeded ? Color.stateSuccess : Color.stateWarning)
            VStack(spacing: AppSpacing.sm) {
                Text(succeeded ? "支付成功" : "支付结果待确认")
                    .font(.system(size: 24, weight: .semibold)).foregroundStyle(.textPrimary)
                Text(succeeded ? "本次使用本地模拟支付，订单已进入待发货流程。" : "支付单已创建，可稍后在订单中查询结果。")
                    .font(.system(size: 13)).foregroundStyle(.textSecondary).multilineTextAlignment(.center)
            }
            VStack(spacing: AppSpacing.sm) {
                resultRow("订单号", order.orderNo)
                resultRow("支付单号", payment.paymentNo)
                resultRow("实付金额", "¥\(String(format: "%.2f", payment.amount))")
                resultRow("支付渠道", payment.channel == "mock" ? "本地模拟支付" : payment.channel)
            }
            .padding(AppSpacing.lg).background(Color.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            NavigationLink { ShopOrderListView() } label: {
                Label("查看商城订单", systemImage: "doc.text")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 44).background(Color.brandDefault)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            }
            Spacer()
        }
        .padding(.horizontal, AppSpacing.xl).background(Color.bgPrimary)
        .navigationTitle("支付结果").navigationBarTitleDisplayMode(.inline)
    }

    private func resultRow(_ label: String, _ value: String) -> some View {
        HStack { Text(label).foregroundStyle(.textTertiary); Spacer(); Text(value).foregroundStyle(.textPrimary) }
            .font(.system(size: 13))
    }
}

struct ShopOrderListView: View {
    @StateObject private var viewModel = ShopOrderListViewModel()
    @State private var selectedStatus: String? = nil
    private let statuses: [(String?, String)] = [(nil, "全部"), ("pending_payment", "待付款"), ("paid", "待发货"), ("shipped", "待收货"), ("completed", "已完成")]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(Array(statuses.enumerated()), id: \.offset) { _, item in
                        Button {
                            selectedStatus = item.0
                            Task { await viewModel.load(status: item.0) }
                        } label: {
                            Text(item.1).font(.system(size: 12, weight: selectedStatus == item.0 ? .semibold : .regular))
                                .foregroundStyle(selectedStatus == item.0 ? Color.white : Color.textSecondary)
                                .padding(.horizontal, 13).padding(.vertical, 8)
                                .background(selectedStatus == item.0 ? Color.brandDefault : Color.bgTertiary)
                                .clipShape(Capsule())
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal, AppSpacing.lg).padding(.vertical, AppSpacing.md)
            }
            Group {
                if viewModel.isLoading && viewModel.orders.isEmpty { DFLoadingView() }
                else if viewModel.orders.isEmpty { DFEmptyState(icon: "doc.text", title: "暂无商城订单", subtitle: viewModel.errorMessage ?? "去商城逛逛吧") }
                else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: AppSpacing.md) {
                            ForEach(viewModel.orders) { order in
                                NavigationLink { ShopOrderDetailView(orderId: order.id) } label: { orderCard(order) }.buttonStyle(.plain)
                            }
                        }.padding(.horizontal, AppSpacing.lg).padding(.bottom, AppSpacing.xl)
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.bgPrimary).navigationTitle("商城订单").navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }.refreshable { await viewModel.load(status: selectedStatus) }
    }

    private func orderCard(_ order: ShopOrder) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text(order.orderNo).font(.system(size: 11)).foregroundStyle(.textTertiary)
                Spacer(); Text(order.statusText).font(.system(size: 12, weight: .medium)).foregroundStyle(.stateWarning)
            }
            Text(order.items?.first?.productName ?? "商城订单")
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(.textPrimary)
            HStack {
                Text(order.createTime).font(.system(size: 11)).foregroundStyle(.textTertiary)
                Spacer(); Text("¥\(order.payAmount, specifier: "%.2f")").font(.system(size: 16, weight: .semibold)).foregroundStyle(.brandDefault)
            }
        }
        .padding(AppSpacing.md).background(Color.bgSecondary).clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
    }
}

struct ShopReturnRecord: Decodable,Identifiable {
    let id:Int64; let returnNo:String; let status:String; let reason:String; let refundAmount:Double
    let carrier:String; let trackingNo:String; let reviewNote:String
    var statusText:String { ["pending_review":"等待审核","approved":"审核通过，请寄回商品","return_shipping":"退货运输中","return_received":"已收货，等待退款","refunding":"退款处理中","completed":"退款完成","rejected":"申请已拒绝"][status] ?? status }
}
struct ShopReturnCreated:Decodable {let id:Int64;let returnNo:String}
struct ShopOrderDetailView: View {
    let orderId:Int64
    @State private var order:ShopOrder?
    @State private var returns:[ShopReturnRecord]=[]
    @State private var errorMessage:String?
    @State private var busy=false
    @State private var reason=""
    @State private var carrier=""
    @State private var tracking=""
    @State private var confirmReceipt=false
    var body:some View {
        List {
            if let order {
                Section("订单进度") {
                    Text(order.statusText).font(.title2.bold()).foregroundStyle(Color.accentDefault)
                    Text(order.orderNo).font(AppTypography.caption).textSelection(.enabled)
                    HStack{Text("订单实付");Spacer();Text(String(format:"¥%.2f",order.payAmount)).bold()}
                    if let logistics=order.logistics,!logistics.trackingNo.isEmpty {Label("\(logistics.expressCompany) · \(logistics.trackingNo)",systemImage:"shippingbox").textSelection(.enabled)}
                }
                Section("商品清单") {ForEach(order.items ?? []) {item in HStack{Text(item.productName);Spacer();Text("×\(item.quantity)");Text(String(format:"¥%.2f",item.price*Double(item.quantity)))}}}
                if order.status=="pending_payment" {Section{Text("继续支付已有订单，不会重新下单。当前为模拟支付。").font(.footnote);Button("继续模拟支付"){Task{await act("pay")}}.disabled(busy)}}
                if order.status=="shipped" {Button("确认收货"){confirmReceipt=true}.disabled(busy)}
                if ["paid","shipped","completed"].contains(order.status) && !returns.contains(where:{$0.status != "rejected"}) {Section("申请售后") {TextField("填写退货或退款原因",text:$reason,axis:.vertical).lineLimit(3...5);Button("提交售后申请"){Task{await act("return")}}.disabled(busy||reason.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)}}
                ForEach(returns){r in Section("售后进度") {
                    Text(r.statusText).font(.headline);Text(r.returnNo).font(AppTypography.caption);Text(r.reason)
                    if !r.reviewNote.isEmpty{Text("审核说明：\(r.reviewNote)")}
                    if !r.trackingNo.isEmpty{Text("\(r.carrier) · \(r.trackingNo)").textSelection(.enabled)}
                    if r.status=="approved"{Text("请先与商家核对退货地址，寄出后填写运单。").font(.footnote);TextField("物流公司",text:$carrier);TextField("运单号",text:$tracking);Button("提交寄回物流"){Task{await act("ship",returnId:r.id)}}.disabled(busy||carrier.isEmpty||tracking.isEmpty)}
                }}
            } else if busy {ProgressView()} else {Text("订单详情尚未加载")}
            if let errorMessage {Text(errorMessage).foregroundStyle(.red)}
            Button("刷新订单进度"){Task{await load()}}.disabled(busy)
        }.scrollContentBackground(.hidden).background(Color.bgPrimary).navigationTitle("订单详情").navigationBarTitleDisplayMode(.inline)
        .task{await load()}.refreshable{await load()}
        .alert("确认已收到商品？",isPresented:$confirmReceipt){Button("返回",role:.cancel){};Button("确认收货"){Task{await act("confirm")}}}
    }
    @MainActor private func load()async{busy=true;defer{busy=false};do{order=try await APIClient.shared.request(.shopOrderById(orderId));returns=try await APIClient.shared.request(.shopReturns(orderId));errorMessage=nil}catch{errorMessage=error.localizedDescription}}
    @MainActor private func act(_ action:String,returnId:Int64=0)async{
        guard !busy,let order else{return};busy=true;errorMessage=nil
        do{
            switch action {
            case "pay":let result:PaymentCreateResult=try await APIClient.shared.request(.paymentCreate(PaymentCreateRequest(orderType:"shop_order",orderNo:order.orderNo,amount:order.payAmount,channel:"mock",userId:AuthStore.shared.userId)));let paid:PaymentRecord=try await APIClient.shared.request(.paymentById(result.id));if paid.status != "success" {errorMessage="支付结果待确认，请刷新订单"}
            case "confirm":let _:ShopOrder=try await APIClient.shared.request(.shopOrderConfirm(orderId))
            case "return":let _:ShopReturnCreated=try await APIClient.shared.request(.shopReturnCreate(orderId,reason));reason=""
            case "ship":let _:PointsActionResult=try await APIClient.shared.request(.shopReturnShip(returnId,carrier,tracking))
            default:break
            }
            await load()
        }catch{errorMessage=error.localizedDescription};busy=false
    }
}

#Preview {
    NavigationStack { ShopView() }
        .preferredColorScheme(.dark)
}
