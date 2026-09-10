import SwiftUI

struct DiyBraceletView: View {
    @StateObject private var viewModel = DiyViewModel()

    var body: some View {
        VStack(spacing: 0) {
            DFTopNavBar("东方珠作", showsBackButton: true) { EmptyView() } trailing: { EmptyView() }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    workbench
                    quickNavigation
                    inspirationSection
                    if let error = viewModel.errorMessage {
                        Text(error).font(.footnote).foregroundStyle(.red).padding()
                        Button("重新加载") { Task { await viewModel.loadDesigns() } }
                    }
                    if viewModel.hasMoreDesigns {
                        Button(viewModel.isLoading ? "加载中…" : "加载更多作品") { Task { await viewModel.loadDesigns(append: true) } }.disabled(viewModel.isLoading).padding()
                    }
                    Spacer(minLength: AppSpacing.navBottom + 24)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)
            }
            .refreshable { await viewModel.loadDesigns() }
        }
        .background(Color.bgPrimary)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if viewModel.designs.isEmpty { await viewModel.loadDesigns() }
        }
        .navigationDestination(for: DiyDesign.self) { design in
            DiyDetailView(designId: design.id)
        }
    }

    private var workbench: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("专属手串设计")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.accentDefault)
            Text("从一颗珠子开始")
                .font(AppTypography.title(22))
                .foregroundStyle(Color.textPrimary)
                .padding(.top, 4)

            DiyMiniBracelet(slots: slots(for: viewModel.designs.first), fallbackCount: 14)
                .frame(height: 244)

            HStack(spacing: 12) {
                Text("天然材质，颗颗不同")
                Text("·")
                Text("自由搭配，保存心意")
            }
            .font(.system(size: 9))
            .foregroundStyle(Color.textTertiary)
            .frame(maxWidth: .infinity)

            NavigationLink {
                DiyDesignView()
            } label: {
                Label("开始设计", systemImage: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.brandDefault)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            }
            .buttonStyle(.plain)
            .padding(.top, 14)
        }
        .padding(16)
        .background(
            RadialGradient(
                colors: [Color(hex: "544338"), Color(hex: "30251E"), Color(hex: "201915")],
                center: .center,
                startRadius: 24,
                endRadius: 280
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay { RoundedRectangle(cornerRadius: AppRadius.md).stroke(Color.borderDefault, lineWidth: 1) }
    }

    private var quickNavigation: some View {
        HStack(spacing: 0) {
            NavigationLink {
                DiyMyDesignsView()
            } label: {
                quickItem(title: "我的作品", subtitle: "已保存的设计")
            }
            .buttonStyle(.plain)

            Rectangle().fill(Color.borderDivider).frame(width: 1, height: 42)

            quickSummary(title: "灵感广场", subtitle: "\(viewModel.designs.count) 个作品")
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.borderDivider).frame(height: 1) }
    }

    private func quickItem(title: String, subtitle: String) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.textPrimary)
                Text(subtitle).font(.system(size: 9)).foregroundStyle(Color.textTertiary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.accentDefault)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
    }

    private func quickSummary(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.textPrimary)
            Text(subtitle).font(.system(size: 9)).foregroundStyle(Color.textTertiary)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var inspirationSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("灵感广场")
                .font(.sectionTitle)
                .foregroundStyle(Color.textPrimary)

            if viewModel.isLoading && viewModel.designs.isEmpty {
                ProgressView("加载作品中")
                    .tint(Color.accentDefault)
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else if viewModel.designs.isEmpty {
                DFEmptyState(icon: "circle.grid.2x2", title: "暂无公开作品", subtitle: "保存并公开的设计会显示在这里")
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(viewModel.designs) { design in
                        NavigationLink(value: design) { designCard(design) }
                            .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.top, 22)
    }

    private func designCard(_ design: DiyDesign) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            DiyMiniBracelet(slots: slots(for: design), fallbackCount: 0)
                .frame(height: 142)
                .background(Color(hex: "30251E"))

            VStack(alignment: .leading, spacing: 6) {
                Text(design.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                HStack {
                    Text("灵感作品").font(.system(size: 9)).foregroundStyle(Color.textTertiary)
                    Spacer()
                    Text("¥\(Int(design.totalPrice))").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.accentLight)
                }
            }
            .padding(10)
        }
        .background(Color.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay { RoundedRectangle(cornerRadius: AppRadius.md).stroke(Color.borderDefault, lineWidth: 1) }
    }

    private func slots(for design: DiyDesign?) -> [DiyBeadSlot] {
        guard let raw = design?.designData,
              let data = raw.data(using: .utf8),
              let document = try? JSONDecoder().decode(DiyDesignDocument.self, from: data) else { return [] }
        return document.beads.sorted { $0.position < $1.position }
    }
}

struct DiyMiniBracelet: View {
    let slots: [DiyBeadSlot]
    let fallbackCount: Int

    private let fallbackColors = ["8F3B3B", "D8C797", "486D57", "315A82", "E6DED0"]

    var body: some View {
        GeometryReader { proxy in
            let count = slots.isEmpty ? fallbackCount : min(slots.count, 60)
            let radiusX = min(proxy.size.width * 0.32, 108)
            let radiusY = min(proxy.size.height * 0.34, 82)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)

            ZStack {
                Ellipse()
                    .stroke(Color(hex: "D8C797").opacity(0.55), lineWidth: 2)
                    .frame(width: radiusX * 2, height: radiusY * 2)

                ForEach(0..<count, id: \.self) { index in
                    let slot = slots.indices.contains(index) ? slots[index] : nil
                    let angle = slots.isEmpty ? -Double.pi / 2 + Double(index) / Double(max(count, 1)) * Double.pi * 2 : DiyPhysicalLayout(slots: slots).angles[index]
                    let size = slots.isEmpty ? CGFloat(20) : CGFloat((slot?.diameterMm ?? 10) / DiyPhysicalLayout(slots: slots).radius) * radiusX
                    DiyMaterialBead(name: slot?.materialName ?? "", category: slot?.subtype ?? "main_bead", size: size, isSelected: false, shape: slot?.shape ?? "round", colorHex: slot?.colorHex ?? fallbackColors[index % fallbackColors.count], textureKey: slot?.textureKey, finish: slot?.finish, translucency: slot?.translucency ?? 0, renderAssets: slot?.renderAssets)
                        .frame(width: size, height: size)
                        .shadow(color: Color.black.opacity(0.45), radius: 4, y: 3)
                        .position(x: center.x + cos(angle) * radiusX, y: center.y + sin(angle) * radiusY)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    NavigationStack { DiyBraceletView() }
        .preferredColorScheme(.dark)
}
