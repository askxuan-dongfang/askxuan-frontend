//
//  DiyDetailView.swift
//  DongFangApp
//
//  DIY 作品详情页：作品预览 + 信息卡 + 材料清单 + 加持状态 + 操作入口。
//

import SwiftUI

struct DiyDetailView: View {
    let designId: Int64

    @StateObject private var viewModel: DiyViewModel
    @State private var showOrderPage: Bool = false
    @Environment(\.dismiss) private var dismiss

    init(designId: Int64, viewModel: DiyViewModel? = nil) {
        self.designId = designId
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
                    previewSection
                    infoSection
                    materialsSection
                    blessingSection
                    Spacer(minLength: 100)
                }
            }
            .ignoresSafeArea(edges: .top)

            bottomActionBar
        }
        .background(Color.bgPrimary)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if viewModel.currentDesign == nil {
                await viewModel.loadDesign(id: designId)
            }
        }
        .sheet(isPresented: $showOrderPage) {
            NavigationStack {
                DiyOrderView(designId: designId, viewModel: viewModel)
            }
        }
    }

    // MARK: - 作品预览
    private var previewSection: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [Color.brandDark.opacity(0.7), Color.bgPrimary],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 240)

            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.accentDefault)
                        .frame(width: 36, height: 36)
                        .background(Color.bgPrimary.opacity(0.6))
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.borderDefault, lineWidth: 1))
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, 56)

            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.brandDefault.opacity(0.3), Color.accentDefault.opacity(0.2)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .overlay(Circle().stroke(Color.borderDefault, lineWidth: 1))
                    Image(systemName: "circle.grid.2x2.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.accentDefault)
                }
                .frame(width: 72, height: 72)
                .padding(.top, 90)

                Text(viewModel.currentDesign?.name ?? "我的手串")
                    .font(.custom(AppFont.serif[0], size: 20).weight(.bold))
                    .foregroundStyle(Color.accentDefault)
                Text("¥\(Int(viewModel.currentDesign?.totalPrice ?? 0))")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.brandDefault)
            }
        }
        .frame(height: 240)
    }

    // MARK: - 信息卡
    private var infoSection: some View {
        VStack(spacing: 0) {
            infoRow(label: "设计编号", value: viewModel.currentDesign?.designNo ?? "—")
            infoRow(label: "创建时间", value: viewModel.currentDesign?.createTime ?? "—")
            infoRow(label: "总价", value: "¥\(Int(viewModel.currentDesign?.totalPrice ?? 0))")
            infoRow(label: "状态", value: designStatusText, isLast: true)
        }
        .background(Color.bgSecondary)
        .cornerRadius(AppRadius.md)
        .padding(.horizontal, AppSpacing.lg)
    }

    private func infoRow(label: String, value: String, isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textTertiary)
                Spacer()
                Text(value)
                    .font(.body)
                    .foregroundStyle(Color.textPrimary)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, 14)

            if !isLast {
                Rectangle().fill(Color.borderDivider).frame(height: 1).padding(.leading, AppSpacing.lg)
            }
        }
    }

    private var designStatusText: String {
        switch viewModel.currentDesign?.status ?? "" {
        case "private":          return "私有"
        case "public":           return "公开"
        case "pending_review":   return "待审核"
        case "approved":         return "已通过"
        case "rejected":         return "已拒绝"
        default:                 return "—"
        }
    }

    // MARK: - 材料清单
    private var materialsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("材料清单")
                    .font(.cardTitle)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Text("\(viewModel.cartItems.count) 种")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.lg)

            if viewModel.cartItems.isEmpty {
                Text("材料配置暂未加载")
                    .font(.caption)
                    .foregroundStyle(Color.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.lg)
                    .padding(.horizontal, AppSpacing.lg)
            } else {
                VStack(spacing: AppSpacing.sm) {
                    ForEach(viewModel.cartItems) { item in
                        materialRow(item)
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
            }
        }
    }

    private func materialRow(_ item: DiyCartItem) -> some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .fill(Color.brandDefault.opacity(0.12))
                Image(systemName: "circle.dashed")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.brandDefault)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.material.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                Text("\(item.material.spec) · \(item.material.categoryDisplay)")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
            }

            Spacer()

            Text("×\(item.quantity)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.textSecondary)
            Text(item.subtotalText)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.brandDefault)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(AppSpacing.md)
        .background(Color.bgSecondary)
        .cornerRadius(AppRadius.md)
        .overlay(RoundedRectangle(cornerRadius: AppRadius.md).stroke(Color.borderDefault, lineWidth: 1))
    }

    // MARK: - 加持信息
    private var blessingSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.accentDefault)
                Text("法师加持")
                    .font(.cardTitle)
                    .foregroundStyle(Color.textPrimary)
            }

            HStack(spacing: AppSpacing.md) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.stateSuccess)
                VStack(alignment: .leading, spacing: 4) {
                    Text("可享法师开光加持")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Text("下单时可选择加持服务，由法师诵经开光加持。")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textTertiary)
                        .lineSpacing(3)
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.lg)
        .background(Color.bgSecondary)
        .cornerRadius(AppRadius.lg)
        .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.lg)
    }

    // MARK: - 底部操作栏
    private var bottomActionBar: some View {
        HStack(spacing: AppSpacing.md) {
            DFSecondaryButton(title: "编辑", icon: "pencil") {
                // 编辑会跳转到 DiyDesignView（简化：暂不实现）
            }
            DFPrimaryButton(title: "立即下单", icon: "creditcard.fill") {
                showOrderPage = true
            }
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
    NavigationStack { DiyDetailView(designId: 1) }
        .preferredColorScheme(.dark)
}
