import SwiftUI

/// Public service catalog; authentication is requested at the booking action.
struct ServicesView: View {
    @State private var services: [ServiceCatalogItem] = []
    @State private var loading = false
    @State private var error: String?
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 16)], spacing: 16) {
                ForEach(services) { item in
                    if let type = ServiceType.from(serviceCode: item.code) {
                        NavigationLink {
                            if type == .diy { DiyBraceletView() }
                            else { ServiceContainerView(serviceType: type) }
                        } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                Image(systemName: type.iconName).font(.title2).foregroundStyle(Color.accentDefault)
                                Text(L10n.lookup(item.name)).font(AppTypography.navigation).foregroundStyle(Color.textPrimary)
                                Text(L10n.lookup(item.priceRange)).font(.caption).foregroundStyle(Color.textSecondary)
                            }.frame(maxWidth: .infinity, minHeight: 108, alignment: .leading).padding(16).appCardSurface()
                        }.buttonStyle(CardPressButtonStyle())
                    }
                }
            }.padding(16)
            if loading { ProgressView(L10n.text("正在加载服务")) }
            if let error { ContentUnavailableView { Label(L10n.text("服务暂不可用"), systemImage: "wifi.exclamationmark") } description: { Text(L10n.lookup(error)) } actions: { Button(L10n.text("重试")) { Task { await load() } } } }
        }.background(Color.bgPrimary).navigationTitle(L10n.text("预约服务")).navigationBarTitleDisplayMode(.inline)
            .task { await load() }.refreshable { await load() }
    }
    @MainActor private func load() async {
        loading = true; defer { loading = false }
        do { let result: ServiceCatalogResponse = try await APIClient.shared.request(.serviceTypes); guard !Task.isCancelled else { return }; services = result.list; error = nil }
        catch { if !Task.isCancelled { self.error = error.localizedDescription } }
    }
}
