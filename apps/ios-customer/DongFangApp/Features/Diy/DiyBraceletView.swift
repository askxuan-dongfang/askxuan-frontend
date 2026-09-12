import SwiftUI

struct DiyBraceletView: View {
    @StateObject private var viewModel = DiyViewModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            DFTopNavBar("东方珠作", showsBackButton: true) { EmptyView() } trailing: {
                NavigationLink { DiyMyDesignsView() } label: {
                    Image(systemName: "square.stack").frame(width: 44, height: 44)
                }
                .accessibilityLabel("我的作品")
            }
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        workbench
                        HStack(spacing: 12) {
                            NavigationLink { DiyMyDesignsView() } label: {
                                quickItem(title: "我的作品", subtitle: "保存每一次灵感", icon: "square.stack")
                            }
                            Button {
                                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { proxy.scrollTo("inspiration", anchor: .top) }
                            } label: {
                                quickItem(title: "灵感广场", subtitle: "发现心仪的搭配", icon: "sparkles")
                            }
                        }
                        .buttonStyle(DiyPressButtonStyle())
                        inspirationSection.id("inspiration")
                        if let error = viewModel.errorMessage {
                            VStack(spacing: 10) {
                                Label(error, systemImage: "wifi.exclamationmark")
                                    .font(.caption).foregroundStyle(Color.textSecondary)
                                Button("重新加载") { Task { await viewModel.loadDesigns() } }
                                    .font(.subheadline).frame(minHeight: 44)
                            }
                            .padding(16).frame(maxWidth: .infinity).diySurface()
                        }
                        if viewModel.hasMoreDesigns {
                            Button { Task { await viewModel.loadDesigns(append: true) } } label: {
                                HStack(spacing: 8) {
                                    if viewModel.isLoading { ProgressView().tint(Color.accentDefault) }
                                    Text(viewModel.isLoading ? "加载中…" : "发现更多作品")
                                }.frame(maxWidth: .infinity, minHeight: 48)
                            }
                            .buttonStyle(DiyPressButtonStyle()).disabled(viewModel.isLoading).diySurface()
                        }
                    }
                    .padding(16).padding(.bottom, AppSpacing.navBottom)
                }
                .refreshable { await viewModel.loadDesigns() }
            }
        }
        .foregroundStyle(Color.accentLight)
        .background(Color.bgPrimary)
        .toolbar(.hidden, for: .navigationBar)
        .task { if viewModel.designs.isEmpty { await viewModel.loadDesigns() } }
        .navigationDestination(for: DiyDesign.self) { design in DiyDetailView(designId: design.id) }
    }

    private var workbench: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("东方珠作 · 手串设计室", systemImage: "sparkle")
                    .font(.caption.weight(.medium)).foregroundStyle(Color.accentLight)
                Spacer()
                Text("DIY").font(.caption.weight(.semibold)).tracking(3)
                    .foregroundStyle(Color.textSecondary)
            }
            Text("一颗一念\n串起你的心意")
                .font(AppTypography.title(30)).foregroundStyle(Color.textPrimary)
                .lineSpacing(6).fixedSize(horizontal: false, vertical: true)
            Text("挑选天然材质，在方寸之间，创造属于自己的搭配。")
                .font(.subheadline).foregroundStyle(Color.textSecondary).lineSpacing(4)
            DiyMiniBracelet(slots: slots(for: viewModel.designs.first), fallbackCount: 14)
                .frame(height: 222)
                .accessibilityLabel("手串搭配示意")
            HStack(spacing: 0) {
                journeyStep("01", "挑选材质")
                journeyStep("02", "自由搭配")
                journeyStep("03", "保存心意")
            }
            NavigationLink { DiyDesignView() } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("开始我的设计")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .font(.subheadline.weight(.semibold)).foregroundStyle(Color.white)
                .padding(.horizontal, 18).frame(minHeight: 52)
                .background(LinearGradient(colors: [.brandLight, .brandDefault], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(DiyPressButtonStyle())
            .padding(.top, 6)
        }
        .padding(20)
        .background(RadialGradient(colors: [Color(hex: "4C4434"), Color(hex: "2F2921"), Color.bgSecondary], center: .center, startRadius: 30, endRadius: 350))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay { RoundedRectangle(cornerRadius: 24).stroke(Color.borderStrong, lineWidth: 1) }
    }

    private func journeyStep(_ number: String, _ title: String) -> some View {
        HStack(spacing: 5) {
            Text(number).font(AppTypography.numeric(12)).foregroundStyle(Color.accentDefault)
            Text(title).font(.caption).foregroundStyle(Color.textSecondary)
        }.frame(maxWidth: .infinity)
    }

    private func quickItem(title: String, subtitle: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon).font(.title3).foregroundStyle(Color.accentLight)
                Spacer()
                Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(Color.textSecondary)
            }
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Color.textPrimary)
            Text(subtitle).font(.caption).foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(16).diySurface()
    }

    private var inspirationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("在这里，遇见灵感").font(AppTypography.title(22)).foregroundStyle(Color.textPrimary)
                Spacer()
                Text("\(viewModel.designs.count) 件作品").font(.caption).foregroundStyle(Color.textSecondary)
            }
            Text("从喜欢的作品出发，再加入一点自己的想法。")
                .font(.caption).foregroundStyle(Color.textSecondary)
            if viewModel.isLoading && viewModel.designs.isEmpty {
                ProgressView("正在寻找灵感").tint(Color.accentDefault)
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else if viewModel.designs.isEmpty && viewModel.errorMessage == nil {
                DFEmptyState(icon: "sparkles", title: "灵感即将相遇", subtitle: "保存并公开你的作品，让更多人发现你的搭配")
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(viewModel.designs) { design in
                        NavigationLink(value: design) { designCard(design) }.buttonStyle(DiyPressButtonStyle())
                    }
                }
            }
        }
    }

    private func designCard(_ design: DiyDesign) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            DiyMiniBracelet(slots: slots(for: design), fallbackCount: 0)
                .frame(height: 152)
                .background(RadialGradient(colors: [Color(hex: "4B4132"), Color(hex: "302920")], center: .center, startRadius: 0, endRadius: 130))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                Text(design.name).font(.subheadline.weight(.semibold)).foregroundStyle(Color.textPrimary).lineLimit(1)
                HStack {
                    Text("灵感作品").font(.caption).foregroundStyle(Color.textSecondary)
                    Spacer(minLength: 4)
                    Text(AppDateFormatter.moneyText(design.totalPrice)).font(AppTypography.numeric(14, weight: .semibold)).foregroundStyle(Color.accentLight)
                }
            }.padding(12)
        }
        .diySurface()
    }

    private func slots(for design: DiyDesign?) -> [DiyBeadSlot] { DiyDesignPreview.slots(from: design?.designData) }
}

