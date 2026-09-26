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
            Section { NavigationLink { CashBalanceView() } label: { VStack(alignment: .leading, spacing: 8) { Label("钱包余额", systemImage: "wallet.bifold"); Text(cashBalance.map { "¥" + CashAPI.money($0.availableCents) } ?? "—").font(.largeTitle.bold()).monospacedDigit(); Text("充值 · 余额流水 · 原路退款").font(.caption).foregroundStyle(.secondary) } } }
            Section {
                Picker("账单渠道", selection: $mode) { Text("真实消费").tag("channel"); Text("演示账单").tag("mock") }.pickerStyle(.segmented)
                VStack(alignment: .leading, spacing: 18) {
                    Label(mode == "mock" ? "演示累计支付" : "累计支付记录", systemImage: "wallet.bifold")
                        .font(.subheadline).foregroundStyle(Color.textSecondary)
                    Text(data.map { money($0.summary.paidCents) } ?? "—").font(.system(size: 34, weight: .semibold, design: .rounded)).monospacedDigit()
                    Divider()
                    HStack {
                        stat("已退款", data?.summary.refundedCents)
                        Spacer()
                        stat("退款处理中", data?.summary.refundingCents)
                    }
                }.padding(.vertical, 12)
                Text(mode == "mock" ? "演示支付和模拟退款不代表真实扣款或到账。" : "汇总已支付账单，退款单独列示。实际扣款、退款到账以支付渠道为准。")
                    .font(.caption).foregroundStyle(Color.textSecondary)
            }
            Section {
                Picker("账单类型", selection: $filter) { Text("全部账单").tag("all"); Text("退款记录").tag("refunds") }.pickerStyle(.segmented)
                if let error {
                    Text(error).foregroundStyle(Color.red)
                    Button("重新加载") { revision += 1 }
                } else if let data {
                    if data.list.isEmpty {
                        ContentUnavailableView(filter == "refunds" ? "暂无退款记录" : "暂无这类账单", systemImage: "doc.text", description: Text(mode == "channel" ? "演示支付请切换至演示账单查看。" : "演示支付后，记录会出现在这里。"))
                    }
                    ForEach(data.list) { entry in
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("支付单号：\(entry.paymentNo)")
                                Text("订单编号：\(entry.orderNo)")
                                Text("支付渠道：\(entry.channel == "mock" ? "演示支付" : entry.channel == "wechat" ? "微信支付" : entry.channel == "alipay" ? "支付宝" : entry.channel)")
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
                                    Text(kinds[entry.orderType] ?? "订单支付").font(.body)
                                    Text(entry.createdAt).font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 6) {
                                    Text(money(entry.amountCents)).monospacedDigit()
                                    Text(statuses[entry.status] ?? entry.status).font(.caption).foregroundStyle(.secondary)
                                }
                            }.padding(.vertical, 6)
                        }
                    }
                    if page > 1 || data.total > 20 {
                        HStack {
                            Button("上一页") { page -= 1 }.disabled(page == 1)
                            Spacer(); Text("第 \(page) 页").font(.caption); Spacer()
                            Button("下一页") { page += 1 }.disabled(page * 20 >= data.total)
                        }.buttonStyle(.borderless)
                    }
                } else { ProgressView("正在读取账单…") }
            }
            Section { Text("钱包余额与真实消费分别记账。积分与功德值独立记录。").font(.caption).foregroundStyle(.secondary) }
        }
        .scrollContentBackground(.hidden).background(Color.bgPrimary)
        .navigationTitle("我的钱包").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
        .onChange(of: mode) { _, _ in page = 1 }
        .onChange(of: filter) { _, _ in page = 1 }
        .task(id: requestKey) { await load() }
        .refreshable { revision += 1 }
    }
    private func stat(_ title: String, _ cents: Int64?) -> some View {
        VStack(alignment: .leading, spacing: 6) { Text(title).font(.caption).foregroundStyle(.secondary); Text(cents.map(money) ?? "—").monospacedDigit() }
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
    let payment: CashPayment?
    let amountCents: Int64; let availableCents: Int64
    let balanceEnabled: Bool; let mockEnabled: Bool; let experience: Bool
}
struct CashPayment: Decodable { let id: Int64; let paymentNo: String; let status: String; let channel: String }
struct CashBalance: Decodable {
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
        let escapedKind = kind.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? kind
        let escapedNo = no.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? no
        let quote: CashQuote = try await CashAPI.request("payments/checkout?orderType=\(escapedKind)&orderNo=\(escapedNo)")
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
    let quote: CashQuote; let kind: String; let no: String; let owner: AuthRequestSession
    let finish: (Result<PaymentCreateResult, Error>) -> Void
    @State private var channel = "balance"
    @State private var busy = false
    @State private var error: String?
    var canBalance: Bool { quote.balanceEnabled && quote.availableCents >= quote.amountCents }
    var body: some View {
        NavigationStack {
            Form {
                Section { Text("¥\(CashAPI.money(quote.amountCents))").font(.largeTitle.bold()).monospacedDigit(); Text("订单 \(no)").font(.caption).foregroundStyle(.secondary) }
                Section("支付方式") {
                    Button { channel = "balance" } label: { HStack { Label("钱包余额", systemImage: "wallet.bifold"); Spacer(); if channel == "balance" { Image(systemName: "checkmark.circle.fill") } } }.disabled(busy || !canBalance)
                    Text(quote.experience ? "体验订单不能使用真实余额" : "可用 ¥\(CashAPI.money(quote.availableCents))\(quote.balanceEnabled ? (canBalance ? "" : " · 余额不足") : " · 暂未开通")").font(.caption).foregroundStyle(.secondary)
                    if quote.mockEnabled { Button { channel = "mock" } label: { HStack { Text("演示支付，不扣真实资金"); Spacer(); if channel == "mock" { Image(systemName: "checkmark.circle.fill") } } }.disabled(busy) }
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
                Section {
                    Button(busy ? "正在确认…" : channel == "mock" ? "确认演示支付" : "确认支付 ¥\(CashAPI.money(quote.amountCents))") { Task { await pay() } }.disabled(busy || (channel == "balance" && !canBalance))
                    NavigationLink("查看钱包与充值") { CashBalanceView() }.disabled(busy)
                } footer: { Text("余额支付的退款退回钱包，充值款可申请原路退回。") }
            }.navigationTitle("确认支付").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { finish(.failure(APIError.serverError(409, "订单已保留，可稍后继续支付"))) }.disabled(busy) } }
        }.onAppear { channel = canBalance ? "balance" : quote.mockEnabled ? "mock" : "balance" }
    }
    @MainActor private func pay() async {
        guard !busy, AuthStore.shared.requestSession == owner else { error = "登录账户已变化，请关闭重试"; return }
        busy = true; defer { busy = false }
        do {
            let p: CashPayment = try await CashAPI.request("payments/checkout", body: ["orderType": kind, "orderNo": no, "expectedCents": quote.amountCents, "channel": channel])
            guard p.status == "success" else { throw APIError.serverError(409, "支付结果待确认，请刷新订单") }
            finish(.success(PaymentCreateResult(id: p.id, paymentNo: p.paymentNo, payUrl: nil)))
        } catch { self.error = error.localizedDescription }
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
    private let labels = ["recharge": "充值到账", "payment": "余额支付", "order_refund": "订单退款", "refund_hold": "充值退款冻结", "recharge_refund": "充值款已退回"]
    var body: some View {
        Form {
            Section("可用余额") {
                Text(data.map { "¥" + CashAPI.money($0.availableCents) } ?? "—").font(.largeTitle.bold()).monospacedDigit()
                Text("退款冻结 ¥\(CashAPI.money(data?.heldCents ?? 0))").font(.caption).foregroundStyle(.secondary)
                Button("刷新余额") { Task { await load() } }
            }
            if let error { Section { Text(error).foregroundStyle(.red) } }
            Section("充值") {
                TextField("充值金额（元）", text: $amount).keyboardType(.decimalPad).disabled(busy)
                Picker("支付方式", selection: $channel) { Text("微信支付").tag("wechat"); Text("支付宝").tag("alipay") }.disabled(busy)
                Button(busy ? "正在处理…" : "前往支付") { Task { await recharge() } }.disabled(busy || data?.channels.first(where: { $0.id == channel })?.enabled != true)
                Text(data?.channels.contains(where: \.enabled) == true ? "支付确认后到账。返回后请刷新余额。" : "微信、支付宝充值暂未开通。演示支付不会增加余额。").font(.caption).foregroundStyle(.secondary)
            }
            Section("余额流水") {
                ForEach(data?.entries ?? []) { e in VStack(alignment: .leading, spacing: 6) { HStack { Text(labels[e.kind] ?? e.kind); Spacer(); Text((e.deltaCents > 0 ? "+" : "") + CashAPI.money(e.deltaCents)).monospacedDigit() }; Text(e.createdAt).font(.caption).foregroundStyle(.secondary); Text("余额 ¥\(CashAPI.money(e.balanceAfterCents))").font(.caption) } }
                if data?.entries.isEmpty == true { Text("暂无真实余额变动").foregroundStyle(.secondary) }
                HStack { Button("上一页") { page -= 1 }.disabled(page == 1); Spacer(); Text("第 \(page) 页"); Spacer(); Button("下一页") { page += 1 }.disabled(data?.hasMore != true) }.buttonStyle(.borderless)
            }
            Section("充值与原路退款") {
                ForEach(data?.recharges ?? []) { r in VStack(alignment: .leading, spacing: 8) {
                    Text("\(r.channel == "wechat" ? "微信" : "支付宝")充值 ¥\(CashAPI.money(r.amountCents))")
                    Text(["pending":"等待支付确认","success":"充值成功","refund_pending":"原路退款处理中","refunded":"充值退款完成","closed":"充值已关闭"][r.status] ?? r.status).font(.caption).foregroundStyle(.secondary)
                    Text(r.createdAt).font(.caption2)
                    if r.status == "success", (data?.availableCents ?? 0) > 0 { Button("申请原路退回") { refund = r }.disabled(busy) }
                } }
            }
        }.navigationTitle("钱包余额").navigationBarTitleDisplayMode(.inline)
            .task(id: page) { await load() }.refreshable { await load() }
            .onChange(of: amount) { _, _ in requestID = UUID().uuidString }
            .onChange(of: channel) { _, _ in requestID = UUID().uuidString }
            .onChange(of: scenePhase) { _, value in if value == .active { Task { await load() } } }
            .confirmationDialog("确认原路退款", isPresented: Binding(get: { refund != nil }, set: { if !$0 { refund = nil } }), presenting: refund) { r in
                Button("退回 ¥\(CashAPI.money(min(r.amountCents, data?.availableCents ?? 0)))") { Task { await refundRecharge(r) } }
                Button("取消", role: .cancel) { refund = nil }
            } message: { _ in Text("先冻结相应余额，再退回本次充值的微信／支付宝账户。每笔充值支持一次退款。") }
    }
    @MainActor private func load() async { do { data = try await CashAPI.request("payments/wallet/balance?page=\(page)"); error = nil } catch { self.error = error.localizedDescription } }
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
