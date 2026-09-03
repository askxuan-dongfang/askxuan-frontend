//
//  DiyOrderView.swift
//  DongFangApp
//
//  DIY 下单页：订单概要 + 收货地址 + 加持服务 + 费用明细 + 提交。
//

import SwiftUI

enum DiyOrderSource {
    case cart
    case design
}

struct DiyOrderView: View {
    let designId: Int64
    let orderSource: DiyOrderSource

    @StateObject private var viewModel: DiyViewModel
    @State private var selectedAddress: UserAddress?
    @State private var selectedBlessingService: BlessingService?
    @State private var checkoutOrder: DiyOrder?
    @State private var materialsExpanded = false

    init(designId: Int64, viewModel: DiyViewModel? = nil, orderSource: DiyOrderSource = .cart) {
        self.designId = designId
        self.orderSource = orderSource
        if let viewModel = viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: DiyViewModel())
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {
                    designSummary
                    addressSection
                    blessingSection
                    materialSection
                    if let message = viewModel.availabilityMessage {
                        availabilityWarning(message)
                    }
                    feeSection
                    Spacer(minLength: 100)
                }
                .padding(.top, AppSpacing.md)
            }
            submitBar
        }
        .background(Color.bgPrimary)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("确认订单")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.accentDefault)
            }
        }
        .alert("提示", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(item: $checkoutOrder) { order in
            NavigationStack {
                DiyPaymentFlowView(order: order, viewModel: viewModel)
            }
        }
        .task {
            await viewModel.loadCheckoutOptions()
            selectedAddress = viewModel.addresses.first(where: { $0.isDefault }) ?? viewModel.addresses.first
            selectedBlessingService = nil
            if orderSource == .design, viewModel.currentDesign?.id != designId {
                await viewModel.loadDesign(id: designId)
            } else if orderSource == .cart {
                let items = viewModel.cartItems.map {
                    DiyOrderItem(materialId: $0.material.id, materialName: $0.material.name,
                                 spec: $0.material.spec, unitPrice: $0.material.unitPrice,
                                 quantity: $0.quantity, subtype: $0.material.category)
                }
                _ = await viewModel.refreshOrderAvailability(designId: designId, items: items)
            }
        }
    }

    // MARK: - 设计概要
    private var designSummary: some View {
        VStack(spacing: 0) {
            DiyMiniBracelet(slots: checkoutSlots, fallbackCount: 0)
                .frame(height: 218)

            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.currentDesign?.name ?? "我的手串")
                        .font(.custom(AppFont.serif[0], size: 17).weight(.bold))
                        .foregroundStyle(Color.textPrimary)
                    Text("\(checkoutSlots.count) 颗 · \(materialLines.count) 种材料")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.textTertiary)
                }
                Spacer()
                Text("¥\(String(format: "%.2f", viewModel.currentDesign?.totalPrice ?? viewModel.totalPrice))")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.brandDefault)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, AppSpacing.md)
        }
        .background(
            RadialGradient(
                colors: [Color(hex: "303236"), Color(hex: "17191B"), Color(hex: "0D0F10")],
                center: .center,
                startRadius: 24,
                endRadius: 280
            )
        )
        .overlay(alignment: .bottom) { Rectangle().fill(Color.borderDefault).frame(height: 1) }
        .padding(.horizontal, AppSpacing.lg)
    }

    private var materialSection: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { materialsExpanded.toggle() }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("材料明细")
                            .font(.cardTitle)
                            .foregroundStyle(Color.textPrimary)
                        Text("\(materialLines.count) 种材料")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.textTertiary)
                    }
                    Spacer()
                    Image(systemName: materialsExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.accentDefault)
                }
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if materialsExpanded {
                VStack(spacing: 0) {
                    ForEach(materialLines) { line in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(line.color)
                                .frame(width: 28, height: 28)
                                .shadow(color: Color.black.opacity(0.3), radius: 3, y: 2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(line.name).font(.system(size: 12, weight: .medium)).foregroundStyle(Color.textPrimary)
                                Text("\(line.spec) × \(line.quantity)").font(.system(size: 9)).foregroundStyle(Color.textTertiary)
                            }
                            Spacer()
                            Text("¥\(String(format: "%.2f", line.total))")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.textSecondary)
                        }
                        .padding(.vertical, 10)
                        .overlay(alignment: .bottom) { Rectangle().fill(Color.borderDivider).frame(height: 1) }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.borderDivider).frame(height: 1) }
    }

    // MARK: - 收货地址
    private var addressSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: 6) {
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.accentDefault)
                Text("收货地址")
                    .font(.cardTitle)
                    .foregroundStyle(Color.textPrimary)
            }
            .padding(.horizontal, AppSpacing.lg)

            if let address = selectedAddress {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(address.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                        Text(address.maskedPhone)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textSecondary)
                        if address.isDefault {
                            Text("默认")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 6).padding(.vertical, 1)
                                .background(Color.brandDefault)
                                .clipShape(Capsule())
                        }
                    }
                    Text(address.fullAddress)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textTertiary)
                        .lineLimit(2)
                }
                .padding(AppSpacing.md)
                .background(Color.bgSecondary)
                .cornerRadius(AppRadius.md)
                .overlay(RoundedRectangle(cornerRadius: AppRadius.md).stroke(Color.borderDefault, lineWidth: 1))
                .padding(.horizontal, AppSpacing.lg)
            } else {
                NavigationLink {
                    AddressListView()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.brandDefault)
                        Text("添加收货地址")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.brandDefault)
                        Spacer()
                    }
                    .padding(AppSpacing.md)
                    .background(Color.bgSecondary)
                    .cornerRadius(AppRadius.md)
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.md).stroke(Color.borderDefault, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, AppSpacing.lg)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(viewModel.addresses) { addr in
                        let isSelected = selectedAddress?.id == addr.id
                        Text(addr.name + " " + addr.district)
                            .font(.system(size: 11))
                            .foregroundStyle(isSelected ? Color.white : Color.textTertiary)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(isSelected ? Color.brandDefault : Color.bgTertiary)
                            .clipShape(Capsule())
                            .contentShape(Capsule())
                            .onTapGesture {
                                selectedAddress = addr
                            }
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
            }
        }
    }

    // MARK: - 加持服务
    private var blessingSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.accentDefault)
                Text("法师加持")
                    .font(.cardTitle)
                    .foregroundStyle(Color.textPrimary)
            }
            .padding(.horizontal, AppSpacing.lg)

            HStack(spacing: AppSpacing.md) {
                Image(systemName: selectedBlessingService == nil ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(selectedBlessingService == nil ? Color.brandDefault : Color.textTertiary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("不需要加持")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Text("订单只包含材料和制作费用")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textTertiary)
                }
                Spacer()
            }
            .padding(AppSpacing.md)
            .background(selectedBlessingService == nil ? Color.brandDefault.opacity(0.08) : Color.bgSecondary)
            .cornerRadius(AppRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(selectedBlessingService == nil ? Color.brandDefault : Color.borderDefault, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    selectedBlessingService = nil
                }
            }
            .padding(.horizontal, AppSpacing.lg)

            ForEach(viewModel.blessingServices) { service in
                let isSelected = selectedBlessingService?.id == service.id
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(isSelected ? Color.brandDefault : Color.textTertiary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(service.serviceName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                        Text(service.description)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textTertiary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Text("+\(service.priceText)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.brandDefault)
                }
                .padding(AppSpacing.md)
                .background(isSelected ? Color.brandDefault.opacity(0.08) : Color.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(isSelected ? Color.brandDefault : Color.borderDefault, lineWidth: 1))
                .contentShape(Rectangle())
                .onTapGesture { selectedBlessingService = service }
                .padding(.horizontal, AppSpacing.lg)
            }
        }
    }

    // MARK: - 费用明细
    private var feeSection: some View {
        VStack(spacing: 0) {
            feeRow(label: "材料费",
                   value: "¥\(Int(viewModel.currentDesign?.totalPrice ?? viewModel.totalPrice))")
            feeRow(label: "加持费",
                   value: selectedBlessingService?.priceText ?? "¥0")
            feeRow(label: "运费", value: "包邮")
            feeRow(label: "合计",
                   value: totalFeeText,
                   isLast: true, highlight: true)
        }
        .background(Color.bgSecondary)
        .cornerRadius(AppRadius.md)
        .padding(.horizontal, AppSpacing.lg)
    }

    private func feeRow(label: String, value: String,
                        isLast: Bool = false, highlight: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(highlight ? Color.textPrimary : Color.textTertiary)
                Spacer()
                Text(value)
                    .font(.system(size: highlight ? 18 : 14, weight: highlight ? .bold : .medium))
                    .foregroundStyle(highlight ? Color.brandDefault : Color.textPrimary)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, 14)

            if !isLast {
                Rectangle().fill(Color.borderDivider).frame(height: 1).padding(.leading, AppSpacing.lg)
            }
        }
    }

    private var totalFeeText: String {
        let material = viewModel.currentDesign?.totalPrice ?? viewModel.totalPrice
        let bless = selectedBlessingService?.price ?? 0
        return "¥\(Int(material + bless))"
    }

    private var checkoutSlots: [DiyBeadSlot] {
        if !viewModel.beadSlots.isEmpty { return viewModel.beadSlots }
        guard let raw = viewModel.currentDesign?.designData,
              let data = raw.data(using: .utf8),
              let document = try? JSONDecoder().decode(DiyDesignDocument.self, from: data) else { return [] }
        return document.beads.sorted { $0.position < $1.position }
    }

    private var materialLines: [DiyCheckoutMaterialLine] {
        var grouped: [String: DiyCheckoutMaterialLine] = [:]
        for slot in checkoutSlots {
            let key = "\(slot.materialId)|\(slot.spec)"
            if var line = grouped[key] {
                line.quantity += 1
                grouped[key] = line
            } else {
                grouped[key] = DiyCheckoutMaterialLine(
                    id: key,
                    name: slot.materialName,
                    spec: slot.spec,
                    unitPrice: slot.unitPrice,
                    quantity: 1,
                    color: Color(hex: slot.colorHex ?? "8F3B3B")
                )
            }
        }
        return grouped.values.sorted { $0.name < $1.name }
    }

    // MARK: - 底部提交栏
    private var submitBar: some View {
        HStack(spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("预估应付")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
                Text(totalFeeText)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.brandDefault)
            }
            Spacer()

            DFPrimaryButton(title: viewModel.isCurrentDesignOrderable ? "提交订单" : "材料需替换", icon: "checkmark.circle.fill",
                            isEnabled: selectedAddress != nil && viewModel.isCurrentDesignOrderable,
                            isLoading: viewModel.isSubmitting) {
                Task {
                    let order = await submitOrder()
                    if let order {
                        checkoutOrder = order
                    }
                }
            }
            .frame(width: 180)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
        .background(
            Color.bgPrimary.opacity(0.95)
                .background(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) { Rectangle().fill(Color.borderDivider).frame(height: 1) }
    }

    private func availabilityWarning(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("部分材料需要重新选择", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.stateWarning)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.lg)
        .background(Color.stateWarning.opacity(0.1))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.md).stroke(Color.stateWarning.opacity(0.35), lineWidth: 1))
        .cornerRadius(AppRadius.md)
        .padding(.horizontal, AppSpacing.lg)
    }

    private func submitOrder() async -> DiyOrder? {
        guard let addressId = selectedAddress?.id else {
            viewModel.errorMessage = "请选择收货地址"
            return nil
        }
        let blessServiceCode = selectedBlessingService?.serviceCode
        switch orderSource {
        case .cart:
            return await viewModel.createOrder(
                designId: designId,
                addressId: addressId,
                blessServiceCode: blessServiceCode
            )
        case .design:
            return await viewModel.createOrderFromDesign(
                designId: designId,
                addressId: addressId,
                blessServiceCode: blessServiceCode
            )
        }
    }
}

