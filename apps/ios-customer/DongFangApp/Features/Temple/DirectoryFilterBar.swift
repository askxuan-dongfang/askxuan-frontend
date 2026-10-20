import SwiftUI

struct DirectoryRegion: Decodable, Identifiable { let code: String; let name: String; var id: String { code } }
struct DirectoryTag: Decodable, Identifiable { let code: String; let group: String; let name: String; let value: String; let beliefCode: String?; var id: String { code } }
struct DirectoryItems<T: Decodable>: Decodable { let list: [T] }

struct DirectorySearchCatalog {
    var beliefs: [BeliefFilterOption] = []
    var tags: [DirectoryTag] = []
    var services: [ServiceFilterOption] = []
    var regions: [DirectoryRegion] = []
}

/// Search normalization never changes saved names or other business values.
enum DirectorySearch {
    static func normalize(_ value: String) -> String {
        let compatible = value.precomposedStringWithCompatibilityMapping
        return (compatible.applyingTransform(StringTransform("Traditional-Simplified"), reverse: false) ?? compatible)
            .lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func tokens(_ query: String) -> [String] {
        normalize(query).split(whereSeparator: \.isWhitespace).map(String.init)
    }

    static func matches(_ query: String, fields: [String]) -> Bool {
        let words = tokens(query)
        guard !words.isEmpty else { return true }
        let normalized = fields.map(normalize)
        return words.allSatisfy { word in normalized.contains { $0.contains(word) } }
    }

    static func fields(temple: Temple, catalog: DirectorySearchCatalog) -> [String] {
        var fields = [temple.name, temple.region, temple.address, temple.type, temple.sect]
        fields += labels(belief: temple.beliefCode, region: temple.regionCode, traditions: temple.traditionCodes, catalog: catalog)
        fields += temple.serviceTags ?? []
        fields += (temple.serviceCodes ?? []).compactMap { code in catalog.services.first { $0.code == code }?.name }
        return fields
    }

    static func fields(master: Master, catalog: DirectorySearchCatalog) -> [String] {
        var fields = [master.dharmaName, master.layName, master.templeName, master.position, master.type, master.sect] + master.specialties
        fields += labels(belief: master.beliefCode, region: master.regionCode, traditions: master.traditionCodes, catalog: catalog)
        fields += (master.serviceTags ?? [])
            .filter { $0.status == nil || $0.status == "" || $0.status == "enabled" }
            .compactMap { tag in catalog.services.first { $0.code == tag.serviceCode }?.name }
        return fields
    }

    private static func labels(belief: String, region: String?, traditions: [String]?, catalog: DirectorySearchCatalog) -> [String] {
        let names = [catalog.beliefs.first { $0.code == belief }?.name ?? "", catalog.regions.first { $0.code == region }?.name ?? ""]
        return names + (traditions ?? []).flatMap { code in
            guard let tag = catalog.tags.first(where: { $0.group == "tradition" && $0.code == code }) else { return [String]() }
            return [tag.name, tag.value]
        }
    }
}

enum DirectoryLoadError: LocalizedError {
    case incomplete
    var errorDescription: String? { "目录数据不完整，请重试" }
}

@MainActor
private final class DirectoryCatalog: ObservableObject {
    @Published var regions: [DirectoryRegion] = []
    @Published var traditions: [DirectoryTag] = []
    @Published var error: String?
    func load() async {
        do {
            async let regions: DirectoryItems<DirectoryRegion> = APIClient.shared.request(.directoryRegions)
            async let tags: DirectoryItems<DirectoryTag> = APIClient.shared.request(.directoryTags)
            let result = try await (regions, tags)
            guard !Task.isCancelled else { return }
            self.regions = result.0.list
            self.traditions = result.1.list.filter { $0.group == "tradition" }
            error = nil
        } catch { if !Task.isCancelled { self.error = "筛选目录加载失败" } }
    }
}

/// One anchored filter row: religion scrolls, while the region trigger remains at the trailing edge.
struct DirectoryFilterBar: View {
    let beliefs: [BeliefFilterOption]
    @Binding var belief: String
    @Binding var region: String
    @Binding var tradition: String
    @Binding var isPresented: Bool
    @StateObject private var catalog = DirectoryCatalog()
    private enum Panel { case traditions, regions }
    @State private var panel: Panel?
    @FocusState private var focusedTrigger: String?
    @AccessibilityFocusState private var accessibleTrigger: String?

