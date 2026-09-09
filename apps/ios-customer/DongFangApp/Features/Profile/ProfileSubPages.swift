//
//  ProfileSubPages.swift
//  DongFangApp
//
//  个人中心二级页面集合：14 个二级页面统一存放于本文件，
//  供 ProfileView 的各菜单项 NavigationLink 跳转使用。
//  有服务端契约的页面读取真实 API；尚无个人数据契约的页面只展示空状态。
//

import SwiftUI

// MARK: - 1. 订单列表
/// 订单列表：顶部状态筛选 Tab + 订单卡片列表。
/// `initialStatus` 用于从个人中心不同入口直达对应分类。
struct OrderListView: View {
    var initialStatus: String? = nil
    @EnvironmentObject private var authStore: AuthStore
    @State private var selectedTab: String
    @State private var bookings: [Booking] = []
    @State private var shopOrders: [ShopOrder] = []
    @State private var diyOrders: [DiyOrder] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var reviewBooking: Booking?

    init(initialStatus: String? = nil) {
        self.initialStatus = initialStatus
        _selectedTab = State(initialValue: initialStatus ?? "all")
    }

    private let tabs: [(key: String, title: String)] = [
        ("all", "全部"), ("booking", "服务/预约"), ("shop", "商城订单"),
        ("diy", "DIY手串")
    ]

    private var isEmpty: Bool {
        switch selectedTab {
        case "booking": return bookings.isEmpty
        case "shop": return shopOrders.isEmpty
        case "diy": return diyOrders.isEmpty
        default: return bookings.isEmpty && shopOrders.isEmpty && diyOrders.isEmpty
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                tabBar
                if isLoading && isEmpty {
                    ProgressView("正在加载订单")
                        .tint(Color.accentDefault)
                        .frame(height: 320)
                } else if isEmpty {
                    DFEmptyState(icon: "doc.text", title: "暂无订单", subtitle: "去首页看看吧")
                        .frame(height: 320)
                } else {
                    orderContent
                }
                Spacer(minLength: AppSpacing.xl)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
        }
        .background(Color.bgPrimary)
        .navigationTitle("我的订单")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadOrders() }
        .refreshable { await loadOrders() }
        .sheet(item: $reviewBooking) { booking in
            BookingReviewSheet(booking: booking) {
                reviewBooking = nil
                Task { await loadOrders() }
            }
        }
        .alert("订单加载失败", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(tabs, id: \.key) { tab in
                    Text(tab.title)
                        .font(.system(size: 13, weight: selectedTab == tab.key ? .semibold : .regular))
                        .foregroundStyle(selectedTab == tab.key ? Color.accentDefault : Color.textTertiary)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                        .background(selectedTab == tab.key ? Color.bgTertiary : Color.bgSecondary)
                        .overlay(
                            Capsule().stroke(Color.borderDefault, lineWidth: 1)
                        )
                        .clipShape(Capsule())
                        .contentShape(Capsule())
                        .onTapGesture { selectedTab = tab.key }
                }
            }
        }
    }

    @ViewBuilder
    private var orderContent: some View {
        if selectedTab == "all" || selectedTab == "booking" {
            orderSectionTitle("服务与预约", count: bookings.count)
            ForEach(bookings) { booking in
                VStack(spacing: AppSpacing.sm) {
                    NavigationLink {
                        CustomerBookingDetailView(bookingId: booking.id)
                    } label: {
                        orderCard(
                            icon: "calendar",
                            title: booking.serviceName.isEmpty ? "预约服务" : booking.serviceName,
                            desc: [booking.templeName, booking.masterName, booking.bookingDate].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "),
                            amount: booking.meritMoneyText,
                            status: booking.statusDisplayText
                        )
                    }
                    .buttonStyle(.plain)
                    if booking.statusEnum == .completed {
                        Button {
                            reviewBooking = booking
                        } label: {
                            Label("评价本次服务", systemImage: "star.bubble")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 38)
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.accentDefault)
                    }
                }
            }
        }
        if selectedTab == "all" || selectedTab == "shop" {
            orderSectionTitle("商城订单", count: shopOrders.count)
            ForEach(shopOrders) { order in
                NavigationLink {
                    ShopOrderDetailView(orderId: order.id)
                } label: {
                    orderCard(
                        icon: "bag",
                        title: order.items?.first?.productName ?? "商城订单 \(order.orderNo)",
                        desc: order.orderNo,
                        amount: String(format: "¥%.2f", order.payAmount),
                        status: order.statusText
                    )
                }
                .buttonStyle(.plain)
            }
        }
        if selectedTab == "all" || selectedTab == "diy" {
            orderSectionTitle("DIY 手串", count: diyOrders.count)
            ForEach(diyOrders) { order in
                NavigationLink {
                    CustomerDiyOrderDetailView(orderId: order.id)
                } label: {
                    orderCard(
                        icon: "circle.grid.2x2",
                        title: "DIY 手串 · \(order.orderNo)",
                        desc: order.source == "design_square" ? "设计广场下单" : "自定义设计",
                        amount: order.totalFeeText,
                        status: order.statusDisplayText
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func orderSectionTitle(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
            Spacer()
            Text("\(count)单")
                .font(.system(size: 12))
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.top, AppSpacing.sm)
    }

    private func orderCard(icon: String, title: String, desc: String, amount: String, status: String) -> some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                Circle().fill(Color.bgTertiary).frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(Color.textTertiary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Text(desc.isEmpty ? "暂无补充信息" : desc)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(amount)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentDefault)
                    .monospacedDigit()
                Text(status)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.stateWarning)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.textTertiary)
        }
        .padding(AppSpacing.md)
        .background(Color.bgSecondary)
        .cornerRadius(AppRadius.lg)
        .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
    }

    @MainActor
    private func loadOrders() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        var failures: [String] = []

        do {
            let response: PageResponse<Booking> = try await APIClient.shared.request(
                .bookings(userId: nil, status: nil, page: 1, size: 50)
            )
            bookings = response.list
        } catch {
            bookings = []
            failures.append("预约")
        }

        do {
            let response: PageResponse<ShopOrder> = try await APIClient.shared.request(
                .shopOrders(status: nil, page: 1, size: 50)
            )
            shopOrders = response.list
        } catch {
            shopOrders = []
            failures.append("商城")
        }

        do {
            let response: PageResponse<DiyOrder> = try await APIClient.shared.request(
                .diyOrders(userId: authStore.userId, status: nil, page: 1, size: 50)
            )
            diyOrders = response.list
        } catch {
            diyOrders = []
            failures.append("DIY")
        }

        if !failures.isEmpty {
            errorMessage = "未能加载：\(failures.joined(separator: "、"))订单"
        }
        isLoading = false
    }
}

