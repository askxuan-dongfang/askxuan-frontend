//
//  DiyDesignView.swift
//  DongFangApp
//

import SwiftUI
import UIKit
import SceneKit
import simd

struct DiyDesignView: View {
    @StateObject private var viewModel: DiyViewModel
    @ObservedObject private var authStore = AuthStore.shared
    @State private var showLogin = false
    @State private var resumeSaveAfterLogin = false
    @State private var showNameDialog = false
    @State private var designNameInput = "我的手串"
    @State private var designDescriptionInput = ""
    @State private var checkoutAfterSave = false
    @State private var showOrderPage = false
    @State private var materialSearch = ""
    @State private var showMyDesigns = false
    @State private var resetView = 0
    @State private var darkSurface = false
    @State private var previewPresentation: DiyPresentationMode?
    @State private var elementFilter = "all"
    @State private var previewExpanded = false
    @State private var replacingBeadId: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var searchFocused: Bool
    @State private var showClearConfirmation = false
    @State private var sizePanelExpanded = false
    @State private var confirmClearAfterFitDismissal = false
    @State private var deletionArmed = false

    @MainActor
    init() {
        _viewModel = StateObject(wrappedValue: DiyViewModel())
    }

    @MainActor
    init(viewModel: DiyViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                topBar
                GeometryReader { geometry in
                    if geometry.size.width >= 700 {
                        HStack(spacing: 12) {
                            composition
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            if !previewExpanded { materialPanel.frame(width: min(380, geometry.size.width * 0.4)) }
                        }.padding(12)
                    } else {
                        VStack(spacing: 10) {
                            composition.frame(height: previewExpanded ? nil : max(280, min(520, geometry.size.height - max(175, geometry.size.height * 0.30))))
                            if !previewExpanded { materialPanel.frame(maxHeight: .infinity) }
                        }.padding(.horizontal, 10).padding(.vertical, 8)
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomActionBar }
            .disabled(viewModel.isSubmitting)

            if viewModel.isSubmitting {
                Color.black.opacity(0.42).ignoresSafeArea()
                ProgressView(L10n.text("正在保存设计"))
                    .tint(.accentDefault)
                    .foregroundStyle(.textPrimary)
                    .padding(24)
                    .background(Color.bgElevated, in: RoundedRectangle(cornerRadius: 20))
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .background(Color.bgPrimary)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { darkSurface = colorScheme == .dark }
        .onChange(of: colorScheme) { _, scheme in darkSurface = scheme == .dark }
        .onChange(of: viewModel.beadSlots.map(\.id)) { _, ids in
            if let replacingBeadId, !ids.contains(replacingBeadId) { self.replacingBeadId = nil }
        }
        .task {
            if viewModel.materials.isEmpty { await viewModel.loadMaterials() }
        }
        .sheet(isPresented: $sizePanelExpanded, onDismiss: {
            guard confirmClearAfterFitDismissal else { return }
            confirmClearAfterFitDismissal = false
            showClearConfirmation = true
        }) {
            ScrollView {
                VStack(spacing: 18) {
                    HStack {
                        Text(L10n.text("佩戴与搭配")).font(.headline)
                        Spacer()
                        Button { sizePanelExpanded = false } label: {
                            Image(systemName: "xmark").frame(width: 44, height: 44)
                        }.accessibilityLabel(L10n.text("关闭佩戴设置"))
                    }
                    sizePanel
                    Divider()
                    Button(L10n.text("清空设计"), role: .destructive) {
                        confirmClearAfterFitDismissal = true
                        sizePanelExpanded = false
                    }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .disabled(viewModel.beadSlots.isEmpty && viewModel.selectedCord == nil)
                }.padding(.horizontal, 24).padding(.vertical, 12)
            }
            .foregroundStyle(Color.textPrimary)
            .presentationDetents([.height(viewModel.selectedCord == nil ? 380 : 430), .large])
            .presentationBackground(Color.bgSecondary)
            .presentationDragIndicator(.visible)
        }
        .confirmationDialog(L10n.text("清空当前搭配？清空后仍可通过撤销恢复。"), isPresented: $showClearConfirmation, titleVisibility: .visible) {
            Button(L10n.text("清空搭配"), role: .destructive) {
                AppMotion.perform { viewModel.clearCart() }
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        }
        .alert(L10n.text("保存设计"), isPresented: $showNameDialog) {
            TextField(L10n.text("设计名称"), text: $designNameInput)
            TextField(L10n.text("搭配灵感（可选）"), text: $designDescriptionInput)
            Button(L10n.text("取消"), role: .cancel) {}
            Button(L10n.text("保存")) { saveDesign() }
        } message: {
            Text(L10n.lookup(viewModel.currentDesign?.publication != nil ? "修改将保存为私有草稿，广场中的已发布定稿保持不变。新款需付款并确认后再发布。" : "保存后可继续编辑；订单付款且款式、用料、价格确认后，可发布到广场。"))
        }
        .alert(L10n.text("提示"), isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button(L10n.text("好的"), role: .cancel) {}
        } message: {
            Text(L10n.lookup(viewModel.errorMessage ?? ""))
        }
        .sheet(isPresented: $showLogin, onDismiss: {
            if resumeSaveAfterLogin && authStore.isLoggedIn { resumeSaveAfterLogin = false; presentSaveDialog(checkout: checkoutAfterSave) }
        }) { NavigationStack { LoginView() }.appVisualDefaults() }
        .onChange(of: authStore.isLoggedIn) { _, loggedIn in if loggedIn && showLogin { showLogin = false } }
        .sheet(isPresented: $showMyDesigns) { NavigationStack { DiyMyDesignsView() } }
        .sheet(isPresented: $showOrderPage) {
            if let design = viewModel.currentDesign {
                NavigationStack {
                    DiyOrderView(designId: design.id, viewModel: viewModel)
                }
            }
        }
    }

    private var topBar: some View {
        HStack {
            DFBackButton()
            Spacer()
            Text(L10n.text("东方珠作")).font(AppTypography.reading.weight(.semibold)).foregroundStyle(.textPrimary)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }.foregroundStyle(.accentDefault).padding(.horizontal, 12).frame(minHeight: 60)
            .background(Color.bgPrimary.opacity(0.96))
            .overlay(alignment: .bottom) { Rectangle().fill(Color.borderDivider).frame(height: 1) }
    }

    private var historyButtons: some View {
        HStack(spacing: 4) {
            Button { viewModel.undo(); UISelectionFeedbackGenerator().selectionChanged() } label: {
                Label(L10n.text("撤销"), systemImage: "arrow.uturn.backward").font(.caption)
                    .frame(minWidth: 48, minHeight: 44)
            }
            .disabled(!viewModel.canUndo)
            .accessibilityLabel(L10n.text("撤销"))
            Button { viewModel.redo(); UISelectionFeedbackGenerator().selectionChanged() } label: {
                Label(L10n.text("重做"), systemImage: "arrow.uturn.forward").font(.caption)
                    .frame(minWidth: 48, minHeight: 44)
            }
            .disabled(!viewModel.canRedo)
            .accessibilityLabel(L10n.text("重做"))
        }.foregroundStyle(Color.textPrimary).buttonStyle(.plain)
    }

    private var composition: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L10n.text("我的手串")).font(.subheadline.weight(.semibold))
                Text(L10n.text("\(viewModel.beadSlots.count) / 60 颗")).font(.caption2).foregroundStyle(Color.textSecondary)
                Spacer()
                Button(L10n.lookup(String(format: "手围 %.1f cm  ›", Double(viewModel.wristSizeMm) / 10))) { sizePanelExpanded = true }
                    .font(.caption).foregroundStyle(Color.textSecondary).frame(minHeight: 36)
            }.padding(.horizontal, 4).frame(height: 32)
            HStack(spacing: 8) {
                Text(L10n.lookup(String(format: "内围预估 %.1f cm", viewModel.fitFeedback.innerMm / 10)))
                Text(L10n.lookup(viewModel.fitFeedback.label))
                    .foregroundStyle(viewModel.fitFeedback.state == .good ? Color.stateSuccess : viewModel.fitFeedback.state == .empty ? Color.textSecondary : Color.stateWarning)
                Spacer()
            }.font(.caption).foregroundStyle(Color.textSecondary).monospacedDigit()
                .padding(.horizontal, 4).frame(minHeight: 22)
                .accessibilityElement(children: .combine).accessibilityIdentifier("diy-fit-feedback")
            DiyNativeStage3D(slots: viewModel.beadSlots, wrist: Double(viewModel.wristSizeMm), allowance: viewModel.fitAllowanceMm,
                selectedId: viewModel.selectedBeadId, onSelect: viewModel.selectBead, onMove: viewModel.moveBead,
                onRemove: viewModel.removeBead, onDeleteState: { deletionArmed = $0 },
                onReplace: { id in
                    replacingBeadId = id
                    materialSearch = ""; elementFilter = "all"; viewModel.selectCategory("all"); previewExpanded = false
                }, onDuplicate: { id in viewModel.selectBead(id); viewModel.duplicateSelectedBead() },
                resetVersion: resetView, darkSurface: darkSurface, cordColor: viewModel.selectedCord?.colorHex, presentationMode: previewPresentation)
                .accessibilityIdentifier("diy-3d-stage")
                .overlay {
                    if viewModel.beadSlots.isEmpty {
                        Text(L10n.text("点选材料，加入手串")).font(.subheadline).foregroundStyle(Color.textSecondary).allowsHitTesting(false)
                    }
                }
                .overlay(alignment: .bottom) {
                    if deletionArmed {
                        Label(L10n.text("松手删除"), systemImage: "trash")
                            .font(.caption.weight(.semibold)).foregroundStyle(Color.stateError)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Color.bgPrimary.opacity(0.94), in: Capsule())
                            .padding(.bottom, 6).allowsHitTesting(false)
                            .accessibilityIdentifier("diy-delete-feedback")
                    }
                }
                .background(darkSurface == (colorScheme == .dark) ? Color.bgPrimary : (darkSurface ? Color(red: 0.15, green: 0.23, blue: 0.2) : Color(red: 0.96, green: 0.95, blue: 0.92)))
                .frame(maxHeight: .infinity)
            HStack(spacing: 0) {
                Button { previewExpanded.toggle() } label: {
                    Image(systemName: previewExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .frame(width: 44, height: 44)
                }.accessibilityLabel(L10n.lookup(previewExpanded ? "收起预览" : "扩大预览")).accessibilityIdentifier("diy-expand-preview")
                Button(L10n.text("复位")) { resetView += 1 }.frame(minWidth: 44, minHeight: 44).accessibilityLabel(L10n.text("重置 3D 视角"))
                Button(L10n.lookup(darkSurface ? "浅色" : "深色")) { darkSurface.toggle() }.frame(minWidth: 44, minHeight: 44).accessibilityLabel(L10n.text("切换台面颜色"))
                DiyPresentationControl(mode: DiyPresentation.mode(selection: previewPresentation, slots: viewModel.beadSlots)) { previewPresentation = $0 }
                Spacer(minLength: 0)
                historyButtons
            }.font(.caption).buttonStyle(.plain).foregroundStyle(Color.textSecondary)

        }
    }

    private var sizePanel: some View {
        VStack(spacing: 16) {
            HStack {
                Text(L10n.text("手围")).font(.subheadline)
                Spacer()
                Picker(L10n.text("手围"), selection: Binding(get: { viewModel.wristSizeMm }, set: { viewModel.setWristSize($0) })) {
                    ForEach(Array(stride(from: 140, through: 200, by: 5)), id: \.self) { size in
                        Text(L10n.lookup(String(format: "%.1f cm", Double(size) / 10))).tag(size)
                    }
                }.pickerStyle(.menu).tint(Color.textPrimary).frame(minHeight: 44)
            }
            HStack {
                Text(L10n.text("佩戴松量")).font(.subheadline)
                Spacer()
                Picker(L10n.text("佩戴松量"), selection: Binding(get: { viewModel.fitAllowanceMm }, set: { viewModel.setFitAllowance($0) })) {
                    Text(L10n.text("贴合")).tag(0.0)
                    Text("＋5 mm").tag(5.0)
                    Text("＋8 mm").tag(8.0)
                    Text("＋12 mm").tag(12.0)
                }.pickerStyle(.menu).tint(Color.textPrimary).frame(minHeight: 44)
            }
            Text(L10n.lookup(fitSummary)).font(.subheadline).foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(L10n.text("天然材质、配件和穿绳方式会影响实物尺寸。")).font(.caption).foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                ForEach(0..<5) { index in
                    let names = ["木", "火", "土", "金", "水"]
                    let codes = ["wood", "fire", "earth", "metal", "water"]
                    let colors = ["427A5B", "C44736", "C38B32", "959A98", "345F95"]
                    let count = viewModel.beadSlots.filter { bead in
                        let element = viewModel.materials.first { $0.id == bead.materialId }?.fiveElements
                        return element == names[index] || element == codes[index]
                    }.count
                    HStack(spacing: 4) {
                        Circle().fill(Color(hex: colors[index])).frame(width: 6, height: 6)
                        Text("\(names[index]) \(count)").font(.caption)
                    }.frame(maxWidth: .infinity)
                }
            }.accessibilityElement(children: .combine)
            if let cord = viewModel.selectedCord {
                HStack {
                    Text(L10n.text("绳线 · \(cord.name)")).font(.subheadline)
                    Spacer()
                    Button(L10n.text("移除")) { viewModel.removeFromCart(DiyCartItem(material: cord, quantity: 1)) }
                        .frame(minHeight: 44)
                }
            }
        }
    }

    private var fitSummary: String {
        String(format: "内围预估 %.1f cm · %@", viewModel.fitFeedback.innerMm / 10, viewModel.fitFeedback.detail)
    }

    private var materialPanel: some View {
        VStack(spacing: 6) {
            HStack {
                Text(L10n.text("挑选材料")).font(.subheadline.weight(.semibold))
                Text(L10n.text("\(filteredMaterials.count) 款")).font(.caption2).foregroundStyle(Color.textSecondary)
                Spacer()
                Picker(L10n.text("五行筛选"), selection: $elementFilter) {
                    Text(L10n.text("全部五行")).tag("all")
                    Text(L10n.text("木")).tag("wood"); Text(L10n.text("火")).tag("fire"); Text(L10n.text("土")).tag("earth"); Text(L10n.text("金")).tag("metal"); Text(L10n.text("水")).tag("water")
                }.pickerStyle(.menu).font(.caption).tint(Color.textSecondary)
            }.padding(.horizontal, 12)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                TextField(L10n.text("搜索材质或规格"), text: $materialSearch)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().focused($searchFocused)
                    .submitLabel(.done).onSubmit { searchFocused = false }
                if !materialSearch.isEmpty { Button { materialSearch = "" } label: { Image(systemName: "xmark.circle.fill") }.accessibilityLabel(L10n.text("清除搜索")) }
            }.font(.subheadline).foregroundStyle(Color.textSecondary).padding(.horizontal, 10).frame(height: 34)
                .background(Color.bgPrimary, in: RoundedRectangle(cornerRadius: 8)).padding(.horizontal, 10)
            if let replacing = viewModel.beadSlots.first(where: { $0.id == replacingBeadId }) {
                HStack(spacing: 8) {
                    Text(L10n.text("选择材料替换：\(replacing.materialName)")).lineLimit(1)
                    Spacer(minLength: 0)
                    Button(L10n.text("取消")) { replacingBeadId = nil }.frame(minHeight: 44).foregroundStyle(Color.textSecondary)
                }.font(.caption).padding(.horizontal, 12).background(Color.brandDefault.opacity(0.06))
            }
            HStack(spacing: 0) {
                categoryTabs.frame(width: 68)
                ScrollView(showsIndicators: false) {
                if viewModel.isLoading && viewModel.materials.isEmpty {
                    ProgressView(L10n.text("正在加载材料")).frame(maxWidth: .infinity, minHeight: 120)
                } else if filteredMaterials.isEmpty {
                    VStack(spacing: 10) {
                        Text(L10n.text("没有符合条件的材料"))
                        Button(L10n.text("清除筛选")) { materialSearch = ""; elementFilter = "all"; viewModel.selectCategory("all") }
                        if viewModel.materials.isEmpty { Button(L10n.text("重新加载")) { Task { await viewModel.loadMaterials() } } }
                    }.font(.caption).frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
                        ForEach(filteredMaterials) { material in materialCard(material) }
                    }.padding(.horizontal, 10)
                    Link(L10n.text("材质素材来源"), destination: URL(string: "/assets/diy/materials-v2/credits.html", relativeTo: AppConfig.baseURL)!.absoluteURL)
                        .font(.caption2).foregroundStyle(Color.textSecondary).padding(.vertical, 12)
                }
                }.scrollDismissesKeyboard(.interactively)
            }
        }.padding(.top, 6).background(Color.bgSecondary)
            .overlay(alignment: .top) { Rectangle().fill(Color.borderDivider).frame(height: 1) }
    }

    private var categoryTabs: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(viewModel.categories, id: \.code) { category in
                    let isSelected = viewModel.selectedCategory == category.code
                    Button {
                        AppMotion.perform {
                            viewModel.selectCategory(category.code)
                        }
                    } label: {
                        Text(L10n.lookup(category.name))
                            .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? Color.textPrimary : Color.textSecondary)
                            .padding(.horizontal, 4)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(isSelected ? Color.brandDefault.opacity(0.08) : .clear)
                            .overlay(alignment: .leading) { Rectangle().fill(isSelected ? Color.brandDefault : .clear).frame(width: 2) }
                    }
                    .buttonStyle(DiyPressButtonStyle())
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }

    private var filteredMaterials: [Material] {
        let keyword = materialSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        return viewModel.filteredMaterials.filter { material in
            let names = ["wood": "木", "fire": "火", "earth": "土", "metal": "金", "water": "水"]
            let elementMatches = elementFilter == "all" || material.category == "cord" || material.fiveElements == elementFilter || material.fiveElements == names[elementFilter]
            return (replacingBeadId == nil || material.category != "cord") && elementMatches && (keyword.isEmpty || material.name.localizedCaseInsensitiveContains(keyword) || material.spec.localizedCaseInsensitiveContains(keyword))
        }
    }

    private func materialCard(_ material: Material) -> some View {
        let count = viewModel.count(for: material.id)
        let replacing = viewModel.beadSlots.first { $0.id == replacingBeadId }
        let otherCount = count - (replacing?.materialId == material.id ? 1 : 0)
        let isUnavailable = material.status != "on_shelf" || otherCount >= material.stock || (replacing == nil && material.category != "cord" && viewModel.beadSlots.count >= 60)
        return Button {
            if let replacing {
                if viewModel.replaceBead(id: replacing.id, with: material) { replacingBeadId = nil }
            } else { viewModel.addToCart(material) }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 5) {
                ZStack(alignment: .topTrailing) {
                    DiyMaterialBead(
                        name: material.name,
                        category: material.category,
                        size: 42,
                        isSelected: count > 0,
                        shape: material.shape ?? "round",
                        colorHex: material.colorHex,
                        textureKey: material.textureKey,
                        finish: material.finish,
                        translucency: material.translucency ?? 0, renderAssets: material.renderAssets, materialId: material.id, materialType: material.materialType
                    )
                    if count > 0 {
                        Text("×\(count)")
                            .font(AppTypography.micro.weight(.semibold))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 4)
                            .frame(minHeight: 16)
                            .background(Color.brandDefault)
                            .clipShape(Capsule())
                            .offset(x: 9, y: -6)
                    }
                }
                Text(L10n.lookup(material.name))
                    .font(AppTypography.caption.weight(.semibold))
                    .foregroundStyle(.textPrimary)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(L10n.lookup(material.spec))
                    .font(AppTypography.micro)
                    .foregroundStyle(.textTertiary)
                    .lineLimit(1)
                Text(L10n.lookup(material.status != "on_shelf" ? "已下架" : isUnavailable ? (material.stock == 0 ? L10n.text("暂时售罄") : L10n.text("已达库存上限")) : material.priceText))
                    .font(AppTypography.caption.weight(.semibold))
                    .foregroundStyle(.accentLight)
            }
            .frame(maxWidth: .infinity, minHeight: 134)
            .padding(.horizontal, 5)
            .background(Color.bgTertiary)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(count > 0 ? Color.borderStrong : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(DiyPressButtonStyle())
        .disabled(isUnavailable)
        .accessibilityLabel("\(material.name)，\(material.spec)，\(material.priceText)")
        .accessibilityValue(isUnavailable ? L10n.text("库存不足，无法继续添加") : (count > 0 ? L10n.text("已选 \(count) 件") : L10n.text("未选择")))
        .accessibilityHint(L10n.lookup(replacing == nil ? "点按加入搭配" : "替换材料"))
    }

    private func quickMaterialButton(_ material: Material) -> some View {
        let count = viewModel.count(for: material.id)
        let isUnavailable = count >= material.stock || (material.category != "cord" && viewModel.beadSlots.count >= 60)
        return Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.8)) {
                viewModel.addToCart(material)
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 6) {
                DiyMaterialBead(
                    name: material.name,
                    category: material.category,
                    size: 44,
                    isSelected: count > 0,
                    shape: material.shape ?? "round",
                    colorHex: material.colorHex,
                    textureKey: material.textureKey,
                    finish: material.finish,
                    translucency: material.translucency ?? 0, renderAssets: material.renderAssets, materialId: material.id, materialType: material.materialType
                )
                Text(L10n.lookup(material.name))
                    .font(AppTypography.micro.weight(.medium))
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
                    .frame(width: 60)
            }
        }
        .buttonStyle(DiyPressButtonStyle())
        .disabled(isUnavailable)
        .accessibilityLabel(L10n.text("添加\(material.name)"))
    }

    private var bottomActionBar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.text("材料预估")).font(.caption2).foregroundStyle(Color.textSecondary)
                Text(L10n.lookup(viewModel.totalPriceText)).appNumericFont(22, weight: .medium).foregroundStyle(Color.accentLight)
            }
            Spacer(minLength: 4)
            Button(L10n.text("保存设计")) { presentSaveDialog(checkout: false) }
                .font(.caption.weight(.semibold)).padding(.horizontal, 14).frame(minHeight: 44)
                .background(Color.bgTertiary, in: RoundedRectangle(cornerRadius: 9))
                .disabled(viewModel.beadSlots.isEmpty)
            Button { presentSaveDialog(checkout: true) } label: {
                Label(L10n.text("去定制"), systemImage: "arrow.right").font(.caption.weight(.semibold))
                    .foregroundStyle(Color.white).padding(.horizontal, 14).frame(minHeight: 44)
                    .background(Color.brandDefault, in: RoundedRectangle(cornerRadius: 9))
            }.disabled(viewModel.beadSlots.isEmpty)
        }.foregroundStyle(Color.accentLight).buttonStyle(DiyPressButtonStyle())
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Color.bgPrimary.ignoresSafeArea(edges: .bottom))
            .overlay(alignment: .top) { Rectangle().fill(Color.borderDivider).frame(height: 1) }
    }

    private func presentSaveDialog(checkout: Bool) {
        checkoutAfterSave = checkout
        guard authStore.isLoggedIn else { resumeSaveAfterLogin = true; showLogin = true; return }
        designNameInput = viewModel.designName
        designDescriptionInput = viewModel.designDescription
        searchFocused = false
        showNameDialog = true
    }

    private func saveDesign() {
        let trimmed = designNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.designName = trimmed.isEmpty ? "我的手串" : trimmed
        viewModel.designDescription = designDescriptionInput.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            let saved = await viewModel.saveDesign()
            if saved && checkoutAfterSave && viewModel.currentDesign != nil {
                showOrderPage = true
            } else if saved { showMyDesigns = true }
        }
    }
}

