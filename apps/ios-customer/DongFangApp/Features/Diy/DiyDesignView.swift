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
    @State private var showSavedDetail = false
    @State private var resetView = 0
    @State private var darkSurface = false
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
                            composition.frame(height: previewExpanded ? nil : max(260, min(400, max(geometry.size.height * 0.52, min(295, geometry.size.height - 155)))))
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
            Text(L10n.text("保存后可发布到广场、分享给朋友或继续定制。修改已发布作品会先转为私密。"))
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
        .sheet(isPresented: $showSavedDetail) {
            if let design = viewModel.currentDesign { NavigationStack { DiyDetailView(designId: design.id, viewModel: viewModel) } }
        }
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
            }.padding(.horizontal, 4)
            HStack(spacing: 8) {
                Text(L10n.lookup(String(format: "内围预估 %.1f cm", viewModel.fitFeedback.innerMm / 10)))
                Text(L10n.lookup(viewModel.fitFeedback.label))
                    .foregroundStyle(viewModel.fitFeedback.state == .good ? Color.stateSuccess : viewModel.fitFeedback.state == .empty ? Color.textSecondary : Color.stateWarning)
                Spacer()
            }.font(.caption).foregroundStyle(Color.textSecondary).monospacedDigit()
                .padding(.horizontal, 4).frame(minHeight: 24)
                .accessibilityElement(children: .combine).accessibilityIdentifier("diy-fit-feedback")
            ZStack(alignment: .topTrailing) {
                DiyNativeStage3D(slots: viewModel.beadSlots, wrist: Double(viewModel.wristSizeMm), allowance: viewModel.fitAllowanceMm,
                    selectedId: viewModel.selectedBeadId, onSelect: viewModel.selectBead, onMove: viewModel.moveBead,
                    resetVersion: resetView, darkSurface: darkSurface, cordColor: viewModel.selectedCord?.colorHex)
                    .padding(.top, 44).padding(.bottom, 52)
                    .accessibilityIdentifier("diy-3d-stage")
                    .accessibilityChildren {
                        ForEach(Array(viewModel.beadSlots.enumerated()), id: \.element.id) { index, bead in
                            Button(L10n.text("第 \(index + 1) 颗 \(bead.materialName)")) { viewModel.selectBead(bead.id) }
                                .accessibilityAddTraits(bead.id == viewModel.selectedBeadId ? .isSelected : [])
                        }
                    }
                HStack(spacing: 6) {
                    Button(L10n.text("复位")) { resetView += 1 }.frame(minWidth: 44, minHeight: 44).accessibilityLabel(L10n.text("重置 3D 视角"))
                    Button(L10n.lookup(darkSurface ? L10n.text("浅色") : L10n.text("深色"))) { darkSurface.toggle() }.frame(minWidth: 44, minHeight: 44).accessibilityLabel(L10n.text("切换台面颜色"))
                }.font(.caption).buttonStyle(.plain).foregroundStyle(Color.textSecondary).padding(.trailing, 4)
                if viewModel.beadSlots.isEmpty {
                    VStack(spacing: 6) {
                        Text(L10n.text("点选材料，加入手串")).font(.subheadline)
                    }.foregroundStyle(Color.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity).allowsHitTesting(false)
                }
            }.frame(maxHeight: .infinity)
                .background(darkSurface == (colorScheme == .dark) ? Color.bgPrimary : (darkSurface ? Color(red: 0.15, green: 0.23, blue: 0.2) : Color(red: 0.96, green: 0.95, blue: 0.92)))
                .overlay(alignment: .bottomTrailing) { historyButtons.padding(.trailing, 4).padding(.bottom, 2) }
                .overlay(alignment: .bottomLeading) { selectedBeadMenu.padding(.leading, 4).padding(.bottom, 2) }
                .overlay(alignment: .topLeading) {
                    Button(L10n.lookup(previewExpanded ? "收起预览" : "扩大预览")) { previewExpanded.toggle() }
                        .font(.caption).foregroundStyle(Color.textSecondary).buttonStyle(.plain)
                        .frame(minHeight: 44).padding(.leading, 8).accessibilityIdentifier("diy-expand-preview")
                }
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

    private var selectedBeadMenu: some View {
        Group {
            if let selected = viewModel.selectedBead {
                let index = viewModel.beadSlots.firstIndex { $0.id == selected.id } ?? 0
                Menu {
                    Text(L10n.lookup(selected.materialName))
                    Button(L10n.text("替换材料")) {
                        replacingBeadId = selected.id
                        materialSearch = ""; elementFilter = "all"; viewModel.selectCategory("all"); previewExpanded = false
                    }
                    Button(L10n.text("向前移动珠子")) { viewModel.moveBead(id: selected.id, to: index - 1) }.disabled(index == 0)
                    Button(L10n.text("向后移动珠子")) { viewModel.moveBead(id: selected.id, to: index + 1) }.disabled(index == viewModel.beadSlots.count - 1)
                    Button(L10n.text("复制")) { viewModel.duplicateSelectedBead() }.disabled(viewModel.beadSlots.count >= 60)
                    Button(L10n.text("删除"), role: .destructive) { viewModel.removeSelectedBead() }
                } label: {
                    HStack(spacing: 4) {
                        Text(L10n.text("编辑珠子"))
                        Image(systemName: "chevron.down").font(.caption2)
                    }.font(.caption).padding(.horizontal, 10).frame(minHeight: 44)
                        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 8))
                }.foregroundStyle(Color.textPrimary).accessibilityLabel(L10n.text("编辑选中珠子"))
            }
        }
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
                    .stroke(count > 0 ? Color.borderStrong : Color.borderDefault, lineWidth: 1)
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
                .overlay { RoundedRectangle(cornerRadius: 9).stroke(Color.borderStrong, lineWidth: 1) }
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
            } else if saved { showSavedDetail = true }
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

