import SwiftUI

@MainActor final class GrowthSync: ObservableObject {
    static let shared = GrowthSync()
    @Published private(set) var identity = ""
    @Published private(set) var overview: GrowthOverview?
    @Published private(set) var notice: GrowthLevelNotice?
    @Published private(set) var error: String?
    @Published private(set) var revision = 0
    private var inFlight: UUID?

    func configure(_ identity: String) {
        guard self.identity != identity else { return }
        self.identity = identity
        overview = nil; notice = nil; error = nil; inFlight = nil; revision = 0
    }
    func dismissNotice() { notice = nil }
    func refresh() async {
        guard !identity.isEmpty, inFlight == nil else { return }
        let owner = identity, request = UUID()
        inFlight = request
        defer { if inFlight == request { inFlight = nil } }
        do {
            let value: GrowthOverview = try await GrowthAPI.request("overview")
            guard !Task.isCancelled, identity == owner, inFlight == request else { return }
            overview = value; error = nil; revision += 1
            let claimed: GrowthNoticeResponse = try await GrowthAPI.request("notice/claim", body: [:])
            guard !Task.isCancelled, identity == owner, inFlight == request else { return }
            if let message = claimed.notice { notice = message }
        } catch is CancellationError {} catch {
            if !Task.isCancelled, identity == owner { self.error = error.localizedDescription }
        }
    }
}

struct GrowthSyncHost: View {
    let identity: String
    @Environment(\.scenePhase) private var phase
    var body: some View {
        Color.clear.frame(width: 0, height: 0)
            .task(id: identity + "|" + String(describing: phase)) {
                GrowthSync.shared.configure(identity)
                guard phase == .active, !identity.isEmpty else { return }
                while !Task.isCancelled {
                    await GrowthSync.shared.refresh()
                    do { try await Task.sleep(for: .seconds(15)) } catch { return }
                }
            }
    }
}

struct GrowthUpgradeBanner: View {
    let identity: String
    @ObservedObject private var sync = GrowthSync.shared
    var body: some View {
        if sync.identity == identity, let notice = sync.notice {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.text("成长有了新进展") + " · L\(notice.level.code) " + L10n.lookup(notice.level.name)).font(.headline)
                    Text(L10n.lookup(notice.level.benefit)).font(.subheadline)
                }.accessibilityElement(children: .combine).accessibilityAddTraits(.updatesFrequently)
                Spacer(minLength: 0)
                Button { sync.dismissNotice() } label: { Image(systemName: "xmark").frame(minWidth: 44, minHeight: 44) }.accessibilityLabel(L10n.text("关闭升级提示"))
            }.padding(14).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)).padding(.horizontal)
        }
    }
}

struct GrowthRulesView: View {
    var provider = false
    var publicRead = false
    @Environment(\.scenePhase) private var phase
    @State private var history: GrowthRuleHistory?
    @State private var page = 1
    @State private var error: String?
    @State private var loading = false
    var body: some View {
        List {
            Section { Text(L10n.text("规则按北京时间生效，已支付订单沿用确认时的快照。")) }
            if let error { Section { Text(L10n.lookup(error)); Button(L10n.text("重试")) { Task { await load() } } } }
            if history == nil && error == nil { ProgressView() }
            ForEach(history?.items ?? []) { rule in
                Section {
                    DisclosureGroup(rule.version + " · " + L10n.lookup(rule.status == "current" ? "当前生效" : "历史版本")) {
                        Text(Self.stamp(rule.effectiveAt > 0 ? rule.effectiveAt : rule.createdAt)).font(.caption)
                        Text(L10n.lookup(rule.summary))
                        ForEach(rule.config.levels) { level in
                            VStack(alignment: .leading, spacing: 5) {
                                Text("L\(level.code) " + L10n.lookup(level.name) + " · \(level.threshold)").font(.headline)
                                Text(L10n.text("指定商品") + " " + GrowthAPI.rate(level.goodsRateBps) + " · " + L10n.text("指定服务") + " " + GrowthAPI.rate(level.serviceRateBps))
                                Text(L10n.text("升级礼券") + " ¥" + GrowthAPI.money(level.couponMinimumCents) + " − ¥" + GrowthAPI.money(level.couponValueCents))
                                Text(L10n.lookup(level.benefit)).font(.caption)
                            }.padding(.vertical, 6)
                        }
                        ForEach(rule.config.tasks) { task in Text(GrowthAPI.label(task.kind) + " +\(task.award) · \(task.limit) " + L10n.lookup(task.period == "day" ? "每日" : task.period == "month" ? "每月" : "一次")) }
                        Text(L10n.text("周期任务月上限") + " \(rule.config.monthlyGrowthLimit)")
                        Text(L10n.text("月优惠上限") + " ¥" + GrowthAPI.money(rule.config.monthlyDiscountLimitCents))
                        Text(L10n.text("单单商品优惠上限") + " ¥" + GrowthAPI.money(rule.config.goodsDiscountCapCents))
                        Text(L10n.text("单单服务优惠上限") + " ¥" + GrowthAPI.money(rule.config.serviceDiscountCapCents))
                        Text(L10n.text("消费观察期") + " \(rule.config.observationDays) " + L10n.text("天") + " · " + L10n.text("礼券有效期") + " \(rule.config.couponDays) " + L10n.text("天"))
                        Text(L10n.text("成长值不可支付、兑换或转赠；随喜、运费、充值、押金、积分和模拟支付不计成长。折扣限已参与的商品和固定价服务，受服务方同意、预算及最低贡献约束。"))
                    }
                }
            }
            Section { HStack { Button(L10n.text("上一页")) { page -= 1; history = nil }.disabled(page == 1 || loading); Spacer(); Button(L10n.text("下一页")) { page += 1; history = nil }.disabled(history?.hasMore != true || loading) } }
        }.scrollContentBackground(.hidden).background(Color.bgPrimary).navigationTitle(L10n.text("成长规则与历史版本"))
            .task(id: "\(page)|\(phase)") {
                guard phase == .active else { return }
                while !Task.isCancelled { await load(); do { try await Task.sleep(for: .seconds(15)) } catch { return } }
            }.refreshable { await load() }
    }
    private static func stamp(_ seconds: Int64) -> String { let f = DateFormatter(); f.timeZone = TimeZone(identifier: "Asia/Shanghai"); f.dateFormat = "yyyy-MM-dd HH:mm"; return f.string(from: Date(timeIntervalSince1970: Double(seconds))) + " " + L10n.text("北京时间") }
    private func load() async {
        guard !loading else { return }; loading = true; defer { loading = false }; let requested = page
        do { let result: GrowthRuleHistory = try await GrowthAPI.request((provider ? "provider/rules" : publicRead ? "public/rules" : "rules") + "?page=\(requested)"); guard !Task.isCancelled, requested == page else { return }; history = result; error = nil }
        catch is CancellationError {} catch { if !Task.isCancelled { self.error = error.localizedDescription } }
    }
}