private struct CustomerBookingDetailView: View {
    let bookingId: String
    @State private var booking: Booking?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let booking {
                List {
                    Section("预约") {
                        detailRow("预约单号", booking.id)
                        detailRow("状态", booking.statusDisplayText)
                        detailRow("寺院", booking.templeName ?? booking.templeId)
                        detailRow("大师", booking.masterName ?? booking.masterId)
                        detailRow("服务", booking.serviceName)
                        detailRow("日期", booking.bookingDate)
                        detailRow("时段", booking.timeSlot)
                    }
                    Section("费用与备注") {
                        detailRow("功德金", booking.meritMoneyText)
                        if !booking.note.isEmpty {
                            Text(booking.note).foregroundStyle(Color.textSecondary)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            } else if let errorMessage {
                DFEmptyState(icon: "exclamationmark.triangle", title: "预约加载失败", subtitle: errorMessage)
            } else {
                DFLoadingView()
            }
        }
        .background(Color.bgPrimary)
        .navigationTitle("预约详情")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @MainActor
    private func load() async {
        do {
            booking = try await APIClient.shared.request(.bookingById(bookingId))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).foregroundStyle(Color.textSecondary)
            Spacer()
            Text(value.isEmpty ? "—" : value)
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct CustomerDiyOrderDetailView: View {
    let orderId: Int64
    @State private var order: DiyOrder?
    @State private var busy=false
    @State private var confirmReceipt=false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let order {
                List {
                    Section("制作与交付") {
                        if let logistics=order.logistics {Text("\(logistics.expressCompany) · \(logistics.trackingNo)").textSelection(.enabled)}
                        Text("选材 → 审核 → 制作 → 加持（选购）→ 发货 → 收货").font(.caption).foregroundStyle(Color.accentDefault)
                        if let errorMessage {Text(errorMessage).foregroundStyle(.red)}
                        if order.status=="shipped" {Button("确认收到作品"){confirmReceipt=true}.disabled(busy)}
                        if order.status=="pending_review" && order.paymentStatus != "success" {Button("继续模拟支付"){Task{await act(false)}}.disabled(busy)}
                        Button("刷新制作进度"){Task{await load()}}.disabled(busy)
                    }
                    Section("订单") {
                        detailRow("订单号", order.orderNo)
                        detailRow("状态", order.statusDisplayText)
                        detailRow("支付 / 退款", ["success":"已支付","pending":"待支付","refunding":"退款中","refunded":"已退款"][order.paymentStatus ?? "pending"] ?? "待确认")
                        detailRow("材料费", String(format: "¥%.2f", order.materialFee))
                        detailRow("加持费", String(format: "¥%.2f", order.blessFee))
                        detailRow("合计", String(format: "¥%.2f", order.totalFee))
                    }
                    if let items = order.items, !items.isEmpty {
                        Section("材料明细") {
                            ForEach(items) { item in
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.materialName)
                                        Text("\(item.spec) × \(item.quantity)")
                                            .font(.caption)
                                            .foregroundStyle(Color.textTertiary)
                                    }
                                    Spacer()
                                    Text(String(format: "¥%.2f", item.unitPrice * Double(item.quantity)))
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            } else if let errorMessage {
                DFEmptyState(icon: "exclamationmark.triangle", title: "DIY 订单加载失败", subtitle: errorMessage)
            } else {
                DFLoadingView()
            }
        }
        .background(Color.bgPrimary)
        .navigationTitle("DIY 订单详情")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }.refreshable{await load()}
        .alert("确认已收到定制作品？",isPresented:$confirmReceipt){Button("返回",role:.cancel){};Button("确认收货"){Task{await act(true)}}}
    }

    @MainActor
    private func load() async {
        do {
            order = try await APIClient.shared.request(.diyOrderById(orderId))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor private func act(_ confirm:Bool) async {
        guard !busy,let order else{return};busy=true;defer{busy=false}
        do{if confirm{let _:DiyOrder=try await APIClient.shared.request(.diyOrderConfirm(orderId))}else{let p:PaymentCreateResult=try await APIClient.shared.request(.paymentCreate(PaymentCreateRequest(orderType:"diy_order",orderNo:order.orderNo,amount:order.totalFee,channel:"mock",userId:AuthStore.shared.userId)));let _:PaymentRecord=try await APIClient.shared.request(.paymentById(p.id))};await load()}catch{errorMessage=error.localizedDescription}
    }
    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Color.textSecondary)
            Spacer()
            Text(value).foregroundStyle(Color.textPrimary)
        }
    }
}

private struct BookingReviewSheet: View {
    let booking: Booking
    let onSubmitted: () -> Void

    @State private var rating = 5
    @State private var content = ""
    @State private var isSubmitting = false
    @State private var busy=false
    @State private var confirmReceipt=false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("本次服务") {
                    Text(booking.serviceName)
                    Text([booking.templeName, booking.masterName].compactMap { $0 }.joined(separator: " · "))
                        .foregroundStyle(Color.textSecondary)
                }
                Section("评分") {
                    HStack(spacing: 14) {
                        ForEach(1...5, id: \.self) { value in
                            Button {
                                rating = value
                            } label: {
                                Image(systemName: value <= rating ? "star.fill" : "star")
                                    .font(.system(size: 24))
                                    .foregroundStyle(Color.stateWarning)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                Section("评价内容") {
                    TextField("请写下真实的服务体验", text: $content, axis: .vertical)
                        .lineLimit(4...8)
                }
            }
            .navigationTitle("服务评价")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("提交") { Task { await submit() } }
                        .disabled(isSubmitting || content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("提交失败", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    @MainActor
    private func submit() async {
        guard !isSubmitting else { return }
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let request = BookingReviewCreateRequest(rating: rating, content: text, images: [])
            let _: BookingReviewCreateResponse = try await APIClient.shared.request(
                .bookingReviewCreate(id: booking.id, request))
            onSubmitted()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - 2. 收藏列表
struct FavoritesView: View {
    private enum Section: String, CaseIterable, Identifiable {
        case masters = "法师"
        case temples = "寺院"
        case products = "商品"
        var id: String { rawValue }
    }

    @State private var section: Section = .masters
    @State private var masters: [Master] = []
    @State private var temples: [Temple] = []
    @State private var products: [ShopProduct] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            Picker("收藏分类", selection: $section) {
                ForEach(Section.allCases) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.sm)

            Group {
                if isLoading && isEmpty {
                    ProgressView("正在加载收藏")
                        .tint(Color.accentDefault)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if isEmpty {
                    DFEmptyState(icon: emptyIcon, title: "暂无收藏",
                                 subtitle: errorMessage ?? emptySubtitle)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            switch section {
                            case .masters:
                                ForEach(masters) { master in
                                    NavigationLink {
                                        MasterProfileView(masterId: master.id)
                                    } label: {
                                        masterRow(master)
                                    }
                                    .buttonStyle(.plain)
                                }
                            case .temples:
                                ForEach(temples) { temple in
                                    NavigationLink {
                                        TempleDetailView(templeId: temple.id, templeName: temple.name)
                                    } label: {
                                        templeRow(temple)
                                    }
                                    .buttonStyle(.plain)
                                }
                            case .products:
                                ForEach(products) { product in
                                    NavigationLink {
                                        ShopProductDetailView(product: product)
                                    } label: {
                                        productRow(product)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
        }
        .background(Color.bgPrimary)
        .navigationTitle("我的收藏")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
    }

    private var isEmpty: Bool {
        switch section {
        case .masters:   return masters.isEmpty
        case .temples:   return temples.isEmpty
        case .products:  return products.isEmpty
        }
    }

    private var emptyIcon: String {
        switch section {
        case .masters:   return "heart"
        case .temples:   return "building.2"
        case .products:  return "bag"
        }
    }

    private var emptySubtitle: String {
        switch section {
        case .masters:   return "在法师主页点击关注后，会显示在这里"
        case .temples:   return "在寺院详情页点击收藏后，会显示在这里"
        case .products:  return "在商品详情页点击收藏后，会显示在这里"
        }
    }

    private func load() async {
        if masters.isEmpty && temples.isEmpty && products.isEmpty { isLoading = true }
        errorMessage = nil
        do {
            // 三类收藏并行加载
            async let m: FollowedMastersResponse? = try? APIClient.shared.request(.communityMyFollowing)
            async let t: TempleFavoritesResponse? = try? APIClient.shared.request(.templeFavorites)
            async let pr: ProductFavoritesResponse? = try? APIClient.shared.request(.productFavorites)
            let (mResp, tResp, prResp) = await (m, t, pr)

            if let ids = mResp?.list {
                let details = await withTaskGroup(of: (String, Master?).self) { group -> [Master] in
                    for id in ids {
                        group.addTask {
                            let master: Master? = try? await APIClient.shared.request(.masterById(id))
                            return (id, master)
                        }
                    }
                    var byId: [String: Master] = [:]
                    for await (id, master) in group {
                        if let master { byId[id] = master }
                    }
                    return ids.compactMap { byId[$0] }
                }
                masters = details
            }
            temples = tResp?.list ?? []
            products = prResp?.list ?? []
        } catch {
            if (error as? APIError)?.isCancellation == true || error is CancellationError { return }
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - 行视图
    private func masterRow(_ master: Master) -> some View {
        HStack(spacing: 12) {
            RemoteAvatar(urlString: master.avatar, size: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text(master.dharmaName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                Text(master.templeName)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
            }
            Spacer()
            chevron
        }
        .rowStyle()
    }

    private func templeRow(_ temple: Temple) -> some View {
        HStack(spacing: 12) {
            RemoteImage(urlString: temple.coverImage, placeholderIcon: "building.2.fill")
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text(temple.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                Text("\(temple.region) · \(temple.sect)")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
            }
            Spacer()
            chevron
        }
        .rowStyle()
    }

    private func productRow(_ product: ShopProduct) -> some View {
        HStack(spacing: 12) {
            RemoteImage(urlString: product.mainImage, placeholderIcon: "bag.fill")
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text(product.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                Text("¥\(product.price, specifier: "%.2f")")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.brandDefault)
            }
            Spacer()
            chevron
        }
        .rowStyle()
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.textTertiary)
    }
}

private extension View {
    func rowStyle() -> some View {
        self
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, 12)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.borderDivider)
                    .frame(height: 1)
                    .padding(.leading, AppSpacing.lg + 48 + 12)
            }
            .contentShape(Rectangle())
    }
}

// MARK: - 3. 收货地址列表
struct AddressListView: View {
    @State private var addresses: [UserAddress] = []
    @State private var editingAddress: UserAddress?
    @State private var showingCreate = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading && addresses.isEmpty {
                ProgressView("正在加载地址")
                    .tint(Color.accentDefault)
            } else if addresses.isEmpty {
                DFEmptyState(icon: "mappin.and.ellipse", title: "暂无收货地址", subtitle: "点击右上角添加地址")
            } else {
                List {
                    ForEach(addresses) { addr in
                        Button {
                            editingAddress = addr
                        } label: {
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                HStack(spacing: AppSpacing.sm) {
                                    Text(addr.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Color.textPrimary)
                                    Text(addr.maskedPhone)
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.textTertiary)
                                    if addr.isDefault {
                                        Text("默认")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(Color.white)
                                            .padding(.horizontal, 6).padding(.vertical, 2)
                                            .background(Color.brandDefault)
                                            .clipShape(Capsule())
                                    }
                                    Spacer()
                                    Image(systemName: "square.and.pencil")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.accentDefault)
                                }
                                Text(addr.fullAddress)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, AppSpacing.sm)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.bgSecondary)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await deleteAddress(addr) }
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .refreshable { await loadAddresses() }
            }
        }
        .background(Color.bgPrimary)
        .navigationTitle("收货地址")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingCreate = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.accentDefault)
                }
            }
        }
        .task { await loadAddresses() }
        .sheet(isPresented: $showingCreate) {
            NavigationStack {
                AddressEditorView(address: nil) {
                    showingCreate = false
                    Task { await loadAddresses() }
                }
            }
        }
        .sheet(item: $editingAddress) { address in
            NavigationStack {
                AddressEditorView(address: address) {
                    editingAddress = nil
                    Task { await loadAddresses() }
                }
            }
        }
        .alert("地址操作失败", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @MainActor
    private func loadAddresses() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response: ListResponse<UserAddress> = try await APIClient.shared.request(.addressList)
            addresses = response.list
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func deleteAddress(_ address: UserAddress) async {
        do {
            let _: AddressDeleteResponse = try await APIClient.shared.request(.addressDelete(address.id))
            addresses.removeAll { $0.id == address.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct AddressDeleteResponse: Decodable {
    let deleted: Bool
}

private struct AddressCreateResponse: Decodable {
    let id: Int64
}

private struct AddressEditorView: View {
    let address: UserAddress?
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var phone: String
    @State private var province: String
    @State private var city: String
    @State private var district: String
    @State private var detail: String
    @State private var isDefault: Bool
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(address: UserAddress?, onSaved: @escaping () -> Void) {
        self.address = address
        self.onSaved = onSaved
        _name = State(initialValue: address?.name ?? "")
        _phone = State(initialValue: address?.phone ?? "")
        _province = State(initialValue: address?.province ?? "")
        _city = State(initialValue: address?.city ?? "")
        _district = State(initialValue: address?.district ?? "")
        _detail = State(initialValue: address?.detail ?? "")
        _isDefault = State(initialValue: address?.isDefault ?? false)
    }

    var body: some View {
        Form {
            Section("联系人") {
                TextField("姓名", text: $name)
                TextField("手机号", text: $phone)
                    .keyboardType(.phonePad)
            }
            Section("所在地区") {
                TextField("省份", text: $province)
                TextField("城市", text: $city)
                TextField("区县", text: $district)
                TextField("详细地址", text: $detail, axis: .vertical)
                    .lineLimit(2...4)
            }
            Section {
                Toggle("设为默认地址", isOn: $isDefault)
                    .tint(Color.brandDefault)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.bgPrimary)
        .navigationTitle(address == nil ? "新增地址" : "编辑地址")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isSaving ? "保存中" : "保存") {
                    Task { await save() }
                }
                .disabled(isSaving || !isValid)
            }
        }
        .alert("保存失败", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        phone.count >= 7 && !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @MainActor
    private func save() async {
        guard isValid else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            if let address {
                let request = AddressUpdateRequest(
                    name: name, phone: phone, province: province, city: city,
                    district: district, detail: detail, isDefault: isDefault
                )
                let _: UserAddress = try await APIClient.shared.request(.addressUpdate(id: address.id, request))
            } else {
                let request = AddressCreateRequest(
                    name: name, phone: phone, province: province, city: city,
                    district: district, detail: detail, isDefault: isDefault
                )
                let _: AddressCreateResponse = try await APIClient.shared.request(.addressCreate(request))
            }
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - 4. 我的评价
struct ReviewListView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var reviews: [UserReview] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                if isLoading && reviews.isEmpty {
                    ProgressView("正在加载评价")
                        .tint(Color.accentDefault)
                        .frame(height: 300)
                } else if reviews.isEmpty {
                    DFEmptyState(icon: "star", title: "暂无评价", subtitle: "完成服务后可提交评价")
                        .frame(height: 300)
                }
                ForEach(reviews) { item in
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        HStack {
                            Text(targetName(item))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            HStack(spacing: 2) {
                                ForEach(0..<5, id: \.self) { i in
                                    Image(systemName: i < item.rating ? "star.fill" : "star")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.stateWarning)
                                }
                            }
                        }
                        Text(item.content)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(item.createTime)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.md)
                    .background(Color.bgSecondary)
                    .cornerRadius(AppRadius.lg)
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
                }
                Spacer(minLength: AppSpacing.xl)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
        }
        .background(Color.bgPrimary)
        .navigationTitle("我的评价")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadReviews() }
        .refreshable { await loadReviews() }
        .alert("评价加载失败", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func targetName(_ review: UserReview) -> String {
        let type: String
        switch review.targetType {
        case "master": type = "法师"
        case "temple": type = "寺院"
        case "product": type = "商品"
        default: type = "服务"
        }
        return "\(type) · \(review.targetId)"
    }

    @MainActor
    private func loadReviews() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response: PageResponse<UserReview> = try await APIClient.shared.request(
                .reviews(userId: authStore.userId, page: 1, size: 50)
            )
            reviews = response.list
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - 5. 功德金（钱包）
struct WalletView: View {
    var body: some View {
        DFEmptyState(icon: "wallet.pass", title: "暂无功德金记录", subtitle: "订单中的功德金会随预约明细展示")
        .background(Color.bgPrimary)
        .navigationTitle("功德金")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 6. 优惠券
struct CouponView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var coupons: [UserCoupon] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                if isLoading && coupons.isEmpty {
                    ProgressView("正在加载优惠券")
                        .tint(Color.accentDefault)
                        .frame(height: 300)
                } else if coupons.isEmpty {
                    DFEmptyState(icon: "ticket", title: "暂无优惠券", subtitle: "可在活动页面领取优惠券")
                        .frame(height: 300)
                }
                ForEach(coupons) { item in
                    HStack(spacing: 0) {
                        VStack(spacing: 2) {
                            Text(item.valueText)
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(Color.brandDefault)
                                .monospacedDigit()
                            Text(item.minAmount > 0 ? "满¥\(Int(item.minAmount))可用" : "无门槛")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.textTertiary)
                        }
                        .frame(width: 92)
                        .padding(.vertical, AppSpacing.md)

                        Rectangle().fill(Color.borderDivider).frame(width: 1)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.textPrimary)
                            Text(item.statusText)
                                .font(.system(size: 12))
                                .foregroundStyle(item.status == "unused" ? Color.stateSuccess : Color.textSecondary)
                            Text("\(item.endTime) 到期")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.textTertiary)
                        }
                        .padding(.leading, AppSpacing.md)
                        Spacer()
                    }
                    .background(Color.bgSecondary)
                    .cornerRadius(AppRadius.lg)
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
                }
                Spacer(minLength: AppSpacing.xl)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
        }
        .background(Color.bgPrimary)
        .navigationTitle("优惠券")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadCoupons() }
        .refreshable { await loadCoupons() }
        .alert("优惠券加载失败", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @MainActor
    private func loadCoupons() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response: PageResponse<UserCoupon> = try await APIClient.shared.request(
                .myCoupons(status: nil, page: 1, size: 50)
            )
            coupons = response.list
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - 7. 积分明细
struct PointsAccount: Decodable { let balance: Int64 }
struct PointsEntry: Decodable, Identifiable {
    let id: Int64; let kind: String; let delta: Int64; let balanceAfter: Int64; let referenceNo: String; let createdAt: String
    var title: String { ["earn":"消费获得", "refund":"退款扣回", "redeem":"兑换商品", "return":"取消兑换退回", "reward_pool":"奖池参与", "reward_wheel":"转盘抽奖"][kind] ?? kind }
}
struct PointsProduct: Decodable, Identifiable {
    let id: Int64; let name: String; let category: String; let description: String; let image: String; let pointsPrice: Int64; let stock: Int64
}
struct PointsOrder: Decodable, Identifiable {
    let id: Int64; let orderNo: String; let productName: String; let quantity: Int64; let pointsTotal: Int64; let status: String; let carrier: String; let trackingNo: String; let address: String; let createdAt: String
    var statusText: String { ["pending":"待发货", "shipped":"已发货", "completed":"已完成", "cancelled":"已取消"][status] ?? status }
}
struct PointsRedeemRequest: Encodable {
    let productId: Int64; let quantity: Int; let expectedPrice: Int64; let requestKey: String; let receiver: String; let mobile: String; let address: String
}
struct PointsActionResult: Decodable { let success: Bool }
struct PointsView: View {
    @State private var keyword=""
    @State private var balance: Int64?
    @State private var tab = 0
    @State private var page = 1
    @State private var entries: [PointsEntry] = []
    @State private var products: [PointsProduct] = []
    @State private var orders: [PointsOrder] = []
    @State private var busy = false
    @State private var error: String?
    @State private var selected: PointsProduct?
    @State private var pendingAction: PointsOrder?
    private var count: Int { tab == 0 ? entries.count : tab == 1 ? products.count : orders.count }
    var body: some View {
        List {
            Section {
                Text(balance.map(String.init) ?? "—").font(.system(size: 38, weight: .semibold)).foregroundStyle(Color.accentDefault)
                Text("每笔实付满 100 元得 1 积分，不足部分舍去。退款后按净实付重算。").font(.footnote).foregroundStyle(.secondary)
                if (balance ?? 0) < 0 { Text("退款扣回后余额不足，后续消费将先补足积分。").font(.footnote) }
            } header: { Text("可用积分") }
            Section("积分活动") {
                NavigationLink { RewardsView(initialTab: 1) } label: { Label("积分转盘 · 即转即开", systemImage: "sparkles") }
                NavigationLink { RewardsView() } label: { Label("大奖池 · 一期一码", systemImage: "gift") }
                NavigationLink("参与记录") { RewardsView(initialTab: 2) }
                NavigationLink("我的奖品") { RewardsView(initialTab: 3) }
                Text("每期参与积分在活动页明示；奖品预算由平台承担，功德值独立成长。").font(.caption).foregroundStyle(.secondary)
            }
            Picker("积分", selection: $tab) { Text("明细").tag(0); Text("积分商城").tag(1); Text("兑换记录").tag(2) }.pickerStyle(.segmented).disabled(busy)
            if let error { Text(error).foregroundStyle(.red); Button("重试") { Task { await load() } } }
            if busy { ProgressView() }
            if tab == 0 {
                ForEach(entries) { e in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text(e.title); Spacer(); Text("\(e.delta > 0 ? "+" : "")\(e.delta) 积分") }
                        Text("\(e.createdAt) · 余额 \(e.balanceAfter)").font(.caption).foregroundStyle(.secondary)
                        Text(e.referenceNo).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            } else if tab == 1 {
                ForEach(products) { p in
                    Button { selected = p } label: {
                        HStack {
                            if let url = URL(string: p.image), !p.image.isEmpty { AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Color.gray.opacity(0.15) }.frame(width: 64, height: 64).clipped().cornerRadius(8) }
                            VStack(alignment: .leading, spacing: 6) { Text(p.name).foregroundStyle(Color.textPrimary); Text("\(p.pointsPrice) 积分 · 库存 \(p.stock)").foregroundStyle(Color.accentDefault); Text(p.category).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
            } else {
                ForEach(orders) { o in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(o.productName) × \(o.quantity)").font(.headline)
                        Text("\(o.pointsTotal) 积分 · \(o.statusText)")
                        Text(o.orderNo).font(.caption2); Text(o.address).font(.caption)
                        if !o.trackingNo.isEmpty { Text("\(o.carrier)：\(o.trackingNo)").font(.caption) }
                        if o.status == "pending" || o.status == "shipped" { Button(o.status == "pending" ? "取消兑换" : "确认收货") { pendingAction = o }.disabled(busy) }
                    }
                }
            }
            if !busy && error == nil && count == 0 { Text(tab == 1 ? "暂无上架的积分商品" : "暂无记录").foregroundStyle(.secondary) }
            HStack { Button("上一页") { page -= 1 }.disabled(page == 1 || busy); Spacer(); Text("第 \(page) 页"); Spacer(); Button("下一页") { page += 1 }.disabled(count < 20 || busy) }
        }
        .scrollContentBackground(.hidden).background(Color.bgPrimary)
        .searchable(text:$keyword,prompt:"搜索积分商品或分类").onSubmit(of:.search){page=1;tab=1;Task{await load()}}
        .navigationTitle("我的积分").navigationBarTitleDisplayMode(.inline)
        .task { await load() }.refreshable { await load() }
        .onChange(of: tab) { _, _ in page = 1; Task { await load() } }
        .onChange(of: page) { _, _ in Task { await load() } }
        .sheet(item: $selected, onDismiss: { Task { await load() } }) { product in PointsRedeemSheet(product: product, balance: balance ?? 0) }
        .alert("确认操作", isPresented: Binding(get: { pendingAction != nil }, set: { if !$0 { pendingAction = nil } })) {
            Button("返回", role: .cancel) { pendingAction = nil }
            Button("确认") { if let order = pendingAction { Task { await transition(order) } }; pendingAction = nil }
        } message: { Text(pendingAction?.status == "pending" ? "取消兑换后将退回积分。" : "请确认已收到商品。") }
    }
    @MainActor private func load() async {
        busy = true; error = nil
        defer { busy = false }
        do {
            let a: PointsAccount = try await APIClient.shared.request(.pointsAccount); balance = a.balance
            if tab == 0 { entries = try await APIClient.shared.request(.pointsLedger(page)) }
            if tab == 1 { products = try await APIClient.shared.request(.pointsSearch(page,keyword)) }
            if tab == 2 { orders = try await APIClient.shared.request(.pointsOrders(page)) }
        } catch { self.error = error.localizedDescription }
    }
    @MainActor private func transition(_ order: PointsOrder) async {
        busy = true
        do { let _: PointsActionResult = try await APIClient.shared.request(.pointsOrderAction(order.id, order.status == "pending" ? "cancel" : "complete")); await load() }
        catch { self.error = error.localizedDescription }
        busy = false
    }
}
struct PointsRedeemSheet: View {
    let product: PointsProduct
    let balance: Int64
    @Environment(\.dismiss) private var dismiss
    @State private var addresses: [UserAddress] = []
    @State private var addressID: Int64 = 0
    @State private var quantity = 1
    @State private var busy = false
    @State private var error: String?
    @State private var request: PointsRedeemRequest?
    var body: some View {
        NavigationStack {
            Form {
                Section(product.name) { Text(product.description); Text("每件 \(product.pointsPrice) 积分 · 库存 \(product.stock)") }
                if product.stock > 0 { Stepper("数量：\(quantity)", value: $quantity, in: 1...Int(min(99, product.stock))).disabled(busy || request != nil) }
                Section("收货地址") {
                    if addresses.isEmpty { Text("请先在“我的”添加收货地址") }
                    Picker("地址", selection: $addressID) { ForEach(addresses) { a in Text("\(a.name) \(a.phone) \(a.fullAddress)").tag(a.id) } }.disabled(busy || request != nil)
                }
                Text("合计 \(Int64(quantity) * product.pointsPrice) 积分 · 可用 \(balance)")
                if let error { Text(error).foregroundStyle(.red) }
                Button(busy ? "兑换中…" : request == nil ? "确认兑换" : "重试本次兑换") { Task { await redeem() } }.disabled(busy || addressID == 0 || product.stock < quantity || balance < Int64(quantity) * product.pointsPrice)
            }
            .navigationTitle("兑换商品")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() }.disabled(busy) } }
            .interactiveDismissDisabled(busy)
            .task { do { addresses = try await APIClient.shared.request(.addressList); addressID = (addresses.first(where: { $0.isDefault }) ?? addresses.first)?.id ?? 0 } catch { self.error = error.localizedDescription } }
        }
    }
    @MainActor private func redeem() async {
        guard !busy, let a = addresses.first(where: { $0.id == addressID }) else { return }
        busy = true; error = nil; defer { busy = false }
        let payload = request ?? PointsRedeemRequest(productId: product.id, quantity: quantity, expectedPrice: product.pointsPrice, requestKey: UUID().uuidString, receiver: a.name, mobile: a.phone, address: a.fullAddress)
        request = payload
        do { let _: PointsOrder = try await APIClient.shared.request(.pointsRedeem(payload)); dismiss() } catch { self.error = error.localizedDescription }
    }
}

// MARK: - 8. 浏览记录
struct HistoryView: View {
    var body: some View {
        DFEmptyState(icon: "clock", title: "暂无浏览记录", subtitle: "最近浏览的内容会显示在这里")
        .background(Color.bgPrimary)
        .navigationTitle("浏览记录")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 9. 通话记录
struct CallHistoryView: View {
    var body: some View {
        DFEmptyState(icon: "phone", title: "暂无通话记录", subtitle: "已完成的音视频通话会显示在这里")
        .background(Color.bgPrimary)
        .navigationTitle("通话记录")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 10. 帮助中心
struct HelpView: View {
    private let faqs: [(q: String, a: String)] = [
        ("如何预约法师？", "在法师主页点击「预约咨询」，选择时间并提交即可。"),
        ("订单如何退款？", "在「我的订单」中找到对应订单，点击「申请退款」并填写原因。"),
        ("积分、活动与功德值有什么区别？", "积分可兑换确定权益，也可用于转盘抽奖和奖池参与；奖品由平台预算提供。功德值独立记录成长，不用于支付或兑换。"),
        ("如何修改收货地址？", "进入「收货地址」页面，点击对应地址进行编辑。"),
        ("DIY 手串定制流程？", "在首页进入「DIY 手串」，选择珠子材质与搭配后提交定制。")
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.sm) {
                ForEach(Array(faqs.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.accentDefault)
                            Text(item.q)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                        }
                        Text(item.a)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.md)
                    .background(Color.bgSecondary)
                    .cornerRadius(AppRadius.lg)
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
                }
                Spacer(minLength: AppSpacing.xl)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
        }
        .background(Color.bgPrimary)
        .navigationTitle("帮助与客服")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 11. 个人资料编辑
struct ProfileEditView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var nickname = ""
    @State private var avatar = ""
    @State private var mobile = ""
    @State private var gender = "unknown"
    @State private var birthday = ""
    @State private var region = ""
    @State private var bio = ""
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var savedMessage: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.lg) {
                avatarSection
                infoSection
                Spacer(minLength: AppSpacing.xl)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
        }
        .background(Color.bgPrimary)
        .navigationTitle("个人资料")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSaving ? "保存中" : "保存") {
                    Task { await saveProfile() }
                }
                .disabled(isSaving || nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .task { await loadProfile() }
        .overlay {
            if isLoading { ProgressView().tint(Color.accentDefault) }
        }
        .alert("提示", isPresented: .init(
            get: { errorMessage != nil || savedMessage != nil },
            set: {
                if !$0 {
                    errorMessage = nil
                    savedMessage = nil
                }
            }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(errorMessage ?? savedMessage ?? "")
        }
    }

    private var avatarSection: some View {
        HStack {
            Spacer()
            ZStack {
                Circle().fill(Color.bgTertiary).frame(width: 72, height: 72)
                RemoteAvatar(urlString: avatar, size: 72)
                Circle().stroke(Color.accentDefault, lineWidth: 2).frame(width: 72, height: 72)
            }
            Spacer()
        }
        .padding(.vertical, AppSpacing.md)
    }

    private var infoSection: some View {
        VStack(spacing: 0) {
            editRow(label: "昵称", value: $nickname)
            divider
            HStack {
                Text("手机号")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Text(maskedMobile)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(AppSpacing.md)
            divider
            HStack {
                Text("性别")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Picker("性别", selection: $gender) {
                    Text("未知").tag("unknown")
                    Text("男").tag("male")
                    Text("女").tag("female")
                }
                .labelsHidden()
                .tint(Color.textSecondary)
            }
            .padding(AppSpacing.md)
            divider
            editRow(label: "生日", value: $birthday)
            divider
            editRow(label: "地区", value: $region)
            divider
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("个人简介")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textPrimary)
                TextEditor(text: $bio)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
                    .frame(height: 80)
                    .padding(AppSpacing.sm)
                    .background(Color.bgTertiary)
                    .cornerRadius(AppRadius.md)
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.md).stroke(Color.borderDefault, lineWidth: 1))
            }
            .padding(AppSpacing.md)
        }
        .background(Color.bgSecondary)
        .cornerRadius(AppRadius.lg)
        .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
    }

    private var maskedMobile: String {
        guard mobile.count >= 11 else { return mobile }
        return "\(mobile.prefix(3))****\(mobile.suffix(4))"
    }

    private func editRow(label: String, value: Binding<String>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Color.textPrimary)
            Spacer()
            TextField("", text: value)
                .font(.system(size: 14))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(AppSpacing.md)
    }

    private var divider: some View {
        Rectangle().fill(Color.borderDivider).frame(height: 1).padding(.leading, AppSpacing.md)
    }

    @MainActor
    private func loadProfile() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let profile: UserProfile = try await APIClient.shared.request(.userProfile)
            nickname = profile.nickname
            avatar = profile.avatar
            mobile = profile.mobile
            gender = profile.gender
            birthday = profile.birthday ?? ""
            region = profile.region ?? ""
            bio = profile.bio ?? ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func saveProfile() async {
        isSaving = true
        defer { isSaving = false }
        let request = UpdateProfileRequest(
            nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
            avatar: avatar,
            gender: gender,
            birthday: birthday,
            region: region,
            bio: bio
        )
        do {
            let profile: UserProfile = try await APIClient.shared.request(.updateProfile(request))
            nickname = profile.nickname
            avatar = profile.avatar
            mobile = profile.mobile
            authStore.updateCachedProfile(nickname: profile.nickname, avatar: profile.avatar, mobile: profile.mobile)
            savedMessage = "个人资料已保存"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - 12. 消息通知设置
struct NotificationSettingsView: View {
    @State private var orderNotify = true
    @State private var activityNotify = true
    @State private var systemNotify = false
    @State private var chatNotify = true

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.lg) {
                toggleGroup
                Spacer(minLength: AppSpacing.xl)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
        }
        .background(Color.bgPrimary)
        .navigationTitle("消息通知")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var toggleGroup: some View {
        VStack(spacing: 0) {
            toggleRow(icon: "doc.text", title: "订单通知", subtitle: "订单状态变更提醒", isOn: $orderNotify)
            divider
            toggleRow(icon: "gift", title: "活动通知", subtitle: "优惠活动与福利提醒", isOn: $activityNotify)
            divider
            toggleRow(icon: "bell", title: "系统通知", subtitle: "系统消息与公告", isOn: $systemNotify)
            divider
            toggleRow(icon: "bubble.left", title: "消息通知", subtitle: "法师/客服消息提醒", isOn: $chatNotify)
        }
        .background(Color.bgSecondary)
        .cornerRadius(AppRadius.lg)
        .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
    }

    private func toggleRow(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.textTertiary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color.brandDefault)
        }
        .padding(AppSpacing.md)
    }

    private var divider: some View {
        Rectangle().fill(Color.borderDivider).frame(height: 1).padding(.leading, 52)
    }
}

// MARK: - 13. 账号安全
struct SecurityView: View {
    private let items: [(icon: String, title: String, value: String)] = [
        ("lock", "修改密码", "已设置"),
        ("phone", "绑定手机", "138****8000"),
        ("person.text.rectangle", "实名认证", "未认证"),
        ("icloud", "第三方账号", "微信未绑定")
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        if index > 0 { divider }
                        NavigationLink {
                            SecurityDetailView(title: item.title)
                        } label: {
                            HStack(spacing: AppSpacing.md) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.textTertiary)
                                    .frame(width: 24)
                                Text(item.title)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.textPrimary)
                                Spacer()
                                Text(item.value)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.textTertiary)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.textTertiary)
                            }
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color.bgSecondary)
                .cornerRadius(AppRadius.lg)
                .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))

                Text("如遇账号异常，请联系客服：400-000-0000")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
                    .frame(maxWidth: .infinity)
                Spacer(minLength: AppSpacing.xl)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
        }
        .background(Color.bgPrimary)
        .navigationTitle("账号安全")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var divider: some View {
        Rectangle().fill(Color.borderDivider).frame(height: 1).padding(.leading, 52)
    }
}

