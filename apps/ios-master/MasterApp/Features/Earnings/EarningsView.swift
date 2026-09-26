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
    private var requestKey: String { "\(auth.sessionID)-\(page)-\(revision)" }
    private var total: Int { tab == 0 ? data?.total ?? 0 : data?.withdrawalTotal ?? 0 }
    private let statuses = ["pending":"待确认结算", "confirmed":"已确认结算", "paid":"账面已结算"]
    private let withdrawals = ["pending":"待审核", "approved":"审核通过", "processing":"模拟处理中", "success":"模拟完成", "failed":"模拟失败", "rejected":"审核拒绝"]
    private func money(_ cents: Int64) -> String { (Decimal(cents) / 100).formatted(.currency(code: "CNY")) }
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    Label("待确认结算", systemImage: "wallet.bifold").font(.subheadline).foregroundStyle(.secondary)
                    Text(data.map { money($0.summary.pendingCents) } ?? "—").font(.system(size: 34, weight: .semibold, design: .rounded)).monospacedDigit()
                    Divider()
                    HStack { stat("已确认结算", data?.summary.confirmedCents); Spacer(); stat("账面已结算", data?.summary.recordedPaidCents) }
                }.padding(.vertical, 12)
                Text("仅统计本人结算份额，不包含寺院收入。当前为账面记录，含演示业务；结算状态不代表银行到账，真实提现暂未开放。").font(.caption).foregroundStyle(.secondary)
            }
            Section { NavigationLink("收入流水与趋势") { EarningsHistoryView() } }
            Section {
                Picker("钱包记录", selection: $tab) { Text("结算明细").tag(0); Text("历史提现").tag(1) }.pickerStyle(.segmented)
                if let error { Text(error).foregroundStyle(.red); Button("重新加载") { revision += 1 } }
                else if let data {
                    if tab == 0 {
                        ForEach(data.settlements) { row in
                            DisclosureGroup {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("结算编号：\(row.number)")
                                    Text("本人分配金额：\(money(row.grossCents))")
                                    Text("平台费用：\(money(row.commissionCents))")
                                    Text("应结金额：\(money(row.netCents))")
                                    Text("来源单号：\(row.sourceNo.isEmpty ? "历史汇总结算" : row.sourceNo)")
                                    if row.sourceType == "booking", !row.sourceNo.isEmpty {
                                        NavigationLink("查看预约") { BookingDetailView(bookingId: row.sourceNo) }
                                    }
                                }.font(.caption).padding(.vertical, 8).textSelection(.enabled)
                            } label: { rowLabel(statuses[row.status] ?? row.status, row.createdAt, row.netCents) }
                        }
                    } else {
                        Text("以下为历史模拟提现记录，不代表银行打款成功。").font(.caption).foregroundStyle(.secondary)
                        ForEach(data.withdrawals) { row in
                            DisclosureGroup { Text("\(row.number) · 模拟记录").font(.caption).textSelection(.enabled) }
                            label: { rowLabel(withdrawals[row.status] ?? row.status, row.createdAt, row.amountCents) }
                        }
                    }
                    if total == 0 { ContentUnavailableView("暂无记录", systemImage: "doc.text", description: Text("记录生成后会集中展示在这里。")) }
                    if page > 1 || total > 20 {
                        HStack { Button("上一页") { page -= 1 }.disabled(page == 1); Spacer(); Text("第 \(page) 页").font(.caption); Spacer(); Button("下一页") { page += 1 }.disabled(page * 20 >= total) }.buttonStyle(.borderless)
                    }
                } else { ProgressView("正在读取钱包…") }
            }
        }.scrollContentBackground(.hidden).background(Color.bgPrimary)
        .navigationTitle("我的钱包").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { NavigationLink("定价") { PricingView() } } }
        .onChange(of: tab) { _, _ in page = 1 }
        .task(id: requestKey) { await load() }.refreshable { revision += 1 }
    }
    private func stat(_ title: String, _ cents: Int64?) -> some View {
        VStack(alignment: .leading, spacing: 6) { Text(title).font(.caption).foregroundStyle(.secondary); Text(cents.map(money) ?? "—").monospacedDigit() }
    }
    private func rowLabel(_ title: String, _ date: String, _ cents: Int64) -> some View {
        HStack { VStack(alignment: .leading, spacing: 6) { Text(title); Text(date).font(.caption2).foregroundStyle(.secondary) }; Spacer(); Text(money(cents)).monospacedDigit() }.padding(.vertical, 6)
    }
    @MainActor private func load() async {
        let key = requestKey; data = nil; error = nil
        do { let result: ProviderWallet = try await APIClient.shared.request(.providerWallet(page: page)); guard !Task.isCancelled, key == requestKey else { return }; data = result }
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
            Text("含预约、咨询和加持等已记录收益。与结算单分开核对，不代表可提现余额。").font(.caption).foregroundStyle(.secondary)
            if let error { Text(error).foregroundStyle(.red); Button("重试") { revision += 1 } }
            else if loading { ProgressView("正在读取流水…") }
            else {
                if let summary {
                    Section("收益记录") { LabeledContent("本月", value: summary.monthIncome.formatted(.currency(code: "CNY"))); LabeledContent("累计", value: summary.totalIncome.formatted(.currency(code: "CNY"))) }
                    Section("收益趋势") { ForEach(summary.trend, id: \.month) { row in LabeledContent(row.month, value: row.amount.formatted(.currency(code: "CNY"))) } }
                }
                Section("收入明细") {
                    ForEach(details) { row in
                        HStack { VStack(alignment: .leading) { Text(row.serviceType == "booking" ? "预约服务" : row.serviceType == "consult" ? "即时咨询" : row.serviceType == "diy_blessing" ? "手串加持" : row.serviceType); Text("\(row.userName) · \(row.date)").font(.caption).foregroundStyle(.secondary) }; Spacer(); Text(row.amount.formatted(.currency(code: "CNY"))).monospacedDigit() }
                    }
                    if details.isEmpty { Text("暂无收入流水").foregroundStyle(.secondary) }
                    if page > 1 || total > 20 {
                        HStack { Button("上一页") { page -= 1 }.disabled(page == 1); Spacer(); Text("第 \(page) 页"); Spacer(); Button("下一页") { page += 1 }.disabled(page * 20 >= total) }.buttonStyle(.borderless)
                    }
                }
            }
        }.navigationTitle("收入流水").navigationBarTitleDisplayMode(.inline)
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
