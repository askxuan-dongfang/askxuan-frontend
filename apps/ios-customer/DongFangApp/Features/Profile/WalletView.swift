import SwiftUI
import UIKit

struct CustomerWallet: Decodable {
    struct Summary: Decodable { let paidCents: Int64; let refundedCents: Int64; let refundingCents: Int64 }
    struct Refund: Decodable, Identifiable { let id: Int64; let refundNo: String; let amountCents: Int64; let status: String; let reason: String; let createdAt: String }
    struct Entry: Decodable, Identifiable { let id: Int64; let paymentNo: String; let orderType: String; let orderNo: String; let amountCents: Int64; let channel: String; let status: String; let createdAt: String; let refunds: [Refund] }
    let summary: Summary
    let list: [Entry]
    let total: Int
    let page: Int
    let pageSize: Int
    let mode: String
}

struct WalletView: View {
 @State private var cashBalance: CashBalance?
    @EnvironmentObject private var auth: AuthStore
    @State private var mode = "channel"
    @State private var filter = "all"
    @State private var page = 1
    @State private var revision = 0
    @State private var data: CustomerWallet?
    @State private var error: String?
    private var requestKey: String { "\(auth.sessionID)-\(mode)-\(filter)-\(page)-\(revision)" }
    private func money(_ cents: Int64) -> String { (Decimal(cents) / 100).formatted(.currency(code: "CNY")) }
    private let kinds = ["booking":"预约服务", "consultation":"即时咨询", "shop_order":"商城购物", "diy_order":"DIY 手串", "ai_report":"AI 报告"]
    private let statuses = ["pending":"待支付", "success":"支付成功", "failed":"支付失败", "refunding":"退款中", "refunded":"已退款", "closed":"已关闭"]
    private let refunds = ["pending":"待处理", "processing":"退款处理中", "success":"退款完成", "failed":"退款失败"]
    var body: some View {
        List {
            Section { NavigationLink { CreatorWalletView().id(auth.sessionID) } label: { Label(L10n.text("创作收益与提现"), systemImage: "paintpalette") } }
            Section { NavigationLink { CashBalanceView() } label: { VStack(alignment: .leading, spacing: 8) { Label(L10n.lookup(cashBalance?.mode == "demo" ? L10n.text("测试余额（模拟）") : L10n.text("钱包余额")), systemImage: "wallet.bifold"); Text(L10n.lookup(cashBalance.map { "¥" + CashAPI.money($0.availableCents) } ?? "—")).font(.largeTitle.bold()).monospacedDigit(); Text(L10n.text("充值 · 余额流水 · 原路退款")).font(.caption).foregroundStyle(.secondary) } } }
            Section {
                Picker(L10n.text("账单渠道"), selection: $mode) { Text(L10n.text("真实消费")).tag("channel"); Text(L10n.text("演示账单")).tag("mock") }.pickerStyle(.segmented)
                VStack(alignment: .leading, spacing: 18) {
                    Label(L10n.lookup(mode == "mock" ? L10n.text("演示累计支付") : L10n.text("累计支付记录")), systemImage: "wallet.bifold")
                        .font(.subheadline).foregroundStyle(Color.textSecondary)
                    Text(L10n.lookup(data.map { money($0.summary.paidCents) } ?? "—")).font(.system(size: 34, weight: .semibold, design: .rounded)).monospacedDigit()
                    Divider()
                    HStack {
                        stat("已退款", data?.summary.refundedCents)
                        Spacer()
                        stat("退款处理中", data?.summary.refundingCents)
                    }
                }.padding(.vertical, 12)
                Text(L10n.lookup(mode == "mock" ? L10n.text("演示支付和模拟退款不代表真实扣款或到账。") : L10n.text("汇总已支付账单，退款单独列示。实际扣款、退款到账以支付渠道为准。")))
                    .font(.caption).foregroundStyle(Color.textSecondary)
            }
            Section {
                Picker(L10n.text("账单类型"), selection: $filter) { Text(L10n.text("全部账单")).tag("all"); Text(L10n.text("退款记录")).tag("refunds") }.pickerStyle(.segmented)
                if let error {
                    Text(L10n.lookup(error)).foregroundStyle(Color.red)
                    Button(L10n.text("重新加载")) { revision += 1 }
                } else if let data {
                    if data.list.isEmpty {
                        ContentUnavailableView(filter == "refunds" ? L10n.text("暂无退款记录") : L10n.text("暂无这类账单"), systemImage: "doc.text", description: Text(L10n.lookup(mode == "channel" ? L10n.text("演示支付请切换至演示账单查看。") : L10n.text("演示支付后，记录会出现在这里。"))))
                    }
                    ForEach(data.list) { entry in
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(L10n.text("支付单号：\(entry.paymentNo)"))
                                Text(L10n.text("订单编号：\(entry.orderNo)"))
                                Text(L10n.text("支付渠道：\(entry.channel == "demo_balance" ? L10n.text("模拟余额支付") : entry.channel == "mock" ? L10n.text("演示支付") : entry.channel == "wechat" ? L10n.text("微信支付") : entry.channel == "alipay" ? L10n.text("支付宝") : entry.channel)"))
                                ForEach(entry.refunds) { refund in
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("\(refunds[refund.status] ?? refund.status) · \(money(refund.amountCents))").fontWeight(.medium)
                                        Text(refund.reason)
                                        Text("\(refund.createdAt) · \(refund.refundNo)").foregroundStyle(.secondary)
                                    }.padding(.vertical, 8)
                                }
                                if entry.orderType == "booking" {
                                    NavigationLink("查看关联预约") { CustomerBookingDetailView(bookingId: entry.orderNo) }
                                } else if entry.orderType == "shop_order" || entry.orderType == "diy_order" {
                                    NavigationLink("查看我的订单") { OrderListView(initialStatus: entry.orderType == "shop_order" ? "shop" : "diy") }
                                }
                            }.font(.caption).textSelection(.enabled).padding(.vertical, 8)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(L10n.lookup(kinds[entry.orderType] ?? L10n.text("订单支付"))).font(.body)
                                    Text(L10n.lookup(entry.createdAt)).font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 6) {
                                    Text(L10n.lookup(money(entry.amountCents))).monospacedDigit()
                                    Text(L10n.lookup(statuses[entry.status] ?? entry.status)).font(.caption).foregroundStyle(.secondary)
                                }
                            }.padding(.vertical, 6)
                        }
                    }
                    if page > 1 || data.total > 20 {
                        HStack {
                            Button(L10n.text("上一页")) { page -= 1 }.disabled(page == 1)
                            Spacer(); Text(L10n.text("第 \(page) 页")).font(.caption); Spacer()
                            Button(L10n.text("下一页")) { page += 1 }.disabled(page * 20 >= data.total)
                        }.buttonStyle(.borderless)
                    }
                } else { ProgressView(L10n.text("正在读取账单…")) }
            }
            Section { Text(L10n.text("钱包余额与真实消费分别记账。积分与功德值独立记录。")).font(.caption).foregroundStyle(.secondary) }
        }
        .scrollContentBackground(.hidden).background(Color.bgPrimary)
        .navigationTitle(L10n.text("我的钱包")).navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
        .onChange(of: mode) { _, _ in page = 1 }
        .onChange(of: filter) { _, _ in page = 1 }
        .task(id: requestKey) { await load() }
        .refreshable { revision += 1 }
    }
    private func stat(_ title: String, _ cents: Int64?) -> some View {
        VStack(alignment: .leading, spacing: 6) { Text(L10n.lookup(title)).font(.caption).foregroundStyle(.secondary); Text(L10n.lookup(cents.map(money) ?? "—")).monospacedDigit() }
    }
    @MainActor private func load() async {
        let key = requestKey
        data = nil; error = nil
        do {
            let result: CustomerWallet = try await APIClient.shared.request(.wallet(mode: mode, filter: filter, page: page))
            guard !Task.isCancelled, key == requestKey else { return }; data = result
            let cash: CashBalance = try await CashAPI.request("payments/wallet/balance")
            guard !Task.isCancelled, key == requestKey else { return }; cashBalance = cash
        } catch { guard !Task.isCancelled, key == requestKey else { return }; self.error = error.localizedDescription }
    }
}

