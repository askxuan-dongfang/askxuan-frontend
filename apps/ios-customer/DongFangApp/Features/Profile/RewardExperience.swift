import SwiftUI

// MARK: - 积分活动：消耗积分参与，奖品由平台预算承担
struct RewardCampaign: Codable, Identifiable {
    let id: Int64
    let title, kind, prizeName, image, description, rules: String
    let prizeValue, budget, pointsCost: Int64
    let prizeQuantity, capacity, participantCount, awardedCount: Int
    let startsAt, endsAt, drawnAt: Int64
    let status, phase, poolDigest, announcement, algorithm: String
    var phaseText: String { ["draft":"草稿","scheduled":"即将开始","open":"参与中","exhausted":"奖品已抽完","full":"名额已满 · 等待截止","awaiting_draw":"正在开奖","drawn":"已结束","cancelled":"已取消"][phase] ?? phase }
    var isDemo: Bool { RewardDemoStore.isDemo(id) }
    var oddsText: String {
        if isDemo && kind == "wheel" { return "50.00%" }
        let n = kind == "pool" ? participantCount : capacity - participantCount
        let k = kind == "pool" ? min(prizeQuantity, n) : prizeQuantity - awardedCount
        return n > 0 ? String(format: "%.2f%%", Double(k) / Double(n) * 100) : "—"
    }
}
struct RewardEntry: Codable, Identifiable {
    var id, campaignId, createdAt, pointsSpent: Int64
    var code, outcome, title: String
    var isDemo: Bool { RewardDemoStore.isDemo(campaignId) }
    var outcomeText: String { ["pending":"等待开奖","won":"恭喜中奖","lost":"本期未中奖"][outcome] ?? outcome }
}
struct RewardOrder: Codable, Identifiable {
    var id, campaignId, entryId, createdAt, claimedAt, shippedAt, completedAt: Int64
    var prizeName, code, status, receiver, mobile, address, carrier, trackingNo: String
    var isDemo: Bool { RewardDemoStore.isDemo(campaignId) }
    var statusText: String { ["awaiting_address":"待填写地址","pending":"待发货","shipped":"已发货","completed":"已完成"][status] ?? status }
}
struct RewardDetail: Decodable { let campaign: RewardCampaign; var mine: RewardEntry?; let winners: [RewardEntry]; let pointsBalance: Int64 }
struct RewardAddressRequest: Encodable { let receiver, mobile, address: String }
func rewardDate(_ n: Int64) -> String {
    Date(timeIntervalSince1970: Double(n)).formatted(.dateTime.month().day().hour().minute())
}

