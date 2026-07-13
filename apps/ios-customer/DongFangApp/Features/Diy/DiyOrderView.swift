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
    @State private var selectedAddress: UserAddress? = UserAddress.mockAddresses.first
    @State private var needBlessing: Bool = true
    @State private var checkoutOrder: DiyOrder?

    init(designId: Int64, viewModel: DiyViewModel? = nil, orderSource: DiyOrderSource = .cart) {
        self.designId = designId
        self.orderSource = orderSource
        if let viewModel = viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: DiyViewModel())
        }
    }

    private let blessingFee: Double = 100

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {
                    designSummary
                    addressSection
                    blessingSection
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
    }

    // MARK: - 设计概要
    private var designSummary: some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .fill(
                        LinearGradient(
                            colors: [Color.brandDefault.opacity(0.2), Color.accentDefault.opacity(0.15)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "circle.grid.2x2.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.accentDefault)
            }
            .frame(width: 64, height: 64)
            .cornerRadius(AppRadius.md)

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.currentDesign?.name ?? "我的手串")
                    .font(.cardTitle)
                    .foregroundStyle(Color.textPrimary)
                Text("编号：\(viewModel.currentDesign?.designNo ?? "—")")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
                Text(materialSummaryText)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            Text("¥\(Int(viewModel.currentDesign?.totalPrice ?? viewModel.totalPrice))")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.brandDefault)
        }
        .padding(AppSpacing.md)
        .background(Color.bgSecondary)
        .cornerRadius(AppRadius.lg)
        .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
        .padding(.horizontal, AppSpacing.lg)
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
                Button {
                    // 跳转地址管理（简化）
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
                    ForEach(UserAddress.mockAddresses) { addr in
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
                Image(systemName: needBlessing ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(needBlessing ? Color.brandDefault : Color.textTertiary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("法师开光加持服务")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Text("由法师诵经开光加持，使法物更具灵性。")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textTertiary)
                        .lineSpacing(3)
                }
                Spacer()
                Text("+¥\(Int(blessingFee))")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.brandDefault)
            }
            .padding(AppSpacing.md)
            .background(needBlessing ? Color.brandDefault.opacity(0.08) : Color.bgSecondary)
            .cornerRadius(AppRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(needBlessing ? Color.brandDefault : Color.borderDefault, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    needBlessing.toggle()
                }
            }
            .padding(.horizontal, AppSpacing.lg)
        }
    }

    // MARK: - 费用明细
    private var feeSection: some View {
        VStack(spacing: 0) {
            feeRow(label: "材料费",
                   value: "¥\(Int(viewModel.currentDesign?.totalPrice ?? viewModel.totalPrice))")
            feeRow(label: "加持费",
                   value: needBlessing ? "¥\(Int(blessingFee))" : "¥0")
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
        let bless = needBlessing ? blessingFee : 0
        return "¥\(Int(material + bless))"
    }

    private var materialSummaryText: String {
        if viewModel.totalQuantity > 0 {
            return "\(viewModel.totalQuantity) 种材料"
        }
        return orderSource == .design ? "按设计方案下单" : "未选择材料"
    }

    // MARK: - 底部提交栏
    private var submitBar: some View {
        HStack(spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("应付")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
                Text(totalFeeText)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.brandDefault)
            }
            Spacer()

            DFPrimaryButton(title: "提交订单", icon: "checkmark.circle.fill",
                            isEnabled: selectedAddress != nil,
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

    private func submitOrder() async -> DiyOrder? {
        let addressId = selectedAddress?.id ?? 1
        let blessServiceCode = needBlessing ? "BLESS_DIY" : nil
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

private struct DiyPaymentFlowView: View {
    let order: DiyOrder
    @ObservedObject var viewModel: DiyViewModel

    @State private var channel = "wechat"
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
            Picker("支付方式", selection: $channel) {
                Text("微信支付").tag("wechat")
                Text("支付宝").tag("alipay")
            }
            .pickerStyle(.segmented)
            .disabled(paymentResult != nil)
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
                        paymentResult = await viewModel.createPayment(for: order, channel: channel)
                        if let paymentResult {
                            payment = await viewModel.loadPayment(id: paymentResult.id)
                        }
                    }
                } label: {
                    Text("确认支付 ¥\(String(format: "%.2f", order.totalFee))")
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
