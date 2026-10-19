import SwiftUI

struct DirectoryRegion: Decodable, Identifiable { let code: String; let name: String; var id: String { code } }
struct DirectoryTag: Decodable, Identifiable { let code: String; let group: String; let name: String; let value: String; var id: String { code } }
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
    @Binding var region: String
    @Binding var tradition: String
    @StateObject private var catalog = DirectoryCatalog()
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    option("全部地区", code: "", selected: region) { region = "" }
                    ForEach(catalog.regions) { item in
                        option(item.name, code: item.code, selected: region) { region = item.code }
                    }
                }.padding(.horizontal, 16)
            }.accessibilityElement(children: .contain).accessibilityLabel(L10n.text("地区筛选"))
            HStack {
                Menu {
                    Button(L10n.text("全部宗派 / 信俗")) { tradition = "" }
                    ForEach(catalog.traditions) { item in Button(L10n.lookup(item.name)) { tradition = item.code } }
                } label: {
                    Label(L10n.lookup(catalog.traditions.first { $0.code == tradition }?.name ?? L10n.text("宗派 / 信俗")), systemImage: "line.3.horizontal.decrease")
                        .font(.subheadline).frame(minHeight: 40)
                }.accessibilityLabel(L10n.text("宗派与信俗筛选"))
                Spacer()
                if !region.isEmpty || !tradition.isEmpty {
                    Button(L10n.text("清除")) { AppMotion.perform { region = ""; tradition = "" } }.font(.subheadline).frame(minHeight: 40)
                }
                if let error = catalog.error { Button(L10n.lookup(error + L10n.text("，重试"))) { Task { await catalog.load() } }.font(.caption) }
            }.padding(.horizontal, 16)
        }.padding(.vertical, 4).background(Color.bgPrimary)
            .task { await catalog.load() }
    }
    private func option(_ title: String, code: String, selected: String, action: @escaping () -> Void) -> some View {
        Button { AppMotion.perform { action() } } label: {
            Text(L10n.lookup(title)).font(.subheadline).padding(.horizontal, 14).frame(minHeight: 40)
                .background(code == selected ? Color.brandDefault : Color.bgSecondary, in: Capsule())
                .foregroundStyle(code == selected ? .white : Color.textSecondary)
        }.buttonStyle(CardPressButtonStyle())
            .accessibilityAddTraits(code == selected ? [.isSelected] : [])
    }
}
