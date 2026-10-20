import SwiftUI

struct GrowthCatalogPriceView: View {
    let items: [GrowthCatalogItem]
    var experience = false
    @ObservedObject private var auth = AuthStore.shared
    @Environment(\.scenePhase) private var phase
    @State private var preview: GrowthCatalogPreview?
    @State private var previewKey = ""
    @State private var validUntil = Date.distantPast
    @State private var error: String?
    @State private var retry = 0
    @State private var showLogin = false
    private var key: String { "\(auth.sessionID):" + items.map { "\($0.itemType):\($0.itemId):\($0.quantity):\($0.spec ?? "")" }.joined(separator: "|") }
    var body: some View {
        Group {
            if items.isEmpty { EmptyView() }
            else if experience { Text(L10n.text("体验商品不参与等级优惠和消费成长")).font(.caption).foregroundStyle(.secondary) }
            else if !auth.isLoggedIn { VStack(alignment: .leading) { Button(L10n.text("登录查看我的等级价")) { showLogin = true }.frame(minHeight: 44); NavigationLink(L10n.text("查看当前规则")) { GrowthView(initialTab: "rules", publicRead: true) }.frame(minHeight: 44) } }
            else {
                TimelineView(.periodic(from: .now, by: 1)) { time in
                    VStack(alignment: .leading, spacing: 8) {
                        if let p = preview, previewKey == key, time.date < validUntil {
                            HStack { Text("L\(p.snapshot.level.code) " + L10n.lookup(p.snapshot.level.name)); Spacer(minLength: 10); Text(L10n.lookup(p.levelPrice == nil ? "当前价格" : "等级价") + " ¥" + GrowthAPI.money(p.levelPrice?.payableCents ?? p.grossCents)).bold() }.foregroundStyle(Color.brandDefault)
                            Text(L10n.lookup(p.reason))
                            if p.snapshot.selected.kind == "coupon" { Text(L10n.text("礼券可享更低价") + " ¥" + GrowthAPI.money(p.snapshot.selected.payableCents)) }
                            Text(L10n.text("所选项目合计，不含运费和随喜；不锁定库存或优惠，以收银台确认为准。")).font(.caption).foregroundStyle(.secondary)
                        } else if let error { Text(L10n.lookup(error)); Button(L10n.text("重试")) { retry += 1 }.frame(minHeight: 44) }
                        else { Text(L10n.lookup(preview == nil ? "正在读取等级价…" : "价格已过期，正在更新")).foregroundStyle(.secondary) }
                    }.font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).padding(14).background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }.task(id: key + ":\(phase):\(retry)") {
            guard auth.isLoggedIn, phase == .active, !experience, !items.isEmpty else { preview = nil; return }
            let captured = key
            if previewKey != captured { preview = nil; error = nil }
            while !Task.isCancelled {
                do {
                    let body = items.map { item -> [String: Any] in var result: [String: Any] = ["itemType":item.itemType,"itemId":item.itemId,"quantity":item.quantity]; if let spec = item.spec { result["spec"] = spec }; return result }
                    let p: GrowthCatalogPreview = try await GrowthAPI.request("catalog/preview", body: ["items":body])
                    guard !Task.isCancelled, captured == key else { return }
                    guard p.valid else { throw APIError.serverError(40943, L10n.text("等级价暂时无法读取，请重试")) }
                    preview = p; previewKey = captured; validUntil = Date().addingTimeInterval(Double(p.expiresAt-p.serverTime)); error = nil
                } catch is CancellationError { return } catch { if !Task.isCancelled, captured == key { preview = nil; self.error = error.localizedDescription } }
                do { try await Task.sleep(for: .seconds(15)) } catch { return }
            }
        }.sheet(isPresented: $showLogin) { NavigationStack { LoginView() }.appVisualDefaults() }
    }
}