/// 账号安全子项详情占位
private struct SecurityDetailView: View {
    let title: String
    var body: some View {
        DFEmptyState(icon: "lock.shield", title: title, subtitle: "功能开发中，敬请期待")
            .background(Color.bgPrimary)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 14. 关于
struct AboutView: View {
    private let items: [(icon: String, title: String)] = [
        ("doc.text", "用户协议"),
        ("hand.raised", "隐私政策"),
        ("star", "给我们评分"),
        ("trash", "清除缓存")
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.lg) {
                VStack(spacing: AppSpacing.sm) {
                    Image("brand-logo")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 84, height: 84)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.accentDefault, lineWidth: 2))
                    Text("问玄东方")
                        .font(.custom(AppFont.serif[0], size: 20).weight(.bold))
                        .foregroundStyle(Color.accentDefault)
                    Text("版本 1.0.0 (1)")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.xl)

                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        if index > 0 { divider }
                        HStack(spacing: AppSpacing.md) {
                            Image(systemName: item.icon)
                                .font(.system(size: 16))
                                .foregroundStyle(Color.textTertiary)
                                .frame(width: 24)
                            Text(item.title)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textTertiary)
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                }
                .background(Color.bgSecondary)
                .cornerRadius(AppRadius.lg)
                .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))

                Text("© 2026 问玄东方 保留所有权利")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
                Spacer(minLength: AppSpacing.xl)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
        }
        .background(Color.bgPrimary)
        .navigationTitle("关于问玄东方")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var divider: some View {
        Rectangle().fill(Color.borderDivider).frame(height: 1).padding(.leading, 52)
    }
}