/// Browser and native examples have independent wallets. No method here calls an API.
@MainActor final class RewardDemoStore {
    nonisolated static let wheelID: Int64 = -91001
    nonisolated static let poolID: Int64 = -91002
    nonisolated static func isDemo(_ id: Int64) -> Bool { id == wheelID || id == poolID }
    struct State: Codable {
        var balance: Int64 = 100
        var startsAt: Int64
        var endsAt: Int64
        var round = UUID().uuidString.prefix(8).uppercased()
        var entries: [RewardEntry] = []
        var orders: [RewardOrder] = []
        var poolDrawnAt: Int64? = nil
    }
    enum Failure: LocalizedError {
        case unavailable, insufficient, priceChanged, joinFirst
        var errorDescription: String? {
            switch self {
            case .unavailable: return "本轮示例已结束，请重置体验"
            case .insufficient: return "演示积分不足，请重置体验"
            case .priceChanged: return "参与积分已变化，请重新确认"
            case .joinFirst: return "请先参与示例奖池"
            }
        }
    }
    private let defaults: UserDefaults
    private let key: String
    private let clock: () -> Int64
    init(accountID: String, defaults: UserDefaults = .standard, clock: @escaping () -> Int64 = { Int64(Date().timeIntervalSince1970) }) {
        self.defaults = defaults; self.key = "reward-demo-v1:\(accountID)"; self.clock = clock
    }
    var state: State {
        if let data = defaults.data(forKey: key), let saved = try? JSONDecoder().decode(State.self, from: data) { return saved }
        let value = State(startsAt: clock(), endsAt: clock() + 72 * 3600)
        save(value); return value
    }
    private func save(_ state: State) { if let data = try? JSONEncoder().encode(state) { defaults.set(data, forKey: key) } }
    func reset() { save(State(startsAt: clock(), endsAt: clock() + 72 * 3600)) }
    func campaigns(kind: String? = nil) -> [RewardCampaign] {
        let s = state
        return [Self.wheelID, Self.poolID].map { id in campaign(id, state: s) }.filter { kind == nil || $0.kind == kind }
    }
    private func campaign(_ id: Int64, state s: State) -> RewardCampaign {
        let wheel = id == Self.wheelID, mine = s.entries.first { $0.campaignId == id }
        let drawn = mine != nil && (wheel || mine?.outcome != "pending")
        return RewardCampaign(id: id, title: wheel ? "草木香囊 · 幸运转盘" : "天然香珠 · 一期一礼", kind: wheel ? "wheel" : "pool", prizeName: wheel ? "平安香囊礼盒" : "天然香珠手串", image: "",
            description: wheel ? "一缕草木香，一份随身的平安。香囊与礼袋的组合，作为本期奖品样式演示。" : "温润的木色与一抹朱红，为日常留一份安静。体验手串奖品、参与码和开奖后的完整流程。",
            rules: "这是独立的交互示例，仅消耗演示积分，不扣真实积分、不发实物。每个示例每轮仅可参与一次，重置后可重新体验。" + (wheel ? "示例中奖概率为 50%，结果由本机随机产生。" : "不添加虚构参与者，只有你一人参与、一份演示奖品时，中奖概率为 100%。可在参与后提前预览开奖。"),
            prizeValue: wheel ? 5000 : 18000, budget: wheel ? 5000 : 18000, pointsCost: wheel ? 10 : 20, prizeQuantity: 1, capacity: wheel ? 2 : 100, participantCount: mine == nil ? 0 : 1, awardedCount: mine?.outcome == "won" ? 1 : 0,
            startsAt: s.startsAt, endsAt: s.endsAt, drawnAt: drawn ? (wheel ? (mine?.createdAt ?? 0) : (s.poolDrawnAt ?? mine?.createdAt ?? 0)) : 0, status: drawn ? "drawn" : "published", phase: drawn ? "drawn" : clock() >= s.endsAt ? (mine == nil ? "drawn" : "awaiting_draw") : "open", poolDigest: "", announcement: drawn ? "演示开奖已完成。下方为本设备的示例记录，不是正式活动公告。" : "", algorithm: "local-demo-only")
    }
    func detail(_ id: Int64) throws -> RewardDetail {
        guard Self.isDemo(id) else { throw Failure.unavailable }
        let s = state
        return RewardDetail(campaign: campaign(id, state: s), mine: s.entries.first { $0.campaignId == id }, winners: s.entries.filter { $0.campaignId == id && $0.outcome == "won" }, pointsBalance: s.balance)
    }
    func join(_ id: Int64, expectedPoints: Int64, randomWin: () -> Bool = { Bool.random() }) throws -> RewardEntry {
        guard Self.isDemo(id) else { throw Failure.unavailable }
        var s = state
        if let existing = s.entries.first(where: { $0.campaignId == id }) { return existing }
        let c = campaign(id, state: s)
        guard c.phase == "open" else { throw Failure.unavailable }
        guard c.pointsCost == expectedPoints else { throw Failure.priceChanged }
        guard s.balance >= c.pointsCost else { throw Failure.insufficient }
        let entry = RewardEntry(id: id, campaignId: id, createdAt: clock(), pointsSpent: c.pointsCost, code: "DEMO-\(c.kind == "wheel" ? "W" : "P")-\(s.round)", outcome: c.kind == "pool" ? "pending" : randomWin() ? "won" : "lost", title: c.title)
        s.balance -= c.pointsCost; s.entries.insert(entry, at: 0)
        if entry.outcome == "won" { award(entry, state: &s) }
        save(s); return entry
    }
    func draw() throws -> RewardEntry {
        var s = state
        guard let index = s.entries.firstIndex(where: { $0.campaignId == Self.poolID }) else { throw Failure.joinFirst }
        if s.entries[index].outcome == "pending" {
            s.entries[index].outcome = "won"; s.poolDrawnAt = clock()
            award(s.entries[index], state: &s); save(s)
        }
        return s.entries[index]
    }
    private func award(_ entry: RewardEntry, state s: inout State) {
        guard !s.orders.contains(where: { $0.entryId == entry.id }) else { return }
        s.orders.insert(RewardOrder(id: entry.id, campaignId: entry.campaignId, entryId: entry.id, createdAt: clock(), claimedAt: 0, shippedAt: 0, completedAt: 0, prizeName: campaign(entry.campaignId, state: s).prizeName, code: entry.code, status: "awaiting_address", receiver: "", mobile: "", address: "", carrier: "", trackingNo: ""), at: 0)
    }
    func advanceOrder(_ id: Int64) throws {
        var s = state
        guard let i = s.orders.firstIndex(where: { $0.id == id }) else { throw Failure.unavailable }
        switch s.orders[i].status {
        case "awaiting_address": s.orders[i].status = "pending"; s.orders[i].receiver = "演示收件人"; s.orders[i].address = "演示地址 · 无需填写真实信息"; s.orders[i].claimedAt = clock()
        case "pending": s.orders[i].status = "shipped"; s.orders[i].carrier = "演示物流"; s.orders[i].trackingNo = "DEMO-ONLY"; s.orders[i].shippedAt = clock()
        case "shipped": s.orders[i].status = "completed"; s.orders[i].completedAt = clock()
        default: break
        }
        save(s)
    }
}