struct DiyMaterialBead: View {
    let name: String
    let category: String
    let size: CGFloat
    let isSelected: Bool
    var seed = "material"
    var shape = "round"
    var colorHex: String?
    var textureKey: String?
    var finish: String?
    var translucency: Double = 0
    var renderAssets: String? = nil
    var materialId: Int64 = 0
    var materialType: String? = nil

    private var palette: DiyBeadPalette { .resolve(name: name, category: category, colorHex: colorHex) }
    private var isDiscSpacer: Bool {
        shape == "disc" || (category == "spacer" && name.contains("隔片"))
    }
    private var accessory: String? { DiyGeometry.kind(shape: shape, category: category, materialId: materialId, name: name) }

    var body: some View {
        Group {
            if let accessory, let mask = DiyMaterialAppearance.accessoryThumbnail(accessory) {
                ZStack {
                    palette.base
                    if let reference = DiyMaterialAppearance.image(id: materialId, texture: textureKey, type: materialType, finish: finish, color: colorHex) {
                        Image(uiImage: reference).resizable().scaledToFill()
                    }
                    Image(uiImage: mask).resizable().scaledToFit().blendMode(.multiply)
                }
                .frame(width: size, height: size)
                .mask(Image(uiImage: mask).resizable().scaledToFit())
                .compositingGroup()
            } else if isDiscSpacer {
                Capsule()
                    .fill(baseGradient)
                    .frame(width: size * 0.52, height: size)
                    .overlay {
                        DiyBeadTexture(name: name, textureKey: textureKey, seed: seed, color: palette.texture)
                            .frame(width: size * 0.52, height: size)
                            .clipShape(Capsule())
                    }
                    .overlay {
                        Capsule()
                            .strokeBorder(rimGradient, lineWidth: isSelected ? 2 : 0.8)
                            .frame(width: size * 0.52, height: size)
                    }
            } else if shape == "barrel" {
                RoundedRectangle(cornerRadius: size * 0.26)
                    .fill(baseGradient)
                    .frame(width: size * 1.14, height: size * 0.86)
                    .overlay {
                        DiyBeadTexture(name: name, textureKey: textureKey, seed: seed, color: palette.texture)
                            .frame(width: size * 1.14, height: size * 0.86)
                            .clipShape(RoundedRectangle(cornerRadius: size * 0.26))
                    }
            } else {
                Circle()
                    .fill(baseGradient)
                    .overlay {
                        DiyBeadTexture(name: name, textureKey: textureKey, seed: seed, color: palette.texture)
                            .clipShape(Circle())
                    }
                    .overlay {
                        Circle().strokeBorder(rimGradient, lineWidth: isSelected ? 2 : 0.8)
                    }
            }
        }
        .frame(width: size, height: size)
        .opacity(max(0.62, 1 - translucency * 0.18))
        .saturation(finish == "matte" || finish == "natural" ? 0.78 : 1)
        .overlay {
            if accessory == nil { Ellipse()
                .fill(Color.white.opacity(0.38))
                .frame(width: size * 0.24, height: size * 0.1)
                .blur(radius: 1.1)
                .offset(x: -size * 0.16, y: -size * 0.2)
                .allowsHitTesting(false) }
        }
        .overlay {
            if accessory == nil, !(DiyRenderAssets.parse(renderAssets)?.beadImageUrl.map { !$0.hasPrefix("/assets/diy/sources/") } ?? false), let reference = DiyMaterialAppearance.image(id: materialId, texture: textureKey, type: materialType, finish: finish, color: colorHex) {
                Image(uiImage: reference).resizable().scaledToFill().frame(width: isDiscSpacer ? size * 0.52 : size, height: size).clipShape(Ellipse())
                    .overlay { Circle().fill(RadialGradient(colors: [.white.opacity(0.18), .clear, .black.opacity(0.35)], center: .init(x: 0.3, y: 0.22), startRadius: 0, endRadius: size * 0.8)) }
            } else if let assets = DiyRenderAssets.parse(renderAssets), let raw = assets.beadImageUrl, !raw.hasPrefix("/assets/diy/sources/"), let url = DiyRenderAssets.url(raw) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        if let c = assets.imageCrop, c.width > 0, c.height > 0 {
                            image.resizable().frame(width: size * c.imageWidth / c.width, height: size * c.imageHeight / c.height)
                                .offset(x: size * (c.imageWidth / 2 - c.x - c.width / 2) / c.width, y: size * (c.imageHeight / 2 - c.y - c.height / 2) / c.height)
                                .frame(width: size, height: size).clipShape(Circle())
                        } else if accessory != nil { image.resizable().scaledToFit().frame(width: size, height: size) }
                        else { image.resizable().scaledToFill().frame(width: size, height: size).clipShape(Circle()) }
                    }
                }
            }
        }
        .shadow(color: isSelected ? Color.accentDefault.opacity(0.62) : .clear, radius: 7)
    }

    private var baseGradient: RadialGradient {
        RadialGradient(
            colors: [palette.highlight, palette.light, palette.base, palette.dark],
            center: UnitPoint(x: 0.3, y: 0.22),
            startRadius: 0,
            endRadius: size * 0.7
        )
    }

    private var rimGradient: LinearGradient {
        LinearGradient(
            colors: [
                isSelected ? Color.accentLight : Color.white.opacity(0.72),
                isSelected ? Color.accentDefault : palette.base.opacity(0.48),
                palette.dark.opacity(0.9)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct DiyBeadTexture: View {
    let name: String
    let textureKey: String?
    let seed: String
    let color: Color

    var body: some View {
        Canvas { context, canvasSize in
            var random = DiySeededRandom(seed: name + seed)

            if textureKey == "bodhi" || textureKey == "seed" || name.contains("菩提") || name.contains("金刚") {
                for _ in 0..<8 {
                    let diameter = canvasSize.width * CGFloat(random.next(in: 0.025...0.065))
                    let rect = CGRect(
                        x: canvasSize.width * CGFloat(random.next(in: 0.18...0.82)),
                        y: canvasSize.height * CGFloat(random.next(in: 0.16...0.84)),
                        width: diameter,
                        height: diameter * 0.72
                    )
                    context.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.42)))
                }
            } else if textureKey == "turquoise" || textureKey == "jade_cloud" || name.contains("绿松") || name.contains("碧玉") || name.contains("翡翠") {
                for index in 0..<3 {
                    var path = Path()
                    let startY = canvasSize.height * CGFloat(0.25 + Double(index) * 0.22)
                    path.move(to: CGPoint(x: -2, y: startY))
                    path.addCurve(
                        to: CGPoint(x: canvasSize.width + 2, y: startY + canvasSize.height * 0.08),
                        control1: CGPoint(x: canvasSize.width * 0.28, y: startY - canvasSize.height * 0.16),
                        control2: CGPoint(x: canvasSize.width * 0.68, y: startY + canvasSize.height * 0.19)
                    )
                    context.stroke(path, with: .color(color.opacity(0.3)), lineWidth: max(0.6, canvasSize.width * 0.025))
                }
            } else if textureKey == "agate" || textureKey == "cinnabar" || name.contains("南红") || name.contains("玛瑙") || name.contains("朱砂") {
                for inset in [0.16, 0.3] {
                    let rect = CGRect(
                        x: canvasSize.width * inset,
                        y: canvasSize.height * (inset - 0.07),
                        width: canvasSize.width * (1 - inset * 2),
                        height: canvasSize.height * (1 - inset * 1.55)
                    )
                    context.stroke(Path(ellipseIn: rect), with: .color(color.opacity(0.26)), lineWidth: max(0.7, canvasSize.width * 0.03))
                }
            } else if textureKey == "amber" || name.contains("蜜蜡") || name.contains("琥珀") {
                let rect = CGRect(
                    x: canvasSize.width * 0.2,
                    y: canvasSize.height * 0.46,
                    width: canvasSize.width * 0.64,
                    height: canvasSize.height * 0.16
                )
                context.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.22)))
            }
        }
        .blendMode(.softLight)
        .allowsHitTesting(false)
    }
}

