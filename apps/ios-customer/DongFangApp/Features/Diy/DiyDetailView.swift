//
//  DiyDetailView.swift
//  DongFangApp
//
//  广场作品详情：只读预览、作者与用料；复制后进入编辑器。
//

import SwiftUI

struct DiyDetailView: View {
    let designId: Int64
    @StateObject private var editorModel = DiyViewModel()

    @StateObject private var viewModel: DiyViewModel
    @ObservedObject private var auth = AuthStore.shared
    @State private var showLogin = false
    @State private var pendingAction: String?
    @State private var showEditor = false
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
        VStack(spacing: 0) {
            DFTopNavBar("作品详情", showsBackButton: true) { EmptyView() } trailing: {
                if viewModel.currentDesign?.status == "public", let url = URL(string: "/c/diy/\(designId)", relativeTo: AppConfig.baseURL)?.absoluteURL {
                    ShareLink(item: url) { Image(systemName: "square.and.arrow.up").frame(width: 44, height: 44) }
                        .accessibilityLabel(L10n.text("分享作品"))
                }
            }
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {
                    if viewModel.isLoading && viewModel.currentDesign == nil {
                        ProgressView(L10n.text("正在展开作品")).tint(Color.accentDefault).frame(maxWidth: .infinity, minHeight: 320)
                    } else if viewModel.currentDesign == nil {
                        VStack(spacing: 16) {
                            Image(systemName: "square.stack").font(.largeTitle)
                            Text(L10n.text("暂时无法打开作品")).font(.headline)
                            Button(L10n.text("重新加载")) { Task { await viewModel.loadDesign(id: designId, checkAvailability: false, persistRestoredDraft: false, published: true) } }.frame(minHeight: 44)
                        }.foregroundStyle(Color.textSecondary).frame(maxWidth: .infinity, minHeight: 320)
                    } else {
                        previewSection
                        materialsSection
                    }
                }.padding(.vertical, 16)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if viewModel.currentDesign != nil { bottomActionBar }
            }
        }
        .background(Color.bgPrimary)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.loadDesign(id: designId, checkAvailability: false, persistRestoredDraft: false, published: true)
        }
        .sheet(isPresented: $showLogin, onDismiss: {
            if auth.isLoggedIn, let action = pendingAction { pendingAction = nil; performAction(action) }
        }) { NavigationStack { LoginView() }.appVisualDefaults() }
        .onChange(of: auth.isLoggedIn) { _, loggedIn in if loggedIn { showLogin = false } }
        .sheet(isPresented: $showEditor) { NavigationStack { DiyDesignView(viewModel: editorModel) } }
        .alert(L10n.text("提示"), isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) { Button(L10n.text("好的"), role: .cancel) {} } message: { Text(L10n.lookup(viewModel.errorMessage ?? "")) }
    }

    // The gallery detail is a viewing surface even for its author.
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DiyNativeStage3D(slots: viewModel.beadSlots, wrist: Double(viewModel.wristSizeMm), allowance: viewModel.fitAllowanceMm)
                .frame(height: 310).accessibilityIdentifier("diy-readonly-preview")
            Text(L10n.lookup(viewModel.currentDesign?.name ?? "我的手串"))
                .font(AppTypography.title(24)).foregroundStyle(Color.textPrimary)
            Text(L10n.lookup(authorText)).font(.subheadline).foregroundStyle(Color.textSecondary)
                .accessibilityIdentifier("diy-design-author")
            if let description = viewModel.currentDesign?.description, !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(description).font(.subheadline).foregroundStyle(Color.textSecondary)
            }
            HStack {
                Text(L10n.text("\(viewModel.beadSlots.count) 颗"))
                Text(L10n.lookup(String(format: "%.1f cm 手围", Double(viewModel.wristSizeMm) / 10)))
                Spacer()
                Text(L10n.text("材料参考价") + String(format: " ¥%.2f", viewModel.currentDesign?.publication?.materialFee ?? viewModel.totalPrice)).foregroundStyle(Color.accentLight)
            }.font(.caption).foregroundStyle(Color.textSecondary)
        }.padding(.horizontal, 20)
    }
    private var authorText: String {
        if viewModel.isDesignOwner { return "作者：我" }
        guard let id = viewModel.currentDesign?.userId, !id.isEmpty else { return "作者信息暂缺" }
        return "创作者 #\(id)"
    }

    // MARK: - 材料清单
    private var materialsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text(L10n.text("材料清单"))
                    .font(.cardTitle)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Text(L10n.text("\(viewModel.cartItems.count) 种"))
                    .font(AppTypography.caption)
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.lg)

            if viewModel.cartItems.isEmpty {
                Text(L10n.text("材料配置暂未加载"))
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
            DiyMaterialBead(name: item.material.name, category: item.material.category, size: 38, isSelected: false,
                            shape: item.material.shape ?? "round", colorHex: item.material.colorHex,
                            textureKey: item.material.textureKey, finish: item.material.finish,
                            translucency: item.material.translucency ?? 0, renderAssets: item.material.renderAssets, materialId: item.material.id, materialType: item.material.materialType)
                .frame(width: 44, height: 44).accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.lookup(item.material.name))
                    .font(AppTypography.body.weight(.medium))
                    .foregroundStyle(Color.textPrimary)
                Text("\(item.material.spec) · \(item.material.categoryDisplay)")
                    .font(AppTypography.micro)
                    .foregroundStyle(Color.textTertiary)
            }

            Spacer()

            Text("×\(item.quantity)")
                .font(AppTypography.supporting.weight(.semibold))
                .foregroundStyle(Color.textSecondary)
            Text(L10n.lookup(item.subtotalText))
                .font(AppTypography.body.weight(.semibold))
                .foregroundStyle(Color.brandDefault)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(AppSpacing.md)
        .background(Color.bgSecondary)
        .cornerRadius(AppRadius.md)
        .overlay(RoundedRectangle(cornerRadius: AppRadius.md).stroke(Color.borderDefault, lineWidth: 1))
    }

    private func performAction(_ action: String) {
        guard auth.isLoggedIn else { pendingAction = action; showLogin = true; return }
        guard !editorModel.isSubmitting else { return }
        Task {
            editorModel.currentDesign = viewModel.currentDesign
            editorModel.materials = viewModel.materials
            if await editorModel.copyCurrentDesign() { showEditor = true }
            else { viewModel.errorMessage = editorModel.errorMessage }
        }
    }

    // MARK: - 底部操作栏
    private var bottomActionBar: some View {
        DFPrimaryButton(title: L10n.text("复制并编辑"), icon: "square.on.square") { performAction("copy") }
        .disabled(editorModel.isSubmitting)
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
