import SwiftUI

struct CreatorWalletData: Decodable {
    struct Account: Decodable { let availableCents: Int64; let heldCents: Int64; let paidCents: Int64 }
    struct Policy: Decodable { let enabled: Bool; let kind: String; let rateBps: Int64; let capCents: Int64; let waitDays: Int; let minWithdrawCents: Int64 }
    struct Reward: Decodable, Identifiable {
        let id: Int64; let orderNo: String; let designId: Int64; let kind: String; let baseCents: Int64
        let amountCents: Int64; let status: String; let reason: String; let createdAt: String
    }
    struct Withdrawal: Decodable, Identifiable {
        let id: Int64; let amountCents: Int64; let status: String; let bankName: String
        let accountNumber: String; let transferReference: String; let note: String; let createdAt: String
    }
    let account: Account; let policy: Policy; let pendingCents: Int64
    let rewards: [Reward]; let withdrawals: [Withdrawal]; let total: Int; let withdrawalTotal: Int
    var isValid: Bool {
        account.heldCents >= 0 && account.paidCents >= 0 && pendingCents >= 0 && total >= 0 && withdrawalTotal >= 0 &&
        ["cash", "balance", "coupon"].contains(policy.kind) && policy.rateBps >= 0 && policy.capCents >= 0 && policy.waitDays >= 0 && policy.minWithdrawCents >= 0 &&
        rewards.allSatisfy { $0.baseCents >= 0 && $0.amountCents >= 0 } && withdrawals.allSatisfy { $0.amountCents >= 0 }
    }
}

enum CreatorWithdrawalInput {
    static func cents(_ amount: String) -> Int64? {
        guard amount.range(of: "^[0-9]+(\\.[0-9]{1,2})?$", options: .regularExpression) != nil,
              let decimal = Decimal(string: amount, locale: Locale(identifier: "en_US_POSIX")),
              decimal > 0, decimal <= Decimal(Int64.max) / 100 else { return nil }
        return NSDecimalNumber(decimal: decimal * 100).int64Value
    }
}

struct CreatorWalletView: View {
    @EnvironmentObject private var auth: AuthStore
    @State private var data: CreatorWalletData?
    @State private var page = 1
    @State private var error: String?
    @State private var notice: String?
    @State private var loading = false
    @State private var withdrawalOpen = false
    @State private var submitting = false
    @State private var amount = ""
    @State private var holder = ""
    @State private var bank = ""
    @State private var account = ""
    @State private var requestKey = UUID().uuidString
    private let statuses = ["review_required":"退款待人工核对", "pending":"待结算", "settled":"已结算", "cancelled":"已撤销", "excluded":"不参与奖励", "approved":"审核通过", "processing":"打款处理中", "paid":"已打款", "rejected":"审核未通过", "failed":"打款失败"]
    private func money(_ value: Int64) -> String {
        "¥" + (Decimal(value) / 100).formatted(.number.precision(.fractionLength(2)).grouping(.never).locale(Locale(identifier: "zh_CN")))
    }

