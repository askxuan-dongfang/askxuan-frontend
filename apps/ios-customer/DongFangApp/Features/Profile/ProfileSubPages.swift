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
                    orderCard(
                        icon: "calendar",
                        title: booking.serviceName.isEmpty ? "预约服务" : booking.serviceName,
                        desc: [booking.templeName, booking.masterName, booking.bookingDate].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "),
                        amount: booking.meritMoneyText,
                        status: booking.statusDisplayText
                    )
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
                orderCard(
                    icon: "circle.grid.2x2",
                    title: "DIY 手串 · \(order.orderNo)",
                    desc: order.source == "design_square" ? "设计广场下单" : "自定义设计",
                    amount: order.totalFeeText,
                    status: order.statusDisplayText
                )
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

private struct BookingReviewSheet: View {
    let booking: Booking
    let onSubmitted: () -> Void

    @State private var rating = 5
    @State private var content = ""
    @State private var isSubmitting = false
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
    var body: some View {
        DFEmptyState(icon: "heart", title: "暂无收藏", subtitle: "收藏的寺院、法师和内容会显示在这里")
        .background(Color.bgPrimary)
        .navigationTitle("我的收藏")
        .navigationBarTitleDisplayMode(.inline)
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
                .myCoupons(userId: authStore.userId, status: nil, page: 1, size: 50)
            )
            coupons = response.list
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - 7. 积分明细
struct PointsView: View {
    var body: some View {
        DFEmptyState(icon: "chart.line.uptrend.xyaxis", title: "暂无积分记录", subtitle: "积分变动会显示在这里")
        .background(Color.bgPrimary)
        .navigationTitle("积分明细")
        .navigationBarTitleDisplayMode(.inline)
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
        ("功德金如何使用？", "功德金可用于法事、供养等服务，下单时勾选功德金支付即可。"),
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