struct RewardCategoryEntry: View {
    let kind: String
    var body: some View {
        NavigationLink { RewardsView(initialTab: kind == "wheel" ? 1 : 0) } label: {
            VStack(alignment: .leading, spacing: 8) {
                RewardGiftArt(kind: kind).frame(height: 100)
                Text(kind == "wheel" ? "积分转盘" : "大奖池").font(.headline)
                Text(kind == "wheel" ? "扣积分参与 · 即转即开" : "一期一码 · 截止开奖").font(.caption2).lineLimit(2, reservesSpace: true)
            }.foregroundStyle(Color.accentDefault).padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(colors: [.brown.opacity(0.4), Color.bgSecondary], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain).accessibilityIdentifier("reward-category-\(kind)")
    }
}

struct RewardGiftArt: View {
    let kind: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { proxy in
                let side = min(proxy.size.width, proxy.size.height)
                ZStack {
                    Circle().stroke(Color.accentDefault.opacity(0.2), lineWidth: 1).padding(side * 0.08)
                    gift.frame(width: side * 0.72, height: side * 0.72).offset(y: sin(t * 1.4) * 5)
                    ForEach(0..<3) { i in
                        Image(systemName: "sparkle").font(.system(size: i == 1 ? 18 : 10)).foregroundStyle(Color.accentDefault)
                            .opacity(reduceMotion ? 0.7 : 0.4 + 0.5 * abs(sin(t + Double(i))))
                            .offset(x: (i == 0 ? -0.38 : 0.36) * side, y: (Double(i) - 1) * side * 0.27)
                    }
                }.frame(width: proxy.size.width, height: proxy.size.height)
            }
        }.accessibilityHidden(true)
    }
    @ViewBuilder private var gift: some View {
        if kind == "wheel" {
            ZStack {
                RoundedRectangle(cornerRadius: 30).fill(LinearGradient(colors: [Color(red: 0.87, green: 0.69, blue: 0.43), .brown], startPoint: .topLeading, endPoint: .bottomTrailing)).rotationEffect(.degrees(-4)).padding(.top, 14)
                VStack(spacing: 2) {
                    Path { path in
                        path.move(to: CGPoint(x: 25, y: 17))
                        path.addCurve(to: CGPoint(x: 25, y: 17), control1: CGPoint(x: -12, y: -9), control2: CGPoint(x: 3, y: 32))
                        path.addCurve(to: CGPoint(x: 25, y: 17), control1: CGPoint(x: 62, y: -9), control2: CGPoint(x: 47, y: 32))
                    }.stroke(Color.accentDefault, style: StrokeStyle(lineWidth: 3, lineCap: .round)).frame(width: 50, height: 24)
                    Rectangle().fill(Color.bgPrimary.opacity(0.5)).frame(height: 5).padding(.horizontal, 12)
                    Text("安").font(.system(size: 36, design: .serif)).foregroundStyle(Color(red: 1, green: 0.88, blue: 0.66)).frame(maxHeight: .infinity)
                }
            }
        } else {
            GeometryReader { p in
                let side = min(p.size.width, p.size.height)
                ZStack {
                    ForEach(0..<14) { i in
                        let angle = Double(i) * .pi * 2 / 14
                        Circle().fill(LinearGradient(colors: [Color.accentDefault, i == 7 ? .red.opacity(0.55) : .brown], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .overlay(Circle().stroke(Color.accentDefault.opacity(0.6), lineWidth: 1))
                            .frame(width: side * 0.19, height: side * 0.19)
                            .offset(x: sin(angle) * side * 0.38, y: -cos(angle) * side * 0.38)
                    }
                    Text("缘").font(.system(size: 25, design: .serif)).foregroundStyle(Color.accentDefault)
                }.frame(width: p.size.width, height: p.size.height)
            }
        }
    }
}
struct RewardCountdown: View {
    let endsAt: Int64
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let seconds = max(0, endsAt - Int64(context.date.timeIntervalSince1970))
            HStack(spacing: 7) {
                Text(seconds == 0 ? "已截止" : "距离截止").foregroundStyle(.secondary)
                if seconds >= 86400 { Text("\(seconds / 86400) 天") }
                Text(String(format: "%02lld : %02lld : %02lld", seconds / 3600 % 24, seconds / 60 % 60, seconds % 60)).monospacedDigit().foregroundStyle(Color.accentDefault)
            }.font(.caption).padding(.vertical, 5).accessibilityElement(children: .combine)
        }
    }
}
private struct RewardWheelSector: Shape {
    let index: Int
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path(); path.move(to: center)
        path.addArc(center: center, radius: min(rect.width, rect.height) / 2, startAngle: .degrees(Double(index) * 45 - 112.5), endAngle: .degrees(Double(index) * 45 - 67.5), clockwise: false)
        path.closeSubpath(); return path
    }
}
struct RewardWheelArt: View {
    let rotation: Double
    let spinning: Bool
    let cost: Int64
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        GeometryReader { p in
            let size = min(p.size.width, p.size.height) - 20
            ZStack {
                ZStack {
                    ForEach(0..<8) { i in
                        RewardWheelSector(index: i).fill(i.isMultiple(of: 2) ? Color.accentDefault : Color.brown.opacity(0.75))
                        VStack(spacing: 4) {
                            Text(i.isMultiple(of: 2) ? "幸运好礼" : "下次有缘").font(.system(size: size < 250 ? 10 : 12, weight: .medium))
                            Image(systemName: i.isMultiple(of: 2) ? "gift.fill" : "sparkle").font(.caption)
                        }.foregroundStyle(i.isMultiple(of: 2) ? Color.bgPrimary : Color.white.opacity(0.85))
                            .offset(y: -size * 0.34).rotationEffect(.degrees(Double(i) * 45))
                    }
                    Circle().stroke(Color.accentDefault, lineWidth: 10)
                }.rotationEffect(.degrees(rotation)).accessibilityIdentifier("reward-wheel-disc")
                ForEach(0..<20) { i in
                    Circle().fill(Color(red: 1, green: 0.92, blue: 0.74)).frame(width: 4, height: 4).offset(y: -size / 2).rotationEffect(.degrees(Double(i) * 18))
                }
                Circle().fill(Color.accentDefault).frame(width: 72, height: 72).overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 4))
                VStack(spacing: 3) { Text(spinning ? "✦" : "\(cost)").font(.title2.bold()); Text(spinning ? "揭晓中" : "积分 / 次").font(.system(size: 10)) }.foregroundStyle(Color.bgPrimary)
                Image(systemName: "arrowtriangle.down.fill").font(.title).foregroundStyle(Color(red: 1, green: 0.9, blue: 0.7)).offset(y: -size / 2 - 4)
            }.frame(width: size, height: size).frame(width: p.size.width, height: p.size.height)
        }.accessibilityElement(children: .ignore).accessibilityLabel(spinning ? "转盘正在减速揭晓" : "八格积分转盘，扇区面积不代表概率")
    }
}

