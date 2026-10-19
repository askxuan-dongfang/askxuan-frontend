import SwiftUI

struct ProviderWallet: Decodable {
    struct Summary: Decodable { let pendingCents: Int64; let confirmedCents: Int64; let recordedPaidCents: Int64 }
    struct Settlement: Decodable, Identifiable { let id: Int64; let number: String; let sourceType: String; let sourceNo: String; let grossCents: Int64; let commissionCents: Int64; let netCents: Int64; let status: String; let createdAt: String }
    struct Withdrawal: Decodable, Identifiable { let id: Int64; let number: String; let amountCents: Int64; let status: String; let createdAt: String }
    let summary: Summary; let settlements: [Settlement]; let withdrawals: [Withdrawal]
    let total: Int; let withdrawalTotal: Int; let page: Int; let pageSize: Int
    let withdrawEnabled: Bool; let recordMode: String
}
struct EarningsView: View {
    @EnvironmentObject private var auth: AuthStore
    @State private var data: ProviderWallet?
    @State private var error: String?
    @State private var tab = 0
    @State private var page = 1
    @State private var revision = 0
    @State private var mode = "accounting_only"
    @State private var payout: ProviderWallet.Settlement?
    @State private var paying = false
    private var requestKey: String { "\(auth.sessionID)-\(page)-\(revision)-\(mode)" }
    private var total: Int { tab == 0 ? data?.total ?? 0 : data?.withdrawalTotal ?? 0 }
    private let statuses = ["pending":"待确认结算", "confirmed":"已确认结算", "paid":"账面已结算"]
    private let withdrawals = ["pending":"待审核", "approved":"审核通过", "processing":"模拟处理中", "success":"模拟完成", "failed":"模拟失败", "rejected":"审核拒绝"]
    private func money(_ cents: Int64) -> String { (Decimal(cents) / 100).formatted(.currency(code: "CNY")) }
    var body: some View {
        List {
            Picker(L10n.text("资金类型"), selection: $mode) { Text(L10n.text("原有账面记录")).tag("accounting_only"); Text(L10n.text("模拟余额结算")).tag("demo") }.pickerStyle(.segmented)
            if mode == "demo" { Text(L10n.text("测试余额订单的独立结算记录，模拟提现不会向银行转账。咨询结束后方可模拟提现。")).font(.caption).foregroundStyle(.secondary) }
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    Label(L10n.text("待确认结算"), systemImage: "wallet.bifold").font(.subheadline).foregroundStyle(.secondary)
                    Text(L10n.lookup(data.map { money($0.summary.pendingCents) } ?? "—")).font(.system(size: 34, weight: .semibold, design: .rounded)).monospacedDigit()
                    Divider()
                    HStack { stat("已确认结算", data?.summary.confirmedCents); Spacer(); stat("账面已结算", data?.summary.recordedPaidCents) }
                }.padding(.vertical, 12)
                Text(L10n.text("仅统计本人结算份额，不包含寺院收入。当前为账面记录，含演示业务；结算状态不代表银行到账，真实提现暂未开放。")).font(.caption).foregroundStyle(.secondary)
            }
            Section { NavigationLink("收入流水与趋势") { EarningsHistoryView() } }
            Section {
                Picker(L10n.text("钱包记录"), selection: $tab) { Text(L10n.text("结算明细")).tag(0); Text(L10n.text("历史提现")).tag(1) }.pickerStyle(.segmented)
                if let error { Text(L10n.lookup(error)).foregroundStyle(.red); Button(L10n.text("重新加载")) { revision += 1 } }
                else if let data {
                    if tab == 0 {
                        ForEach(data.settlements) { row in
                            DisclosureGroup {
                                VStack(alignment: .leading, spacing: 10) {
                                    if mode == "demo", data.withdrawEnabled, row.status != "paid" { Button(L10n.text("模拟提现")) { payout = row }.disabled(paying) }
                                    Text(L10n.text("结算编号：\(row.number)"))
                                    Text(L10n.text("本人分配金额：\(money(row.grossCents))"))
                                    Text(L10n.text("平台费用：\(money(row.commissionCents))"))
                                    Text(L10n.text("应结金额：\(money(row.netCents))"))
                                    Text(L10n.text("来源单号：\(row.sourceNo.isEmpty ? "历史汇总结算" : row.sourceNo)"))
                                    if row.sourceType == "booking", !row.sourceNo.isEmpty {
                                        NavigationLink("查看预约") { BookingDetailView(bookingId: row.sourceNo) }
                                    }
                                }.font(.caption).padding(.vertical, 8).textSelection(.enabled)
                            } label: { rowLabel(statuses[row.status] ?? row.status, row.createdAt, row.netCents) }
                        }
                    } else {
                        Text(L10n.text("以下为历史模拟提现记录，不代表银行打款成功。")).font(.caption).foregroundStyle(.secondary)
                        ForEach(data.withdrawals) { row in
                            DisclosureGroup { Text(L10n.text("\(row.number) · 模拟记录")).font(.caption).textSelection(.enabled) }
                            label: { rowLabel(withdrawals[row.status] ?? row.status, row.createdAt, row.amountCents) }
                        }
                    }
                    if total == 0 { ContentUnavailableView(L10n.text("暂无记录"), systemImage: "doc.text", description: Text(L10n.text("记录生成后会集中展示在这里。"))) }
                    if page > 1 || total > 20 {
                        HStack { Button(L10n.text("上一页")) { page -= 1 }.disabled(page == 1); Spacer(); Text(L10n.text("第 \(page) 页")).font(.caption); Spacer(); Button(L10n.text("下一页")) { page += 1 }.disabled(page * 20 >= total) }.buttonStyle(.borderless)
                    }
                } else { ProgressView(L10n.text("正在读取钱包…")) }
            }
        }.scrollContentBackground(.hidden).background(Color.bgPrimary)
        .navigationTitle(L10n.text("我的钱包")).navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { NavigationLink("定价") { PricingView() } } }
        .onChange(of: mode) { _, _ in page = 1 }
        .confirmationDialog(L10n.text("确认模拟提现"), isPresented: Binding(get: { payout != nil }, set: { if !$0 { payout = nil } }), presenting: payout) { row in
            Button(L10n.text("模拟提现 \(money(row.netCents))")) { Task { await simulate(row.id) } }
            Button(L10n.text("取消"), role: .cancel) { payout = nil }
        } message: { _ in Text(L10n.text("只更新测试结算记录，不发生真实转账。")) }
        .onChange(of: tab) { _, _ in page = 1 }
        .task(id: requestKey) { await load() }.refreshable { revision += 1 }
    }
    @MainActor private func simulate(_ id: Int64) async {
        guard !paying else { return }; paying = true; defer { paying = false }
        struct Result: Decodable { let status: String }
        do { let _: Result = try await APIClient.shared.request(.simulateWalletPayout(settlementId: id)); payout = nil; revision += 1 }
        catch { self.error = error.localizedDescription }
    }
    private func stat(_ title: String, _ cents: Int64?) -> some View {
        VStack(alignment: .leading, spacing: 6) { Text(L10n.lookup(title)).font(.caption).foregroundStyle(.secondary); Text(L10n.lookup(cents.map(money) ?? "—")).monospacedDigit() }
    }
    private func rowLabel(_ title: String, _ date: String, _ cents: Int64) -> some View {
        HStack { VStack(alignment: .leading, spacing: 6) { Text(L10n.lookup(title)); Text(L10n.lookup(date)).font(.caption2).foregroundStyle(.secondary) }; Spacer(); Text(L10n.lookup(money(cents))).monospacedDigit() }.padding(.vertical, 6)
    }
    @MainActor private func load() async {
        let key = requestKey; data = nil; error = nil
        do { let result: ProviderWallet = try await APIClient.shared.request(.providerWallet(page: page, mode: mode)); guard !Task.isCancelled, key == requestKey else { return }; data = result }
        catch { guard !Task.isCancelled, key == requestKey else { return }; self.error = error.localizedDescription }
    }
}