private struct DiySeededRandom {
    private var state: UInt64

    init(seed: String) {
        state = seed.unicodeScalars.reduce(1_469_598_103_934_665_603) {
            ($0 ^ UInt64($1.value)) &* 1_099_511_628_211
        }
    }

    mutating func next(in range: ClosedRange<Double>) -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        let unit = Double(state >> 11) / Double(1 << 53)
        return range.lowerBound + (range.upperBound - range.lowerBound) * unit
    }
}

private struct DiyBeadPalette {
    let highlight: Color
    let light: Color
    let base: Color
    let dark: Color
    let texture: Color

    static func resolve(name: String, category: String, colorHex: String? = nil) -> DiyBeadPalette {
        if let colorHex, !colorHex.isEmpty {
            let base = Color(hex: colorHex)
            return .init(
                highlight: base.opacity(0.48),
                light: base.opacity(0.82),
                base: base,
                dark: base.opacity(0.58),
                texture: finishTextureColor(base: base, category: category)
            )
        }
        if name.contains("南红") || name.contains("玛瑙") || name.contains("朱砂") {
            return .init(highlight: Color(hex: "FFD3BD"), light: Color(hex: "F77C64"), base: Color(hex: "B93631"), dark: Color(hex: "4A1018"), texture: Color(hex: "FFE1CE"))
        }
        if name.contains("蜜蜡") || name.contains("琥珀") {
            return .init(highlight: Color(hex: "FFF3B3"), light: Color(hex: "F6C84D"), base: Color(hex: "C98213"), dark: Color(hex: "663007"), texture: Color(hex: "FFF0A4"))
        }
        if name.contains("绿松") || name.contains("碧玉") || name.contains("翡翠") {
            return .init(highlight: Color(hex: "D8F1DD"), light: Color(hex: "79BFA1"), base: Color(hex: "3E806A"), dark: Color(hex: "153D34"), texture: Color(hex: "214B43"))
        }
        if name.contains("青金") || name.contains("蓝") {
            return .init(highlight: Color(hex: "B8C9F0"), light: Color(hex: "597AC2"), base: Color(hex: "294A8D"), dark: Color(hex: "0B1738"), texture: Color(hex: "D7B85D"))
        }
        if name.contains("水晶") || name.contains("白玉") || name.contains("菩提") {
            return .init(highlight: Color.white, light: Color(hex: "F3EBD5"), base: Color(hex: "CFC3A4"), dark: Color(hex: "716957"), texture: Color(hex: "7A6449"))
        }
        if name.contains("黑曜") || name.contains("黑檀") {
            return .init(highlight: Color(hex: "A4ADA8"), light: Color(hex: "626B67"), base: Color(hex: "242927"), dark: Color(hex: "050706"), texture: Color(hex: "BAC0BD"))
        }
        if name.contains("银") || category == "spacer" {
            return .init(highlight: Color.white, light: Color(hex: "D8E0E2"), base: Color(hex: "899396"), dark: Color(hex: "3D4447"), texture: Color.white)
        }
        if name.contains("金") {
            return .init(highlight: Color(hex: "FFF7C5"), light: Color(hex: "E8C86B"), base: Color(hex: "B98B2B"), dark: Color(hex: "5C3B0D"), texture: Color(hex: "FFF1AE"))
        }
        return .init(highlight: Color(hex: "EFB19D"), light: Color(hex: "BA6657"), base: Color(hex: "672A25"), dark: Color(hex: "250B0C"), texture: Color(hex: "E6B29F"))
    }

