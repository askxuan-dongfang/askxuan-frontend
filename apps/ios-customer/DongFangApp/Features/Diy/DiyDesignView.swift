//
//  DiyDesignView.swift
//  DongFangApp
//

import SwiftUI
import UIKit

struct DiyDesignView: View {
    @StateObject private var viewModel: DiyViewModel
    @State private var showNameDialog = false
    @State private var designNameInput = "我的手串"
    @State private var checkoutAfterSave = false
    @State private var showOrderPage = false
    @State private var materialSearch = ""
    @Environment(\.dismiss) private var dismiss

    @MainActor
    init() {
        _viewModel = StateObject(wrappedValue: DiyViewModel())
    }

    @MainActor
    init(viewModel: DiyViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                topBar
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        DiyBraceletStage(
                            slots: viewModel.beadSlots,
                            selectedId: viewModel.selectedBeadId,
                            wristSizeMm: viewModel.wristSizeMm,
                            fitState: viewModel.fitState,
                            totalPrice: viewModel.totalPrice,
                            usedLengthMm: viewModel.usedLengthMm,
                            onSelect: viewModel.selectBead,
                            onMove: viewModel.moveBead,
                            onRemove: viewModel.removeBead,
                            onWristChange: viewModel.setWristSize
                        )
                        selectedToolbar
                        materialPanel
                    }
                    .padding(.bottom, 92)
                }
            }
            bottomActionBar

            if viewModel.isSubmitting {
                Color.black.opacity(0.42).ignoresSafeArea()
                ProgressView("正在保存设计")
                    .tint(.accentDefault)
                    .foregroundStyle(.textPrimary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(Color.bgElevated)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            }
        }
        .background(Color.bgPrimary)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if viewModel.materials.isEmpty { await viewModel.loadMaterials() }
        }
        .alert("保存设计", isPresented: $showNameDialog) {
            TextField("设计名称", text: $designNameInput)
            Button("取消", role: .cancel) {}
            Button("保存") { saveDesign() }
        } message: {
            Text("设计保存后可继续选择加持服务和收货地址")
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

    private var topBar: some View {
        HStack(spacing: 8) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("返回")

            VStack(alignment: .leading, spacing: 2) {
                Text("设计你的手串")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.textPrimary)
                Text(viewModel.draftStateText)
                    .font(.system(size: 10))
                    .foregroundStyle(.textTertiary)
            }
            Spacer()
            Button { viewModel.undo() } label: {
                Image(systemName: "arrow.uturn.backward")
                    .frame(width: 32, height: 32)
            }
            .disabled(!viewModel.canUndo)
            .accessibilityLabel("撤销")
            Button { viewModel.redo() } label: {
                Image(systemName: "arrow.uturn.forward")
                    .frame(width: 32, height: 32)
            }
            .disabled(!viewModel.canRedo)
            .accessibilityLabel("重做")
        }
        .foregroundStyle(.accentDefault)
        .padding(.horizontal, 12)
        .frame(height: 54)
        .background(Color.bgPrimary.opacity(0.96))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.borderDivider).frame(height: 1)
        }
    }

    @ViewBuilder
    private var selectedToolbar: some View {
        if let selected = viewModel.selectedBead {
            HStack(spacing: 10) {
                DiyMaterialBead(
                    name: selected.materialName,
                    category: selected.subtype,
                    size: 30,
                    isSelected: true
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text("当前选中")
                        .font(.system(size: 9))
                        .foregroundStyle(.textTertiary)
                    Text(selected.materialName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.textPrimary)
                        .lineLimit(1)
                }
                Spacer()
                Button { viewModel.duplicateSelectedBead() } label: {
                    Image(systemName: "plus.square.on.square")
                        .frame(width: 34, height: 32)
                }
                .accessibilityLabel("复制珠子")
                Button(role: .destructive) { viewModel.removeSelectedBead() } label: {
                    Image(systemName: "trash")
                        .frame(width: 34, height: 32)
                }
                .accessibilityLabel("移除珠子")
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 58)
            .background(Color.bgSecondary)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.borderDivider).frame(height: 1)
            }
        }
    }

    private var materialPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Text("选择材料")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.textPrimary)
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                    TextField("搜索材质", text: $materialSearch)
                        .font(.system(size: 11))
                        .textInputAutocapitalization(.never)
                }
                .foregroundStyle(.textTertiary)
                .padding(.horizontal, 9)
                .frame(width: 126, height: 32)
                .background(Color.bgTertiary)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .stroke(Color.borderDefault, lineWidth: 1)
                }
            }

            categoryTabs

            if filteredMaterials.isEmpty && !viewModel.isLoading {
                ContentUnavailableView("暂无可选材料", systemImage: "circle.slash")
                    .foregroundStyle(.textTertiary)
                    .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 74, maximum: 96), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(filteredMaterials) { material in
                        materialCard(material)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.bgSecondary)
    }

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(viewModel.categories, id: \.code) { category in
                    let isSelected = viewModel.selectedCategory == category.code
                    Button {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            viewModel.selectCategory(category.code)
                        }
                    } label: {
                        Text(category.name)
                            .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? Color.accentLight : Color.textTertiary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(isSelected ? Color.accentLight : Color.clear)
                                    .frame(height: 2)
                            }
                    }
                    .buttonStyle(.plain)
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
            withAnimation(.spring(response: 0.36, dampingFraction: 0.72)) {
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
                        isSelected: count > 0
                    )
                    if count > 0 {
                        Text("×\(count)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 4)
                            .frame(minHeight: 16)
                            .background(Color.brandDefault)
                            .clipShape(Capsule())
                            .offset(x: 9, y: -6)
                    }
                }
                Text(material.name)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(material.spec)
                    .font(.system(size: 9))
                    .foregroundStyle(.textTertiary)
                    .lineLimit(1)
                Text("¥\(Int(material.unitPrice))")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.accentLight)
            }
            .frame(maxWidth: .infinity, minHeight: 112)
            .padding(.horizontal, 5)
            .background(Color.bgTertiary)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(count > 0 ? Color.borderStrong : Color.borderDefault, lineWidth: 1)
            }
            .opacity(isUnavailable ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isUnavailable)
        .accessibilityLabel("\(material.name)，\(material.spec)，\(material.priceText)")
        .accessibilityValue(count > 0 ? "已选 \(count) 件" : "未选择")
    }

    private var bottomActionBar: some View {
        HStack(spacing: 10) {
            Button(role: .destructive) { viewModel.clearCart() } label: {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 38, height: 42)
                    .background(Color.bgTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            }
            .disabled(viewModel.totalQuantity == 0)
            .accessibilityLabel("清空设计")

            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.beadSlots.count) 颗")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.textPrimary)
                Text("下单由服务端重新计价")
                    .font(.system(size: 8))
                    .foregroundStyle(.textTertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button { presentSaveDialog(checkout: false) } label: {
                Text("保存设计")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 70, height: 42)
                    .overlay {
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .stroke(Color.accentDefault.opacity(0.55), lineWidth: 1)
                    }
            }
            .disabled(viewModel.beadSlots.isEmpty)

            Button { presentSaveDialog(checkout: true) } label: {
                Text("完成设计")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 78, height: 42)
                    .background(Color.brandDefault)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            }
            .disabled(viewModel.beadSlots.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.bgPrimary.opacity(0.97).ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle().fill(Color.borderDivider).frame(height: 1)
        }
    }

    private func presentSaveDialog(checkout: Bool) {
        checkoutAfterSave = checkout
        designNameInput = viewModel.designName
        showNameDialog = true
    }

    private func saveDesign() {
        let trimmed = designNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.designName = trimmed.isEmpty ? "我的手串" : trimmed
        Task {
            let saved = await viewModel.saveDesign()
            if saved && checkoutAfterSave && viewModel.currentDesign != nil {
                showOrderPage = true
            }
        }
    }
}