struct DiyMiniBracelet: View {
    let slots: [DiyBeadSlot]
    let fallbackCount: Int

    private let fallbackColors = ["8F3B3B", "D8C797", "486D57", "315A82", "E6DED0"]

    var body: some View {
        GeometryReader { proxy in
            let count = slots.isEmpty ? fallbackCount : min(slots.count, 60)
            let physical = DiyPhysicalLayout(slots: slots)
            let radiusX = min(proxy.size.width * 0.32, 108)
            let radiusY = min(proxy.size.height * 0.34, 82)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)

            ZStack {
                Ellipse()
                    .stroke(Color(hex: "D8C797").opacity(0.55), lineWidth: 2)
                    .frame(width: radiusX * 2, height: radiusY * 2)

                ForEach(0..<count, id: \.self) { index in
                    let slot = slots.indices.contains(index) ? slots[index] : nil
                    let angle = slots.isEmpty ? -Double.pi / 2 + Double(index) / Double(max(count, 1)) * Double.pi * 2 : physical.angles[index]
                    let size = slots.isEmpty ? CGFloat(20) : CGFloat((slot?.diameterMm ?? 10) / physical.radius) * radiusX
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


// Shared DIY surfaces keep the native app's warm palette and respect Reduce Motion.
struct DiyPressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.55)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

extension View {
    func diySurface(highlighted: Bool = false) -> some View {
        background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 20))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay { RoundedRectangle(cornerRadius: 20).stroke(highlighted ? Color.accentDefault.opacity(0.5) : Color.borderDefault, lineWidth: 1) }
    }
}

struct DiyPreviewModePicker: View {
    @Binding var show3D: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            mode("2D 搭配", icon: "circle.dotted", is3D: false)
            mode("3D 环视", icon: "cube.transparent", is3D: true)
        }
        .padding(4)
        .background(Color.bgPrimary.opacity(0.6), in: Capsule())
    }

    private func mode(_ title: String, icon: String, is3D: Bool) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { show3D = is3D }
        } label: {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(show3D == is3D ? Color.accentLight : Color.textSecondary)
                .background(show3D == is3D ? Color.bgElevated : Color.clear, in: Capsule())
        }
        .buttonStyle(DiyPressButtonStyle())
        .accessibilityAddTraits(show3D == is3D ? .isSelected : [])
    }
}

enum DiyDesignPreview {
    static func slots(from raw: String?) -> [DiyBeadSlot] {
        guard let raw, let data = raw.data(using: .utf8),
              let document = try? JSONDecoder().decode(DiyDesignDocument.self, from: data) else { return [] }
        return document.beads.sorted { $0.position < $1.position }
    }
}
