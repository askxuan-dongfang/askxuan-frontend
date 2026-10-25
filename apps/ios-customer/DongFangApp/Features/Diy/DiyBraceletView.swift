import SwiftUI

struct DiyBraceletView: View {
    enum InitialSection { case workbench, plaza }

    @StateObject private var viewModel = DiyViewModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let initialSection: InitialSection

    init(initialSection: InitialSection = .workbench) { self.initialSection = initialSection }

    var body: some View {
        VStack(spacing: 0) {
            DFTopNavBar(initialSection == .plaza ? "设计广场" : "东方珠作", showsBackButton: true) { EmptyView() } trailing: {
                NavigationLink { DiyMyDesignsView().requireAuth(title: L10n.text("登录后查看我的设计"), subtitle: L10n.text("登录后同步和管理你的手串设计")) } label: {
                    Image(systemName: "square.stack").frame(width: 44, height: 44)
                }
                .accessibilityLabel(L10n.text("我的设计"))
            }
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        if initialSection == .workbench {
                            workbench
                            HStack(spacing: 12) {
                                NavigationLink { DiyMyDesignsView().requireAuth(title: L10n.text("登录后查看我的设计"), subtitle: L10n.text("登录后同步和管理你的手串设计")) } label: {
                                    quickItem(title: L10n.text("我的设计"), subtitle: L10n.text("保存每一次灵感"), icon: "square.stack")
                                }
                                Button {
                                    AppMotion.perform(AppMotion.reveal) { proxy.scrollTo("inspiration", anchor: .top) }
                                } label: {
                                    quickItem(title: L10n.text("灵感广场"), subtitle: L10n.text("发现心仪的搭配"), icon: "sparkles")
                                }
                            }
                            .buttonStyle(DiyPressButtonStyle())
                        }
                        inspirationSection.id("inspiration")
                        if let error = viewModel.errorMessage {
                            VStack(spacing: 10) {
                                Label(L10n.lookup(error), systemImage: "wifi.exclamationmark")
                                    .font(.caption).foregroundStyle(Color.textSecondary)
                                Button(L10n.text("重新加载")) { Task { await viewModel.loadDesigns() } }
                                    .font(.subheadline).frame(minHeight: 44)
                            }
                            .padding(16).frame(maxWidth: .infinity).diySurface()
                        }
                        if viewModel.hasMoreDesigns {
                            Button { Task { await viewModel.loadDesigns(append: true) } } label: {
                                HStack(spacing: 8) {
                                    if viewModel.isLoading { ProgressView().tint(Color.accentDefault) }
                                    Text(L10n.lookup(viewModel.isLoading ? L10n.text("加载中…") : L10n.text("发现更多作品")))
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
    }

    private var workbench: some View {
        DiyStudioIntro(identifier: "diy-home-intro")
    }

    private func quickItem(title: String, subtitle: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon).font(.title3).foregroundStyle(Color.accentLight)
                Spacer()
                Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(Color.textSecondary)
            }
            Text(L10n.lookup(title)).font(.subheadline.weight(.semibold)).foregroundStyle(Color.textPrimary)
            Text(L10n.lookup(subtitle)).font(.caption).foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(16).diySurface()
    }

    private var inspirationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.text("在这里，遇见灵感")).font(AppTypography.title(22)).foregroundStyle(Color.textPrimary)
                Spacer()
                Text(L10n.text("\(viewModel.designs.count) 件作品")).font(.caption).foregroundStyle(Color.textSecondary)
            }
            if viewModel.isLoading && viewModel.designs.isEmpty {
                ProgressView(L10n.text("正在寻找灵感")).tint(Color.accentDefault)
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else if viewModel.designs.isEmpty && viewModel.errorMessage == nil {
                DFEmptyState(icon: "sparkles", title: L10n.text("灵感即将相遇"), subtitle: "")
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(viewModel.designs) { design in
                        NavigationLink { DiyDetailView(designId: design.id) } label: { designCard(design) }.buttonStyle(DiyPressButtonStyle()).accessibilityIdentifier("diy-gallery-design-\(design.id)")
                    }
                }
            }
        }
    }

    private func designCard(_ design: DiyDesign) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            DiyMiniBracelet(slots: slots(for: design), fallbackCount: 0)
                .frame(height: 152)
                .background(RadialGradient(colors: [Color.bgElevated, Color.bgTertiary], center: .center, startRadius: 0, endRadius: 130))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.lookup(design.name)).font(.subheadline.weight(.semibold)).foregroundStyle(Color.textPrimary).lineLimit(1)
                HStack {
                    Text(L10n.text("灵感作品")).font(.caption).foregroundStyle(Color.textSecondary)
                    Spacer(minLength: 4)
                    Text(L10n.lookup(AppDateFormatter.moneyText(design.totalPrice))).appNumericFont(14, weight: .semibold).foregroundStyle(Color.accentLight)
                }
            }.padding(12)
        }
        .diySurface()
    }

    private func slots(for design: DiyDesign?) -> [DiyBeadSlot] { DiyDesignPreview.slots(from: design?.designData) }
}