    private static func finishTextureColor(base: Color, category: String) -> Color {
        category == "spacer" ? Color.white.opacity(0.72) : base.opacity(0.46)
    }
}

#Preview {
    NavigationStack { DiyDesignView() }
        .preferredColorScheme(.dark)
}

struct DiyPresentationControl: View {
    let mode: DiyPresentationMode
    let onSelect: (DiyPresentationMode) -> Void
    var body: some View {
        Menu {
            ForEach(DiyPresentationMode.allCases, id: \.self) { item in
                Button { onSelect(item) } label: {
                    if item == mode { Label(L10n.lookup(item.title), systemImage: "checkmark") }
                    else { Text(L10n.lookup(item.title)) }
                }.accessibilityIdentifier("diy-presentation-\(item.rawValue)")
            }
        } label: {
            HStack(spacing: 3) {
                Text(L10n.lookup(mode.title))
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold))
            }.frame(minWidth: 56, minHeight: 44)
        }.font(.caption).foregroundStyle(Color.textSecondary)
            .accessibilityIdentifier("diy-presentation-mode").accessibilityValue(L10n.lookup(mode.title))
    }
}

struct DiyNativeStage3D: UIViewRepresentable {
    let slots: [DiyBeadSlot]
    var wrist: Double = 160
    var allowance: Double = 8
    var selectedId: String?
    var onSelect: ((String?) -> Void)?
    var onMove: ((String, Int) -> Void)?
    var onRemove: ((String) -> Void)?
    var onDeleteState: ((Bool) -> Void)?
    var onReplace: ((String) -> Void)?
    var onDuplicate: ((String) -> Void)?
    var resetVersion = 0
    var darkSurface = false
    var cordColor: String?
    var presentationMode: DiyPresentationMode?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> SCNView {
        let view = DiyStageSceneView()
        let coordinator = context.coordinator
        view.onLayout = { [weak coordinator] in coordinator?.fitCamera(); coordinator?.updateAccessibility() }
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 30
        view.isPlaying = false
        view.accessibilityLabel = L10n.text("手串 3D 工作台")
        view.accessibilityIdentifier = "diy-3d-stage"
        view.isAccessibilityElement = false
        view.accessibilityHint = L10n.text("拖动空白处旋转，双指缩放")
        context.coordinator.configure(view)
        return view
    }
    func updateUIView(_ view: SCNView, context: Context) { context.coordinator.update(self, view: view) }
    static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) { coordinator.dispose(); view.scene = nil }

    @MainActor final class Coordinator: NSObject {
        private weak var view: SCNView?
        private let scene = SCNScene(), camera = SCNNode(), cord = SCNNode()
        private var nodes: [String: SCNNode] = [:], signatures: [String: Int] = [:]
        private var bodyVertices: [String: [SIMD3<Float>]] = [:]
        private var owner: DiyNativeStage3D?
        private var textures = NSCache<NSString, UIImage>()
        private var requests: [URL: URLSessionDataTask] = [:]
        private var textureWaiters: [URL: [SCNMaterialProperty]] = [:]
        private var resetVersion = 0
        private var yaw = 0.0, pitch = 1.05, distance = 5.3
        private var gestureYaw = 0.0, gesturePitch = 1.05, gestureDistance = 5.3
        private var cordSignature: Int?
        private var lastFitSignature: Int?
        private var fittedDistance = 5.3
        private var viewportSize = CGSize.zero
        private var cameraTarget = SCNVector3Zero
        private var drag: DiyBeadDragSession?
        private var dragDepth: Float = 0
        private var startAnchors: [CGPoint] = []
        private var deleteFeedback = false
        private var presentationMode: DiyPresentationMode = .flat
        private var hangingRotation = 0.0
        private var displayRotation: Double { presentationMode == .hanging ? hangingRotation : 0 }
        private var movementSignature: Int?
        private var swingStart = 0.0
        private var settlingLink: CADisplayLink?
        private lazy var contactShadow: UIImage = UIGraphicsImageRenderer(size: CGSize(width: 128, height: 128)).image { context in
            let colors = [UIColor.black.withAlphaComponent(0.24).cgColor, UIColor.black.withAlphaComponent(0).cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { return }
            context.cgContext.drawRadialGradient(gradient, startCenter: CGPoint(x: 64, y: 64), startRadius: 0, endCenter: CGPoint(x: 64, y: 64), endRadius: 64, options: [])
        }

        func configure(_ view: SCNView) {
            self.view = view; view.scene = scene
            camera.camera = SCNCamera(); camera.camera?.fieldOfView = 44; camera.camera?.projectionDirection = .vertical
            camera.camera?.wantsHDR = true; camera.camera?.wantsExposureAdaptation = false
            camera.camera?.exposureOffset = -0.7; camera.camera?.bloomIntensity = 0
            scene.rootNode.addChildNode(camera); view.pointOfView = camera; updateCamera()
            for (position, intensity, color) in [(SCNVector3(3, 6, 4), CGFloat(240), UIColor(red: 1, green: 0.96, blue: 0.88, alpha: 1)), (SCNVector3(-4, 3, -2), CGFloat(100), UIColor(red: 0.85, green: 0.92, blue: 0.9, alpha: 1))] {
                let node = SCNNode(); node.light = SCNLight(); node.light?.type = .omni; node.light?.intensity = intensity; node.light?.color = color; node.position = position; scene.rootNode.addChildNode(node)
            }
            let key = SCNNode(); key.light = SCNLight(); key.light?.type = .directional
            key.light?.intensity = 65; key.light?.castsShadow = false; key.light?.shadowRadius = 6
            key.light?.shadowColor = UIColor.black.withAlphaComponent(0.2)
            key.position = SCNVector3(2, 5, 3); key.look(at: SCNVector3Zero); scene.rootNode.addChildNode(key)
            let ambient = SCNNode(); ambient.light = SCNLight(); ambient.light?.type = .ambient; ambient.light?.intensity = 35; scene.rootNode.addChildNode(ambient)
            if let environment = DiyMaterialAppearance.root?.appendingPathComponent("studio.hdr") {
                scene.lightingEnvironment.contents = environment; scene.lightingEnvironment.intensity = 0.4
            }
            scene.rootNode.addChildNode(cord)
            let tap = UITapGestureRecognizer(target: self, action: #selector(tap(_:)))
            let pan = DiyDirectDragGestureRecognizer(target: self, action: #selector(pan(_:)))
            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(pinch(_:)))
            tap.require(toFail: pan)
            view.addGestureRecognizer(tap); view.addGestureRecognizer(pan); view.addGestureRecognizer(pinch)
        }
        func update(_ owner: DiyNativeStage3D, view: SCNView) {
            self.owner = owner
            let nextMode = DiyPresentation.mode(selection: owner.presentationMode, slots: owner.slots)
            if nextMode != presentationMode {
                finishDrag(endedNormally: false)
                stopSettling()
                presentationMode = nextMode
                if nextMode == .hanging {
                    let layout = DiyPhysicalLayout(slots: owner.slots, wrist: owner.wrist, allowance: owner.allowance)
                    hangingRotation = DiyPresentation.initialHangingRotation(slots: owner.slots, angles: layout.angles)
                }
                yaw = nextMode == .hanging ? 0.3 : 0
                pitch = nextMode == .hanging ? 0.16 : 1.05
                lastFitSignature = nil
            }
            view.accessibilityValue = L10n.lookup(presentationMode.title)
            view.accessibilityHint = L10n.lookup(owner.onMove == nil ? "拖动空白处旋转，双指缩放" : "拖动珠子换位，拖出手串删除，拖动空白处旋转，双指缩放")
            if resetVersion != owner.resetVersion { resetVersion = owner.resetVersion; yaw = presentationMode == .hanging ? 0.3 : 0; pitch = presentationMode == .hanging ? 0.16 : 1.05; lastFitSignature = nil; distance = 5.3; updateCamera() }
            // Keep the UI surface outside HDR tone mapping so the paper color
            // matches H5. Only the beads and their lighting pass through HDR.
            view.isOpaque = false; view.backgroundColor = .clear; scene.background.contents = UIColor.clear
            if drag == nil { render(owner.slots, animated: !owner.reduceMotion) }
            fitCamera()
        }
        func fitCamera(force: Bool = false, preserveZoom: Bool = false) {
            guard let view, let owner, drag == nil, view.bounds.width > 0, view.bounds.height > 0 else { return }
            let signature = owner.slots.hashValue ^ owner.wrist.hashValue ^ owner.allowance.hashValue ^ presentationMode.hashValue
            guard force || view.bounds.size != viewportSize || signature != lastFitSignature else { return }
            let zoom = preserveZoom ? distance / fittedDistance : 1
            viewportSize = view.bounds.size; lastFitSignature = signature
            updateCamera()
            let points = envelopeWorldPoints()
            let right = SIMD3(camera.simdWorldTransform.columns.0.x, camera.simdWorldTransform.columns.0.y, camera.simdWorldTransform.columns.0.z)
            let up = SIMD3(camera.simdWorldTransform.columns.1.x, camera.simdWorldTransform.columns.1.y, camera.simdWorldTransform.columns.1.z)
            let outward = SIMD3(camera.simdWorldTransform.columns.2.x, camera.simdWorldTransform.columns.2.y, camera.simdWorldTransform.columns.2.z)
            let origin = SIMD3<Float>(
                ((points.map(\.x).min() ?? 0) + (points.map(\.x).max() ?? 0)) / 2,
                ((points.map(\.y).min() ?? 0) + (points.map(\.y).max() ?? 0)) / 2,
                ((points.map(\.z).min() ?? 0) + (points.map(\.z).max() ?? 0)) / 2)
            let xs = points.map { simd_dot($0 - origin, right) }, ys = points.map { simd_dot($0 - origin, up) }
            let center = origin + right * (((xs.min() ?? 0) + (xs.max() ?? 0)) / 2) + up * (((ys.min() ?? 0) + (ys.max() ?? 0)) / 2)
            cameraTarget = SCNVector3(center)
            let tangentY = Float(tan(22 * Double.pi / 180)), tangentX = tangentY * Float(view.bounds.width / view.bounds.height)
            let needed = points.map { point -> Float in
                let relative = point - center, depth = simd_dot(relative, outward)
                return max(depth + abs(simd_dot(relative, right)) / (tangentX * 0.88), depth + abs(simd_dot(relative, up)) / (tangentY * 0.88))
            }.max() ?? 5.3
            fittedDistance = max(2.8, Double(needed) * 1.02)
            distance = max(2.8, fittedDistance * zoom)
            updateCamera()
        }
        private func updateCamera() {
            camera.position = SCNVector3(Double(cameraTarget.x) + sin(yaw) * cos(pitch) * distance,
                                         Double(cameraTarget.y) + sin(pitch) * distance,
                                         Double(cameraTarget.z) + cos(yaw) * cos(pitch) * distance)
            camera.look(at: cameraTarget)
            updateAccessibility()
        }
        private func bodyWorldPoints(_ node: SCNNode, presentation: Bool = false) -> [SIMD3<Float>] {
            guard let id = node.name, let vertices = bodyVertices[id],
                  let body = node.childNode(withName: "body", recursively: true) else { return [] }
            let transform = presentation ? body.presentation.simdWorldTransform : body.simdWorldTransform
            return vertices.map { vertex in
                let world = transform * SIMD4(vertex.x, vertex.y, vertex.z, 1)
                return SIMD3(world.x, world.y, world.z)
            }
        }
        private func envelopeWorldPoints(presentation: Bool = false) -> [SIMD3<Float>] {
            guard let owner else { return [] }
            let layout = DiyPhysicalLayout(slots: owner.slots, wrist: owner.wrist, allowance: owner.allowance)
            let cordPoints = DiyGeometry.cordPoints(slots: owner.slots, layout: layout, rotation: displayRotation), scale = Float(1.65 / layout.radius)
            // The whole cord loop closes the envelope, including the bracelet's
            // inner opening; real mesh vertices preserve the curved bead and accessory outlines.
            let loop = (0..<64).map { index -> SIMD3<Float> in
                let point = DiyPresentation.point(cordPoints[min(cordPoints.count - 1, index * cordPoints.count / 64)], mode: presentationMode)
                return SIMD3(Float(point.x), Float(point.y), Float(point.z)) * scale
            }
            return loop + nodes.values.flatMap { bodyWorldPoints($0, presentation: presentation) }
        }
        private func project(_ point: SIMD3<Float>) -> CGPoint {
            guard let view else { return .zero }
            let projected = view.projectPoint(SCNVector3(point))
            return CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y))
        }
        func updateAccessibility() {
            guard let view, let owner, drag == nil else { return }
            view.accessibilityElements = owner.slots.enumerated().compactMap { index, bead -> UIAccessibilityElement? in
                guard let node = nodes[bead.id] else { return nil }
                let projected = bodyWorldPoints(node).map(project)
                guard let minX = projected.map(\.x).min(), let maxX = projected.map(\.x).max(),
                      let minY = projected.map(\.y).min(), let maxY = projected.map(\.y).max() else { return nil }
                let element = DiyBeadAccessibilityElement(accessibilityContainer: view)
                element.accessibilityLabel = L10n.text("第 \(index + 1) 颗 \(bead.materialName)")
                element.accessibilityIdentifier = "diy-bead-\(bead.id)"
                element.accessibilityTraits = owner.onSelect == nil ? [.image] : bead.id == owner.selectedId ? [.button, .selected] : [.button]
                element.accessibilityFrameInContainerSpace = CGRect(x: minX, y: minY, width: max(1, maxX-minX), height: max(1, maxY-minY))
                element.activate = { [weak self] in self?.owner?.onSelect?(bead.id) }
                var actions: [UIAccessibilityCustomAction] = []
                if owner.onMove != nil && index > 0 { actions.append(UIAccessibilityCustomAction(name: L10n.text("向前移动珠子")) { [weak self] _ in self?.owner?.onMove?(bead.id, index - 1); return true }) }
                if owner.onMove != nil && index + 1 < owner.slots.count { actions.append(UIAccessibilityCustomAction(name: L10n.text("向后移动珠子")) { [weak self] _ in self?.owner?.onMove?(bead.id, index + 1); return true }) }
                if owner.onRemove != nil { actions.append(UIAccessibilityCustomAction(name: L10n.text("删除")) { [weak self] _ in self?.owner?.onRemove?(bead.id); return true }) }
                if owner.onReplace != nil { actions.append(UIAccessibilityCustomAction(name: L10n.text("替换材料")) { [weak self] _ in self?.owner?.onReplace?(bead.id); return true }) }
                if owner.onDuplicate != nil && owner.slots.count < 60 { actions.append(UIAccessibilityCustomAction(name: L10n.text("复制")) { [weak self] _ in self?.owner?.onDuplicate?(bead.id); return true }) }
                element.accessibilityCustomActions = actions
                return element
            }
        }
        private func render(_ slots: [DiyBeadSlot], animated: Bool) {
            guard let owner else { return }
            let layout = DiyPhysicalLayout(slots: slots, wrist: owner.wrist, allowance: owner.allowance)
            let scale = 1.65 / layout.radius, ids = Set(slots.map(\.id))
            let placements = DiyPresentation.hangingPlacements(slots: slots, layout: layout, rotation: displayRotation)
            let newMovementSignature = slots.hashValue ^ layout.radius.hashValue ^ presentationMode.hashValue ^ displayRotation.hashValue
            let moved = movementSignature != newMovementSignature
            movementSignature = newMovementSignature
            if cordSignature != newMovementSignature {
                cordSignature = newMovementSignature
                let points = DiyGeometry.cordPoints(slots: slots, layout: layout, rotation: displayRotation).map { DiyPresentation.point($0, mode: presentationMode) }
                cord.geometry = DiyMaterialAppearance.cordGeometry(points: points, scale: scale)
                let material = SCNMaterial(); material.roughness.contents = 0.9; material.lightingModel = .physicallyBased
                cord.geometry?.materials = [material]
            }
            let cordTint = UIColor(Color(hex: owner.cordColor ?? "B49A73"))
            cord.geometry?.firstMaterial?.diffuse.contents = cordTint
            for id in Array(nodes.keys) where !ids.contains(id) { nodes.removeValue(forKey: id)?.removeFromParentNode(); signatures.removeValue(forKey: id); bodyVertices.removeValue(forKey: id) }
            for (index, bead) in slots.enumerated() {
                let node: SCNNode
                if let existing = nodes[bead.id] { node = existing }
                else { node = SCNNode(); node.name = bead.id; nodes[bead.id] = node; scene.rootNode.addChildNode(node) }
                let physical = DiyGeometry.dimensions(bead)
                let suspended = presentationMode == .hanging && DiyPresentation.isSuspended(physical.kind)
                let signature = bead.hashValue ^ layout.radius.hashValue ^ presentationMode.hashValue ^ (placements[index]?.standOffMm.hashValue ?? 0) ^ (placements[index]?.connectorMm.hashValue ?? 0)
                if signatures[bead.id] != signature {
                    signatures[bead.id] = signature
                    let radius = CGFloat(physical.diameterMm * scale / 2)
                    let accessory = physical.kind.flatMap { DiyMaterialAppearance.accessoryGeometry($0) }
                    let geometry = accessory ?? DiyMaterialAppearance.geometry(radius: radius, shape: bead.shape ?? "round", axialLength: CGFloat(physical.pitchMm * scale))
                    let material = SCNMaterial(); material.lightingModel = .physicallyBased
                    material.diffuse.contents = texture(bead)
                    DiyMaterialAppearance.apply(bead, to: material)
                    geometry.materials = [material]; node.geometry = nil
                    node.childNodes.forEach { $0.removeFromParentNode() }
                    let body = SCNNode(geometry: geometry); body.name = "body"
                    if accessory != nil {
                        let diameter = Float(physical.diameterMm * scale); body.scale = SCNVector3(diameter, diameter, diameter)
                    } else {
                        body.simdOrientation = simd_quatf(angle: DiyGeometry.textureTurn(bead.id), axis: SIMD3(1, 0, 0)) * simd_quatf(angle: -.pi / 2, axis: SIMD3(0, 0, 1))
                    }
                    if suspended {
                        let suspension = SCNNode(); suspension.name = "suspension"
                        let profile = physical.kind.flatMap(DiyGeometry.profile)
                        let placement = placements[index]
                        let lengthMm = placement?.connectorMm ?? physical.diameterMm * (profile?.connectorRatio ?? 0.12)
                        let pivotMm = SIMD3<Double>(0, placement?.standOffMm ?? 0, lengthMm)
                        suspension.simdPosition = SIMD3(Float(pivotMm.x * scale), Float(pivotMm.y * scale), Float(pivotMm.z * scale))
                        let mount = profile?.anchors["mount"] ?? [0, 0, 0]
                        let mountOffset = mount.count == 3 ? SIMD3(Float(mount[0]), Float(mount[1]), Float(mount[2])) * Float(physical.diameterMm * scale) : .zero
                        body.simdPosition = -mountOffset
                        let connector = SCNNode(geometry: DiyMaterialAppearance.cordGeometry(points: [.zero, pivotMm], scale: scale))
                        connector.name = "connector"
                        let cordMaterial = SCNMaterial(); cordMaterial.lightingModel = .physicallyBased; cordMaterial.roughness.contents = 0.9
                        connector.geometry?.materials = [cordMaterial]
                        node.addChildNode(connector); suspension.addChildNode(body); node.addChildNode(suspension)
                    } else { node.addChildNode(body) }
                    bodyVertices[bead.id] = DiyMaterialAppearance.vertices(of: geometry)
                    if presentationMode == .flat {
                        let shadow = SCNNode(geometry: SCNPlane(width: radius * 3, height: CGFloat((physical.maxZ - physical.minZ) * scale * 1.4)))
                        shadow.name = "contact-shadow"; shadow.eulerAngles.x = -.pi / 2
                        shadow.position = SCNVector3(0, Float(-physical.centerHeightMm * scale + 0.003), Float((physical.maxZ + physical.minZ) / 2 * scale))
                        shadow.geometry?.firstMaterial?.lightingModel = .constant
                        shadow.geometry?.firstMaterial?.diffuse.contents = contactShadow
                        shadow.geometry?.firstMaterial?.writesToDepthBuffer = false
                        shadow.geometry?.firstMaterial?.isDoubleSided = true
                        node.addChildNode(shadow)
                    }
                    let assets = DiyRenderAssets.parse(bead.renderAssets)
                    for (raw, property) in [(assets?.albedoMapUrl, material.diffuse), (assets?.normalMapUrl, material.normal), (assets?.roughnessMapUrl, material.roughness)] {
                        if let raw, !raw.hasPrefix("/assets/diy/textures/wood/"), let url = DiyRenderAssets.url(raw) { load(url, into: property) }
                    }
                    // Highlight the actual silhouette, never a detached ring that
                    // can be mistaken for another string below a tassel.
                    if let outlineGeometry = geometry.copy() as? SCNGeometry {
                        let outline = SCNNode(geometry: outlineGeometry); outline.name = "selection"
                        outline.scale = SCNVector3(1.025, 1.025, 1.025)
                        let highlight = SCNMaterial(); highlight.lightingModel = .constant
                        highlight.diffuse.contents = UIColor(red: 0.68, green: 0.51, blue: 0.28, alpha: 0.7)
                        highlight.cullMode = .front; highlight.writesToDepthBuffer = false
                        outlineGeometry.materials = [highlight]; body.addChildNode(outline)
                    }
                }
                let selected = bead.id == owner.selectedId
                node.childNode(withName: "selection", recursively: true)?.isHidden = !selected
                if let material = node.childNode(withName: "body", recursively: true)?.geometry?.firstMaterial {
                    material.emission.contents = UIColor(red: 0.68, green: 0.51, blue: 0.28, alpha: 1)
                    material.emission.intensity = selected ? 0.08 : 0
                }
                node.childNode(withName: "connector", recursively: true)?.geometry?.firstMaterial?.diffuse.contents = cordTint
                node.opacity = 1
                let angle = layout.angles[index] + displayRotation
                let position = DiyPresentation.point(SIMD3(cos(angle) * 1.65, physical.centerHeightMm * scale, sin(angle) * 1.65), mode: presentationMode)
                SCNTransaction.begin(); SCNTransaction.animationDuration = animated && presentationMode == .flat && !SCNVector3EqualToVector3(node.position, SCNVector3Zero) ? 0.14 : 0
                node.simdPosition = SIMD3(Float(position.x), Float(position.y), Float(position.z))
                node.simdOrientation = DiyPresentation.orientation(angle: angle, kind: physical.kind, mode: presentationMode)
                SCNTransaction.commit()
            }
            if presentationMode != .hanging || !animated || drag != nil { stopSettling() }
            else if moved { startSettling() }
            updateAccessibility()
        }
        private func startSettling() {
            stopSettling()
            guard nodes.values.contains(where: { $0.childNode(withName: "suspension", recursively: false) != nil }) else { return }
            swingStart = CACurrentMediaTime()
            let link = CADisplayLink(target: self, selector: #selector(settle(_:)))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 20, maximum: 30, preferred: 30)
            link.add(to: .main, forMode: .common); settlingLink = link
            view?.isPlaying = true
        }
        @objc private func settle(_ link: CADisplayLink) {
            guard let owner else { stopSettling(); return }
            let elapsed = link.timestamp - swingStart
            guard !owner.reduceMotion, drag == nil, elapsed < DiyPresentation.settlingDuration else { stopSettling(); updateAccessibility(); return }
            for (id, node) in nodes {
                let swing = DiyPresentation.swing(elapsed: elapsed, identity: id, reducedMotion: false)
                node.childNode(withName: "suspension", recursively: false)?.eulerAngles = SCNVector3(swing.x, swing.y, 0)
            }
        }
        private func stopSettling() {
            settlingLink?.invalidate(); settlingLink = nil
            for node in nodes.values { node.childNode(withName: "suspension", recursively: false)?.eulerAngles = SCNVector3Zero }
            view?.isPlaying = false
        }
        private func bead(at point: CGPoint) -> String? {
            guard let view else { return nil }
            for hit in view.hitTest(point, options: [.searchMode: SCNHitTestSearchMode.all.rawValue]) {
                guard hit.node.name == "body" else { continue }
                var node: SCNNode? = hit.node
                while let item = node { if let name = item.name, nodes[name] != nil { return name }; node = item.parent }
            }
            // Thin tassel strands may fall between rays. Keep the same bounded
            // finger tolerance around the actual projected mesh, including a
            // long body's tip, rather than only around its distant mount.
            let bodies = nodes.map { id, node in
                (id: id, points: bodyWorldPoints(node, presentation: true).map(project))
            }
            return DiyProjectedHit.nearest(to: point, bodies: bodies)
        }
        @objc private func tap(_ recognizer: UITapGestureRecognizer) { if let id = bead(at: recognizer.location(in: view)) { owner?.onSelect?(id) } }
        @objc private func pan(_ recognizer: DiyDirectDragGestureRecognizer) {
            guard let view, let owner else { return }
            let location = recognizer.currentPoint, translation = recognizer.translation
            switch recognizer.state {
            case .began:
                stopSettling()
                gestureYaw = yaw; gesturePitch = pitch
                if owner.onMove != nil, let id = bead(at: recognizer.startPoint), let index = owner.slots.firstIndex(where: { $0.id == id }), let node = nodes[id] {
                    let anchor = view.projectPoint(node.presentation.worldPosition)
                    startAnchors = owner.slots.compactMap { slot in nodes[slot.id].map { item in
                        let p = view.projectPoint(item.presentation.worldPosition); return CGPoint(x: CGFloat(p.x), y: CGFloat(p.y))
                    } }
                    dragDepth = anchor.z
                    drag = DiyBeadDragSession(id: id, initialIndex: index, pointer: recognizer.startPoint,
                        anchor: CGPoint(x: CGFloat(anchor.x), y: CGFloat(anchor.y)),
                        envelope: DiyDragEnvelope(points: envelopeWorldPoints(presentation: true).map(project)))
                    owner.onSelect?(id)
                    updateDrag(at: location)
                }
            case .changed:
                if drag != nil { updateDrag(at: location) }
                else {
                    yaw = gestureYaw - Double(translation.x) * 0.008
                    pitch = min(1.4, max(presentationMode == .hanging ? -1.4 : 0.25, gesturePitch + Double(translation.y) * 0.008))
                    if presentationMode == .hanging { fitCamera(force: true, preserveZoom: true) }
                    else { updateCamera() }
                }
            case .ended:
                if drag != nil { updateDrag(at: location) }
                finishDrag(endedNormally: true)
            case .cancelled, .failed:
                finishDrag(endedNormally: false)
            default: break
            }
        }
        private func updateDrag(at pointer: CGPoint) {
            guard var session = drag, let view, let owner,
                  let from = owner.slots.firstIndex(where: { $0.id == session.id }) else { return }
            let anchor = session.translatedAnchor(pointer: pointer)
            let target = startAnchors.indices.min { hypot(startAnchors[$0].x - anchor.x, startAnchors[$0].y - anchor.y) < hypot(startAnchors[$1].x - anchor.x, startAnchors[$1].y - anchor.y) } ?? from
            session.update(pointer: pointer, targetIndex: target); drag = session
            var preview = owner.slots
            if !session.deletionArmed { preview.insert(preview.remove(at: from), at: target) }
            render(preview, animated: !owner.reduceMotion)
            SCNTransaction.begin(); SCNTransaction.animationDuration = 0
            nodes[session.id]?.position = view.unprojectPoint(SCNVector3(Float(anchor.x), Float(anchor.y), dragDepth))
            nodes[session.id]?.opacity = session.deletionArmed ? 0.45 : 1
            SCNTransaction.commit()
            if deleteFeedback != session.deletionArmed {
                deleteFeedback = session.deletionArmed
                owner.onDeleteState?(deleteFeedback)
                UISelectionFeedbackGenerator().selectionChanged()
            }
        }
        private func finishDrag(endedNormally: Bool) {
            guard let session = drag else { return }
            drag = nil
            if deleteFeedback { deleteFeedback = false; owner?.onDeleteState?(false) }
            switch session.completion(endedNormally: endedNormally) {
            case .unchanged: break
            case .move(let id, let index): owner?.onMove?(id, index)
            case .remove(let id): owner?.onRemove?(id)
            }
            if let owner { render(owner.slots, animated: !owner.reduceMotion) }
        }
        @objc private func pinch(_ recognizer: UIPinchGestureRecognizer) {
            if recognizer.state == .began {
                finishDrag(endedNormally: false)
                gestureDistance = distance
            }
            distance = min(16, max(2.8, gestureDistance / Double(recognizer.scale))); updateCamera()
        }
        private func load(_ url: URL, into property: SCNMaterialProperty) {
            if let image = textures.object(forKey: url.absoluteString as NSString) { property.contents = image; return }
            textureWaiters[url, default: []].append(property)
            guard requests[url] == nil else { return }
            let request = URLSession.shared.dataTask(with: url) { [weak self] data, response, _ in
                let image = (response as? HTTPURLResponse)?.statusCode == 200 ? data.flatMap(UIImage.init(data:)) : nil
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.requests.removeValue(forKey: url)
                    let waiters = self.textureWaiters.removeValue(forKey: url) ?? []
                    if let image { self.textures.setObject(image, forKey: url.absoluteString as NSString); waiters.forEach { $0.contents = image } }
                }
            }
            requests[url] = request; request.resume()
        }
        private func texture(_ bead: DiyBeadSlot) -> UIImage {
            DiyMaterialAppearance.fallbackImage(color: bead.colorHex, texture: bead.textureKey, type: bead.materialType) ?? UIImage()
        }
        func dispose() { stopSettling(); requests.values.forEach { $0.cancel() }; requests.removeAll(); textureWaiters.removeAll(); textures.removeAllObjects(); bodyVertices.removeAll(); owner = nil }
    }
}

