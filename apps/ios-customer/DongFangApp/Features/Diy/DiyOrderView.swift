//
//  DiyOrderView.swift
//  DongFangApp
//
//  DIY 下单页：订单概要 + 收货地址 + 加持服务 + 费用明细 + 提交。
//

import SwiftUI

struct DiyOrderView: View {
    let designId: Int64

    @StateObject private var viewModel: DiyViewModel
    @State private var selectedAddress: UserAddress? = UserAddress.mockAddresses.first
    @State private var needBlessing: Bool = true
    @State private var showSuccess: Bool = false
    @Environment(\.dismiss) private var dismiss

    init(designId: Int64, viewModel: DiyViewModel? = nil) {
        self.designId = designId
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
        .alert("下单成功", isPresented: $showSuccess) {
            Button("查看订单") { dismiss() }
        } message: {
            Text("订单已创建，请前往「我的-订单」查看详情。")
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
                Text("\(viewModel.totalQuantity) 种材料")
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
                    let _ = await viewModel.createOrder(
                        designId: designId,
                        addressId: selectedAddress?.id ?? 1,
                        blessServiceCode: needBlessing ? "BLESS_DIY" : nil
                    )
                    if viewModel.currentOrder != nil {
                        showSuccess = true
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
}

#Preview {
    NavigationStack {
        DiyOrderView(designId: 1, viewModel: DiyViewModel())
    }
    .preferredColorScheme(.dark)
}