/// A fixed brand ornament keeps the discovery header independent of catalogue contents.
struct DiyStudioIntro: View {
    let identifier: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.text("一颗一念，串起心意"))
                    .font(AppTypography.title(22)).foregroundStyle(Color.textPrimary)
                NavigationLink { DiyDesignView() } label: {
                    Label(L10n.text("开始我的设计"), systemImage: "plus")
                        .accessibilityIdentifier("diy-start")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Color.white)
                        .padding(.horizontal, 16).frame(minHeight: 44)
                        .background(Color.brandDefault, in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(DiyPressButtonStyle())
            }.frame(maxWidth: .infinity, alignment: .leading)
            DiyIdentityOrnament().frame(width: 112, height: 112)
        }.padding(16).background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 16))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(identifier)
    }
}

struct DiyIdentityOrnament: View {
    var body: some View {
        GeometryReader { geometry in
            let edge = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = edge * 0.405
            ZStack {
                Circle().stroke(Color.accentDefault.opacity(0.32), lineWidth: 1)
                    .frame(width: radius * 2, height: radius * 2)
                    .position(center)
                ForEach(0..<15, id: \.self) { index in
                    let angle = -Double.pi / 2 + Double(index) * Double.pi * 2 / 15 - Double.pi / 15
                    let size = edge * (index == 6 ? 0.11 : 0.16)
                    let colors = index == 6 ? ["F5F1D7", "C6AD6B", "8A713C"] :
                        (index + 1).isMultiple(of: 3) ? ["FFFBDD", "E8DCB0", "CBBB83", "A1925E"] :
                        ["B4C5A3", "799771", "446A51", "2C4E3C"]
                    Circle()
                        .fill(RadialGradient(colors: colors.map { Color(hex: $0) }, center: .init(x: 0.3, y: 0.25), startRadius: 0, endRadius: size * 0.8))
                        .frame(width: size, height: size)
                        .shadow(color: .black.opacity(0.15), radius: 1.5, x: 1, y: 2)
                        .position(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
                }
                VStack(spacing: 5) {
                    Text(L10n.text("一珠")).font(AppTypography.title(18)).tracking(3)
                    Text(L10n.text("一心意")).font(AppTypography.title(9)).tracking(2)
                }.foregroundStyle(Color.accentDefault).position(center)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.text("一珠，一心意"))
        .accessibilityAddTraits(.isImage)
        .accessibilityIdentifier("diy-identity-ornament")
    }
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
                    DiyMaterialBead(name: slot?.materialName ?? "", category: slot?.subtype ?? "main_bead", size: size, isSelected: false, shape: slot?.shape ?? "round", colorHex: slot?.colorHex ?? fallbackColors[index % fallbackColors.count], textureKey: slot?.textureKey, finish: slot?.finish, translucency: slot?.translucency ?? 0, renderAssets: slot?.renderAssets, materialId: slot?.materialId ?? 0, materialType: slot?.materialType)
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
            .animation(reduceMotion ? nil : AppMotion.press, value: configuration.isPressed)
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
            AppMotion.perform { show3D = is3D }
        } label: {
            Label(L10n.lookup(title), systemImage: icon)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(show3D == is3D ? Color.accentLight : Color.textSecondary)
                .background(show3D == is3D ? Color.bgElevated : Color.clear, in: Capsule())
        }
        .buttonStyle(DiyPressButtonStyle())
        .accessibilityAddTraits(show3D == is3D ? .isSelected : [])
        .accessibilityIdentifier(is3D ? "diy-mode-3d" : "diy-mode-2d")
    }
}

enum DiyDesignPreview {
    static func slots(from raw: String?) -> [DiyBeadSlot] {
        guard let raw, let data = raw.data(using: .utf8),
              let document = try? JSONDecoder().decode(DiyDesignDocument.self, from: data) else { return [] }
        return document.beads.sorted { $0.position < $1.position }
    }
}
