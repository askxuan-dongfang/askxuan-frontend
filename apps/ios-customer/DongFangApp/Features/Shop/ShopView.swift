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
    @StateObject private var cart = ShopCartStore.shared

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
        NavigationLink {
            ShopCartView()
        } label: {
            Image(systemName: "cart")
                .font(.system(size: 20))
                .foregroundStyle(.textPrimary)
                .overlay(alignment: .topTrailing) {
                    if cart.itemCount > 0 {
                        Text("\(cart.itemCount)")
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
            viewModel.keyword = "礼盒"
            viewModel.search()
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
        NavigationLink {
            ShopProductDetailView(product: product)
        } label: {
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
        }
        .buttonStyle(.plain)
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

struct ShopProductDetailView: View {
    @StateObject private var viewModel: ShopProductDetailViewModel
    @StateObject private var cart = ShopCartStore.shared
    @State private var selectedSkuId: Int64?
    @State private var quantity = 1
    @State private var showCart = false
    @State private var added = false

    init(product: ShopProduct) {
        _viewModel = StateObject(wrappedValue: ShopProductDetailViewModel(product: product))
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
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.textPrimary)
                    HStack(alignment: .firstTextBaseline) {
                        Text("¥\(unitPrice, specifier: "%.2f")")
                            .font(.system(size: 24, weight: .bold))
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
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, 92)
            }
        }
        .background(Color.bgPrimary)
        .navigationTitle("商品详情")
        .navigationBarTitleDisplayMode(.inline)
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
                                Text("\(cart.itemCount)").font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white).padding(5).background(Color.brandDefault).clipShape(Circle())
                            }
                        }
                }.buttonStyle(.plain)
                DFPrimaryButton(title: added ? "已加入购物车" : "加入购物车", icon: added ? "checkmark" : "cart.badge.plus",
                                isEnabled: availableStock > 0) {
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
                            .font(.system(size: 20, weight: .bold)).foregroundStyle(.brandDefault)
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
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(.brandDefault)
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
                    .font(.system(size: 20, weight: .bold)).foregroundStyle(.brandDefault)
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
                    .font(.system(size: 24, weight: .bold)).foregroundStyle(.textPrimary)
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
                Spacer(); Text("¥\(order.payAmount, specifier: "%.2f")").font(.system(size: 16, weight: .bold)).foregroundStyle(.brandDefault)
            }
        }
        .padding(AppSpacing.md).background(Color.bgSecondary).clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
    }
}

struct ShopOrderDetailView: View {
    let orderId: Int64
    @State private var order: ShopOrder?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            if let order {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    HStack { Text(order.statusText).font(.system(size: 20, weight: .bold)); Spacer(); Text("¥\(order.payAmount, specifier: "%.2f")").foregroundStyle(.brandDefault) }
                    Text("订单号：\(order.orderNo)").font(.system(size: 12)).foregroundStyle(.textTertiary)
                    ForEach(order.items ?? []) { item in
                        HStack { Text(item.productName); Spacer(); Text("×\(item.quantity)"); Text("¥\(item.price, specifier: "%.2f")") }
                            .font(.system(size: 13)).foregroundStyle(.textSecondary)
                    }
                    if let logistics = order.logistics, !logistics.trackingNo.isEmpty {
                        Label("\(logistics.expressCompany) · \(logistics.trackingNo)", systemImage: "shippingbox")
                            .font(.system(size: 13)).foregroundStyle(.textSecondary)
                    }
                }
                .padding(AppSpacing.lg).background(Color.bgSecondary).clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                .padding(AppSpacing.lg)
            } else if let errorMessage {
                DFEmptyState(icon: "exclamationmark.triangle", title: "订单加载失败", subtitle: errorMessage)
                    .frame(minHeight: 360)
            } else { DFLoadingView().frame(minHeight: 360) }
        }
        .background(Color.bgPrimary).navigationTitle("订单详情").navigationBarTitleDisplayMode(.inline)
        .task {
            do { order = try await APIClient.shared.request(.shopOrderById(orderId)) }
            catch { errorMessage = error.localizedDescription }
        }
    }
}

#Preview {
    NavigationStack { ShopView() }
        .preferredColorScheme(.dark)
}