    var body: some View {
        List {
            Section {
                Text(L10n.text("独立于消费余额，仅现金创作收益可申请提现。"))
                if let notice { Text(L10n.lookup(notice)).foregroundStyle(Color.stateSuccess).accessibilityAddTraits(.updatesFrequently) }
                if let error { Text(L10n.lookup(error)).foregroundStyle(Color.stateError) }
            }.listRowBackground(Color.bgSecondary)
            if let data {
                Section(L10n.text("创作收益")) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 20) {
                        metric("可提现", data.account.availableCents)
                        metric("待结算", data.pendingCents)
                        metric("提现中", data.account.heldCents)
                        metric("累计已打款", data.account.paidCents)
                    }.padding(.vertical, 8)
                    if data.account.availableCents < 0 { Text(L10n.text("存在退款奖励待抵扣，后续收益会先抵扣欠额。")).foregroundStyle(Color.stateWarning) }
                    Text(L10n.lookup(policyText(data.policy))).font(.footnote).foregroundStyle(.secondary)
                    Button(L10n.text("申请提现")) { withdrawalOpen = true }
                        .disabled(data.account.availableCents < data.policy.minWithdrawCents || data.account.availableCents <= 0)
                    NavigationLink("我的优惠券") { CouponView() }
                }.listRowBackground(Color.bgSecondary)
                Section(L10n.text("创作奖励明细（\(data.total)）")) {
                    if data.rewards.isEmpty { Text(L10n.text("暂无采用成交奖励。发布到设计广场后，他人通过作品或其副本成交才会计奖。")).foregroundStyle(.secondary) }
                    ForEach(data.rewards) { reward in
                        VStack(alignment: .leading, spacing: 6) {
                            NavigationLink("设计 #\(reward.designId)") { DiyDetailView(designId: reward.designId) }
                            Text(L10n.lookup(reward.orderNo)).font(.caption).textSelection(.enabled)
                            Text(L10n.text("\(reward.kind == "cash" ? "现金收益" : reward.kind == "balance" ? "消费余额" : "优惠券") · \(reward.kind == "coupon" ? "1 张" : money(reward.amountCents)) · \(statuses[reward.status] ?? reward.status)"))
                            if !reward.reason.isEmpty { Text(L10n.lookup(reward.reason)).font(.footnote) }
                            Text(L10n.lookup(reward.createdAt)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }.listRowBackground(Color.bgSecondary)
                Section(L10n.text("提现记录（\(data.withdrawalTotal)）")) {
                    if data.withdrawals.isEmpty { Text(L10n.text("暂无提现申请")).foregroundStyle(.secondary) }
                    ForEach(data.withdrawals) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L10n.text("\(money(item.amountCents)) · \(item.status == "pending" ? "待审核" : statuses[item.status] ?? item.status)")).monospacedDigit()
                            Text("\(item.bankName) \(item.accountNumber)").font(.footnote)
                            if !item.note.isEmpty { Text(L10n.lookup(item.note)).font(.footnote) }
                            if !item.transferReference.isEmpty { Text(L10n.text("打款流水：\(item.transferReference)")).font(.caption).textSelection(.enabled) }
                            Text(L10n.lookup(item.createdAt)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if max(data.total, data.withdrawalTotal) > 20 {
                        HStack {
                            Button(L10n.text("上一页")) { page -= 1 }.disabled(page == 1 || loading)
                            Spacer(); Text(L10n.text("第 \(page) 页")); Spacer()
                            Button(L10n.text("下一页")) { page += 1 }.disabled(page * 20 >= max(data.total, data.withdrawalTotal) || loading)
                        }.buttonStyle(.borderless)
                    }
                }.listRowBackground(Color.bgSecondary)
            } else if loading { ProgressView(L10n.text("正在读取创作收益")) }
            if !loading { Button(L10n.text("刷新收益")) { Task { await load() } } }
        }
        .scrollContentBackground(.hidden).background(Color.bgPrimary)
        .navigationTitle(L10n.text("创作收益"))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: "\(auth.sessionID)-\(page)") { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $withdrawalOpen, onDismiss: { account = ""; holder = ""; bank = ""; amount = "" }) {
            withdrawalForm.appVisualDefaults()
        }
    }
    private func metric(_ title: String, _ value: Int64) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.lookup(title)).font(.caption).foregroundStyle(.secondary)
            Text(L10n.lookup(money(value))).font(.title3.bold()).monospacedDigit().fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func policyText(_ policy: CreatorWalletData.Policy) -> String {
        let benefit = policy.kind == "coupon" ? "券面额、门槛及有效期以券详情为准" : "材料实付的 \(Decimal(policy.rateBps) / 100)%，每单最高 \(money(policy.capCents))"
        return (policy.enabled ? "新订单奖励：\(policy.kind == "cash" ? "现金收益" : policy.kind == "balance" ? "消费余额" : "优惠券")；\(benefit)，完成订单 \(policy.waitDays) 天后结算。" : "新订单奖励暂未开启。") + "自购、模拟支付不计奖，退款会撤销奖励。历史订单按下单时规则执行。"
    }
    private var withdrawalForm: some View {
        NavigationStack {
            Form {
                Section {
                    Text(L10n.text("人民币人工银行转账，最低 \(money(data?.policy.minWithdrawCents ?? 0))，平台手续费 0 元。提交后等待审核及实际打款；到账以银行为准。"))
                    if let error { Text(L10n.lookup(error)).foregroundStyle(Color.stateError) }
                }.listRowBackground(Color.bgSecondary)
                Section(L10n.text("本人银行账户")) {
                    TextField(L10n.text("金额（元）"), text: $amount).keyboardType(.decimalPad)
                    TextField(L10n.text("收款人姓名"), text: $holder).textContentType(.name)
                    TextField(L10n.text("银行及开户支行"), text: $bank)
                    TextField(L10n.text("银行卡号"), text: $account).keyboardType(.numberPad).privacySensitive()
                }.disabled(submitting).listRowBackground(Color.bgSecondary)
                Button(L10n.lookup(submitting ? L10n.text("提交中…") : L10n.text("确认申请"))) { Task { await submit() } }.disabled(submitting)
            }
            .scrollContentBackground(.hidden).background(Color.bgPrimary)
            .navigationTitle(L10n.text("申请提现")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L10n.text("取消")) { withdrawalOpen = false }.disabled(submitting) } }
            .interactiveDismissDisabled(submitting)
            .onChange(of: [amount, holder, bank, account]) { _, _ in requestKey = UUID().uuidString; notice = nil }
        }
    }
    @MainActor private func load() async {
        loading = true; defer { loading = false }
        do {
            let value: CreatorWalletData = try await CashAPI.request("diy/creator-wallet?page=\(page)")
            guard !Task.isCancelled else { return }
            guard value.isValid else { throw APIError.serverError(500, "创作收益数据格式异常，请重新读取") }
            data = value; error = nil
        } catch { if !Task.isCancelled { data = nil; withdrawalOpen = false; self.error = error.localizedDescription } }
    }
    @MainActor private func submit() async {
        guard !submitting, let data else { return }
        guard let cents = CreatorWithdrawalInput.cents(amount), cents >= data.policy.minWithdrawCents, cents <= data.account.availableCents else { error = "请输入有效金额，且不低于最低提现额、不超过可提现余额"; return }
        let name = holder.trimmingCharacters(in: .whitespacesAndNewlines)
        let branch = bank.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 100, !branch.isEmpty, branch.count <= 150,
              account.range(of: "^[0-9]{6,40}$", options: .regularExpression) != nil else { error = "请填写完整的本人姓名、银行支行和有效银行卡号"; return }
        submitting = true; defer { submitting = false }
        do {
            struct Submitted: Decodable {}
            let _: Submitted = try await CashAPI.request("diy/creator-withdrawals", body: ["requestKey": requestKey, "amountCents": cents, "holderName": name, "bankName": branch, "accountNumber": account])
            withdrawalOpen = false; requestKey = UUID().uuidString; account = ""
            notice = "提现申请已提交，资金已冻结；审核通过不代表已经到账。"
            await load()
        } catch { self.error = error.localizedDescription }
    }
}
