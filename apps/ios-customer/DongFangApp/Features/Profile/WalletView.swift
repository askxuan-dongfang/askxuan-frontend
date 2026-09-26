import SwiftUI

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
            Section {
                Picker("账单渠道", selection: $mode) { Text("渠道账单").tag("channel"); Text("演示账单").tag("mock") }.pickerStyle(.segmented)
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
            Section { Text("钱包暂不提供充值、余额支付和提现。积分与功德值独立记录。").font(.caption).foregroundStyle(.secondary) }
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
        } catch { guard !Task.isCancelled, key == requestKey else { return }; self.error = error.localizedDescription }
    }
}