struct RewardCampaignCard: View {
    let campaign: RewardCampaign
    var body: some View {
        let c = campaign
        NavigationLink { RewardDetailView(id: c.id) } label: {
            VStack(alignment: .leading, spacing: 12) {
                ZStack(alignment: .topLeading) {
                    if let url = URL(string: c.image), !c.image.isEmpty {
                        AsyncImage(url: url) { image in image.resizable().scaledToFit() } placeholder: { RewardGiftArt(kind: c.kind) }
                    } else { RewardGiftArt(kind: c.kind) }
                    Text(c.isDemo ? "体验示例" : c.phaseText).font(.caption2.bold()).padding(8).background(Color.bgPrimary.opacity(0.85), in: Capsule())
                }.frame(height: 190).padding(8).background(Color.accentDefault.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                Text(c.title).font(.title3.bold()).foregroundStyle(Color.textPrimary)
                Text("\(c.prizeName) × \(c.prizeQuantity)").font(.subheadline)
                ProgressView(value: Double(c.participantCount), total: Double(c.capacity)).tint(Color.accentDefault)
                HStack { Text("\(c.participantCount) 人已参与\(c.isDemo ? "（本机）" : "")"); Spacer(); Text("限 \(c.capacity) 人") }.font(.caption)
                RewardCountdown(endsAt: c.endsAt)
                HStack {
                    Text(c.isDemo ? "不扣真实积分 · 不发实物" : "\(c.pointsCost) 积分参与").font(.caption2)
                    Spacer(); Text(c.isDemo ? "立即体验 →" : "查看详情 →").font(.caption.bold())
                }
            }.foregroundStyle(Color.accentDefault).padding(.vertical, 8)
        }.accessibilityIdentifier("reward-campaign-\(c.id)")
    }
}
struct RewardDemoBanner: View {
    let balance: Int64
    let busy: Bool
    let reset: () -> Void
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 7) {
                Text("先体验一份惊喜").font(.headline).foregroundStyle(Color.accentDefault)
                Text("演示余额 \(balance) 积分 · 仅在本设备保存").font(.caption).accessibilityIdentifier("reward-demo-balance")
                Text("示例不扣真实积分、不发实物；正式活动按配置扣积分。").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button("重置体验", action: reset).font(.caption).buttonStyle(.bordered).tint(Color.accentDefault).disabled(busy)
        }.padding(.vertical, 6)
    }
}
struct RewardsView: View {
    init(initialTab: Int = 0) { _tab = State(initialValue: initialTab) }
    @EnvironmentObject private var auth: AuthStore
    @State private var tab: Int
    @State private var page = 1
    @State private var campaigns: [RewardCampaign] = []
    @State private var entries: [RewardEntry] = []
    @State private var orders: [RewardOrder] = []
    @State private var demoBalance: Int64 = 100
    @State private var loading = false
    @State private var error: String?
    @State private var claim: RewardOrder?
    @State private var completing: RewardOrder?
    @State private var resetting = false
    private var store: RewardDemoStore { RewardDemoStore(accountID: auth.userId) }
    private var count: Int { tab < 2 ? campaigns.count : tab == 2 ? entries.count : orders.count }
    private var realCount: Int { tab < 2 ? campaigns.filter { !$0.isDemo }.count : tab == 2 ? entries.filter { !$0.isDemo }.count : orders.filter { !$0.isDemo }.count }
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("A GIFT, A LITTLE JOY").font(.caption2).tracking(2).foregroundStyle(Color.accentDefault)
                    Text("把小欢喜，留给有缘的你").font(.system(size: 26, weight: .semibold, design: .serif))
                    Text("用积分参与，让每一期多一份期待。").font(.subheadline).foregroundStyle(.secondary)
                }.padding(.vertical, 12)
            }.listRowBackground(Color.accentDefault.opacity(0.1))
            Picker("活动分类", selection: $tab) {
                Text("大奖池").tag(0); Text("转盘").tag(1); Text("参与记录").tag(2); Text("我的奖品").tag(3)
            }.pickerStyle(.segmented).disabled(loading)
            RewardDemoBanner(balance: demoBalance, busy: loading) { resetting = true }
            if let error { Section { Text(error).font(.caption).foregroundStyle(.red); Button("重新加载") { Task { await load() } } } }
            if loading { ProgressView("正在准备活动…") }
            if tab < 2 { ForEach(campaigns) { RewardCampaignCard(campaign: $0) } }
            else if tab == 2 {
                ForEach(entries) { e in
                    NavigationLink { RewardDetailView(id: e.campaignId) } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            if e.isDemo { Text("体验示例").font(.caption2).foregroundStyle(Color.accentDefault) }
                            HStack { Text(e.title); Spacer(); Text(e.outcomeText).foregroundStyle(Color.accentDefault) }
                            Text(e.code).font(.system(.subheadline, design: .monospaced))
                            Text("消耗 \(e.pointsSpent) \(e.isDemo ? "演示" : "")积分 · \(rewardDate(e.createdAt))").font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 8)
                    }
                }
            } else { ForEach(orders) { orderCard($0) } }
            if !loading && count == 0 {
                ContentUnavailableView(tab == 2 ? "还没有参与记录" : tab == 3 ? "还没有中奖礼物" : "暂无更多活动", systemImage: "gift", description: Text("每次参与都会保留参与码与结果。"))
            }
            if page > 1 || realCount >= 20 {
                HStack { Button("上一页") { page -= 1 }.disabled(page == 1 || loading); Spacer(); Text("第 \(page) 页"); Spacer(); Button("下一页") { page += 1 }.disabled(realCount < 20 || loading) }.font(.caption)
            }
            Text("功德值独立记录成长，与活动概率无关。").font(.caption).foregroundStyle(.secondary)
        }
        .navigationTitle("积分活动").navigationBarTitleDisplayMode(.inline)
        .task(id: "\(tab)-\(page)-\(auth.userId)") { await load() }
        .onChange(of: tab) { _, _ in page = 1 }
        .refreshable { await load() }
        .sheet(item: $claim, onDismiss: { Task { await load() } }) { RewardClaimSheet(order: $0) }
        .alert("重置体验？", isPresented: $resetting) {
            Button("取消", role: .cancel) {}
            Button("重置示例", role: .destructive) { store.reset(); Task { await load() } }
        } message: { Text("清除本设备当前账号的两项示例记录，演示积分恢复为 100。正式积分和活动记录不受影响。") }
        .alert("确认已收到奖品？", isPresented: Binding(get: { completing != nil }, set: { if !$0 { completing = nil } })) {
            Button("取消", role: .cancel) { completing = nil }
            Button("确认收货") { if let o = completing { Task { await complete(o) } } }
        } message: { Text("确认后本次实物领奖流程完成。") }
    }
    private func orderCard(_ o: RewardOrder) -> some View {
        Section {
            if o.isDemo { Text("体验示例 · 不发实物").font(.caption2).foregroundStyle(Color.accentDefault) }
            HStack { Text(o.prizeName).font(.headline); Spacer(); Text(o.statusText).foregroundStyle(Color.accentDefault) }
            NavigationLink("中奖码 \(o.code)") { RewardDetailView(id: o.campaignId) }.font(.caption)
            RewardDeliverySteps(status: o.status)
            if !o.address.isEmpty { Text("\(o.receiver)\n\(o.address)").font(.subheadline) }
            if !o.mobile.isEmpty { Text(o.mobile).font(.subheadline) }
            if !o.trackingNo.isEmpty { Text("物流：\(o.carrier) · \(o.trackingNo)").font(.caption).textSelection(.enabled) }
            if o.claimedAt > 0 { Label("提交地址 \(rewardDate(o.claimedAt))", systemImage: "mappin.circle").font(.caption) }
            if o.shippedAt > 0 { Label("发货 \(rewardDate(o.shippedAt))", systemImage: "shippingbox").font(.caption) }
            if o.completedAt > 0 { Label("已完成 \(rewardDate(o.completedAt))", systemImage: "checkmark.circle").font(.caption) }
            if o.isDemo && o.status != "completed" {
                Button(o.status == "awaiting_address" ? "使用演示地址领取" : o.status == "pending" ? "模拟发货" : "模拟确认收货") { Task { await advanceDemo(o) } }.buttonStyle(.borderedProminent).disabled(loading)
            } else if !o.isDemo && o.status == "awaiting_address" {
                Button("填写收货地址") { claim = o }.buttonStyle(.borderedProminent)
            } else if !o.isDemo && o.status == "shipped" { Button("确认收货") { completing = o }.disabled(loading) }
        }.tint(Color.accentDefault)
    }
    @MainActor private func load() async {
        loading = true; error = nil; defer { loading = false }
        demoBalance = store.state.balance
        campaigns = page == 1 && tab < 2 ? store.campaigns(kind: tab == 0 ? "pool" : "wheel") : []
        entries = page == 1 ? store.state.entries : []; orders = page == 1 ? store.state.orders : []
        guard auth.isLoggedIn else { return }
        do {
            if tab < 2 { let real: [RewardCampaign] = try await APIClient.shared.request(.rewardCampaigns(page, tab == 0 ? "pool" : "wheel")); campaigns = real + campaigns }
            else if tab == 2 { let real: [RewardEntry] = try await APIClient.shared.request(.rewardEntries(page)); entries += real }
            else { let real: [RewardOrder] = try await APIClient.shared.request(.rewardOrders(page)); orders += real }
        } catch is CancellationError {} catch { self.error = "正式活动暂未加载成功，仍可体验示例。\n\(error.localizedDescription)" }
    }
    @MainActor private func advanceDemo(_ o: RewardOrder) async {
        do { try store.advanceOrder(o.id); await load() } catch { self.error = error.localizedDescription }
    }
    @MainActor private func complete(_ o: RewardOrder) async {
        loading = true; defer { loading = false }
        do { let _: PointsActionResult = try await APIClient.shared.request(.rewardComplete(o.id)); completing = nil; await load() } catch { self.error = error.localizedDescription }
    }
}
struct RewardDeliverySteps: View {
    let status: String
    private let steps = ["awaiting_address", "pending", "shipped", "completed"]
    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                VStack(spacing: 8) {
                    Capsule().fill(index <= (steps.firstIndex(of: status) ?? 0) ? Color.accentDefault : Color.gray.opacity(0.2)).frame(height: 3)
                    Text(["中奖", "待发货", "已发货", "完成"][index]).font(.caption2)
                }.foregroundStyle(index <= (steps.firstIndex(of: status) ?? 0) ? Color.accentDefault : .secondary)
            }
        }.padding(.vertical, 12).accessibilityElement(children: .combine)
    }
}