// MARK: - 积分活动：消耗积分参与，奖品由平台预算承担
struct RewardCampaign: Decodable, Identifiable {
    let id: Int64
    let title, kind, prizeName, image, description, rules: String
    let prizeValue, budget, pointsCost: Int64
    let prizeQuantity, capacity, participantCount, awardedCount: Int
    let startsAt, endsAt, drawnAt: Int64
    let status, phase, poolDigest, announcement, algorithm: String
    var phaseText: String { ["draft":"草稿","scheduled":"即将开始","open":"参与中","full":"名额已满 · 等待截止","awaiting_draw":"正在开奖","drawn":"已结束","cancelled":"已取消"][phase] ?? phase }
    var oddsText: String {
        let n = kind == "pool" ? participantCount : capacity - participantCount
        let k = kind == "pool" ? min(prizeQuantity, n) : prizeQuantity - awardedCount
        return n > 0 ? String(format: "%.2f%%", Double(k) / Double(n) * 100) : "—"
    }
}
struct RewardEntry: Decodable, Identifiable {
    let id, campaignId, createdAt, pointsSpent: Int64
    let code, outcome, title: String
    var outcomeText: String { ["pending":"等待开奖","won":"恭喜中奖","lost":"本期未中奖"][outcome] ?? outcome }
}
struct RewardOrder: Decodable, Identifiable {
    let id, campaignId, entryId, createdAt, claimedAt, shippedAt, completedAt: Int64
    let prizeName, code, status, receiver, mobile, address, carrier, trackingNo: String
    var statusText: String { ["awaiting_address":"待填写地址","pending":"待发货","shipped":"已发货","completed":"已完成"][status] ?? status }
}
struct RewardDetail: Decodable { let campaign: RewardCampaign; var mine: RewardEntry?; let winners: [RewardEntry]; let pointsBalance: Int64 }
struct RewardAddressRequest: Encodable { let receiver, mobile, address: String }
private func rewardDate(_ n: Int64) -> String {
    Date(timeIntervalSince1970: Double(n)).formatted(.dateTime.month().day().hour().minute())
}
struct RewardsView: View {
    init(initialTab: Int = 0) { _tab = State(initialValue: initialTab) }
    @State private var tab: Int
    @State private var page = 1
    @State private var campaigns: [RewardCampaign] = []
    @State private var entries: [RewardEntry] = []
    @State private var orders: [RewardOrder] = []
    @State private var loading = false
    @State private var error: String?
    @State private var claim: RewardOrder?
    @State private var completing: RewardOrder?
    private var count: Int { tab < 2 ? campaigns.count : tab == 2 ? entries.count : orders.count }
    var body: some View {
        List {
            Section {
                VStack(alignment:.leading,spacing:12) {
                    Text("A GIFT, A LITTLE JOY").font(.caption2).tracking(2).foregroundStyle(Color.accentDefault)
                    Text("把小欢喜，留给有缘的你").font(.system(size:26,weight:.semibold,design:.serif))
                    Text("用积分参与，让每一期多一份期待。").font(.subheadline).foregroundStyle(.secondary)
                    HStack { Label("积分参与",systemImage:"checkmark.seal"); Spacer(); Label("实物包邮",systemImage:"gift") }.font(.caption).foregroundStyle(Color.accentDefault)
                }.padding(.vertical,12)
            }.listRowBackground(Color.accentDefault.opacity(0.1))
            Picker("活动分类",selection:$tab) { Text("大奖池").tag(0);Text("转盘").tag(1);Text("参与记录").tag(2);Text("我的奖品").tag(3) }.pickerStyle(.segmented).disabled(loading)
            if let error { Section { Text(error).foregroundStyle(.red); Button("重新加载") { Task { await load() } } } }
            if loading { ProgressView("正在准备活动…") }
            if tab < 2 {
                ForEach(campaigns) { c in
                    NavigationLink { RewardDetailView(id:c.id) } label: {
                        VStack(alignment:.leading,spacing:12) {
                            HStack { Text("第 \(c.id) 期 · \(c.kind == "pool" ? "大奖池" : "幸运转盘")");Spacer();Text(c.phaseText).foregroundStyle(Color.accentDefault) }.font(.caption)
                            if let url=URL(string:c.image), !c.image.isEmpty { AsyncImage(url:url) { image in image.resizable().scaledToFill() } placeholder: { Color.accentDefault.opacity(0.15) }.frame(height:150).clipped().clipShape(RoundedRectangle(cornerRadius:14)) }
                            Text(c.title).font(.title3.bold()).foregroundStyle(Color.textPrimary)
                            Text("\(c.prizeName) × \(c.prizeQuantity)").font(.subheadline)
                            ProgressView(value:Double(c.participantCount),total:Double(c.capacity)).tint(Color.accentDefault)
                            HStack { Text("\(c.participantCount) 人参与 / 限 \(c.capacity) 人");Spacer();Text("\(c.pointsCost) 积分 →") }.font(.caption).foregroundStyle(Color.accentDefault)
                            Text("\(rewardDate(c.endsAt)) 截止\(c.kind == "pool" ? " · 到期即开" : " · 即转即开")").font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical,8)
                    }
                }
            } else if tab == 2 {
                ForEach(entries) { e in NavigationLink { RewardDetailView(id:e.campaignId) } label: { VStack(alignment:.leading,spacing:10) { HStack { Text(e.title);Spacer();Text(e.outcomeText).foregroundStyle(Color.accentDefault) };Text(e.code).font(.system(.subheadline,design:.monospaced));Text("消耗 \(e.pointsSpent) 积分 · \(rewardDate(e.createdAt))").font(.caption).foregroundStyle(.secondary) }.padding(.vertical,6) } }
            } else {
                ForEach(orders) { o in
                    Section {
                        HStack { Text(o.prizeName).font(.headline);Spacer();Text(o.statusText).foregroundStyle(Color.accentDefault) }
                        NavigationLink("中奖码 \(o.code)") { RewardDetailView(id:o.campaignId) }.font(.caption)
                        if !o.address.isEmpty { Text("\(o.receiver) · \(o.mobile)\n\(o.address)").font(.subheadline) }
                        if !o.trackingNo.isEmpty { Text("物流：\(o.carrier) · \(o.trackingNo)").font(.subheadline).textSelection(.enabled) }
                        if o.claimedAt > 0 { Label("提交地址 \(rewardDate(o.claimedAt))",systemImage:"mappin.circle").font(.caption) }
                        if o.shippedAt > 0 { Label("发货 \(rewardDate(o.shippedAt))",systemImage:"shippingbox").font(.caption) }
                        if o.completedAt > 0 { Label("已完成 \(rewardDate(o.completedAt))",systemImage:"checkmark.circle").font(.caption) }
                        if o.status == "awaiting_address" { Button("填写收货地址") { claim=o }.buttonStyle(.borderedProminent).tint(Color.accentDefault) }
                        if o.status == "shipped" { Button("确认收货") { completing=o }.disabled(loading) }
                    }
                }
            }
            if !loading && error == nil && count == 0 { ContentUnavailableView(tab < 2 ? "下一份惊喜，正在准备" : tab == 2 ? "还没有参与记录" : "还没有中奖礼物",systemImage:"gift",description:Text("每次参与会扣除页面所示积分，并保留参与码和结果。")) }
            if page > 1 || count >= 20 { HStack { Button("上一页") { page-=1 }.disabled(page==1||loading);Spacer();Text("第 \(page) 页");Spacer();Button("下一页") { page+=1 }.disabled(count<20||loading) }.font(.caption) }
            Section { NavigationLink("积分商城 · 确定的回馈") { PointsView() };Text("功德值独立记录成长，与活动概率无关。").font(.caption).foregroundStyle(.secondary) }
        }
        .navigationTitle("积分活动").navigationBarTitleDisplayMode(.inline)
        .task(id:"\(tab)-\(page)") { await load() }
        .onChange(of:tab) { _,_ in page=1 }
        .refreshable { await load() }
        .sheet(item:$claim,onDismiss:{Task {await load()}}) { RewardClaimSheet(order:$0) }
        .alert("确认已收到奖品？",isPresented:Binding(get:{completing != nil},set:{if !$0 {completing=nil}})) { Button("取消",role:.cancel){completing=nil};Button("确认收货"){if let o=completing { Task {await complete(o)} }} } message: { Text("确认后本次实物领奖流程完成。") }
    }
    @MainActor private func load() async {
        loading=true;error=nil;defer{loading=false}
        do { if tab < 2 { campaigns=try await APIClient.shared.request(.rewardCampaigns(page,tab==0 ? "pool":"wheel")) } else if tab==2 { entries=try await APIClient.shared.request(.rewardEntries(page)) } else { orders=try await APIClient.shared.request(.rewardOrders(page)) } } catch { self.error=error.localizedDescription }
    }
    @MainActor private func complete(_ o:RewardOrder) async { loading=true;defer{loading=false};do { let _:PointsActionResult=try await APIClient.shared.request(.rewardComplete(o.id));completing=nil;await load() }catch{self.error=error.localizedDescription} }
}
struct RewardDetailView: View {
    let id:Int64
    @State private var detail:RewardDetail?
    @State private var error:String?
    @State private var busy=false
    @State private var spinning=false
    @State private var confirming=false
    @State private var rotation=0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body:some View {
        List {
            if let error { Text(error).foregroundStyle(.red);Button("重新加载") {Task{await load()}} }
            if let d=detail {
                Section {
                    VStack(spacing:16) {
                        Text("第 \(d.campaign.id) 期 · \(d.campaign.phaseText)").font(.caption).foregroundStyle(Color.accentDefault)
                        Text(d.campaign.title).font(.system(size:25,weight:.semibold,design:.serif)).multilineTextAlignment(.center)
                        if d.campaign.kind == "wheel" { wheel }
                        else if let url=URL(string:d.campaign.image), !d.campaign.image.isEmpty { AsyncImage(url:url) { image in image.resizable().scaledToFill() } placeholder: { Image(systemName:"gift.fill").font(.system(size:70)) }.frame(height:190).clipped().clipShape(RoundedRectangle(cornerRadius:18)) }
                        else { Image(systemName:"gift.fill").font(.system(size:70)).foregroundStyle(Color.accentDefault).padding(30) }
                        Text("\(d.campaign.prizeName) × \(d.campaign.prizeQuantity)").font(.headline)
                        Text("平台提供 · \(d.campaign.pointsCost) 积分参与 · 实物包邮").font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth:.infinity).padding(.vertical,14)
                }.listRowBackground(Color.accentDefault.opacity(0.08))
                Section {
                    HStack { fact("已参与人数","\(d.campaign.participantCount)");Spacer();fact("奖品数量","\(d.campaign.prizeQuantity)");Spacer();fact(d.campaign.kind=="pool" ? "按当前人数估算":"下一位即时概率",d.campaign.oddsText) }
                    ProgressView(value:Double(d.campaign.participantCount),total:Double(d.campaign.capacity)).tint(Color.accentDefault)
                    Text("名额 \(d.campaign.participantCount) / \(d.campaign.capacity) 人").font(.caption)
                    Text("开始：\(rewardDate(d.campaign.startsAt))\n截止：\(rewardDate(d.campaign.endsAt))").font(.subheadline)
                    Text(d.campaign.kind=="pool" ? "截止后自动开奖，不需要等满额。最终概率为 min(奖品数量, 有效人数) ÷ 有效人数；100 人抽 1 人，每人为 1%。" : "当前概率 = 剩余奖品 ÷ 剩余名额，随结果变化。扇区仅作动画展示，不代表概率。剩余奖品 \(d.campaign.prizeQuantity-d.campaign.awardedCount) 份。").font(.caption).foregroundStyle(.secondary)
                }
                if let mine=d.mine { Section("我的专属参与码") { Text(mine.code).font(.system(.title3,design:.monospaced)).foregroundStyle(Color.accentDefault).textSelection(.enabled);Text(spinning ? "正在揭晓…":mine.outcomeText).font(.headline);Text("消耗 \(mine.pointsSpent) 积分 · \(rewardDate(mine.createdAt))").font(.caption);if mine.outcome=="won" && !spinning { NavigationLink("查看我的奖品并领奖") { RewardsView(initialTab: 3) } } } }
                Section("这一份礼物") { Text(d.campaign.description);Text(d.campaign.rules).font(.subheadline);Text("每个账号每期一次，消耗 \(d.campaign.pointsCost) 积分；成功参与后无论中奖与否均不退回。请求失败不扣分，重复点击不重复扣分。奖品预算由平台承担，功德值不变。").font(.caption).foregroundStyle(.secondary) }
                if !d.campaign.announcement.isEmpty || !d.winners.isEmpty { Section("开奖公告") { Text(d.campaign.announcement.isEmpty ? "本期实时中奖码，活动结束后归档。":d.campaign.announcement);if d.campaign.drawnAt>0 {Text("实际开奖 \(rewardDate(d.campaign.drawnAt))").font(.caption)};ForEach(d.winners) {Text($0.code).font(.system(.caption,design:.monospaced)).textSelection(.enabled)};if !d.campaign.poolDigest.isEmpty { DisclosureGroup("开奖留档信息") { Text(d.campaign.algorithm);Text("参与码按创建顺序以换行分隔，SHA-256：");Text(d.campaign.poolDigest).textSelection(.enabled) }.font(.caption) } } }
                Section { Button { confirming=true } label: { Text(busy ? "正在处理…":d.mine != nil ? "本期已参与":d.campaign.phase=="open" ? (d.pointsBalance<d.campaign.pointsCost ? "积分不足" : "\(d.campaign.pointsCost) 积分\(d.campaign.kind=="wheel" ? "转一次":"参与奖池")"):d.campaign.phaseText).frame(maxWidth:.infinity).padding(8) }.buttonStyle(.borderedProminent).tint(Color.accentDefault).disabled(busy||d.mine != nil||d.campaign.phase != "open"||error != nil||d.pointsBalance<d.campaign.pointsCost||d.campaign.pointsCost<1);Text("可用 \(d.pointsBalance) 积分 · 每期一次").font(.caption).frame(maxWidth:.infinity).foregroundStyle(.secondary) }
            } else if error == nil { ProgressView("加载活动…") }
        }.alert("确认扣除积分参与？",isPresented:$confirming) {
            Button("再想想",role:.cancel) {}
            Button("确认扣除 \(detail?.campaign.pointsCost ?? 0) 积分") { Task { await join() } }
        } message: { Text("当前可用 \(detail?.pointsBalance ?? 0) 积分，本次消耗 \(detail?.campaign.pointsCost ?? 0) 积分。参与成功后无论中奖与否均不退回；失败不扣分，重复请求不重复扣分。") }
        .navigationTitle("活动详情").navigationBarTitleDisplayMode(.inline).refreshable {await load()}.task { await load();while !Task.isCancelled { do {try await Task.sleep(for:.seconds(15))}catch{return};if !busy {await load()} } }
    }
    private func fact(_ title:String,_ value:String)->some View { VStack(spacing:8) {Text(value).font(.title3.bold()).foregroundStyle(Color.accentDefault);Text(title).font(.system(size:10)).foregroundStyle(.secondary)} }
    private var wheel:some View { ZStack { Circle().fill(Color.accentDefault.opacity(0.18));VStack {Text("好礼");Spacer();Text("下次有缘").rotationEffect(.degrees(180))}.padding(30).frame(width:210,height:210).background(LinearGradient(colors:[Color.accentDefault.opacity(0.5),Color.brown.opacity(0.4)],startPoint:.top,endPoint:.bottom)).clipShape(Circle()).rotationEffect(.degrees(rotation));Circle().fill(Color.accentDefault).frame(width:64,height:64);Text("\(detail?.campaign.pointsCost ?? 0)\n积分").font(.caption).multilineTextAlignment(.center).foregroundStyle(.black);VStack{Image(systemName:"arrowtriangle.down.fill").foregroundStyle(Color.accentDefault);Spacer()}.offset(y:-8) }.frame(width:210,height:210).padding(12).accessibilityLabel(spinning ? "转盘正在揭晓":"积分幸运转盘") }
    @MainActor private func load()async {do{detail=try await APIClient.shared.request(.rewardDetail(id));error=nil}catch{self.error=error.localizedDescription}}
    @MainActor private func join()async { guard !busy, let c=detail?.campaign else{return};busy=true;error=nil;defer{busy=false;spinning=false};do{let entry:RewardEntry=try await APIClient.shared.request(.rewardJoin(id,c.pointsCost));detail?.mine=entry;if detail?.campaign.kind=="wheel" {spinning=true;withAnimation(reduceMotion ? nil:.easeOut(duration:1.8)){rotation+=1800+(entry.outcome=="won" ? 0:180)};if !reduceMotion {try? await Task.sleep(for:.milliseconds(1800))}};await load()}catch{self.error=error.localizedDescription} }
}
struct RewardClaimSheet:View {
    let order:RewardOrder
    @Environment(\.dismiss) private var dismiss
    @State private var receiver=""
    @State private var mobile=""
    @State private var address=""
    @State private var busy=false
    @State private var error:String?
    var body:some View { NavigationStack { Form { Section(order.prizeName) { Text("平台包邮，填写地址后进入待发货。").font(.subheadline);Text(order.code).font(.caption) };Section("收货信息") { TextField("收货人",text:$receiver).textContentType(.name);TextField("联系电话",text:$mobile).keyboardType(.phonePad).textContentType(.telephoneNumber);TextField("省市区、街道与门牌号",text:$address,axis:.vertical).textContentType(.fullStreetAddress).lineLimit(3...5) }.disabled(busy);if let error {Text(error).foregroundStyle(.red)};Section { Text("提交后请等待平台发货，请先核对地址和联系电话。").font(.caption);Button(busy ? "提交中…":"确认地址，等待发货") {Task{await submit()}}.disabled(busy||receiver.trimmingCharacters(in:.whitespaces).isEmpty||mobile.count<6||address.count<5) } }.navigationTitle("领奖地址").navigationBarTitleDisplayMode(.inline).toolbar {ToolbarItem(placement:.cancellationAction){Button("稍后填写"){dismiss()}.disabled(busy)}}.interactiveDismissDisabled(busy) } }
    @MainActor private func submit()async {busy=true;error=nil;defer{busy=false};do{let _:PointsActionResult=try await APIClient.shared.request(.rewardClaim(order.id,RewardAddressRequest(receiver:receiver.trimmingCharacters(in:.whitespacesAndNewlines),mobile:mobile.trimmingCharacters(in:.whitespacesAndNewlines),address:address.trimmingCharacters(in:.whitespacesAndNewlines))));dismiss()}catch{self.error=error.localizedDescription}}
}