private struct DiyCheckoutMaterialLine: Identifiable {
    let id: String
    let name: String
    let spec: String
    let unitPrice: Double
    var quantity: Int
    let color: Color

    var total: Double { unitPrice * Double(quantity) }
}

private struct DiyPaymentFlowView: View {
    let order: DiyOrder
    @ObservedObject var viewModel: DiyViewModel

    @State private var paymentResult: PaymentCreateResult?
    @State private var payment: PaymentRecord?
    @State private var showOrderDetail = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                orderAmount
                if order.priceChanged == true {
                    priceChangeNotice
                }
                paymentChannel
                paymentStatus
                actions
            }
            .padding(AppSpacing.lg)
        }
        .background(Color.bgPrimary)
        .navigationTitle("支付结果")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("关闭") { dismiss() }
            }
        }
		.navigationDestination(isPresented: $showOrderDetail) {
			DiyOrderResultDetailView(order: viewModel.currentOrder ?? order)
        }
        .alert("提示", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var orderAmount: some View {
        VStack(spacing: 8) {
            Image(systemName: paymentIcon)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(paymentColor)
            Text(paymentTitle)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
            Text("¥\(String(format: "%.2f", order.totalFee))")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Color.brandDefault)
            Text(order.orderNo)
                .font(.system(size: 12))
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.lg)
    }

    private var priceChangeNotice: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.stateWarning)
            VStack(alignment: .leading, spacing: 3) {
                Text("材料价格已更新")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text("作品展示 ¥\(String(format: "%.2f", order.originalMaterialFee ?? 0))，最终材料费 ¥\(String(format: "%.2f", order.materialFee))")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer()
        }
        .padding(AppSpacing.md)
        .background(Color.stateWarning.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
    }

    private var paymentChannel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("支付方式")
                .font(.cardTitle)
                .foregroundStyle(Color.textPrimary)
            Label("本地模拟支付（仅开发/测试）", systemImage: "testtube.2")
                .font(.system(size: 14))
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.md)
                .background(Color.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var paymentStatus: some View {
        if let payment {
            HStack {
                Text("支付状态")
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                Text(paymentStatusText(payment.status))
                    .fontWeight(.semibold)
                    .foregroundStyle(payment.status == "success" ? Color.stateSuccess : Color.stateWarning)
            }
            .font(.system(size: 14))
            .padding(AppSpacing.md)
            .background(Color.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        }
    }

    private var actions: some View {
        VStack(spacing: AppSpacing.md) {
            if let paymentResult {
                if let raw = paymentResult.payUrl, let url = URL(string: raw) {
                    Link(destination: url) {
                        Label("前往支付", systemImage: "arrow.up.right.square")
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.brandDefault)
                }
                Button {
                    Task { payment = await viewModel.loadPayment(id: paymentResult.id) }
                } label: {
                    Label("查询支付结果", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.bordered)
            } else {
                Button {
                    Task {
                        paymentResult = await viewModel.createPayment(for: order, channel: "mock")
                        if let paymentResult {
                            payment = await viewModel.loadPayment(id: paymentResult.id)
                        }
                    }
                } label: {
                    Text("模拟支付 ¥\(String(format: "%.2f", order.totalFee))")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.brandDefault)
                .disabled(viewModel.isSubmitting)
            }

            Button {
                Task {
                    await viewModel.loadOrder(id: order.id)
                    showOrderDetail = true
                }
            } label: {
                Label("查看订单详情", systemImage: "doc.text.magnifyingglass")
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.bordered)
        }
    }

    private var paymentTitle: String {
        switch payment?.status {
        case "success": return "支付成功"
        case "failed", "closed": return "支付未完成"
        default: return paymentResult == nil ? "订单已创建" : "等待支付"
        }
    }

    private var paymentIcon: String {
        payment?.status == "success" ? "checkmark.circle.fill" : "creditcard.fill"
    }

    private var paymentColor: Color {
        payment?.status == "success" ? Color.stateSuccess : Color.accentDefault
    }

    private func paymentStatusText(_ status: String) -> String {
        switch status {
        case "pending": return "待支付"
        case "success": return "支付成功"
        case "failed": return "支付失败"
        case "closed": return "已关闭"
        case "refunding": return "退款中"
        case "refunded": return "已退款"
        default: return status
        }
    }
}

private struct DiyOrderResultDetailView: View {
	let order: DiyOrder

    var body: some View {
        List {
            Section("订单") {
                detailRow("订单号", order.orderNo)
                detailRow("状态", order.statusDisplayText)
                detailRow("材料费", "¥\(String(format: "%.2f", order.materialFee))")
                detailRow("加持费", "¥\(String(format: "%.2f", order.blessFee))")
                detailRow("合计", "¥\(String(format: "%.2f", order.totalFee))")
            }
            if let items = order.items, !items.isEmpty {
                Section("材料明细") {
                    ForEach(items) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.materialName)
                                Text("\(item.spec) × \(item.quantity)")
                                    .font(.caption)
                                    .foregroundStyle(Color.textTertiary)
                            }
                            Spacer()
                            Text("¥\(String(format: "%.2f", item.unitPrice * Double(item.quantity)))")
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.bgPrimary)
        .navigationTitle("订单详情")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Color.textSecondary)
            Spacer()
            Text(value).foregroundStyle(Color.textPrimary)
        }
    }
}

#Preview {
    NavigationStack {
        DiyOrderView(designId: 1, viewModel: DiyViewModel())
    }
    .preferredColorScheme(.dark)
}
