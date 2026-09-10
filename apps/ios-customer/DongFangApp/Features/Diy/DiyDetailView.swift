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
    @State private var showEditor = false
    @State private var showPublishConfirm = false
    @State private var show3D = false
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
                    publicationSection
                    infoSection
                    materialsSection
                    if let message = viewModel.availabilityMessage {
                        availabilityWarning(message)
                    }
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
        .sheet(isPresented: $showEditor) { NavigationStack { DiyDesignView(viewModel: viewModel) } }
        .confirmationDialog(viewModel.currentDesign?.status == "public" ? "下架后，仅你可见；已有副本与订单保留。" : "发布后，其他人可以分享、复制搭配和定制。", isPresented: $showPublishConfirm, titleVisibility: .visible) {
            Button(viewModel.currentDesign?.status == "public" ? "确认下架" : "确认发布") { Task { await viewModel.setPublication(viewModel.currentDesign?.status != "public") } }
        }
        .alert("提示", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) { Button("好的", role: .cancel) {} } message: { Text(viewModel.errorMessage ?? "") }
        .sheet(isPresented: $showOrderPage) {
            NavigationStack {
                DiyOrderView(designId: viewModel.currentDesign?.id ?? designId, viewModel: viewModel, orderSource: viewModel.isDesignOwner ? .cart : .design)
            }
        }
    }

    // MARK: - 作品预览
    private var previewSection: some View {
        VStack(spacing: 12) {
            HStack { DFBackButton(style: .circle); Spacer(); Button(show3D ? "2D 作品" : "3D 环视") { show3D.toggle() }.font(.caption).foregroundStyle(Color.accentDefault) }.padding(.top, 56).padding(.horizontal)
            if show3D { DiyNativeStage3D(slots: viewModel.beadSlots).frame(height: 280) }
            else { DiyMiniBracelet(slots: viewModel.beadSlots, fallbackCount: 0).frame(height: 260) }
            Text(viewModel.currentDesign?.name ?? "我的手串").font(AppTypography.title(24)).foregroundStyle(Color.textPrimary)
            Text(viewModel.currentDesign?.description ?? "把喜欢的珠子，串成自己的心意。").font(.caption).foregroundStyle(Color.textSecondary).padding(.horizontal)
            Text(viewModel.totalPriceText).font(.title3).foregroundStyle(Color.accentDefault)
        }.padding(.bottom, 24).background(Color(hex: "30251E"))
    }
    private var publicationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                if viewModel.isDesignOwner { Button(viewModel.currentDesign?.status == "public" ? "下架作品" : "发布到广场") { showPublishConfirm = true }.disabled(viewModel.isSubmitting) }
                Spacer()
                if viewModel.currentDesign?.status == "public", let url = URL(string: "/c/diy/\(viewModel.currentDesign?.id ?? designId)", relativeTo: AppConfig.baseURL)?.absoluteURL {
                    ShareLink(item: url) { Label("分享作品", systemImage: "square.and.arrow.up") }
                }
            }.font(.subheadline).foregroundStyle(Color.accentDefault)
            if let message = viewModel.successMessage { Text(message).font(.caption).foregroundStyle(Color.stateSuccess) }
            if let source = viewModel.currentDesign?.sourceDesignId, source > 0 { Text("源自作品 #\(source) 的灵感再创作").font(.caption).foregroundStyle(Color.textTertiary) }
            Text("复制后保留珠子顺序，自由替换材料；原作品不会改变。").font(.caption).foregroundStyle(Color.textSecondary)
            if let url = URL(string: "/assets/diy/credits.html", relativeTo: AppConfig.baseURL)?.absoluteURL { Link("实拍参考与材质素材来源", destination: url).font(.caption) }
        }.padding().background(Color.bgSecondary).cornerRadius(AppRadius.md).padding(.horizontal)
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
                    .font(AppTypography.body)
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
                    .font(AppTypography.caption)
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
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.brandDefault)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(AppSpacing.md)
        .background(Color.bgSecondary)
        .cornerRadius(AppRadius.md)
        .overlay(RoundedRectangle(cornerRadius: AppRadius.md).stroke(Color.borderDefault, lineWidth: 1))
    }

    private func availabilityWarning(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("该作品暂不可直接下单", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.stateWarning)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)
            Text("请进入编辑器替换已失效材料。")
                .font(.system(size: 12))
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.lg)
        .background(Color.stateWarning.opacity(0.1))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.md).stroke(Color.stateWarning.opacity(0.35), lineWidth: 1))
        .cornerRadius(AppRadius.md)
        .padding(.horizontal, AppSpacing.lg)
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
            DFSecondaryButton(title: viewModel.isDesignOwner ? "继续编辑" : "复制并编辑", icon: "pencil") {
                if viewModel.isDesignOwner { showEditor = true }
                else { Task { if await viewModel.copyCurrentDesign() { showEditor = true } } }
            }
            DFPrimaryButton(
                title: viewModel.isCurrentDesignOrderable ? "立即下单" : "材料需替换",
                icon: "creditcard.fill",
                isEnabled: viewModel.isCurrentDesignOrderable
            ) {
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