struct RewardDetailView: View {
    let id: Int64
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var detail: RewardDetail?
    @State private var error: String?
    @State private var busy = false
    @State private var spinning = false
    @State private var confirming = false
    @State private var resetting = false
    @State private var rotation = 0.0
    @State private var motionID = 0
    @State private var result: RewardEntry?
    @State private var actionTask: Task<Void, Never>?
    private var isDemo: Bool { RewardDemoStore.isDemo(id) }
    private var store: RewardDemoStore { RewardDemoStore(accountID: auth.userId) }
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 18) {
                    if isDemo { RewardDemoBanner(balance: detail?.pointsBalance ?? store.state.balance, busy: busy) { resetting = true }.rewardPanel() }
                    if let error { VStack { Text(error).font(.caption).foregroundStyle(.red); Button("重新加载") { Task { await load() } } }.rewardPanel() }
                    if let d = detail {
                        hero(d).id("reward-art")
                        facts(d).rewardPanel()
                        if let mine = d.mine { ticket(mine).rewardPanel() }
                        rules(d).rewardPanel()
                        if !d.campaign.announcement.isEmpty || !d.winners.isEmpty { announcement(d).rewardPanel() }
                    } else if error == nil { ProgressView("正在准备活动…").padding(40) }
                }.padding(16)
            }.onChange(of: motionID) { _, _ in
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) { proxy.scrollTo("reward-art", anchor: .top) }
            }
        }
        .background(Color.bgPrimary)
        .safeAreaInset(edge: .bottom) { if let d = detail { actionBar(d) } }
        .navigationTitle("活动详情").navigationBarTitleDisplayMode(.inline)
        .task(id: "\(id)-\(auth.userId)") {
            await load()
            while !Task.isCancelled { do { try await Task.sleep(for: .seconds(15)) } catch { return }; if !busy { await load() } }
        }
        .refreshable { if !busy { await load() } }
        .onDisappear { actionTask?.cancel() }
        .alert(isDemo ? "确认演示参与？" : "确认扣除积分参与？", isPresented: $confirming) {
            Button("再想想", role: .cancel) {}
            Button("确认扣除 \(detail?.campaign.pointsCost ?? 0) 积分") { actionTask = Task { await participate() } }
        } message: {
            Text("当前可用 \(detail?.pointsBalance ?? 0) \(isDemo ? "演示" : "")积分，本次消耗 \(detail?.campaign.pointsCost ?? 0) 积分。" + (isDemo ? "仅扣演示积分，不扣真实积分、不发实物。" : "参与成功后无论中奖与否均不退回；失败不扣分，重复请求不重复扣分。"))
        }
        .alert("重置体验？", isPresented: $resetting) {
            Button("取消", role: .cancel) {}
            Button("重置示例", role: .destructive) { store.reset(); rotation = 0; result = nil; Task { await load() } }
        } message: { Text("清除两项本机示例记录，恢复 100 演示积分。正式积分和活动不受影响。") }
        .sheet(item: $result) { entry in RewardResultSheet(entry: entry).presentationDetents([.height(440)]).presentationDragIndicator(.visible) }
    }
    private func hero(_ d: RewardDetail) -> some View {
        VStack(spacing: 16) {
            Text("\(d.campaign.kind == "wheel" ? "LUCKY WHEEL" : "THE PRIZE POOL") · \(isDemo ? "体验示例" : "第 \(id) 期")").font(.caption2).tracking(2).foregroundStyle(Color.accentDefault)
            Text(d.campaign.title).font(.system(size: 26, weight: .semibold, design: .serif)).multilineTextAlignment(.center)
            Text(d.campaign.phaseText).font(.caption).padding(.horizontal, 12).padding(.vertical, 6).background(Color.accentDefault.opacity(0.15), in: Capsule())
            if d.campaign.kind == "wheel" {
                RewardWheelArt(rotation: spinning ? rotation : (d.mine?.outcome == "lost" ? 315 : 0), spinning: spinning, cost: d.campaign.pointsCost).frame(height: 280)
            } else {
                ZStack {
                    if let url = URL(string: d.campaign.image), !d.campaign.image.isEmpty {
                        AsyncImage(url: url) { image in image.resizable().scaledToFit() } placeholder: { RewardGiftArt(kind: "pool") }
                    } else { RewardGiftArt(kind: "pool") }
                    if spinning {
                        VStack(spacing: 16) {
                            Image(systemName: "sparkle").font(.system(size: 52)).symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)
                            Text(d.mine == nil ? "正在生成参与码" : "正在揭晓幸运码").font(.headline)
                            Text("✧ · ✦ · ✧").font(.title2)
                        }.foregroundStyle(Color.accentDefault).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.bgPrimary.opacity(0.9), in: RoundedRectangle(cornerRadius: 18))
                    }
                }.frame(height: 240)
            }
            Text("\(d.campaign.prizeName) × \(d.campaign.prizeQuantity)").font(.headline)
            Text("\(isDemo ? "体验示例" : "平台提供") · \(d.campaign.pointsCost) \(isDemo ? "演示" : "")积分参与 · \(isDemo ? "不发实物" : "实物包邮")").font(.caption).foregroundStyle(.secondary)
        }.padding(18).frame(maxWidth: .infinity).background(LinearGradient(colors: [Color.brown.opacity(0.4), Color.bgSecondary], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 22))
    }
    private func facts(_ d: RewardDetail) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                fact("已参与人数", "\(d.campaign.participantCount)"); Spacer()
                fact("奖品数量", "\(d.campaign.prizeQuantity)"); Spacer()
                fact(d.campaign.kind == "pool" ? "按当前人数估算" : isDemo ? "示例中奖概率" : "下一位即时概率", d.campaign.oddsText)
            }
            ProgressView(value: Double(d.campaign.participantCount), total: Double(d.campaign.capacity)).tint(Color.accentDefault)
            Text("\(isDemo ? "示例进度 · 本机记录" : "活动进度") · \(d.campaign.participantCount) / \(d.campaign.capacity) 人").font(.caption)
            RewardCountdown(endsAt: d.campaign.endsAt)
            Text("开始：\(rewardDate(d.campaign.startsAt))\n截止：\(rewardDate(d.campaign.endsAt))").font(.caption).foregroundStyle(.secondary)
            Text(d.campaign.kind == "pool" ? (isDemo ? "示例参与后可提前预览开奖，无需等待截止。" : "截止后自动开奖，不需要等满额。最终概率为 min(奖品数量, 有效人数) ÷ 有效人数；100 人抽 1 人，每人为 1%。") : "扇区仅作动画展示，不代表概率。正式活动当前概率 = 剩余奖品 ÷ 剩余名额。").font(.caption).foregroundStyle(.secondary)
        }
    }
    private func fact(_ title: String, _ value: String) -> some View {
        VStack(spacing: 7) { Text(value).font(.title3.bold()).foregroundStyle(Color.accentDefault); Text(title).font(.system(size: 10)).foregroundStyle(.secondary) }
    }
    private func ticket(_ e: RewardEntry) -> some View {
        VStack(spacing: 14) {
            Text(isDemo ? "我的演示参与码" : "我的专属参与码").font(.caption)
            Text(e.code).font(.system(.title3, design: .monospaced)).foregroundStyle(Color.accentDefault).textSelection(.enabled)
            Text(spinning ? "正在揭晓…" : e.outcomeText).font(.headline)
            Text("消耗 \(e.pointsSpent) \(isDemo ? "演示" : "")积分 · \(rewardDate(e.createdAt))").font(.caption).foregroundStyle(.secondary)
            if isDemo && id == RewardDemoStore.poolID && e.outcome == "pending" {
                Button("预览本期开奖") { actionTask = Task { await previewDraw() } }.buttonStyle(.borderedProminent).disabled(busy)
            }
            if e.outcome == "won" && !spinning { NavigationLink("查看我的奖品并领奖") { RewardsView(initialTab: 3) }.buttonStyle(.borderedProminent) }
        }.frame(maxWidth: .infinity).tint(Color.accentDefault)
    }
    private func rules(_ d: RewardDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("这一份礼物").font(.headline); Text(d.campaign.description).font(.subheadline)
            Text("参与规则").font(.headline); Text(d.campaign.rules).font(.subheadline)
            if !isDemo { Text("每个账号每期一次，消耗 \(d.campaign.pointsCost) 积分；成功参与后无论中奖与否均不退回。请求失败不扣分，重复点击不重复扣分。奖品预算由平台承担，功德值不变。").font(.caption).foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func announcement(_ d: RewardDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("开奖公告").font(.headline)
            Text(d.campaign.announcement.isEmpty ? "本期实时中奖码，活动结束后归档。" : d.campaign.announcement).font(.subheadline)
            if d.campaign.drawnAt > 0 { Text("实际开奖 \(rewardDate(d.campaign.drawnAt))").font(.caption) }
            ForEach(d.winners) { Text($0.code).font(.system(.caption, design: .monospaced)).foregroundStyle(Color.accentDefault).textSelection(.enabled) }
            if !d.campaign.poolDigest.isEmpty {
                DisclosureGroup("开奖留档信息") { Text(d.campaign.algorithm); Text("参与码按创建顺序以换行分隔，SHA-256："); Text(d.campaign.poolDigest).textSelection(.enabled) }.font(.caption)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func actionBar(_ d: RewardDetail) -> some View {
        VStack(spacing: 8) {
            Text(d.mine != nil ? (isDemo ? "本轮已体验，可重置再玩一次" : "本期已参与，记录保留") : "可用 \(d.pointsBalance) \(isDemo ? "演示" : "")积分 · 每期一次").font(.caption).foregroundStyle(.secondary)
            Button(busy ? "正在揭晓…" : d.mine != nil ? "本期已参与" : d.campaign.phase != "open" ? d.campaign.phaseText : d.pointsBalance < d.campaign.pointsCost ? "积分不足" : "\(d.campaign.pointsCost) 积分\(d.campaign.kind == "wheel" ? "转一次" : "参与奖池")") { confirming = true }
                .buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity).tint(Color.accentDefault)
                .disabled(busy || d.mine != nil || d.campaign.phase != "open" || error != nil || d.pointsBalance < d.campaign.pointsCost || d.campaign.pointsCost < 1)
        }.padding(.horizontal, 16).padding(.vertical, 10).frame(maxWidth: .infinity).background(Color.bgPrimary).overlay(alignment: .top) { Rectangle().fill(Color.accentDefault.opacity(0.2)).frame(height: 1) }
    }
    @MainActor private func load() async {
        do {
            detail = isDemo ? try store.detail(id) : try await APIClient.shared.request(.rewardDetail(id))
            error = nil
            if !spinning { rotation = detail?.mine?.outcome == "lost" ? 315 : 0 }
        } catch is CancellationError {} catch { self.error = error.localizedDescription }
    }
    @MainActor private func participate() async {
        guard !busy, let c = detail?.campaign else { return }
        busy = true; error = nil; defer { busy = false; spinning = false }
        do {
            let entry: RewardEntry = isDemo ? try store.join(id, expectedPoints: c.pointsCost) : try await APIClient.shared.request(.rewardJoin(id, c.pointsCost))
            try Task.checkCancellation(); spinning = true; motionID += 1
            if c.kind == "wheel" {
                let target = entry.outcome == "won" ? 0.0 : 315.0
                withAnimation(reduceMotion ? nil : .timingCurve(0.12, 0.64, 0.1, 1, duration: 3.7)) { rotation += 2520 + (target - rotation.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) }
                if !reduceMotion { try await Task.sleep(for: .milliseconds(3700)) }
            } else if !reduceMotion { try await Task.sleep(for: .milliseconds(1400)) }
            try Task.checkCancellation(); await load(); result = entry
        } catch is CancellationError {} catch { self.error = error.localizedDescription }
    }
    @MainActor private func previewDraw() async {
        guard isDemo, !busy else { return }
        busy = true; spinning = true; motionID += 1; defer { busy = false; spinning = false }
        do { if !reduceMotion { try await Task.sleep(for: .milliseconds(2600)) }; try Task.checkCancellation(); let entry = try store.draw(); await load(); result = entry }
        catch is CancellationError {} catch { self.error = error.localizedDescription }
    }
}
private extension View {
    func rewardPanel() -> some View { padding(18).frame(maxWidth: .infinity).background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.accentDefault.opacity(0.16), lineWidth: 1)) }
}
struct RewardResultSheet: View {
    let entry: RewardEntry
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appear = false
    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()
            if entry.outcome == "won" && !reduceMotion {
                GeometryReader { p in
                    ForEach(0..<22) { i in
                        Rectangle().fill([Color.accentDefault, .brown, .orange.opacity(0.7)][i % 3]).frame(width: 6, height: 12)
                            .rotationEffect(.degrees(appear ? Double(i * 23 + 420) : 0))
                            .position(x: CGFloat(i * 47 % 100) / 100 * p.size.width, y: appear ? p.size.height + 15 : -15)
                            .opacity(appear ? 0 : 1).animation(.easeOut(duration: 2).delay(Double(i % 6) * 0.09), value: appear)
                    }
                }.allowsHitTesting(false).accessibilityHidden(true)
            }
            VStack(spacing: 18) {
                Image(systemName: entry.outcome == "won" ? "sparkles" : entry.outcome == "pending" ? "ticket.fill" : "sparkle").font(.system(size: 48)).foregroundStyle(Color.accentDefault).scaleEffect(appear ? 1 : 0.6)
                Text(entry.isDemo ? "DEMO EXPERIENCE" : "A LITTLE JOY").font(.caption2).tracking(2).foregroundStyle(Color.accentDefault)
                Text(entry.outcomeText).font(.title2.bold())
                Text(entry.outcome == "pending" ? "参与码已为你生成，静候这一期的惊喜。" : entry.outcome == "won" ? "这份小欢喜，属于你。" : "谢谢参与，愿下一份好运与你相逢。").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Text(entry.code).font(.system(.subheadline, design: .monospaced)).foregroundStyle(Color.accentDefault)
                Text("已扣 \(entry.pointsSpent) \(entry.isDemo ? "演示" : "")积分\(entry.isDemo ? " · 不发实物" : "")").font(.caption)
                Button("收好这份期待") { dismiss() }.buttonStyle(.borderedProminent).controlSize(.large).tint(Color.accentDefault)
            }.padding(24)
        }.onAppear { withAnimation(reduceMotion ? nil : .spring(duration: 0.5)) { appear = true } }
    }
}

