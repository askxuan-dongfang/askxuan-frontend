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
    @StateObject private var catalog = DirectoryCatalog()
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(beliefs) { item in
                        option(item.name, code: item.code, selected: belief) {
                            if belief != item.code { tradition = "" }
                            belief = item.code
                        }.accessibilityIdentifier("directory-belief-" + item.code)
                    }
                }.padding(.horizontal, 16)
            }.accessibilityElement(children: .contain).accessibilityLabel(L10n.text("信仰分类"))
            if let selected = beliefs.first(where: { !$0.code.isEmpty && $0.code == belief }) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        option(L10n.text("全部") + L10n.lookup(selected.name), code: "", selected: tradition) { tradition = "" }
                        ForEach(catalog.traditions.filter { $0.beliefCode == belief }) { item in
                            option(item.name, code: item.code, selected: tradition) { tradition = item.code }
                                .accessibilityIdentifier("directory-tradition-" + item.code)
                        }
                    }.padding(.horizontal, 16)
                }.padding(.vertical, 8).background(Color.bgSecondary)
                    .accessibilityElement(children: .contain).accessibilityLabel(L10n.text("宗派与信俗筛选"))
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    option("全部地区", code: "", selected: region) { region = "" }
                    ForEach(catalog.regions) { item in
                        option(item.name, code: item.code, selected: region) { region = item.code }
                    }
                }.padding(.horizontal, 16)
            }.accessibilityElement(children: .contain).accessibilityLabel(L10n.text("地区筛选"))
            HStack {
                Spacer()
                if !region.isEmpty {
                    Button(L10n.text("清除")) { AppMotion.perform { region = "" } }.font(.subheadline).frame(minHeight: 44)
                }
                if let error = catalog.error { Button(L10n.lookup(error + L10n.text("，重试"))) { Task { await catalog.load() } }.font(.caption) }
            }.padding(.horizontal, 16)
        }.padding(.vertical, 4).background(Color.bgPrimary)
            .task { await catalog.load() }
    }
    private func option(_ title: String, code: String, selected: String, action: @escaping () -> Void) -> some View {
        Button { AppMotion.perform { action() } } label: {
            Text(L10n.lookup(title)).font(.subheadline).padding(.horizontal, 14).frame(minHeight: 44)
                .background(code == selected ? Color.brandDefault : Color.bgSecondary, in: Capsule())
                .foregroundStyle(code == selected ? .white : Color.textSecondary)
        }.buttonStyle(CardPressButtonStyle())
            .accessibilityAddTraits(code == selected ? [.isSelected] : [])
    }
}