struct DiyNativeStage3D: UIViewRepresentable {
    let slots: [DiyBeadSlot]
    var wrist: Double = 160
    var allowance: Double = 8
    var selectedId: String?
    var onSelect: ((String?) -> Void)?
    var onMove: ((String, Int) -> Void)?
    var resetVersion = 0
    var darkSurface = false
    var cordColor: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> SCNView {
        let view = DiyStageSceneView()
        let coordinator = context.coordinator
        view.onLayout = { [weak coordinator] in coordinator?.fitCamera() }
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 30
        view.isPlaying = false
        view.accessibilityLabel = "手串 3D 工作台，点选珠子编辑，拖动珠子换位，拖动空白处旋转，双指缩放"
        context.coordinator.configure(view)
        return view
    }
    func updateUIView(_ view: SCNView, context: Context) { context.coordinator.update(self, view: view) }
    static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) { coordinator.dispose(); view.scene = nil }

    @MainActor final class Coordinator: NSObject {
        private weak var view: SCNView?
        private let scene = SCNScene(), camera = SCNNode(), cord = SCNNode()
        private var nodes: [String: SCNNode] = [:], signatures: [String: Int] = [:]
        private var owner: DiyNativeStage3D?
        private var textures = NSCache<NSString, UIImage>()
        private var requests: [URL: URLSessionDataTask] = [:]
        private var textureWaiters: [URL: [SCNMaterialProperty]] = [:]
        private var resetVersion = 0
        private var yaw = 0.0, pitch = 0.82, distance = 5.3
        private var gestureYaw = 0.0, gesturePitch = 0.82, gestureDistance = 5.3
        private var cordSignature: Int?
        private var lastExtent = 0.0
        private var viewportSize = CGSize.zero
        private var draggedId: String?, targetIndex = 0, startAngles: [Double] = []
        private var dragPlaneY: Float = 0
        private var dragAngleOffset = 0.0
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
            let pan = UIPanGestureRecognizer(target: self, action: #selector(pan(_:))); pan.maximumNumberOfTouches = 1
            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(pinch(_:)))
            tap.require(toFail: pan)
            view.addGestureRecognizer(tap); view.addGestureRecognizer(pan); view.addGestureRecognizer(pinch)
        }
        func update(_ owner: DiyNativeStage3D, view: SCNView) {
            self.owner = owner
            if resetVersion != owner.resetVersion { resetVersion = owner.resetVersion; yaw = 0; pitch = 0.82; lastExtent = 0; distance = 5.3; updateCamera() }
            // Keep the UI surface outside HDR tone mapping so the paper color
            // matches H5. Only the beads and their lighting pass through HDR.
            view.isOpaque = false; view.backgroundColor = .clear; scene.background.contents = UIColor.clear
            if draggedId == nil { render(owner.slots, animated: !owner.reduceMotion) }
            fitCamera()
        }
        func fitCamera() {
            guard let view, let owner, view.bounds.width > 0, view.bounds.height > 0 else { return }
            let layout = DiyPhysicalLayout(slots: owner.slots, wrist: owner.wrist, allowance: owner.allowance)
            let extent = 1.65 + max(5, owner.slots.map { DiyGeometry.dimensions($0).maxZ }.max() ?? 5) / layout.radius * 1.65
            guard view.bounds.size != viewportSize || abs(extent - lastExtent) > 0.0001 else { return }
            viewportSize = view.bounds.size; lastExtent = extent
            distance = max(5.3, extent / sin(22 * .pi / 180) / min(1, Double(view.bounds.width / view.bounds.height)) * 1.04)
            updateCamera()
        }
        private func updateCamera() {
            camera.position = SCNVector3(sin(yaw) * cos(pitch) * distance, sin(pitch) * distance, cos(yaw) * cos(pitch) * distance)
            camera.look(at: SCNVector3Zero)
        }
        private func render(_ slots: [DiyBeadSlot], animated: Bool) {
            guard let owner else { return }
            let layout = DiyPhysicalLayout(slots: slots, wrist: owner.wrist, allowance: owner.allowance)
            let scale = 1.65 / layout.radius, ids = Set(slots.map(\.id))
            let newCordSignature = slots.hashValue ^ layout.radius.hashValue
            if cordSignature != newCordSignature {
                cordSignature = newCordSignature
                cord.geometry = DiyMaterialAppearance.cordGeometry(points: DiyGeometry.cordPoints(slots: slots, layout: layout), scale: scale)
                let material = SCNMaterial(); material.roughness.contents = 0.9; material.lightingModel = .physicallyBased
                cord.geometry?.materials = [material]
            }
            cord.geometry?.firstMaterial?.diffuse.contents = UIColor(Color(hex: owner.cordColor ?? "B49A73"))
            for id in Array(nodes.keys) where !ids.contains(id) { nodes.removeValue(forKey: id)?.removeFromParentNode(); signatures.removeValue(forKey: id) }
            for (index, bead) in slots.enumerated() {
                let node: SCNNode
                if let existing = nodes[bead.id] { node = existing }
                else { node = SCNNode(); node.name = bead.id; nodes[bead.id] = node; scene.rootNode.addChildNode(node) }
                let signature = bead.hashValue ^ layout.radius.hashValue
                if signatures[bead.id] != signature {
                    signatures[bead.id] = signature
                    let physical = DiyGeometry.dimensions(bead), radius = CGFloat(physical.diameterMm * scale / 2)
                    let accessory = physical.kind.flatMap { DiyMaterialAppearance.accessoryGeometry($0) }
                    let geometry = accessory ?? DiyMaterialAppearance.geometry(radius: radius, shape: bead.shape ?? "round", axialLength: CGFloat(physical.pitchMm * scale))
                    let material = SCNMaterial(); material.lightingModel = .physicallyBased
                    material.diffuse.contents = texture(bead)
                    DiyMaterialAppearance.apply(bead, to: material)
                    geometry.materials = [material]; node.geometry = nil
                    node.childNodes.forEach { $0.removeFromParentNode() }
                    let body = SCNNode(geometry: geometry); body.name = "body"
                    if accessory != nil {
                        let diameter = Float(physical.diameterMm * scale); body.scale = SCNVector3(diameter,diameter,diameter)
                    } else {
                        body.simdOrientation = simd_quatf(angle: DiyGeometry.textureTurn(bead.id), axis: SIMD3(1,0,0)) * simd_quatf(angle: -.pi / 2, axis: SIMD3(0,0,1))
                    }
                    node.addChildNode(body)
                    let shadow = SCNNode(geometry: SCNPlane(width: radius * 3, height: CGFloat((physical.maxZ-physical.minZ) * scale * 1.4)))
                    shadow.name = "contact-shadow"; shadow.eulerAngles.x = -.pi / 2
                    shadow.position = SCNVector3(0, Float(-physical.centerHeightMm * scale + 0.003), Float((physical.maxZ+physical.minZ) / 2 * scale))
                    shadow.geometry?.firstMaterial?.lightingModel = .constant
                    shadow.geometry?.firstMaterial?.diffuse.contents = contactShadow
                    shadow.geometry?.firstMaterial?.writesToDepthBuffer = false
                    shadow.geometry?.firstMaterial?.isDoubleSided = true
                    node.addChildNode(shadow)
                    let assets = DiyRenderAssets.parse(bead.renderAssets)
                    for (raw, property) in [(assets?.albedoMapUrl, material.diffuse), (assets?.normalMapUrl, material.normal), (assets?.roughnessMapUrl, material.roughness)] {
                        if let raw, !raw.hasPrefix("/assets/diy/textures/wood/"), let url = DiyRenderAssets.url(raw) { load(url, into: property) }
                    }
                    let selection = SCNNode(geometry: SCNTorus(ringRadius: radius * 1.22, pipeRadius: radius * 0.035))
                    selection.name = "selection"; selection.position = SCNVector3(0, Float(-physical.centerHeightMm * scale + 0.006), physical.kind?.hasPrefix("pendant") == true || physical.kind == "tassel" ? Float(radius) : 0)
                    selection.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 0.68, green: 0.51, blue: 0.28, alpha: 1)
                    selection.geometry?.firstMaterial?.lightingModel = .constant; node.addChildNode(selection)
                }
                let angle = layout.angles[index]
                node.childNode(withName: "selection", recursively: false)?.isHidden = bead.id != owner.selectedId
                SCNTransaction.begin(); SCNTransaction.animationDuration = animated && !SCNVector3EqualToVector3(node.position, SCNVector3Zero) ? 0.14 : 0
                node.position = SCNVector3(cos(angle) * 1.65, DiyGeometry.dimensions(bead).centerHeightMm * scale, sin(angle) * 1.65)
                node.eulerAngles.y = Float(.pi / 2 - angle); SCNTransaction.commit()
            }
        }
        private func bead(at point: CGPoint) -> String? {
            guard let view else { return nil }
            for hit in view.hitTest(point, options: [.searchMode: SCNHitTestSearchMode.all.rawValue]) {
                var node: SCNNode? = hit.node
                while let item = node { if let name = item.name, nodes[name] != nil { return name }; node = item.parent }
            }
            // A finger targets an area larger than a small bead. Use projected
            // centers as a bounded fallback; never claim an unrelated floor hit.
            let nearest = nodes.min { left, right in
                let a = view.projectPoint(left.value.presentation.worldPosition), b = view.projectPoint(right.value.presentation.worldPosition)
                return hypot(CGFloat(a.x) - point.x, CGFloat(a.y) - point.y) < hypot(CGFloat(b.x) - point.x, CGFloat(b.y) - point.y)
            }
            if let nearest {
                let center = view.projectPoint(nearest.value.presentation.worldPosition)
                if hypot(CGFloat(center.x) - point.x, CGFloat(center.y) - point.y) <= 18 { return nearest.key }
            }
            return nil
        }
        @objc private func tap(_ recognizer: UITapGestureRecognizer) { if let id = bead(at: recognizer.location(in: view)) { owner?.onSelect?(id) } }
        @objc private func pan(_ recognizer: UIPanGestureRecognizer) {
            guard let view, let owner else { return }
            let location = recognizer.location(in: view), translation = recognizer.translation(in: view)
            switch recognizer.state {
            case .began:
                gestureYaw = yaw; gesturePitch = pitch
                if owner.onMove != nil, let id = bead(at: CGPoint(x: location.x - translation.x, y: location.y - translation.y)), let index = owner.slots.firstIndex(where: { $0.id == id }) {
                    draggedId = id; targetIndex = index
                    startAngles = DiyPhysicalLayout(slots: owner.slots, wrist: owner.wrist, allowance: owner.allowance).angles
                    dragPlaneY = nodes[id]?.presentation.worldPosition.y ?? 0
                    if let point = planePoint(CGPoint(x: location.x - translation.x, y: location.y - translation.y)) {
                        dragAngleOffset = startAngles[index] - atan2(Double(point.z), Double(point.x))
                    } else { dragAngleOffset = 0 }
                    owner.onSelect?(id)
                }
            case .changed:
                if let id = draggedId, let from = owner.slots.firstIndex(where: { $0.id == id }), let point = planePoint(location) {
                    let angle = atan2(Double(point.z), Double(point.x)) + dragAngleOffset
                    targetIndex = startAngles.indices.min { angularDistance(angle, startAngles[$0]) < angularDistance(angle, startAngles[$1]) } ?? from
                    var preview = owner.slots; preview.insert(preview.remove(at: from), at: targetIndex)
                    render(preview, animated: !owner.reduceMotion)
                    SCNTransaction.begin(); SCNTransaction.animationDuration = 0
                    let layout = DiyPhysicalLayout(slots: owner.slots, wrist: owner.wrist, allowance: owner.allowance)
                    nodes[id]?.position = SCNVector3(cos(angle) * 1.65, DiyGeometry.dimensions(owner.slots[from]).centerHeightMm * 1.65 / layout.radius + 0.13, sin(angle) * 1.65); SCNTransaction.commit()
                } else {
                    yaw = gestureYaw - Double(translation.x) * 0.008
                    pitch = min(1.4, max(0.25, gesturePitch + Double(translation.y) * 0.008)); updateCamera()
                }
            case .ended:
                if let id = draggedId { draggedId = nil; owner.onMove?(id, targetIndex); if let latest = self.owner { render(latest.slots, animated: !latest.reduceMotion) } }
            case .cancelled, .failed:
                draggedId = nil; render(owner.slots, animated: !owner.reduceMotion)
            default: break
            }
        }
        private func angularDistance(_ a: Double, _ b: Double) -> Double { abs(atan2(sin(a - b), cos(a - b))) }
        private func planePoint(_ point: CGPoint) -> SCNVector3? {
            guard let view else { return nil }
            let near = view.unprojectPoint(SCNVector3(Float(point.x), Float(point.y), 0)), far = view.unprojectPoint(SCNVector3(Float(point.x), Float(point.y), 1))
            let denominator = far.y - near.y
            guard abs(denominator) > 0.00001 else { return nil }
            let t = (dragPlaneY - near.y) / denominator
            return SCNVector3(near.x + t * (far.x - near.x), dragPlaneY, near.z + t * (far.z - near.z))
        }
        @objc private func pinch(_ recognizer: UIPinchGestureRecognizer) {
            if recognizer.state == .began {
                if draggedId != nil { draggedId = nil; if let owner { render(owner.slots, animated: false) } }
                gestureDistance = distance
            }
            distance = min(10, max(2.8, gestureDistance / Double(recognizer.scale))); updateCamera()
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
        func dispose() { requests.values.forEach { $0.cancel() }; requests.removeAll(); textureWaiters.removeAll(); textures.removeAllObjects(); owner = nil }
    }
}

private final class DiyStageSceneView: SCNView {
    var onLayout: (() -> Void)?
    override func layoutSubviews() { super.layoutSubviews(); onLayout?() }
}