struct RewardClaimSheet:View {
    let order:RewardOrder
    @Environment(\.dismiss) private var dismiss
    @State private var receiver=""
    @State private var mobile=""
    @State private var address=""
    @State private var busy=false
    @State private var error:String?
    var body:some View { NavigationStack { Form { Section(order.prizeName) { Text("平台包邮，填写地址后进入待发货。").font(.subheadline);Text(order.code).font(.caption) };Section("收货信息") { TextField("收货人",text:$receiver).textContentType(.name);TextField("联系电话",text:$mobile).keyboardType(.phonePad).textContentType(.telephoneNumber);TextField("省市区、街道与门牌号",text:$address,axis:.vertical).textContentType(.fullStreetAddress).lineLimit(3...5) }.disabled(busy);if let error {Text(error).foregroundStyle(.red)};Section { Text("提交后请等待平台发货，请先核对地址和联系电话。").font(.caption);Button(busy ? "提交中…":"确认地址，等待发货") {Task{await submit()}}.disabled(busy||receiver.trimmingCharacters(in:.whitespaces).isEmpty||mobile.count<6||address.count<5) } }.navigationTitle("领奖地址").navigationBarTitleDisplayMode(.inline).toolbar {ToolbarItem(placement:.cancellationAction){Button("稍后填写"){dismiss()}.disabled(busy)}}.interactiveDismissDisabled(busy) } }
    @MainActor private func submit()async {busy=true;error=nil;defer{busy=false};do{let _:PointsActionResult=try await APIClient.shared.request(.rewardClaim(order.id,RewardAddressRequest(receiver:receiver.trimmingCharacters(in:.whitespacesAndNewlines),mobile:mobile.trimmingCharacters(in:.whitespacesAndNewlines),address:address.trimmingCharacters(in:.whitespacesAndNewlines))));dismiss()}catch{self.error=error.localizedDescription}}
}
