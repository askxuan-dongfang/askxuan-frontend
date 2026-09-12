//
//  DiyDesignView.swift
//  DongFangApp
//

import SwiftUI
import UIKit
import SceneKit

struct DiyDesignView: View {
    @StateObject private var viewModel: DiyViewModel
    @State private var showNameDialog = false
    @State private var designNameInput = "我的手串"
    @State private var designDescriptionInput = ""
    @State private var checkoutAfterSave = false
    @State private var showOrderPage = false
    @State private var materialSearch = ""
    @State private var show3D = false
    @State private var showSavedDetail = false
    @State private var materialPanelExpanded = true
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var searchFocused: Bool
    @State private var showClearConfirmation = false
    @State private var sizePanelExpanded = false

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
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        VStack(spacing: 0) {
                            DiyPreviewModePicker(show3D: $show3D)
                                .padding(12)
                            if show3D {
                                DiyNativeStage3D(slots: viewModel.beadSlots, wrist: Double(viewModel.wristSizeMm), allowance: viewModel.fitAllowanceMm)
                                    .frame(height: 280)
                            } else {
                                DiyBraceletStage(
                                    slots: viewModel.beadSlots,
                                    selectedId: viewModel.selectedBeadId,
                                    wristSizeMm: viewModel.wristSizeMm,
                                    fitAllowanceMm: viewModel.fitAllowanceMm,
                                    fitState: viewModel.fitState,
                                    totalPrice: viewModel.totalPrice,
                                    usedLengthMm: viewModel.usedLengthMm,
                                    onSelect: viewModel.selectBead,
                                    onMove: viewModel.moveBead,
                                    onRemove: viewModel.removeBead
                                )
                            }
                            Label(show3D ? "拖动旋转 · 双指缩放" : "点按选中 · 拖动排序 · 移出圆环删除", systemImage: "hand.draw")
                                .font(.caption)
                                .foregroundStyle(Color.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .diySurface()
                        sizePanel
                        selectedToolbar
                        materialPanel
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomActionBar }
            .disabled(viewModel.isSubmitting)

            if viewModel.isSubmitting {
                Color.black.opacity(0.42).ignoresSafeArea()
                ProgressView("正在保存设计")
                    .tint(.accentDefault)
                    .foregroundStyle(.textPrimary)
                    .padding(24)
                    .background(Color.bgElevated, in: RoundedRectangle(cornerRadius: 20))
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .background(Color.bgPrimary)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if viewModel.materials.isEmpty { await viewModel.loadMaterials() }
        }
        .confirmationDialog("清空当前搭配？清空后仍可通过撤销恢复。", isPresented: $showClearConfirmation, titleVisibility: .visible) {
            Button("清空搭配", role: .destructive) {
                withAnimation(reduceMotion ? nil : .snappy(duration: 0.24)) { viewModel.clearCart() }
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        }
        .alert("保存设计", isPresented: $showNameDialog) {
            TextField("设计名称", text: $designNameInput)
            TextField("搭配灵感（可选）", text: $designDescriptionInput)
            Button("取消", role: .cancel) {}
            Button("保存") { saveDesign() }
        } message: {
            Text("保存后可发布到广场、分享给朋友或继续定制。修改已发布作品会先转为私密。")
        }
        .alert("提示", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
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
        HStack(spacing: 8) {
            DFBackButton()

            VStack(alignment: .leading, spacing: 2) {
                Text("设计你的手串")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.textPrimary)
                Text(viewModel.draftStateText)
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
            }
            Spacer()
            Button { viewModel.undo(); UISelectionFeedbackGenerator().selectionChanged() } label: {
                Image(systemName: "arrow.uturn.backward")
                    .frame(width: 44, height: 44)
            }
            .disabled(!viewModel.canUndo)
            .accessibilityLabel("撤销")
            Button { viewModel.redo(); UISelectionFeedbackGenerator().selectionChanged() } label: {
                Image(systemName: "arrow.uturn.forward")
                    .frame(width: 44, height: 44)
            }
            .disabled(!viewModel.canRedo)
            .accessibilityLabel("重做")
        }
        .foregroundStyle(.accentDefault)
        .padding(.horizontal, 12)
        .frame(minHeight: 60)
        .background(Color.bgPrimary.opacity(0.96))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.borderDivider).frame(height: 1)
        }
    }

    private var sizePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation(reduceMotion ? nil : .snappy(duration: 0.24)) { sizePanelExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "ruler").foregroundStyle(Color.accentLight)
                    Text("佩戴尺寸").font(.subheadline.weight(.semibold))
                    Spacer(minLength: 4)
                    Text(String(format: "%.1f cm · 松量 %.0f mm", Double(viewModel.wristSizeMm) / 10, viewModel.fitAllowanceMm))
                        .font(.caption).foregroundStyle(Color.textSecondary)
                    Image(systemName: sizePanelExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold)).foregroundStyle(Color.accentLight)
                }.frame(minHeight: 44)
            }
            .buttonStyle(DiyPressButtonStyle())
            .accessibilityLabel(sizePanelExpanded ? "收起佩戴尺寸设置" : "展开佩戴尺寸设置")
            if sizePanelExpanded {
                HStack {
                    Text("手围").font(.subheadline)
                    Spacer()
                    Stepper(value: Binding(get: { viewModel.wristSizeMm }, set: { viewModel.setWristSize($0) }), in: 140...200, step: 5) {
                        Text(String(format: "%.1f cm", Double(viewModel.wristSizeMm) / 10))
                            .font(.subheadline.weight(.semibold)).monospacedDigit()
                            .foregroundStyle(Color.accentLight)
                    }
                    .frame(maxWidth: 230)
                    .accessibilityLabel("手围")
                }
                Picker("佩戴松量", selection: Binding(get: { viewModel.fitAllowanceMm }, set: { viewModel.setFitAllowance($0) })) {
                    Text("贴合").tag(0.0)
                    Text("＋5 mm").tag(5.0)
                    Text("＋8 mm").tag(8.0)
                    Text("＋12 mm").tag(12.0)
                }
                .pickerStyle(.segmented)
                Text("贴腕测量一圈；松量越大，佩戴越宽松。天然材质以实物为准。")
                    .font(.caption).foregroundStyle(Color.textSecondary)
            }
        }
        .foregroundStyle(Color.textPrimary)
        .padding(.horizontal, 16).padding(.vertical, 8)
        .diySurface()
    }

    @ViewBuilder
    private var selectedToolbar: some View {
        if let selected = viewModel.selectedBead {
            HStack(spacing: 10) {
                DiyMaterialBead(
                    name: selected.materialName,
                    category: selected.subtype,
                    size: 30,
                    isSelected: true,
                    shape: selected.shape ?? "round",
                    colorHex: selected.colorHex,
                    textureKey: selected.textureKey,
                    finish: selected.finish,
                    translucency: selected.translucency ?? 0, renderAssets: selected.renderAssets
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text("第 \((viewModel.beadSlots.firstIndex { $0.id == selected.id } ?? 0) + 1) 颗 · 当前选中")
                        .font(.caption)
                        .foregroundStyle(.textTertiary)
                    Text(selected.materialName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.textPrimary)
                        .lineLimit(1)
                }
                Spacer()
                Button { viewModel.duplicateSelectedBead(); UIImpactFeedbackGenerator(style: .light).impactOccurred() } label: {
                    Image(systemName: "plus.square.on.square")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("复制珠子")
                Button(role: .destructive) { viewModel.removeSelectedBead() } label: {
                    Image(systemName: "trash")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("移除珠子")
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 70)
            .foregroundStyle(Color.accentLight)
            .buttonStyle(DiyPressButtonStyle())
            .diySurface(highlighted: true)
            .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
        }
    }

    private var materialPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("材料库")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.textPrimary)
                    Text("\(filteredMaterials.count) 种材料 · 点按加入搭配")
                        .font(.system(size: 11))
                        .foregroundStyle(.textTertiary)
                }
                Spacer()
                Button {
                    withAnimation(reduceMotion ? nil : .snappy(duration: 0.24)) {
                        materialPanelExpanded.toggle()
                    }
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Image(systemName: materialPanelExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.accentDefault)
                        .frame(width: 44, height: 44)
                        .background(Color.bgTertiary)
                        .clipShape(Circle())
                        .overlay { Circle().stroke(Color.borderDefault, lineWidth: 1) }
                }
                .buttonStyle(DiyPressButtonStyle())
                .accessibilityLabel(materialPanelExpanded ? "收起材料库" : "展开材料库")
            }

            categoryTabs

            if materialPanelExpanded {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                    TextField("搜索材质、规格", text: $materialSearch)
                        .font(.system(size: 11))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($searchFocused)
                        .submitLabel(.done)
                        .onSubmit { searchFocused = false }
                    if !materialSearch.isEmpty {
                        Button { materialSearch = "" } label: {
                            Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("清除搜索")
                    }
                }
                .foregroundStyle(.textTertiary)
                .padding(.horizontal, 10)
                .frame(height: 48)
                .background(Color.bgTertiary)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .stroke(Color.borderDefault, lineWidth: 1)
                }

                if viewModel.isLoading && viewModel.materials.isEmpty {
                    ProgressView("正在准备材料")
                        .tint(Color.accentDefault)
                        .frame(maxWidth: .infinity, minHeight: 160)
                } else if filteredMaterials.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass").font(.title2)
                        Text(materialSearch.isEmpty ? "该分类暂无材料" : "没有找到匹配材料")
                            .font(.subheadline.weight(.medium))
                        Button(materialSearch.isEmpty ? "重新加载" : "清除搜索") {
                            if materialSearch.isEmpty { Task { await viewModel.loadMaterials() } }
                            else { materialSearch = "" }
                        }
                        .font(.subheadline).foregroundStyle(Color.accentLight)
                        .frame(minHeight: 44)
                    }
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 160)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 94), spacing: 10)],
                        spacing: 8
                    ) {
                        ForEach(filteredMaterials) { material in
                            materialCard(material)
                        }
                    }
                    .transition(.opacity)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(filteredMaterials.prefix(10))) { material in
                            quickMaterialButton(material)
                        }
                    }
                    .padding(.vertical, 3)
                }
                .transition(.opacity)
            }
        }
        .padding(14)
        .diySurface()
    }

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(viewModel.categories, id: \.code) { category in
                    let isSelected = viewModel.selectedCategory == category.code
                    Button {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.16)) {
                            viewModel.selectCategory(category.code)
                        }
                    } label: {
                        Text(category.name)
                            .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? Color.accentLight : Color.textTertiary)
                            .padding(.horizontal, 10)
                            .frame(minHeight: 44)
                            .background(isSelected ? Color.accentDefault.opacity(0.14) : Color.bgTertiary.opacity(0.45), in: Capsule())
                            .overlay { Capsule().stroke(isSelected ? Color.accentDefault.opacity(0.6) : Color.clear, lineWidth: 1) }
                    }
                    .buttonStyle(DiyPressButtonStyle())
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }

    private var filteredMaterials: [Material] {
        let keyword = materialSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return viewModel.filteredMaterials }
        return viewModel.filteredMaterials.filter {
            $0.name.localizedCaseInsensitiveContains(keyword)
                || $0.spec.localizedCaseInsensitiveContains(keyword)
        }
    }

    private func materialCard(_ material: Material) -> some View {
        let count = viewModel.count(for: material.id)
        let isUnavailable = count >= material.stock
        return Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.8)) {
                viewModel.addToCart(material)
            }
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
                        translucency: material.translucency ?? 0, renderAssets: material.renderAssets
                    )
                    if count > 0 {
                        Text("×\(count)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 4)
                            .frame(minHeight: 16)
                            .background(Color.brandDefault)
                            .clipShape(Capsule())
                            .offset(x: 9, y: -6)
                    }
                }
                Text(material.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(material.spec)
                    .font(.system(size: 11))
                    .foregroundStyle(.textTertiary)
                    .lineLimit(1)
                Text(isUnavailable ? (material.stock == 0 ? "暂时售罄" : "已达库存上限") : material.priceText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.accentLight)
            }
            .frame(maxWidth: .infinity, minHeight: 142)
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
        .accessibilityValue(isUnavailable ? "库存不足，无法继续添加" : (count > 0 ? "已选 \(count) 件" : "未选择"))
        .accessibilityHint("点按加入搭配")
    }

    private func quickMaterialButton(_ material: Material) -> some View {
        let count = viewModel.count(for: material.id)
        let isUnavailable = count >= material.stock
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
                    translucency: material.translucency ?? 0, renderAssets: material.renderAssets
                )
                Text(material.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
                    .frame(width: 60)
            }
        }
        .buttonStyle(DiyPressButtonStyle())
        .disabled(isUnavailable)
        .accessibilityLabel("添加\(material.name)")
    }

    private var bottomActionBar: some View {
        VStack(spacing: 10) {
            HStack {
                Text("\(viewModel.beadSlots.count) 颗 · 搭配预估")
                    .font(.caption).foregroundStyle(Color.textSecondary)
                Spacer()
                Text(viewModel.totalPriceText)
                    .font(AppTypography.numeric(22, weight: .semibold))
                    .foregroundStyle(Color.accentLight)
                    .contentTransition(.numericText())
            }
            HStack(spacing: 10) {
                Button(role: .destructive) { showClearConfirmation = true } label: {
                    Image(systemName: "trash").frame(width: 48, height: 48)
                        .background(Color.bgTertiary, in: RoundedRectangle(cornerRadius: 14))
                }
                .disabled(viewModel.totalQuantity == 0)
                .accessibilityLabel("清空设计")
                Button { presentSaveDialog(checkout: false) } label: {
                    Text("保存设计").font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .overlay { RoundedRectangle(cornerRadius: 14).stroke(Color.accentDefault.opacity(0.5), lineWidth: 1) }
                }
                .disabled(viewModel.beadSlots.isEmpty)
                Button { presentSaveDialog(checkout: true) } label: {
                    Label("完成搭配", systemImage: "arrow.right")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(LinearGradient(colors: [.brandLight, .brandDefault], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 14))
                }
                .disabled(viewModel.beadSlots.isEmpty)
            }
            .foregroundStyle(Color.accentLight)
            .buttonStyle(DiyPressButtonStyle())
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color.bgPrimary.opacity(0.97).ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(Color.borderStrong).frame(height: 1) }
    }

    private func presentSaveDialog(checkout: Bool) {
        checkoutAfterSave = checkout
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

private struct DiyBraceletStage: View {
    let slots: [DiyBeadSlot]
    let selectedId: String?
    let wristSizeMm: Int
    let fitAllowanceMm: Double
    let fitState: DiyFitState
    let totalPrice: Double
    let usedLengthMm: Double
    let onSelect: (String?) -> Void
    let onMove: (String, Int) -> Void
    let onRemove: (String) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var rotation = -Double.pi / 2
    @State private var rotationStart: Double?
    @State private var draggingId: String?
    @State private var dragLocation = CGPoint.zero
    @State private var isOutsideRing = false

    var body: some View {
        GeometryReader { proxy in
            let sceneSize = min(proxy.size.width - 28, min(proxy.size.height - 32, 318))
            ZStack {
                Color(hex: "241C17")
                RadialGradient(
                    colors: [Color(hex: "544338").opacity(0.72), Color(hex: "30251E"), Color(hex: "201915")],
                    center: UnitPoint(x: 0.5, y: 0.57),
                    startRadius: 18,
                    endRadius: proxy.size.width * 0.72
                )

                Ellipse()
                    .fill(Color.black.opacity(0.52))
                    .frame(width: sceneSize * 0.82, height: sceneSize * 0.33)
                    .blur(radius: 22)
                    .position(x: proxy.size.width / 2, y: proxy.size.height * 0.69)

                VStack(spacing: 0) {
                    statusRow
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)

                braceletScene(size: sceneSize)
                    .frame(width: sceneSize, height: sceneSize)
                    .position(x: proxy.size.width / 2, y: proxy.size.height * 0.57)

                if draggingId != nil && isOutsideRing {
                    VStack(spacing: 3) {
                        Image(systemName: "trash.fill")
                        Text("松手移除")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Color.stateError)
                    .frame(width: 104, height: 52)
                    .background(Color.black.opacity(0.72))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .stroke(Color.stateError, style: StrokeStyle(lineWidth: 1, dash: [4]))
                    }
                    .position(x: proxy.size.width / 2, y: proxy.size.height - 36)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .frame(height: 280)
        .clipped()
    }

    private var statusRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Circle().fill(fitState.color).frame(width: 6, height: 6)
                Text(fitState.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(fitState.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 0) {
                Text("预估")
                    .font(.system(size: 11))
                    .foregroundStyle(.textTertiary)
                Text(AppDateFormatter.moneyText(totalPrice))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.accentLight)
            }
        }
    }

    private func braceletScene(size: CGFloat) -> some View {
        let physical = DiyPhysicalLayout(slots: slots, wrist: Double(wristSizeMm), allowance: fitAllowanceMm)
        return ZStack {
            Circle()
                .fill(Color.clear)
                .contentShape(Circle())
                .gesture(rotationGesture)

            Ellipse()
                .stroke(Color.black.opacity(0.58), lineWidth: 5)
                .frame(width: size * 0.70, height: size * 0.63)
                .offset(y: 3)

            Ellipse()
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: "D8C797"), Color(hex: "8B7952"), Color(hex: "D8C797")],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 2.2
                )
                .frame(width: size * 0.70, height: size * 0.63)
                .opacity(0.78)

            VStack(spacing: 3) {
                if slots.isEmpty {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 26))
                        .foregroundStyle(.accentDefault)
                    Text("从下方选择材料")
                        .font(.system(size: 11))
                        .foregroundStyle(.textTertiary)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(slots.count)")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(.textPrimary)
                        Text("颗")
                            .font(.system(size: 12))
                            .foregroundStyle(.textTertiary)
                    }
                    Text("已用 \(Int(usedLengthMm)) mm")
                        .font(.system(size: 12))
                        .foregroundStyle(.textTertiary)
                }
            }
            .allowsHitTesting(false)

            ForEach(Array(slots.enumerated()), id: \.element.id) { index, slot in
                let layout = beadLayout(index: index, size: size, physical: physical)
                DiyMaterialBead(
                    name: slot.materialName,
                    category: slot.subtype,
                    size: CGFloat(slot.diameterMm / physical.radius) * size * 0.35,
                    isSelected: selectedId == slot.id,
                    seed: slot.id,
                    shape: slot.shape ?? "round",
                    colorHex: slot.colorHex,
                    textureKey: slot.textureKey,
                    finish: slot.finish,
                    translucency: slot.translucency ?? 0, renderAssets: slot.renderAssets
                )
                .rotationEffect(.radians(layout.angle + Double.pi / 2))
                .scaleEffect(layout.depth)
                .position(draggingId == slot.id ? dragLocation : layout.point)
                .zIndex(draggingId == slot.id ? 1_000 : layout.zIndex)
                .shadow(
                    color: .black.opacity(draggingId == slot.id ? 0.78 : 0.52),
                    radius: draggingId == slot.id ? 10 : 4,
                    y: draggingId == slot.id ? 9 : 4
                )
                .gesture(beadDragGesture(slot: slot, size: size))
                .simultaneousGesture(TapGesture().onEnded { onSelect(slot.id) })
                .accessibilityLabel("\(slot.materialName)，第 \(index + 1) 位")
                .accessibilityAddTraits(selectedId == slot.id ? [.isSelected, .isButton] : .isButton)
                .accessibilityAction(named: "选中珠子") { onSelect(slot.id) }
                .accessibilityAction(named: "向前移动") { onMove(slot.id, max(0, index - 1)) }
                .accessibilityAction(named: "向后移动") { onMove(slot.id, min(slots.count - 1, index + 1)) }
                .accessibilityAction(named: "移除珠子") { onRemove(slot.id) }
            }
        }
        .coordinateSpace(name: "bracelet-space")
        .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.8), value: slots)
    }

    private var rotationGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if rotationStart == nil { rotationStart = rotation }
                rotation = (rotationStart ?? rotation) + Double(value.translation.width / 108)
            }
            .onEnded { _ in rotationStart = nil }
    }

    private func beadDragGesture(slot: DiyBeadSlot, size: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named("bracelet-space"))
            .onChanged { value in
                if draggingId == nil {
                    onSelect(slot.id)
                    UISelectionFeedbackGenerator().selectionChanged()
                }
                draggingId = slot.id
                dragLocation = value.location
                let center = CGPoint(x: size / 2, y: size / 2)
                let normalized = sqrt(
                    pow((value.location.x - center.x) / (size * 0.39), 2)
                    + pow((value.location.y - center.y) / (size * 0.36), 2)
                )
                let outside = normalized > 1.34
                if outside != isOutsideRing {
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.65)
                }
                isOutsideRing = outside
            }
            .onEnded { value in
                if isOutsideRing {
                    onRemove(slot.id)
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                } else if !slots.isEmpty {
                    onMove(slot.id, targetIndex(for: value.location, size: size))
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                draggingId = nil
                isOutsideRing = false
            }
    }

    private func beadLayout(index: Int, size: CGFloat, physical: DiyPhysicalLayout) -> (point: CGPoint, depth: CGFloat, zIndex: Double, angle: Double) {
        let angle = rotation + (physical.angles.indices.contains(index) ? physical.angles[index] + Double.pi / 2 : 0)
        let x = size / 2 + cos(angle) * size * 0.35
        let y = size / 2 + sin(angle) * size * 0.315
        let depth = 0.94 + CGFloat((sin(angle) + 1) / 2) * 0.12
        return (CGPoint(x: x, y: y), depth, Double(y), angle)
    }

    private func targetIndex(for location: CGPoint, size: CGFloat) -> Int {
        let physical = DiyPhysicalLayout(slots: slots, wrist: Double(wristSizeMm), allowance: fitAllowanceMm)
        return slots.indices.min { a, b in
            let p = beadLayout(index: a, size: size, physical: physical).point
            let q = beadLayout(index: b, size: size, physical: physical).point
            return hypot(location.x - p.x, location.y - p.y) < hypot(location.x - q.x, location.y - q.y)
        } ?? 0
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

    private var palette: DiyBeadPalette { .resolve(name: name, category: category, colorHex: colorHex) }
    private var isDiscSpacer: Bool {
        shape == "disc" || (category == "spacer" && name.contains("隔片"))
    }

    var body: some View {
        Group {
            if isDiscSpacer {
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
            Ellipse()
                .fill(Color.white.opacity(0.38))
                .frame(width: size * 0.24, height: size * 0.1)
                .blur(radius: 1.1)
                .offset(x: -size * 0.16, y: -size * 0.2)
                .allowsHitTesting(false)
        }
        .overlay {
            if let assets = DiyRenderAssets.parse(renderAssets), let url = DiyRenderAssets.url(assets.beadImageUrl) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        if let c = assets.imageCrop, c.width > 0, c.height > 0 {
                            image.resizable().frame(width: size * c.imageWidth / c.width, height: size * c.imageHeight / c.height)
                                .offset(x: size * (c.imageWidth / 2 - c.x - c.width / 2) / c.width, y: size * (c.imageHeight / 2 - c.y - c.height / 2) / c.height)
                                .frame(width: size, height: size).clipShape(Circle())
                        } else { image.resizable().scaledToFill().frame(width: size, height: size).clipShape(Circle()) }
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(); view.allowsCameraControl = true; view.autoenablesDefaultLighting = false
        view.backgroundColor = UIColor(red: 0.14, green: 0.105, blue: 0.085, alpha: 1)
        view.antialiasingMode = .multisampling4X; view.preferredFramesPerSecond = 30
        view.accessibilityLabel = "手串 3D 预览，拖动旋转，双指缩放"
        return view
    }
    func updateUIView(_ view: SCNView, context: Context) {
        view.defaultCameraController.inertiaEnabled = !reduceMotion
        let signature = String(slots.hashValue) + "-\(wrist)-\(allowance)"
        guard view.accessibilityIdentifier != signature else { return }
        view.accessibilityIdentifier = signature
        let scene = SCNScene(); let layout = DiyPhysicalLayout(slots: slots, wrist: wrist, allowance: allowance)
        let scale = 1.65 / layout.radius
        let camera = SCNNode(); camera.camera = SCNCamera(); camera.position = SCNVector3(0, 4, 5.8); camera.look(at: SCNVector3Zero)
        scene.rootNode.addChildNode(camera); view.pointOfView = camera
        for (position, intensity, color) in [(SCNVector3(2, 5, 4), CGFloat(1100), UIColor.white), (SCNVector3(-4, 3, -2), CGFloat(700), UIColor(red: 0.75, green: 0.85, blue: 1, alpha: 1))] {
            let light = SCNNode(); light.light = SCNLight(); light.light?.type = .omni; light.light?.intensity = intensity; light.light?.color = color; light.position = position; scene.rootNode.addChildNode(light)
        }
        let ambient = SCNNode(); ambient.light = SCNLight(); ambient.light?.type = .ambient; ambient.light?.intensity = 350; scene.rootNode.addChildNode(ambient)
        let cord = SCNNode(geometry: SCNTorus(ringRadius: 1.65, pipeRadius: 0.012)); cord.geometry?.firstMaterial?.diffuse.contents = UIColor(Color.accentDefault); scene.rootNode.addChildNode(cord)
        for (index, bead) in slots.enumerated() {
            let r = CGFloat(bead.diameterMm * scale / 2)
            let geometry: SCNGeometry
            if bead.shape == "disc" || bead.shape == "barrel" { geometry = SCNCylinder(radius: r, height: r * (bead.shape == "disc" ? 0.9 : 2.3)) }
            else { let sphere = SCNSphere(radius: r); sphere.segmentCount = bead.shape == "faceted" ? 10 : 40; geometry = sphere }
            let mat = SCNMaterial(); mat.lightingModel = .physicallyBased
            mat.diffuse.contents = UIColor(Color(hex: bead.colorHex ?? "93795B")); mat.metalness.contents = bead.materialType == "metal" ? 0.85 : 0.0
            mat.roughness.contents = bead.finish == "matte" || bead.finish == "natural" ? 0.55 : 0.2
            mat.clearCoat.contents = 0.8; mat.clearCoatRoughness.contents = 0.12
            geometry.materials = [mat]
            let node = SCNNode(geometry: geometry); let angle = layout.angles[index]
            node.position = SCNVector3(cos(angle) * 1.65, 0, sin(angle) * 1.65)
            if bead.shape == "disc" || bead.shape == "barrel" { node.eulerAngles = SCNVector3(0, -angle, Double.pi / 2) }
            if bead.shape == "pendant" { node.scale = SCNVector3(0.8, 1.25, 0.7) }
            scene.rootNode.addChildNode(node)
            let assets = DiyRenderAssets.parse(bead.renderAssets)
            for (urlString, property) in [(assets?.albedoMapUrl, mat.diffuse), (assets?.normalMapUrl, mat.normal), (assets?.roughnessMapUrl, mat.roughness)] {
                guard let url = DiyRenderAssets.url(urlString) else { continue }
                URLSession.shared.dataTask(with: url) { data, response, _ in
                    guard let response = response as? HTTPURLResponse, response.statusCode == 200, response.mimeType?.hasPrefix("image/") == true, let data, let image = UIImage(data: data) else { return }
                    DispatchQueue.main.async { property.contents = image }
                }.resume()
            }
        }
        view.scene = scene
    }
}