private struct DiyBraceletStage: View {
    let slots: [DiyBeadSlot]
    let selectedId: String?
    let wristSizeMm: Int
    let fitState: DiyFitState
    let totalPrice: Double
    let usedLengthMm: Double
    let onSelect: (String?) -> Void
    let onMove: (String, Int) -> Void
    let onRemove: (String) -> Void
    let onWristChange: (Int) -> Void

    @State private var rotation = -Double.pi / 2
    @State private var rotationStart: Double?
    @State private var draggingId: String?
    @State private var dragLocation = CGPoint.zero
    @State private var isOutsideRing = false

    var body: some View {
        GeometryReader { proxy in
            let sceneSize = min(proxy.size.width - 28, 318)
            ZStack {
                Color(hex: "111315")
                RadialGradient(
                    colors: [Color(hex: "303236").opacity(0.72), Color(hex: "17191B"), Color(hex: "0D0F10")],
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
                            .font(.system(size: 10, weight: .semibold))
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
        .frame(height: 380)
        .clipped()
    }

    private var statusRow: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(Array(stride(from: 140, through: 200, by: 10)), id: \.self) { value in
                    Button("\(value / 10) cm") { onWristChange(value) }
                }
            } label: {
                HStack(spacing: 5) {
                    Text("手围")
                        .font(.system(size: 9))
                        .foregroundStyle(.textTertiary)
                    Text("\(wristSizeMm / 10) cm")
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundStyle(.textPrimary)
                .padding(.horizontal, 9)
                .frame(height: 36)
                .background(Color(hex: "181A1D").opacity(0.94))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .stroke(Color.borderDefault, lineWidth: 1)
                }
            }

            HStack(spacing: 5) {
                Circle().fill(fitState.color).frame(width: 6, height: 6)
                Text(fitState.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(fitState.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 0) {
                Text("预估")
                    .font(.system(size: 8))
                    .foregroundStyle(.textTertiary)
                Text("¥\(Int(totalPrice))")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.accentLight)
            }
        }
    }

    private func braceletScene(size: CGFloat) -> some View {
        ZStack {
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
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.textPrimary)
                        Text("颗")
                            .font(.system(size: 10))
                            .foregroundStyle(.textTertiary)
                    }
                    Text("已用 \(Int(usedLengthMm)) mm")
                        .font(.system(size: 10))
                        .foregroundStyle(.textTertiary)
                }
            }
            .allowsHitTesting(false)

            ForEach(Array(slots.enumerated()), id: \.element.id) { index, slot in
                let layout = beadLayout(index: index, count: slots.count, size: size)
                DiyMaterialBead(
                    name: slot.materialName,
                    category: slot.subtype,
                    size: max(28, min(39, 31 + CGFloat(slot.diameterMm - 8) * 1.15)),
                    isSelected: selectedId == slot.id,
                    seed: slot.id
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
                .accessibilityAddTraits(selectedId == slot.id ? .isSelected : [])
            }
        }
        .coordinateSpace(name: "bracelet-space")
        .animation(.spring(response: 0.34, dampingFraction: 0.76), value: slots)
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

    private func beadLayout(index: Int, count: Int, size: CGFloat) -> (point: CGPoint, depth: CGFloat, zIndex: Double, angle: Double) {
        let angle = rotation + (Double(index) / Double(max(count, 1))) * Double.pi * 2
        let x = size / 2 + cos(angle) * size * 0.35
        let y = size / 2 + sin(angle) * size * 0.315
        let depth = 0.94 + CGFloat((sin(angle) + 1) / 2) * 0.12
        return (CGPoint(x: x, y: y), depth, Double(y), angle)
    }

    private func targetIndex(for location: CGPoint, size: CGFloat) -> Int {
        guard !slots.isEmpty else { return 0 }
        let dx = (location.x - size / 2) / (size * 0.35)
        let dy = (location.y - size / 2) / (size * 0.315)
        var angle = atan2(Double(dy), Double(dx)) - rotation
        angle = angle.truncatingRemainder(dividingBy: Double.pi * 2)
        if angle < 0 { angle += Double.pi * 2 }
        return Int(round(angle / (Double.pi * 2) * Double(slots.count))) % slots.count
    }
}

