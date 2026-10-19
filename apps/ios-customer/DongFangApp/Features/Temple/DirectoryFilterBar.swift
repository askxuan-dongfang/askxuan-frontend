import SwiftUI

struct DirectoryRegion: Decodable, Identifiable { let code: String; let name: String; var id: String { code } }
struct DirectoryTag: Decodable, Identifiable { let code: String; let group: String; let name: String; let value: String; let beliefCode: String?; var id: String { code } }
private struct DirectoryItems<T: Decodable>: Decodable { let list: [T] }

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

/// The same server-owned regions and tradition codes used by both H5 directories.
struct DirectoryFilterBar: View {
    let beliefs: [BeliefFilterOption]
    @Binding var belief: String
    @Binding var region: String
    @Binding var tradition: String
    @Binding var isTraditionPresented: Bool
    @StateObject private var catalog = DirectoryCatalog()
    @FocusState private var focusedBelief: String?
    @AccessibilityFocusState private var accessibleBelief: String?

    private var selectedBelief: BeliefFilterOption? { beliefs.first { !$0.code.isEmpty && $0.code == belief } }
    private var traditions: [DirectoryTag] { catalog.traditions.filter { $0.beliefCode == belief } }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(beliefs) { item in
                        option(beliefTitle(item), code: item.code, selected: belief) {
                            let wasOpen = isTraditionPresented && belief == item.code
                            if belief != item.code { tradition = "" }
                            belief = item.code
                            isTraditionPresented = !item.code.isEmpty && !wasOpen
                        }
                        .focused($focusedBelief, equals: item.code)
                        .accessibilityFocused($accessibleBelief, equals: item.code)
                        .accessibilityIdentifier("directory-belief-" + item.code)
                        .accessibilityValue(L10n.text(isTraditionPresented && belief == item.code ? "已展开" : "已收起"))
                    }
                }.padding(.horizontal, 16)
            }.accessibilityElement(children: .contain).accessibilityLabel(L10n.text("信仰分类"))
            Group {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    option("全部地区", code: "", selected: region) { region = "" }
                    ForEach(catalog.regions) { item in
                        option(item.name, code: item.code, selected: region) { region = item.code }
                    }
                }.padding(.horizontal, 16)
            }.accessibilityElement(children: .contain).accessibilityLabel(L10n.text("地区筛选")).accessibilityIdentifier("directory-regions")
            HStack {
                Spacer()
                if !region.isEmpty {
                    Button(L10n.text("清除")) { AppMotion.perform { region = "" } }.font(.subheadline).frame(minHeight: 44)
                }
                if let error = catalog.error { Button(L10n.lookup(error + L10n.text("，重试"))) { Task { await catalog.load() } }.font(.caption) }
            }.padding(.horizontal, 16)
            }
        }.padding(.vertical, 4).background(Color.bgPrimary)
            .overlay(alignment: .top) {
                GeometryReader { geometry in
                    if isTraditionPresented, let selected = selectedBelief {
                        ZStack(alignment: .top) {
                            // The first row stays interactive; the rest of the bar, including its gaps,
                            // dismisses the overlay before any underlying region action can run.
                            Color.clear.contentShape(Rectangle())
                                .frame(height: max(0, geometry.size.height - 48)).offset(y: 48)
                                .onTapGesture { closeTraditions() }.accessibilityHidden(true)
                            traditionPanel(selected).padding(.horizontal, 12).padding(.top, 52)
                        }
                    }
                }
            }
            .transaction { $0.animation = nil; $0.disablesAnimations = true }
            .onKeyPress(.escape) {
                guard isTraditionPresented else { return .ignored }
                closeTraditions()
                return .handled
            }
            .onChange(of: belief) { _, value in if value.isEmpty { isTraditionPresented = false } }
            .task { await catalog.load() }
    }

    private func beliefTitle(_ item: BeliefFilterOption) -> String {
        guard item.code == belief, let selected = traditions.first(where: { $0.code == tradition }) else { return item.name }
        return L10n.lookup(item.name) + " · " + L10n.lookup(selected.name)
    }

    private func closeTraditions() {
        isTraditionPresented = false
        focusedBelief = belief
        accessibleBelief = belief
    }

    private func traditionPanel(_ selected: BeliefFilterOption) -> some View {
        ScrollView(showsIndicators: true) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                option(L10n.text("全部") + L10n.lookup(selected.name), code: "", selected: tradition) {
                    tradition = ""; closeTraditions()
                }
                ForEach(traditions) { item in
                    option(item.name, code: item.code, selected: tradition) {
                        tradition = item.code; closeTraditions()
                    }.accessibilityIdentifier("directory-tradition-" + item.code)
                }
            }.padding(8)
        }
        .frame(height: min(240, CGFloat((traditions.count + 2) / 2) * 52 + 8))
        .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.16), radius: 14, y: 5)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.text("宗派与信俗筛选"))
        .accessibilityIdentifier("directory-traditions")
        .accessibilityAction(.escape) { closeTraditions() }
    }

    private func option(_ title: String, code: String, selected: String, action: @escaping () -> Void) -> some View {
        Button {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction, action)
        } label: {
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
