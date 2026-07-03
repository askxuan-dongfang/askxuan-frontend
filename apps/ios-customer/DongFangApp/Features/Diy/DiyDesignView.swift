//
//  DiyDesignView.swift
//  DongFangApp
//
//  DIY 设计编辑器：名称输入 + 材料分类 Tab + 材料列表 + 购物车 + 保存/下单。
//

import SwiftUI

struct DiyDesignView: View {
    @StateObject private var viewModel = DiyViewModel()
    @State private var showSaveAlert: Bool = false
    @State private var designNameInput: String = "我的手串"
    @State private var showOrderPage: Bool = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                topBar
                nameInputSection
                categoryTab
                materialsList
                cartPreview
            }

            bottomActionBar
        }
        .background(Color.bgPrimary)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if viewModel.materials.isEmpty { await viewModel.loadMaterials() }
        }
        .alert("保存设计", isPresented: $showSaveAlert) {
            TextField("设计名称", text: $designNameInput)
            Button("取消", role: .cancel) {}
            Button("保存") {
                viewModel.designName = designNameInput
                Task {
                    let ok = await viewModel.saveDesign()
                    if ok, viewModel.currentDesign != nil {
                        showOrderPage = true
                    }
                }
            }
        } message: {
            Text("请输入设计名称")
        }
        .alert("提示", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: $showOrderPage) {
            if let design = viewModel.currentDesign {
                NavigationStack {
                    DiyOrderView(designId: design.id, viewModel: viewModel)
                }
            }
        }
    }


    // MARK: - 顶部
    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.accentDefault)
                    .frame(width: 36, height: 36)
            }
            Spacer()
            Text("设计手串")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.accentDefault)
            Spacer()
            Button {
                viewModel.clearCart()
            } label: {
                Text("清空")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppSpacing.lg)
        .frame(height: AppSpacing.navTop)
        .background(Color.bgPrimary.opacity(0.85).background(.ultraThinMaterial))
        .overlay(alignment: .bottom) { Rectangle().fill(Color.borderDivider).frame(height: 1) }
    }

    // MARK: - 名称输入
    private var nameInputSection: some View {
        HStack {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 14))
                .foregroundStyle(Color.accentDefault)
            TextField("为你的手串起个名字", text: $designNameInput)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.textPrimary)
            Spacer()
            Text("¥\(Int(viewModel.totalPrice))")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.brandDefault)
        }
        .padding(AppSpacing.md)
        .background(Color.bgSecondary)
        .cornerRadius(AppRadius.md)
        .overlay(RoundedRectangle(cornerRadius: AppRadius.md).stroke(Color.borderDefault, lineWidth: 1))
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.md)
    }

    // MARK: - 分类 Tab
    private var categoryTab: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(viewModel.categories, id: \.code) { category in
                    let isSelected = viewModel.selectedCategory == category.code
                    HStack(spacing: 4) {
                        Image(systemName: category.icon)
                            .font(.system(size: 11))
                        Text(category.name)
                            .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    }
                    .foregroundStyle(isSelected ? Color.white : Color.textTertiary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isSelected ? Color.brandDefault : Color.bgTertiary)
                    .clipShape(Capsule())
                    .contentShape(Capsule())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            viewModel.selectCategory(category.code)
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)
        }
    }

    // MARK: - 材料列表
    private var materialsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.md), count: 2),
                      spacing: AppSpacing.md) {
                ForEach(viewModel.filteredMaterials) { material in
                    materialCard(material)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, 200) // 给购物车预览和底部栏留空
        }
    }

    private func materialCard(_ material: Material) -> some View {
        let inCart = viewModel.cartItems.first(where: { $0.material.id == material.id })
        return VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .fill(
                        LinearGradient(
                            colors: [Color.bgTertiary, Color.bgElevated],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "circle.dashed")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.accentDefault)
                if let inCart {
                    Text("×\(inCart.quantity)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.brandDefault)
                        .clipShape(Capsule())
                        .padding(6)
                }
            }
            .frame(height: 80)
            .cornerRadius(AppRadius.md)
            .overlay(alignment: .topTrailing) {
                if inCart != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.stateSuccess)
                        .padding(6)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(material.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Text(material.spec)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
                HStack {
                    Text(material.priceText)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.brandDefault)
                    Spacer()
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.brandDefault)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.addToCart(material)
                        }
                }
            }
        }
        .padding(AppSpacing.sm)
        .background(Color.bgSecondary)
        .cornerRadius(AppRadius.lg)
        .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
    }

    // MARK: - 购物车预览
    private var cartPreview: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("已选材料 (\(viewModel.totalQuantity))")
                    .font(.cardTitle)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Text(viewModel.totalPriceText)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.brandDefault)
            }

            if viewModel.cartItems.isEmpty {
                Text("请从上方选择材料")
                    .font(.caption)
                    .foregroundStyle(Color.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.sm) {
                        ForEach(viewModel.cartItems) { item in
                            cartChip(item)
                        }
                    }
                }
            }
        }
        .padding(AppSpacing.md)
        .background(Color.bgSecondary)
        .cornerRadius(AppRadius.lg)
        .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
        .padding(.horizontal, AppSpacing.lg)
        .padding(.bottom, 80)
    }

    private func cartChip(_ item: DiyCartItem) -> some View {
        HStack(spacing: 6) {
            Text(item.material.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.textPrimary)
            Text("×\(item.quantity)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.brandDefault)
            Button {
                viewModel.removeFromCart(item)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.bgTertiary)
        .clipShape(Capsule())
    }

    // MARK: - 底部操作栏
    private var bottomActionBar: some View {
        HStack(spacing: AppSpacing.md) {
            DFSecondaryButton(title: "保存设计", icon: "tray.and.arrow.down") {
                showSaveAlert = true
            }
            DFPrimaryButton(title: "立即下单", icon: "creditcard.fill",
                            isEnabled: !viewModel.cartItems.isEmpty) {
                Task {
                    let ok = await viewModel.saveDesign()
                    if ok, viewModel.currentDesign != nil {
                        showOrderPage = true
                    }
                }
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
    NavigationStack { DiyDesignView() }
        .preferredColorScheme(.dark)
}
