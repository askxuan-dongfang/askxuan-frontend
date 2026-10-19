import SwiftUI
struct GrowthProviderView: View {
 @Environment(\.scenePhase) private var phase
    @State private var policies: [GrowthPolicy] = []
    @State private var bills: [GrowthBill] = []
    @State private var error: String?
    @State private var busy = false
    var body: some View {
        List {
 Section { NavigationLink(L10n.text("成长规则与历史版本")) { GrowthRulesView(provider: true) } }
            Section { Text(L10n.text("平台补贴不改变已确认的服务结算规则。个人成长账户与工作身份分开。")) }
            if let error { Section { Text(L10n.lookup(error)); Button(L10n.text("重试")) { Task { await load() } }.disabled(busy) } }
            if busy { ProgressView() }
            Section(L10n.text("参与项目")) {
                if policies.isEmpty && !busy { Text(L10n.text("暂无待确认的项目")) }
                ForEach(policies) { p in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.lookup(p.title)).font(.headline)
                        Text(p.itemId).font(.caption).foregroundStyle(.secondary)
                        Text(L10n.lookup(p.enabled ? L10n.text("平台已启用") : L10n.text("平台未启用")))
                        Button(L10n.lookup(p.consent ? L10n.text("停止后续参与") : L10n.text("同意参与"))) { Task { await consent(p) } }.disabled(busy)
                    }.padding(.vertical, 5)
                }
            }
            Section(L10n.text("优惠订单账单")) {
                if bills.isEmpty && !busy { Text(L10n.text("暂无优惠订单")) }
                ForEach(bills) { b in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(b.orderNo).font(.headline)
                        LabeledContent(L10n.text("合同金额"), value: "¥"+GrowthAPI.money(b.contractGrossCents))
                        LabeledContent(L10n.text("用户实付"), value: "¥"+GrowthAPI.money(b.customerPaidCents))
                        LabeledContent(L10n.text("平台补贴"), value: "¥"+GrowthAPI.money(b.platformSubsidyCents))
                        Text(L10n.lookup(b.status == "refunded" ? L10n.text("已退款") : L10n.text("已支付"))).foregroundStyle(.secondary)
                    }.padding(.vertical, 5)
                }
            }
        }.scrollContentBackground(.hidden).background(Color.bgPrimary).navigationTitle(L10n.text("成长优惠参与")).task(id: phase) { guard phase == .active else { return }; while !Task.isCancelled { await load(); do { try await Task.sleep(for: .seconds(15)) } catch { return } } }.refreshable { await load() }
    }
    @MainActor private func load() async {
        busy = true; error = nil; defer { busy = false }
        do {
            async let p: [GrowthPolicy] = GrowthAPI.request("provider/policies?ownerType=master")
            async let b: [GrowthBill] = GrowthAPI.request("provider/bills?ownerType=master")
            let result = try await (p,b); guard !Task.isCancelled else { return }; policies = result.0; bills = result.1
        } catch { self.error = error.localizedDescription }
    }
    @MainActor private func consent(_ p: GrowthPolicy) async {
        guard !busy else { return }; busy = true; error = nil
        do { let _: GrowthAck = try await GrowthAPI.request("provider/consent?ownerType=master", body: ["itemType":p.itemType,"itemId":p.itemId,"revision":p.revision,"consent":!p.consent]); await load() }
        catch { self.error = error.localizedDescription; busy = false }
    }
}

// Shared immutable customer receipt. Original order fields retain their gross meaning.
struct GrowthOrderPriceView: View {
    let kind: String
    let number: String
    @State private var quote: GrowthPriceQuote?
    var body: some View {
        Group {
            if let q = quote, q.discountCents > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.lookup(q.status == "refunded" ? "已退实付" : "实付") + " ¥" + GrowthAPI.money(q.payableCents)).font(.headline)
                    Text(L10n.text("优惠") + " ¥" + GrowthAPI.money(q.discountCents)).font(.caption)
                    Text(L10n.text("按支付时确认的优惠结算，退款以实付金额为准。")).font(.caption).foregroundStyle(.secondary)
                }
            }
        }.task(id: kind + ":" + number) {
            quote = nil
            var query = URLComponents()
            query.queryItems = [URLQueryItem(name: "orderType", value: kind), URLQueryItem(name: "orderNo", value: number)]
            do {
                let result: GrowthPriceQuote = try await GrowthAPI.request("order?" + (query.percentEncodedQuery ?? ""))
                guard !Task.isCancelled else { return }; quote = result
            } catch { /* A missing receipt does not change the original order amount. */ }
        }
    }
}