// Cash and points are independent accounts. Shared by every native checkout.
struct CashQuote: Decodable {
    var pricing: GrowthPriceQuote? = nil
    var mode: String? = nil; var balanceChannel: String? = nil
    let payment: CashPayment?
    let amountCents: Int64; let availableCents: Int64
    let balanceEnabled: Bool; let mockEnabled: Bool; let experience: Bool
}
struct CashPayment: Decodable { let id: Int64; let paymentNo: String; let status: String; let channel: String }
struct CashBalance: Decodable {
    var mode: String? = nil
    struct Channel: Decodable, Identifiable { let id: String; let enabled: Bool }
    struct Entry: Decodable, Identifiable { let id: Int64; let kind: String; let referenceNo: String; let deltaCents: Int64; let balanceAfterCents: Int64; let createdAt: String }
    struct Recharge: Decodable, Identifiable { let rechargeNo: String; var id: String { rechargeNo }; let channel: String; let amountCents: Int64; let status: String; let payUrl: String; let refundCents: Int64; let createdAt: String }
    let availableCents: Int64; let heldCents: Int64; let enabled: Bool
    let channels: [Channel]; let entries: [Entry]; let recharges: [Recharge]; let hasMore: Bool
}
enum CashAPI {
    static func request<T: Decodable>(_ path: String, body: [String: Any]? = nil) async throws -> T {
        guard let url = URL(string: APIClient.shared.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/" + path) else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        if let body { request.httpMethod = "POST"; request.httpBody = try JSONSerialization.data(withJSONObject: body); request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        let (data, _) = try await APIClient.shared.sessionData(for: request)
        let response = try JSONDecoder().decode(APIResponse<T>.self, from: data)
        guard response.isSuccess, let value = response.data else { throw APIError.serverError(response.code, response.message) }
        return value
    }
    static func money(_ cents: Int64) -> String { String(format: "%.2f", Double(cents) / 100) }
}
@MainActor enum CashCheckout {
    private static var active = false
    static func pay(_ kind: String, _ no: String) async throws -> PaymentCreateResult {
        guard !active else { throw APIError.serverError(409, "请先完成当前收银操作") }
        active = true; defer { active = false }
        let owner = AuthStore.shared.requestSession
        let quote: CashQuote = try await CashAPI.request("payments/checkout/quote", body:["orderType":kind,"orderNo":no])
        guard AuthStore.shared.requestSession == owner else { throw CancellationError() }
        if let paid = quote.payment, paid.status == "success" { return PaymentCreateResult(id: paid.id, paymentNo: paid.paymentNo, payUrl: nil) }
        guard var top = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).filter({ $0.activationState == .foregroundActive }).flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController else { throw CancellationError() }
        while let next = top.presentedViewController { top = next }
        return try await withCheckedThrowingContinuation { continuation in
            var host: UIHostingController<NativeCashier>?
            var finished = false
            let complete: (Result<PaymentCreateResult, Error>) -> Void = { result in
                guard !finished else { return }; finished = true
                host?.dismiss(animated: true) { continuation.resume(with: result); host = nil }
            }
            host = UIHostingController(rootView: NativeCashier(quote: quote, kind: kind, no: no, owner: owner, finish: complete))
            host?.isModalInPresentation = true
            host?.sheetPresentationController?.detents = [.medium(), .large()]
            host?.sheetPresentationController?.prefersGrabberVisible = false
            if let host { top.present(host, animated: true) }
        }
    }
}
private struct NativeCashier: View {
    @State var quote: CashQuote; let kind: String; let no: String; let owner: AuthRequestSession
    let finish: (Result<PaymentCreateResult, Error>) -> Void
    @State private var channel = "balance"
    @State private var busy = false
    @State private var error: String?
    var demo: Bool { quote.mode == "demo" }
    var balanceChannel: String { quote.balanceChannel ?? "balance" }
    @State private var selectedOffer: GrowthOffer?
    @State private var stale = false
    var offer: GrowthOffer? { selectedOffer ?? quote.pricing?.snapshot.selected }
    var amount: Int64 { channel == "mock" ? quote.pricing?.grossCents ?? quote.amountCents : offer?.payableCents ?? quote.amountCents }
    var canBalance: Bool { quote.balanceEnabled && quote.availableCents >= (offer?.payableCents ?? quote.amountCents) }
    var body: some View {
        NavigationStack {
            Form {
                Section { Text("¥\(CashAPI.money(amount))").font(.largeTitle.bold()).monospacedDigit(); Text(L10n.text("订单 \(no)")).font(.caption).foregroundStyle(.secondary) }
                if let pricing=quote.pricing, let offer, channel == "balance" {
                    Section(L10n.text("选择优惠")) {
                        ForEach(pricing.snapshot.offers) { candidate in
                            Button { selectedOffer=candidate } label: {
                                HStack { VStack(alignment:.leading,spacing:5) {Text(GrowthAPI.label(candidate.kind));Text("¥"+GrowthAPI.money(candidate.payableCents)).font(.subheadline)};Spacer();if candidate.id==offer.id {Image(systemName:"checkmark.circle.fill")} }
                            }.disabled(busy||stale)
                        }
                        DisclosureGroup(L10n.text("查看优惠与成长明细")) {
                            ForEach(offer.lines) { line in VStack(alignment:.leading,spacing:5) {Text(L10n.lookup(line.name)+" · ¥"+GrowthAPI.money(line.netCents));if line.discountCents>0 {Text(L10n.text("已优惠")+" ¥"+GrowthAPI.money(line.discountCents))};if !line.eligible {Text(L10n.text("不参与优惠")).font(.caption)} } }
                            Text(L10n.text("预计成长值")+" +\(offer.estimatedGrowth) · "+L10n.text("完成后经过 7 天观察期入账"))
                        }
                        Text(L10n.text("优惠不叠加；确认时会重新核验价格与额度。" )).font(.caption)
                    }
                }
                Section(L10n.text("支付方式")) {
                    Button { channel = balanceChannel } label: { HStack { Label(L10n.lookup(demo ? L10n.text("模拟余额支付") : L10n.text("钱包余额")), systemImage: "wallet.bifold"); Spacer(); if channel == balanceChannel { Image(systemName: "checkmark.circle.fill") } } }.disabled(busy || !canBalance)
                    Text(L10n.lookup(quote.experience && !demo ? L10n.text("体验订单不能使用真实余额") : L10n.text("可用 ¥\(CashAPI.money(quote.availableCents))\(quote.balanceEnabled ? (canBalance ? "" : L10n.text(" · 余额不足")) : L10n.text(" · 暂未开通"))"))).font(.caption).foregroundStyle(.secondary)
                    if quote.mockEnabled { Button { channel = "mock" } label: { HStack { Text(L10n.text("演示支付，不扣真实资金")); Spacer(); if channel == "mock" { Image(systemName: "checkmark.circle.fill") } } }.disabled(busy) }
                }
                if let error { Section { Text(L10n.lookup(error)).foregroundStyle(.red);if stale {Button(L10n.text("重新获取报价")){Task{await refreshQuote()}}.disabled(busy)} } }
                Section {
                    Button(L10n.lookup(busy ? L10n.text("正在确认…") : channel == "mock" ? L10n.text("确认演示支付") : L10n.text("\(demo ? L10n.text("模拟支付") : L10n.text("确认支付")) ¥\(CashAPI.money(amount))"))) { Task { await pay() } }.disabled(busy || stale || (channel == balanceChannel && !canBalance))
                    NavigationLink("查看钱包与充值") { CashBalanceView().onDisappear { Task { await refreshQuote() } } }.disabled(busy)
                } footer: { Text(L10n.lookup(demo ? L10n.text("扣减测试余额，不收取真实费用。退款退回测试余额。") : L10n.text("余额支付的退款退回钱包，充值款可申请原路退回。"))) }
            }.navigationTitle(L10n.text("确认支付")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L10n.text("取消")) { finish(.failure(APIError.serverError(409, "订单已保留，可稍后继续支付"))) }.disabled(busy) } }
        }.task { await refreshQuote() }
    }
    @MainActor private func refreshQuote() async {
            do {
                let refreshed: CashQuote = try await CashAPI.request("payments/checkout/quote", body:["orderType":kind,"orderNo":no])
                guard !Task.isCancelled else { return }
                if let paid = refreshed.payment, paid.status == "success" { finish(.success(PaymentCreateResult(id: paid.id, paymentNo: paid.paymentNo, payUrl: nil))); return }
                guard AuthStore.shared.requestSession == owner else {throw CancellationError()}
                quote = refreshed
                selectedOffer = refreshed.pricing?.snapshot.selected;stale=false;error=nil
                channel = canBalance ? balanceChannel : quote.mockEnabled ? "mock" : balanceChannel
            } catch { self.error = error.localizedDescription }
    }

    @MainActor private func pay() async {
        guard !busy, AuthStore.shared.requestSession == owner else { error = "登录账户已变化，请关闭重试"; return }
        busy = true; defer { busy = false }
        do {
            var body:[String:Any] = ["orderType":kind,"orderNo":no,"expectedCents":amount,"channel":channel]
            if channel == "balance", let pricing=quote.pricing,let offer {
                let held:GrowthPriceQuote=try await CashAPI.request("payments/checkout/reserve",body:["orderType":kind,"orderNo":no,"quoteId":pricing.quoteId,"offerKind":offer.kind,"couponId":offer.couponId,"expectedCents":amount]);body["quoteId"]=held.quoteId
            }
            let p: CashPayment = try await CashAPI.request("payments/checkout", body: body)
            guard p.status == "success" else { throw APIError.serverError(409, "支付结果待确认，请刷新订单") }
            finish(.success(PaymentCreateResult(id: p.id, paymentNo: p.paymentNo, payUrl: nil)))
        } catch { if case APIError.serverError(40941, _) = error {stale=true}; self.error = error.localizedDescription }
    }
}
struct CashBalanceView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var data: CashBalance?
    @State private var error: String?
    @State private var amount = "100"
    @State private var channel = "wechat"
    @State private var requestID = UUID().uuidString
    @State private var busy = false
    @State private var page = 1
    @State private var refund: CashBalance.Recharge?
    private var demo: Bool { data?.mode == "demo" }
    private let labels = ["recharge": "充值到账", "payment": "余额支付", "order_refund": "订单退款", "refund_hold": "充值退款冻结", "recharge_refund": "充值款已退回"]
    var body: some View {
        Form {
            Section(L10n.lookup(demo ? L10n.text("测试余额（模拟）") : L10n.text("可用余额"))) {
                Text(L10n.lookup(data.map { "¥" + CashAPI.money($0.availableCents) } ?? "—")).font(.largeTitle.bold()).monospacedDigit()
                Text(L10n.text("退款冻结 ¥\(CashAPI.money(data?.heldCents ?? 0))")).font(.caption).foregroundStyle(.secondary)
                Button(L10n.text("刷新余额")) { Task { await load() } }
            }
            if let error { Section { Text(L10n.lookup(error)).foregroundStyle(.red) } }
            Section(L10n.text("充值")) {
                TextField(L10n.text("充值金额（元）"), text: $amount).keyboardType(.decimalPad).disabled(busy)
                Picker(L10n.text("支付方式"), selection: $channel) { ForEach(data?.channels ?? []) { c in Text(L10n.lookup(c.id == "demo" ? L10n.text("模拟充值") : c.id == "wechat" ? L10n.text("微信支付") : L10n.text("支付宝"))).tag(c.id) } }.disabled(busy)
                Button(L10n.lookup(busy ? L10n.text("正在处理…") : demo ? L10n.text("确认模拟充值") : L10n.text("前往支付"))) { Task { await recharge() } }.disabled(busy || data?.channels.first(where: { $0.id == channel })?.enabled != true)
                Text(L10n.lookup(demo ? L10n.text("测试余额用于体验支付及退款，不代表真实资金，不可兑换或提现。") : data?.channels.contains(where: \.enabled) == true ? L10n.text("支付确认后到账。返回后请刷新余额。") : L10n.text("微信、支付宝充值暂未开通。演示支付不会增加余额。"))).font(.caption).foregroundStyle(.secondary)
            }
            Section(L10n.text("余额流水")) {
                ForEach(data?.entries ?? []) { e in VStack(alignment: .leading, spacing: 6) { HStack { Text(L10n.lookup(labels[e.kind] ?? e.kind)); Spacer(); Text(L10n.lookup((e.deltaCents > 0 ? "+" : "") + CashAPI.money(e.deltaCents))).monospacedDigit() }; Text(L10n.lookup(e.createdAt)).font(.caption).foregroundStyle(.secondary); Text(L10n.text("余额 ¥\(CashAPI.money(e.balanceAfterCents))")).font(.caption) } }
                if data?.entries.isEmpty == true { Text(L10n.lookup(demo ? L10n.text("暂无测试余额变动") : L10n.text("暂无真实余额变动"))).foregroundStyle(.secondary) }
                HStack { Button(L10n.text("上一页")) { page -= 1 }.disabled(page == 1); Spacer(); Text(L10n.text("第 \(page) 页")); Spacer(); Button(L10n.text("下一页")) { page += 1 }.disabled(data?.hasMore != true) }.buttonStyle(.borderless)
            }
            Section(L10n.lookup(demo ? L10n.text("模拟充值记录") : L10n.text("充值与原路退款"))) {
                ForEach(data?.recharges ?? []) { r in VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.text("\(r.channel == "demo" ? L10n.text("模拟") : r.channel == "wechat" ? L10n.text("微信") : L10n.text("支付宝"))充值 ¥\(CashAPI.money(r.amountCents))"))
                    Text(L10n.lookup(["pending":"等待支付确认","success":"充值成功","refund_pending":"原路退款处理中","refunded":"充值退款完成","closed":"充值已关闭"][r.status] ?? r.status)).font(.caption).foregroundStyle(.secondary)
                    Text(L10n.lookup(r.createdAt)).font(.caption2)
                    if r.status == "success", (data?.availableCents ?? 0) > 0 { Button(L10n.text("申请原路退回")) { refund = r }.disabled(busy) }
                } }
            }
        }.navigationTitle(L10n.text("钱包余额")).navigationBarTitleDisplayMode(.inline)
            .task(id: page) { await load() }.refreshable { await load() }
            .onChange(of: amount) { _, _ in requestID = UUID().uuidString }
            .onChange(of: channel) { _, _ in requestID = UUID().uuidString }
            .onChange(of: scenePhase) { _, value in if value == .active { Task { await load() } } }
            .confirmationDialog(L10n.lookup(demo ? L10n.text("撤回测试余额") : L10n.text("确认原路退款")), isPresented: Binding(get: { refund != nil }, set: { if !$0 { refund = nil } }), presenting: refund) { r in
                Button(L10n.text("退回 ¥\(CashAPI.money(min(r.amountCents, data?.availableCents ?? 0)))")) { Task { await refundRecharge(r) } }
                Button(L10n.text("取消"), role: .cancel) { refund = nil }
            } message: { _ in Text(L10n.lookup(demo ? L10n.text("撤回本次充值的测试余额，不向任何账户转账。") : L10n.text("先冻结相应余额，再退回本次充值的微信／支付宝账户。每笔充值支持一次退款。"))) }
    }
    @MainActor private func load() async { do { data = try await CashAPI.request("payments/wallet/balance?page=\(page)"); if data?.channels.first(where: { $0.id == channel && $0.enabled }) == nil, let first = data?.channels.first(where: \.enabled) { channel = first.id }; error = nil } catch { self.error = error.localizedDescription } }
    @MainActor private func recharge() async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do {
            guard amount.range(of: "^\\d+(\\.\\d{1,2})?$", options: .regularExpression) != nil, let value = Decimal(string: amount), value >= 1, value <= 5000 else { throw APIError.serverError(400, "请输入 1 至 5000 元，最多两位小数") }
            let cents = NSDecimalNumber(decimal: value * 100).int64Value
            let r: CashBalance.Recharge = try await CashAPI.request("payments/wallet/recharges", body: ["channel": channel, "amountCents": cents, "requestId": requestID])
            if r.status == "success" { await load(); requestID = UUID().uuidString; return }
            guard let url = URL(string: r.payUrl), url.scheme == "https", ["wx.tenpay.com","openapi.alipay.com","openapi-sandbox.dl.alipaydev.com"].contains(url.host ?? "") else { throw APIError.invalidURL }
            openURL(url)
        } catch { self.error = error.localizedDescription }
    }
    @MainActor private func refundRecharge(_ r: CashBalance.Recharge) async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do { let _: CashBalance.Recharge = try await CashAPI.request("payments/wallet/recharge/refund", body: ["rechargeNo": r.rechargeNo, "amountCents": min(r.amountCents, data?.availableCents ?? 0)]); refund = nil; await load() } catch { self.error = error.localizedDescription }
    }
}