    private var selectedBelief: BeliefFilterOption? { beliefs.first { !$0.code.isEmpty && $0.code == belief } }
    private var traditions: [DirectoryTag] { catalog.traditions.filter { $0.beliefCode == belief } }
    private var selectedRegion: DirectoryRegion? { catalog.regions.first { $0.code == region } }
    private var regionTitle: String {
        guard let selectedRegion else { return "地区" }
        for suffix in ["特别行政区", "特別行政區", "省", "市"] where selectedRegion.name.hasSuffix(suffix) {
            return String(selectedRegion.name.dropLast(suffix.count))
        }
        return selectedRegion.name
    }

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(beliefs) { item in
                        option(beliefTitle(item), code: item.code, selected: belief) {
                            let wasOpen = isPresented && panel == .traditions && belief == item.code
                            if belief != item.code { tradition = "" }
                            belief = item.code
                            panel = !item.code.isEmpty && !wasOpen ? .traditions : nil
                            isPresented = panel != nil
                        }
                        .focused($focusedTrigger, equals: item.code)
                        .accessibilityFocused($accessibleTrigger, equals: item.code)
                        .accessibilityIdentifier("directory-belief-" + item.code)
                        .accessibilityValue(L10n.text(isPresented && panel == .traditions && belief == item.code ? "已展开" : "已收起"))
                    }
                }.padding(.leading, 16).padding(.trailing, 8)
            }
            .accessibilityElement(children: .contain).accessibilityLabel(L10n.text("信仰分类"))
            Button {
                withoutAnimation {
                    let wasOpen = isPresented && panel == .regions
                    panel = wasOpen ? nil : .regions
                    isPresented = !wasOpen
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse").font(.system(size: 14))
                    Text(L10n.lookup(regionTitle)).font(.subheadline).lineLimit(1)
                }
                .foregroundStyle(region.isEmpty ? Color.textSecondary : Color.brandDefault)
                .frame(width: 88, height: 52)
                .background(Color.bgPrimary)
                .overlay(alignment: .leading) { Rectangle().fill(Color.borderDivider).frame(width: 1, height: 24) }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focused($focusedTrigger, equals: "region")
            .accessibilityFocused($accessibleTrigger, equals: "region")
            .accessibilityLabel(L10n.text("地区筛选"))
            .accessibilityValue(L10n.lookup(selectedRegion?.name ?? "全部地区"))
            .accessibilityIdentifier("directory-region-trigger")
        }
        .frame(height: 52).background(Color.bgPrimary)
        .overlay(alignment: .topTrailing) {
            if isPresented {
                Group {
                    if panel == .traditions, let selected = selectedBelief { traditionPanel(selected) }
                    if panel == .regions { regionPanel }
                }
                .padding(.horizontal, 12).offset(y: 56)
            }
        }
        .transaction { $0.animation = nil; $0.disablesAnimations = true }
        .onKeyPress(.escape) {
            guard isPresented else { return .ignored }
            closePanel()
            return .handled
        }
        .onChange(of: isPresented) { _, value in if !value { restoreFocus(); panel = nil } }
        .onChange(of: belief) { _, value in if value.isEmpty && panel == .traditions { closePanel() } }
        .task { await catalog.load() }
    }

    private func beliefTitle(_ item: BeliefFilterOption) -> String {
        guard item.code == belief, let selected = traditions.first(where: { $0.code == tradition }) else { return item.name }
        return L10n.lookup(item.name) + " · " + L10n.lookup(selected.name)
    }

    private func restoreFocus() {
        let target = panel == .regions ? "region" : belief
        focusedTrigger = target
        accessibleTrigger = target
    }

    private func closePanel() {
        restoreFocus()
        withoutAnimation { isPresented = false }
    }

    private func traditionPanel(_ selected: BeliefFilterOption) -> some View {
        ScrollView(showsIndicators: true) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                option(L10n.text("全部") + L10n.lookup(selected.name), code: "", selected: tradition) {
                    tradition = ""; closePanel()
                }
                ForEach(traditions) { item in
                    option(item.name, code: item.code, selected: tradition) {
                        tradition = item.code; closePanel()
                    }.accessibilityIdentifier("directory-tradition-" + item.code)
                }
                retryOption
            }.padding(8)
        }
        .frame(height: min(240, CGFloat((traditions.count + 2) / 2) * 52 + (catalog.error == nil ? 8 : 52)))
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.16), radius: 14, y: 5)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.text("宗派与信俗筛选"))
        .accessibilityIdentifier("directory-traditions")
        .accessibilityAction(.escape) { closePanel() }
    }

    private var regionPanel: some View {
        ScrollView(showsIndicators: true) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                option("全部地区", code: "", selected: region) { region = ""; closePanel() }
                ForEach(catalog.regions) { item in
                    option(item.name, code: item.code, selected: region) { region = item.code; closePanel() }
                        .accessibilityIdentifier("directory-region-" + item.code)
                }
                if !region.isEmpty && selectedRegion == nil {
                    option("清除地区筛选", code: region, selected: region) { region = ""; closePanel() }
                }
                retryOption
            }.padding(8)
        }
        .frame(maxWidth: 360)
        .frame(height: min(280, CGFloat((catalog.regions.count + 2) / 2) * 52 + (catalog.error == nil ? 8 : 52)))
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.16), radius: 14, y: 5)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.text("地区筛选"))
        .accessibilityIdentifier("directory-regions")
        .accessibilityAction(.escape) { closePanel() }
    }

    @ViewBuilder private var retryOption: some View {
        if let error = catalog.error {
            Button(L10n.lookup(error) + L10n.text("，重试")) { Task { await catalog.load() } }
                .font(.caption).frame(minHeight: 44).buttonStyle(.plain)
        }
    }

    private func withoutAnimation(_ action: () -> Void) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction, action)
    }

    private func option(_ title: String, code: String, selected: String, action: @escaping () -> Void) -> some View {
        Button { withoutAnimation(action) } label: {
            Text(L10n.lookup(title)).font(.subheadline).padding(.horizontal, 14).frame(minHeight: 44).fixedSize(horizontal: false, vertical: true)
                .background(code == selected ? Color.brandDefault : Color.bgSecondary, in: Capsule())
                .foregroundStyle(code == selected ? .white : Color.textSecondary)
        }.buttonStyle(.plain)
            .accessibilityAddTraits(code == selected ? [.isSelected] : [])
    }
}

extension View {
    /// Outside taps dismiss the floating filters without activating a covered result or moving layout.
    func directoryFilterDismissArea(isPresented: Binding<Bool>) -> some View {
        overlay {
            if isPresented.wrappedValue {
                Color.clear.contentShape(Rectangle())
                    .onTapGesture {
                        var transaction = Transaction(animation: nil)
                        transaction.disablesAnimations = true
                        withTransaction(transaction) { isPresented.wrappedValue = false }
                    }
                    .accessibilityHidden(true)
            }
        }
    }
}