private struct EarningsHistoryView: View {
    @EnvironmentObject private var auth: AuthStore
    @State private var summary: EarningsSummary?
    @State private var details: [EarningsDetailItem] = []
    @State private var total = 0
    @State private var page = 1
    @State private var revision = 0
    @State private var loading = true
    @State private var error: String?
    private var key: String { "\(auth.sessionID)-\(page)-\(revision)" }
    var body: some View {
        List {
            Text(L10n.text("含预约、咨询和加持等已记录收益。与结算单分开核对，不代表可提现余额。")).font(.caption).foregroundStyle(.secondary)
            if let error { Text(L10n.lookup(error)).foregroundStyle(.red); Button(L10n.text("重试")) { revision += 1 } }
            else if loading { ProgressView(L10n.text("正在读取流水…")) }
            else {
                if let summary {
                    Section(L10n.text("收益记录")) { LabeledContent(L10n.text("本月"), value: summary.monthIncome.formatted(.currency(code: "CNY"))); LabeledContent(L10n.text("累计"), value: summary.totalIncome.formatted(.currency(code: "CNY"))) }
                    Section(L10n.text("收益趋势")) { ForEach(summary.trend, id: \.month) { row in LabeledContent(row.month, value: row.amount.formatted(.currency(code: "CNY"))) } }
                }
                Section(L10n.text("收入明细")) {
                    ForEach(details) { row in
                        HStack { VStack(alignment: .leading) { Text(L10n.lookup(row.serviceType == "booking" ? L10n.text("预约服务") : row.serviceType == "consult" ? L10n.text("即时咨询") : row.serviceType == "diy_blessing" ? L10n.text("手串加持") : row.serviceType)); Text("\(row.userName) · \(row.date)").font(.caption).foregroundStyle(.secondary) }; Spacer(); Text(L10n.lookup(row.amount.formatted(.currency(code: "CNY")))).monospacedDigit() }
                    }
                    if details.isEmpty { Text(L10n.text("暂无收入流水")).foregroundStyle(.secondary) }
                    if page > 1 || total > 20 {
                        HStack { Button(L10n.text("上一页")) { page -= 1 }.disabled(page == 1); Spacer(); Text(L10n.text("第 \(page) 页")); Spacer(); Button(L10n.text("下一页")) { page += 1 }.disabled(page * 20 >= total) }.buttonStyle(.borderless)
                    }
                }
            }
        }.navigationTitle(L10n.text("收入流水")).navigationBarTitleDisplayMode(.inline)
        .task(id: key) { await load() }.refreshable { revision += 1 }
    }
    @MainActor private func load() async {
        let current = key; summary = nil; details = []; error = nil; loading = true
        do {
            async let s: EarningsSummary = APIClient.shared.request(.earningsSummary)
            async let d: EarningsDetailResponse = APIClient.shared.request(.earningsDetails(serviceType: nil, page: page, size: 20))
            let (summary, rows) = try await (s,d)
            guard !Task.isCancelled, key == current else { return }
            self.summary = summary; details = rows.list; total = Int(rows.total)
        } catch { guard !Task.isCancelled, key == current else { return }; self.error = error.localizedDescription }
        loading = false
    }
}