private final class DiyStageSceneView: SCNView {
    var onLayout: (() -> Void)?
    override func layoutSubviews() { super.layoutSubviews(); onLayout?() }
}

// A six-point threshold separates a tap from a direct bead drag. A second
// finger cancels the draft gesture before the pinch recognizer can take over.
private final class DiyDirectDragGestureRecognizer: UIGestureRecognizer {
    private(set) var startPoint = CGPoint.zero
    private(set) var currentPoint = CGPoint.zero
    private weak var trackedTouch: UITouch?
    var translation: CGPoint { CGPoint(x: currentPoint.x - startPoint.x, y: currentPoint.y - startPoint.y) }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard trackedTouch == nil, touches.count == 1, event.allTouches?.filter({ $0.phase != .ended && $0.phase != .cancelled }).count == 1,
              let touch = touches.first else { state = state == .possible ? .failed : .cancelled; return }
        trackedTouch = touch; startPoint = touch.location(in: view); currentPoint = startPoint
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = trackedTouch else { return }
        currentPoint = touch.location(in: view)
        if state == .possible {
            if hypot(translation.x, translation.y) >= DiyBeadDragSession.activationDistance { state = .began }
        } else if state == .began || state == .changed { state = .changed }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        if let touch = trackedTouch { currentPoint = touch.location(in: view) }
        state = state == .began || state == .changed ? .ended : .failed
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) { state = .cancelled }
    override func reset() { super.reset(); trackedTouch = nil; startPoint = .zero; currentPoint = .zero }
}

private final class DiyBeadAccessibilityElement: UIAccessibilityElement {
    var activate: (() -> Void)?
    override func accessibilityActivate() -> Bool { activate?(); return activate != nil }
}