private struct DiyMaterialBead: View {
    let name: String
    let category: String
    let size: CGFloat
    let isSelected: Bool
    var seed = "material"

    private var palette: DiyBeadPalette { .resolve(name: name, category: category) }
    private var isDiscSpacer: Bool {
        category == "spacer"
            && (name.contains("隔片") || name.contains("金属") || name.contains("银隔") || name.contains("金隔"))
    }

    var body: some View {
        Group {
            if isDiscSpacer {
                Capsule()
                    .fill(baseGradient)
                    .frame(width: size * 0.52, height: size)
                    .overlay {
                        DiyBeadTexture(name: name, seed: seed, color: palette.texture)
                            .frame(width: size * 0.52, height: size)
                            .clipShape(Capsule())
                    }
                    .overlay {
                        Capsule()
                            .strokeBorder(rimGradient, lineWidth: isSelected ? 2 : 0.8)
                            .frame(width: size * 0.52, height: size)
                    }
            } else {
                Circle()
                    .fill(baseGradient)
                    .overlay {
                        DiyBeadTexture(name: name, seed: seed, color: palette.texture)
                            .clipShape(Circle())
                    }
                    .overlay {
                        Circle().strokeBorder(rimGradient, lineWidth: isSelected ? 2 : 0.8)
                    }
            }
        }
        .frame(width: size, height: size)
        .overlay {
            Ellipse()
                .fill(Color.white.opacity(0.38))
                .frame(width: size * 0.24, height: size * 0.1)
                .blur(radius: 1.1)
                .offset(x: -size * 0.16, y: -size * 0.2)
                .allowsHitTesting(false)
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
    let seed: String
    let color: Color

    var body: some View {
        Canvas { context, canvasSize in
            var random = DiySeededRandom(seed: name + seed)

            if name.contains("菩提") || name.contains("金刚") {
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
            } else if name.contains("绿松") || name.contains("碧玉") || name.contains("翡翠") {
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
            } else if name.contains("南红") || name.contains("玛瑙") || name.contains("朱砂") {
                for inset in [0.16, 0.3] {
                    let rect = CGRect(
                        x: canvasSize.width * inset,
                        y: canvasSize.height * (inset - 0.07),
                        width: canvasSize.width * (1 - inset * 2),
                        height: canvasSize.height * (1 - inset * 1.55)
                    )
                    context.stroke(Path(ellipseIn: rect), with: .color(color.opacity(0.26)), lineWidth: max(0.7, canvasSize.width * 0.03))
                }
            } else if name.contains("蜜蜡") || name.contains("琥珀") {
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

    static func resolve(name: String, category: String) -> DiyBeadPalette {
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
}

#Preview {
    NavigationStack { DiyDesignView() }
        .preferredColorScheme(.dark)
}
