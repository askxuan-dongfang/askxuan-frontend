import SwiftUI

// MARK: - 积分活动：消耗积分参与，奖品由平台预算承担
struct RewardPrize: Codable, Identifiable {
    let id: Int64
    let name, kind, image: String
    let value: Int64
    let quantity, awardedCount: Int
    let platform, instructions: String
    let expiresAt: Int64
    let redemptionUrl: String
    var probabilityBps: Int? = nil
    var kindText: String { ["physical":"实物奖品", "code":"兑换码", "link":"兑换券"][kind] ?? kind }
}
func rewardWheelSlots(prizes: [RewardPrize], configured: [Int]? = nil) -> [Int] {
    if let configured, configured.count == 10, configured.allSatisfy({ $0 == -1 || prizes.indices.contains($0) }) { return configured }
    let hasLoss = !prizes.allSatisfy { $0.probabilityBps != nil } || prizes.reduce(0, { $0 + ($1.probabilityBps ?? 0) }) < 10000
    let base = Array(prizes.indices) + (hasLoss ? [-1] : [])
    return (0..<10).map { base.isEmpty ? -1 : base[$0 % base.count] }
}
struct RewardJoinRequest: Encodable { let expectedPoints: Int64; let requestKey: String }
struct RewardRedemption: Decodable {
    let code, url, platform, instructions: String
    let expiresAt: Int64
    var safeURL: URL? {
        guard let parsed = URL(string: url), parsed.scheme == "https", let host = parsed.host, !host.isEmpty, parsed.user == nil, parsed.password == nil else { return nil }
        return parsed
    }
}
struct RewardCampaign: Codable, Identifiable {
    let id: Int64
    let title, kind, prizeName, image, description, rules: String
    let prizeValue, budget, pointsCost: Int64
    let prizeQuantity, capacity, participantCount, awardedCount: Int
    let startsAt, endsAt, drawnAt: Int64
    let status, phase, poolDigest, announcement, algorithm: String
    var prizes: [RewardPrize]? = nil
    var wheelSlots: [Int]? = nil
    var displayPrizes: [RewardPrize] {
        if let prizes, !prizes.isEmpty { return prizes }
        return [RewardPrize(id: 0, name: prizeName, kind: "physical", image: image, value: prizeValue, quantity: prizeQuantity, awardedCount: awardedCount, platform: "", instructions: "", expiresAt: 0, redemptionUrl: "")]
    }
    var displaySlots: [Int] { rewardWheelSlots(prizes: displayPrizes, configured: wheelSlots) }
    func wheelAngle(for entry: RewardEntry?) -> Double {
        guard let entry else { return 0 }
        let matches = displaySlots.indices.filter { index in
            let slot = displaySlots[index]
            return entry.outcome == "won" ? slot >= 0 && displayPrizes[slot].id == (entry.prizeId ?? 0) : slot == -1
        }
        guard !matches.isEmpty else { return 0 }
        let index = matches[Int(entry.id % Int64(matches.count))]
        return (360 - Double(index) * 36).truncatingRemainder(dividingBy: 360)
    }
    var phaseText: String { ["draft":"草稿","scheduled":"即将开始","open":"参与中","exhausted":"本期已结束","paused":"本期暂不可参与","full":"名额已满 · 等待截止","awaiting_draw":"正在开奖","drawn":"已结束","cancelled":"已取消"][phase] ?? phase }
    var hasFixedOdds: Bool { !displayPrizes.isEmpty && displayPrizes.allSatisfy { $0.probabilityBps != nil } }
    func probability(for prize: RewardPrize) -> Double? {
        if hasFixedOdds, let bps = prize.probabilityBps { return Double(bps) / 100 }
        guard capacity > participantCount else { return nil }
        return Double(max(0, prize.quantity - prize.awardedCount)) / Double(capacity - participantCount) * 100
    }
    var noPrizeProbability: Double? {
        if hasFixedOdds { return Double(10000 - displayPrizes.reduce(0) { $0 + ($1.probabilityBps ?? 0) }) / 100 }
        guard capacity > participantCount else { return nil }
        return max(0, 100 - Double(prizeQuantity - awardedCount) / Double(capacity - participantCount) * 100)
    }
    var oddsText: String {
        if hasFixedOdds { return rewardProbabilityText(100 - (noPrizeProbability ?? 100)) }
        let n = kind == "pool" ? participantCount : capacity - participantCount
        let k = kind == "pool" ? min(prizeQuantity, n) : prizeQuantity - awardedCount
        return n > 0 ? String(format: "%.2f%%", Double(k) / Double(n) * 100) : "—"
    }
}
struct RewardEntry: Codable, Identifiable {
    var id, campaignId, createdAt, pointsSpent: Int64
    var code, outcome, title: String
    var prizeId: Int64? = nil
    var prizeName: String? = nil
    var outcomeText: String { ["pending":"等待开奖","won":"恭喜中奖","lost":"本期未中奖"][outcome] ?? outcome }
}
struct RewardOrder: Codable, Identifiable {
    var id, campaignId, entryId, createdAt, claimedAt, shippedAt, completedAt: Int64
    var prizeName, code, status, receiver, mobile, address, carrier, trackingNo: String
    var prizeId: Int64? = nil
    var prizeKind: String? = nil
    var platform: String? = nil
    var instructions: String? = nil
    var expiresAt: Int64? = nil
    var redemptionUrl: String? = nil
    var isDigital: Bool { prizeKind == "code" || prizeKind == "link" }
    var statusText: String { ["awaiting_address":"待填写地址","pending":"待发货","shipped":"已发货","completed":"已完成","delivered":"已发放"][status] ?? status }
}
struct RewardDetail: Decodable { let campaign: RewardCampaign; var mine: RewardEntry?; let winners: [RewardEntry]; let pointsBalance: Int64 }
struct RewardAddressRequest: Encodable { let receiver, mobile, address: String }
func rewardProbabilityText(_ value: Double?) -> String {
    guard let value else { return "—" }
    return value.formatted(.number.precision(.fractionLength(0...2)).locale(Locale(identifier: "en_US_POSIX"))) + "%"
}
func rewardDate(_ n: Int64) -> String {
    Date(timeIntervalSince1970: Double(n)).formatted(.dateTime.month().day().hour().minute())
}

struct RewardCategoryEntry: View {
    let kind: String
    @State private var showActivity = false
    var body: some View {
        Button { showActivity = true } label: {
            VStack(alignment: .leading, spacing: 8) {
                RewardGiftArt(kind: kind).frame(height: 100)
                Text(kind == "wheel" ? "积分转盘" : "大奖池").font(.headline)
                Text(kind == "wheel" ? "扣积分参与 · 即转即开" : "一期一码 · 截止开奖").font(.caption2).lineLimit(2, reservesSpace: true)
            }.foregroundStyle(Color.accentDefault).padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(colors: [.brown.opacity(0.4), Color.bgSecondary], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain).accessibilityIdentifier("reward-category-\(kind)")
            .navigationDestination(isPresented: $showActivity) { RewardsView(initialTab: kind == "wheel" ? 1 : 0) }
    }
}

struct RewardGiftArt: View {
    let kind: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: true)) { _ in
            let t: Double = 0
            GeometryReader { proxy in
                let side = min(proxy.size.width, proxy.size.height)
                ZStack {
                    Circle().stroke(Color(hex: "C8A96E").opacity(0.2), lineWidth: 1).padding(side * 0.08)
                    gift.frame(width: side * 0.72, height: side * 0.72).offset(y: sin(t * 1.4) * 5)
                    ForEach(0..<3) { i in
                        Image(systemName: "sparkle").font(.system(size: i == 1 ? 18 : 10)).foregroundStyle(Color(hex: "C8A96E"))
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
                    }.stroke(Color(hex: "C8A96E"), style: StrokeStyle(lineWidth: 3, lineCap: .round)).frame(width: 50, height: 24)
                    Rectangle().fill(Color(hex: "1C1210").opacity(0.5)).frame(height: 5).padding(.horizontal, 12)
                    Text("安").font(AppTypography.title(36)).foregroundStyle(Color(red: 1, green: 0.88, blue: 0.66)).frame(maxHeight: .infinity)
                }
            }
        } else {
            GeometryReader { p in
                let side = min(p.size.width, p.size.height)
                ZStack {
                    ForEach(0..<14) { i in
                        let angle = Double(i) * .pi * 2 / 14
                        Circle().fill(LinearGradient(colors: [Color(hex: "C8A96E"), i == 7 ? .red.opacity(0.55) : .brown], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .overlay(Circle().stroke(Color(hex: "C8A96E").opacity(0.6), lineWidth: 1))
                            .frame(width: side * 0.19, height: side * 0.19)
                            .offset(x: sin(angle) * side * 0.38, y: -cos(angle) * side * 0.38)
                    }
                    Text("缘").font(AppTypography.title(25)).foregroundStyle(Color(hex: "C8A96E"))
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
            }.font(AppTypography.caption).padding(.vertical, 5).accessibilityElement(children: .combine)
        }
    }
}
private struct RewardWheelSector: Shape {
    let index: Int
    let count: Int
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path(); path.move(to: center)
        path.addArc(center: center, radius: min(rect.width, rect.height) / 2, startAngle: .degrees(Double(index) * 360 / Double(count) - 90 - 180 / Double(count)), endAngle: .degrees(Double(index) * 360 / Double(count) - 90 + 180 / Double(count)), clockwise: false)
        path.closeSubpath(); return path
    }
}
struct RewardWheelArt: View {
    let rotation: Double
    let spinning: Bool
    let cost: Int64
    var prizes: [RewardPrize] = []
    var slots: [Int]? = nil
    private var layout: [Int] { rewardWheelSlots(prizes: prizes, configured: slots) }
    var actionLabel: String? = nil
    var actionDisabled = false
    var hasResult = false
    var onDraw: (() -> Void)? = nil
    var onPrize: ((RewardPrize) -> Void)? = nil
    private let jade = Color(hex: "254C40")
    private let gold = Color(hex: "E4C58F")
    private var brass: LinearGradient {
        LinearGradient(colors: [Color(hex: "F5DFAD"), Color(hex: "B58A4E"), Color(hex: "E7C78D"), Color(hex: "8B683D")], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            ZStack {
                ZStack {
                    Circle().fill(brass).padding(size * 0.025)
                    Circle().fill(jade).padding(size * 0.045)
                    ForEach(0..<48) { index in
                        Circle().fill(gold.opacity(index.isMultiple(of: 6) ? 1 : 0.6))
                            .frame(width: size * (index.isMultiple(of: 6) ? 0.013 : 0.006))
                            .offset(y: -size * 0.442).rotationEffect(.degrees(Double(index) * 7.5))
                    }
                    ZStack {
                        ForEach(0..<10, id: \.self) { index in
                            let prizeIndex = layout[index]
                            let gift = prizeIndex >= 0
                            let light = index.isMultiple(of: 2)
                            RewardWheelSector(index: index, count: 10)
                                .fill(RadialGradient(colors: light ? [Color(hex: "FFF8E8"), Color(hex: "E8D8B7")] : [Color(hex: "466C5E"), Color(hex: "23483F")], center: .topLeading, startRadius: 0, endRadius: size))
                            RewardWheelSector(index: index, count: 10).stroke(Color(hex: "B59862"), lineWidth: 0.6)
                            VStack(spacing: size * 0.028) {
                                Text(gift ? prizes[prizeIndex].name : "谢谢参与").font(.system(size: size * 0.031, weight: .medium)).lineLimit(2).multilineTextAlignment(.center).frame(width: size * 0.18, height: size * 0.08)
                                if gift, let url = URL(string: prizes[prizeIndex].image), !prizes[prizeIndex].image.isEmpty {
                                    AsyncImage(url: url) { image in image.resizable().scaledToFit() } placeholder: { Image(systemName: "gift") }.frame(width: size * 0.09, height: size * 0.09)
                                } else { Image(systemName: gift ? (prizes[prizeIndex].kind == "physical" ? "gift" : "ticket") : "leaf").font(.system(size: size * 0.064, weight: .light)) }
                            }
                            .foregroundStyle(light ? Color(hex: "76562F") : Color(hex: "EDE4C9"))
                            .offset(y: -size * 0.29).rotationEffect(.degrees(Double(index) * 360 / 10))
                        }
                    }.frame(width: size * 0.839, height: size * 0.839)
                        .rotationEffect(.degrees(rotation)).accessibilityIdentifier("reward-wheel-disc")
                    Circle().stroke(Color(hex: "EAD6AC"), lineWidth: 1.5).frame(width: size * 0.839)
                    Circle().fill(brass).frame(width: size * 0.284)
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: size * 0.065)).foregroundStyle(brass)
                        .shadow(color: .black.opacity(0.18), radius: 1, y: 2).offset(y: -size * 0.435)
                }.accessibilityHidden(true)
                if let onPrize {
                    ZStack {
                        ForEach(0..<10, id: \.self) { index in
                            if layout[index] >= 0 {
                            let prize = prizes[layout[index]]
                            Button { onPrize(prize) } label: {
                                Color.clear.contentShape(RewardWheelSector(index: index, count: 10))
                            }.buttonStyle(.plain).disabled(spinning)
                                .accessibilityLabel("查看\(prize.name)详情")
                                .accessibilityIdentifier("reward-wheel-prize-\(prize.id)-\(index)")
                            }
                        }
                    }.frame(width: size * 0.839, height: size * 0.839).rotationEffect(.degrees(rotation))
                }
                if let onDraw {
                    Button(action: onDraw) { center(size: size) }
                        .buttonStyle(.plain).disabled(actionDisabled).opacity(actionDisabled ? 0.7 : 1)
                        .accessibilityLabel(actionLabel ?? "\(cost) 积分转一次")
                        .accessibilityIdentifier("reward-wheel-draw")
                } else { center(size: size).accessibilityLabel("十格积分转盘，扇区面积不代表概率") }
            }.frame(width: size, height: size)
                .shadow(color: jade.opacity(0.1), radius: 9, y: 7)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
    private func center(size: CGFloat) -> some View {
        VStack(spacing: 5) {
            Text(spinning ? "揭晓中" : hasResult ? "查看结果" : "转一次").font(.system(size: max(14, size * 0.05), weight: .semibold))
            Text(spinning ? "请稍候" : hasResult ? "本期已参与" : "\(cost) 积分").font(.system(size: max(10, size * 0.031)))
                .foregroundStyle(Color(hex: "DFD7BE"))
        }.foregroundStyle(Color(hex: "FFF4DA"))
            .frame(width: size * 0.257, height: size * 0.257)
            .background(LinearGradient(colors: [Color(hex: "42685A"), Color(hex: "1D4338")], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
            .overlay(Circle().stroke(Color(hex: "E7D0A0"), lineWidth: 1))
            .contentShape(Circle())
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
                    Text(c.phaseText).font(.caption2.bold()).padding(8).background(Color.bgPrimary.opacity(0.85), in: Capsule())
                }.frame(height: 190).padding(8).background(Color.accentDefault.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                Text(c.title).font(AppTypography.card).foregroundStyle(Color.textPrimary)
                Text("\(c.prizeName) × \(c.prizeQuantity)").font(.subheadline)
                ProgressView(value: Double(c.participantCount), total: Double(c.capacity)).tint(Color.accentDefault)
                HStack { Text("\(c.participantCount) 人已参与"); Spacer(); Text("限 \(c.capacity) 人") }.font(AppTypography.caption)
                RewardCountdown(endsAt: c.endsAt)
                HStack {
                    Text("\(c.pointsCost) 积分参与").font(.caption2)
                    Spacer(); Text("查看详情 →").font(.caption.bold())
                }
            }.foregroundStyle(Color.accentDefault).padding(.vertical, 8)
        }.accessibilityIdentifier("reward-campaign-\(c.id)")
    }
}
struct RewardsView: View {
    var embedded: Bool
    var onBalanceChange: ((Int64) -> Void)?
    init(initialTab: Int = 1, embedded: Bool = false, onBalanceChange: ((Int64) -> Void)? = nil) { _tab = State(initialValue: initialTab); self.embedded = embedded; self.onBalanceChange = onBalanceChange }
    @EnvironmentObject private var auth: AuthStore
    @State private var tab: Int
    @State private var page = 1
    @State private var campaigns: [RewardCampaign] = []
    @State private var entries: [RewardEntry] = []
    @State private var orders: [RewardOrder] = []
    @State private var selectedWheel: Int64?
    @State private var loading = false
    @State private var error: String?
    @State private var claim: RewardOrder?
    @State private var completing: RewardOrder?
    @State private var redemption: RewardOrder?
    @State private var generation = 0
    private var count: Int { (tab < 2 || tab == 4) ? campaigns.count : tab == 2 ? entries.count : orders.count }
    private var wheel: RewardCampaign? { campaigns.first { $0.id == selectedWheel } ?? campaigns.first { $0.phase == "open" } ?? campaigns.first { $0.phase == "scheduled" } ?? campaigns.first }
    var body: some View {
        VStack(spacing: 0) {
            if !embedded { Picker("活动分类", selection: $tab) {
                Text("转盘").tag(1); Text("大奖池").tag(0); Text("参与记录").tag(2); Text("我的奖品").tag(3)
            }.pickerStyle(.segmented).padding(.horizontal, 16).padding(.vertical, 10) }
            if let error { VStack { Text(error).font(AppTypography.caption).foregroundStyle(.red); Button("重新加载") { Task { await load() } } }.padding() }
            if loading { ProgressView("正在准备活动…").padding() }
            if tab == 1, let wheel {
                if campaigns.count > 1 {
                    Picker("选择转盘活动", selection: Binding(get: { wheel.id }, set: { selectedWheel = $0 })) {
                        ForEach(campaigns) { Text($0.title).tag($0.id) }
                    }.tint(Color.accentDefault).padding(.horizontal)
                }
                RewardDetailView(id: wheel.id, embedded: true, onBalanceChange: onBalanceChange).id(wheel.id)
            } else {
                List {
                    if tab == 0 { ForEach(campaigns) { RewardCampaignCard(campaign: $0) } }
                    if tab == 2 {
                        ForEach(entries) { e in
                            NavigationLink { RewardDetailView(id: e.campaignId) } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: e.outcome == "won" ? "sparkles" : "ticket").font(.title2).foregroundStyle(Color.accentDefault)
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack { Text(e.title); Spacer(); Text(e.outcomeText).font(AppTypography.caption).foregroundStyle(Color.accentDefault) }
                                        Text("消耗 \(e.pointsSpent) 积分 · \(rewardDate(e.createdAt))").font(AppTypography.caption).foregroundStyle(.secondary)
                                        Text(e.code).font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary)
                                    }
                                }.padding(.vertical, 8)
                            }
                        }
                    }
                    if tab == 4 { ForEach(campaigns) { c in
                        NavigationLink { RewardDetailView(id: c.id) } label: {
                            VStack(alignment: .leading, spacing: 8) { Text(c.title).font(.headline); Text("\(c.kind == "wheel" ? "积分转盘" : "奖池") · \(rewardDate(c.drawnAt))").font(.caption).foregroundStyle(.secondary); Text("\(c.awardedCount) 次中奖 · 查看开奖 →").font(.subheadline).foregroundStyle(Color.accentDefault) }.padding(.vertical, 8)
                        }
                    } }
                    if tab == 3 { ForEach(orders) { orderCard($0) } }
                    if !loading && error == nil && count == 0 {
                        ContentUnavailableView(tab == 2 ? "暂无抽奖记录" : tab == 3 ? "暂无中奖奖品" : tab == 4 ? "暂无开奖记录" : "暂无活动", systemImage: "gift", description: Text(tab == 4 ? "活动开奖后可查看结果。" : "活动和领奖进度会显示在这里。"))
                    }
                    if page > 1 || count >= 20 {
                        HStack { Button("上一页") { page -= 1 }.disabled(page == 1 || loading); Spacer(); Text("第 \(page) 页"); Spacer(); Button("下一页") { page += 1 }.disabled(count < 20 || loading) }.font(AppTypography.caption)
                    }
                    Text("功德值独立记录成长，与活动概率无关。").font(AppTypography.caption).foregroundStyle(.secondary)
                }.scrollContentBackground(.hidden).refreshable { await load() }
            }
        }.background(Color.bgPrimary)
        .navigationTitle(embedded ? (tab < 2 ? "积分中心" : "积分记录") : "积分活动").navigationBarTitleDisplayMode(.inline)
        .task(id: "\(tab)-\(page)-\(auth.userId)") { await load() }
        .onChange(of: tab) { _, _ in page = 1; selectedWheel = nil }
        .sheet(item: $redemption) { RewardRedemptionSheet(order: $0) }
        .sheet(item: $claim, onDismiss: { Task { await load() } }) { RewardClaimSheet(order: $0) }
        .alert("确认已收到奖品？", isPresented: Binding(get: { completing != nil }, set: { if !$0 { completing = nil } })) {
            Button("取消", role: .cancel) { completing = nil }
            Button("确认收货") { if let o = completing { Task { await complete(o) } } }
        } message: { Text("确认后本次实物领奖流程完成。") }
    }
    private func orderCard(_ o: RewardOrder) -> some View {
        Section {
            HStack { Text(o.prizeName).font(.headline); Spacer(); Text(o.statusText).font(AppTypography.caption).foregroundStyle(Color.accentDefault) }
            if o.isDigital {
                Text(o.platform ?? "").font(AppTypography.caption).foregroundStyle(.secondary)
                if let expires = o.expiresAt, expires > 0 { Text("有效期至 \(rewardDate(expires))").font(AppTypography.caption).foregroundStyle(.secondary) }
                Button(o.prizeKind == "code" ? "查看兑换码" : "查看兑换券") { redemption = o }.buttonStyle(.borderedProminent)
            } else { RewardDeliverySteps(status: o.status) }
            if !o.trackingNo.isEmpty { Text("物流：\(o.carrier) · \(o.trackingNo)").font(AppTypography.caption).textSelection(.enabled) }
            DisclosureGroup("领取与订单详情") {
                NavigationLink("中奖码 \(o.code)") { RewardDetailView(id: o.campaignId) }.font(AppTypography.caption)
                if !o.address.isEmpty { Text("\(o.receiver) · \(o.mobile)\n\(o.address)").font(AppTypography.caption) }
                if o.claimedAt > 0 { Text("提交地址 \(rewardDate(o.claimedAt))").font(AppTypography.caption) }
                if o.shippedAt > 0 { Text("发货 \(rewardDate(o.shippedAt))").font(AppTypography.caption) }
                if o.completedAt > 0 { Text("已完成 \(rewardDate(o.completedAt))").font(AppTypography.caption) }
            }
            if o.status == "awaiting_address" { Button("填写收货地址") { claim = o }.buttonStyle(.borderedProminent) }
            if o.status == "shipped" { Button("确认收货") { completing = o }.disabled(loading) }
        }.tint(Color.accentDefault)
    }
    @MainActor private func load() async {
        generation += 1; let version = generation
        loading = true; error = nil; campaigns = []; entries = []; orders = []
        defer { if version == generation { loading = false } }
        guard auth.isLoggedIn else { error = "请先登录后参与积分活动"; return }
        do {
            if tab < 2 || tab == 4 { let rows: [RewardCampaign] = try await APIClient.shared.request(.rewardCampaigns(page, tab == 4 ? "draws" : tab == 0 ? "pool" : "wheel")); try Task.checkCancellation(); guard version == generation else { return }; campaigns = rows }
            else if tab == 2 { let rows: [RewardEntry] = try await APIClient.shared.request(.rewardEntries(page)); try Task.checkCancellation(); guard version == generation else { return }; entries = rows }
            else { let rows: [RewardOrder] = try await APIClient.shared.request(.rewardOrders(page)); try Task.checkCancellation(); guard version == generation else { return }; orders = rows }
        } catch is CancellationError {} catch { if version == generation { self.error = error.localizedDescription } }
    }
    @MainActor private func complete(_ o: RewardOrder) async {
        guard !loading else { return }; loading = true; defer { loading = false }
        do { let _: PointsActionResult = try await APIClient.shared.request(.rewardComplete(o.id)); completing = nil; await load() } catch { self.error = error.localizedDescription }
    }
}
struct RewardDeliverySteps: View {
    let status: String
    var firstLabel = "中奖"
    private let steps = ["awaiting_address", "pending", "shipped", "completed"]
    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                VStack(spacing: 8) {
                    Capsule().fill(index <= (steps.firstIndex(of: status) ?? 0) ? Color.accentDefault : Color.gray.opacity(0.2)).frame(height: 3)
                    Text([firstLabel, "待发货", "已发货", "完成"][index]).font(.caption2)
                }.foregroundStyle(index <= (steps.firstIndex(of: status) ?? 0) ? Color.accentDefault : .secondary)
            }
        }.padding(.vertical, 12).accessibilityElement(children: .combine)
    }
}

struct RewardDetailView: View {
    let id: Int64
    var embedded = false
    var onBalanceChange: ((Int64) -> Void)? = nil
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var detail: RewardDetail?
    @State private var error: String?
    @State private var busy = false
    @State private var spinning = false
    @State private var confirming = false
    @State private var rotation = 0.0
    @State private var motionID = 0
    @State private var result: RewardEntry?
    @State private var repeatAfterDismiss = false
    @State private var actionTask: Task<Void, Never>?
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 18) {
                    if let error { VStack { Text(error).font(AppTypography.caption).foregroundStyle(.red); Button("重新加载") { Task { await load() } } }.rewardPanel() }
                    if let d = detail {
                        if d.campaign.kind == "wheel" {
                            RewardWheelExperience(detail: d, busy: busy, spinning: spinning, rotation: rotation, hasError: error != nil, onJoin: { confirming = true }, onResult: { result = d.mine }).id("reward-art")
                        } else {
                        hero(d).id("reward-art")
                        facts(d).rewardPanel()
                        if let mine = d.mine { ticket(mine).rewardPanel() }
                        rules(d).rewardPanel()
                        if !d.campaign.announcement.isEmpty || !d.winners.isEmpty { announcement(d).rewardPanel() }
                        }
                    } else if error == nil { ProgressView("正在准备活动…").padding(40) }
                }.padding(16)
            }.onChange(of: motionID) { _, _ in
                AppMotion.perform(AppMotion.reveal) { proxy.scrollTo("reward-art", anchor: .top) }
            }
        }
        .background(Color.bgPrimary)
        .safeAreaInset(edge: .bottom) { if let d = detail, d.campaign.kind != "wheel" { actionBar(d) } }
        .navigationTitle(embedded ? "积分中心" : detail?.campaign.kind == "wheel" ? "幸运转盘" : "活动详情").navigationBarTitleDisplayMode(.inline)
        .task(id: "\(id)-\(auth.userId)") {
            await load()
            while !Task.isCancelled { do { try await Task.sleep(for: .seconds(15)) } catch { return }; if !busy { await load() } }
        }
        .refreshable { if !busy { await load() } }
        .onDisappear { actionTask?.cancel() }
        .alert("确认扣除积分参与？", isPresented: $confirming) {
            Button("再想想", role: .cancel) {}
            Button("确认扣除 \(detail?.campaign.pointsCost ?? 0) 积分") { actionTask = Task { await participate() } }
        } message: {
            Text("当前可用 \(detail?.pointsBalance ?? 0) 积分，本次消耗 \(detail?.campaign.pointsCost ?? 0) 积分。" + "参与成功后无论中奖与否均不退回；失败不扣分，重复请求不重复扣分。")
        }
        .sheet(item: $result, onDismiss: { if repeatAfterDismiss { repeatAfterDismiss = false; confirming = true } }) { entry in RewardResultSheet(entry: entry, prizeName: detail?.campaign.kind == "wheel" ? (entry.prizeName?.isEmpty == false ? entry.prizeName : detail?.campaign.prizeName) : nil, onAgain: detail?.campaign.kind == "wheel" && detail?.campaign.phase == "open" && (detail?.pointsBalance ?? 0) >= (detail?.campaign.pointsCost ?? 1) ? { repeatAfterDismiss = true } : nil).appSheetSurface() }
    }
    private func hero(_ d: RewardDetail) -> some View {
        VStack(spacing: 16) {
            Text("\(d.campaign.kind == "wheel" ? "LUCKY WHEEL" : "THE PRIZE POOL") · 第 \(id) 期").font(.caption2).tracking(2).foregroundStyle(Color.accentDefault)
            Text(d.campaign.title).font(AppTypography.title(28)).multilineTextAlignment(.center)
            Text(d.campaign.phaseText).font(AppTypography.caption).padding(.horizontal, 12).padding(.vertical, 6).background(Color.accentDefault.opacity(0.15), in: Capsule())
            if d.campaign.kind == "wheel" {
                RewardWheelArt(rotation: spinning ? rotation : d.campaign.wheelAngle(for: d.mine), spinning: spinning, cost: d.campaign.pointsCost, prizes: d.campaign.displayPrizes).frame(height: 280)
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
            Text("平台提供 · \(d.campaign.pointsCost) 积分参与 · 实物包邮").font(AppTypography.caption).foregroundStyle(.secondary)
        }.padding(18).frame(maxWidth: .infinity).background(LinearGradient(colors: [Color.brown.opacity(0.4), Color.bgSecondary], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 22))
    }
    private func facts(_ d: RewardDetail) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                fact("已参与人数", "\(d.campaign.participantCount)"); Spacer()
                fact("奖品数量", "\(d.campaign.prizeQuantity)"); Spacer()
                fact(d.campaign.kind == "pool" ? "按当前人数估算" : "下一位即时概率", d.campaign.oddsText)
            }
            ProgressView(value: Double(d.campaign.participantCount), total: Double(d.campaign.capacity)).tint(Color.accentDefault)
            Text("活动进度 · \(d.campaign.participantCount) / \(d.campaign.capacity) 人").font(AppTypography.caption)
            RewardCountdown(endsAt: d.campaign.endsAt)
            Text("开始：\(rewardDate(d.campaign.startsAt))\n截止：\(rewardDate(d.campaign.endsAt))").font(AppTypography.caption).foregroundStyle(.secondary)
            Text(d.campaign.kind == "pool" ? "截止后自动开奖，不需要等满额。最终概率为 min(奖品数量, 有效人数) ÷ 有效人数；100 人抽 1 人，每人为 1%。" : "扇区仅作动画展示，不代表概率。正式活动当前概率 = 剩余奖品 ÷ 剩余名额。").font(AppTypography.caption).foregroundStyle(.secondary)
        }
    }
    private func fact(_ title: String, _ value: String) -> some View {
        VStack(spacing: 7) { Text(value).font(.title3.bold()).foregroundStyle(Color.accentDefault); Text(title).font(AppTypography.micro).foregroundStyle(.secondary) }
    }
    private func ticket(_ e: RewardEntry) -> some View {
        VStack(spacing: 14) {
            Text("我的专属参与码").font(AppTypography.caption)
            Text(e.code).font(.system(.title3, design: .monospaced)).foregroundStyle(Color.accentDefault).textSelection(.enabled)
            Text(spinning ? "正在揭晓…" : e.outcomeText).font(.headline)
            Text("消耗 \(e.pointsSpent) 积分 · \(rewardDate(e.createdAt))").font(AppTypography.caption).foregroundStyle(.secondary)
            if e.outcome == "won" && !spinning { NavigationLink("查看我的奖品并领奖") { PointsHistoryView(initialTab: 4) }.buttonStyle(.borderedProminent) }
        }.frame(maxWidth: .infinity).tint(Color.accentDefault)
    }
    private func rules(_ d: RewardDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("这一份礼物").font(.headline); Text(d.campaign.description).font(.subheadline)
            Text("参与规则").font(.headline); Text(d.campaign.rules).font(.subheadline)
            Group { Text("每个账号每期一次，消耗 \(d.campaign.pointsCost) 积分；成功参与后无论中奖与否均不退回。请求失败不扣分，重复点击不重复扣分。奖品预算由平台承担，功德值不变。").font(AppTypography.caption).foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func announcement(_ d: RewardDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("开奖公告").font(.headline)
            Text(d.campaign.announcement.isEmpty ? "本期实时中奖码，活动结束后归档。" : d.campaign.announcement).font(.subheadline)
            if d.campaign.drawnAt > 0 { Text("实际开奖 \(rewardDate(d.campaign.drawnAt))").font(AppTypography.caption) }
            ForEach(d.winners) { Text($0.code).font(.system(.caption, design: .monospaced)).foregroundStyle(Color.accentDefault).textSelection(.enabled) }
            if !d.campaign.poolDigest.isEmpty {
                DisclosureGroup("开奖留档信息") { Text(d.campaign.algorithm); Text("参与码按创建顺序以换行分隔，SHA-256："); Text(d.campaign.poolDigest).textSelection(.enabled) }.font(AppTypography.caption)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func actionBar(_ d: RewardDetail) -> some View {
        VStack(spacing: 8) {
            Text(d.mine != nil ? "本期已参与，记录保留" : "可用 \(d.pointsBalance) 积分 · 每期一次").font(AppTypography.caption).foregroundStyle(.secondary)
            Button(busy ? "正在揭晓…" : d.mine != nil ? "本期已参与" : d.campaign.phase != "open" ? d.campaign.phaseText : d.pointsBalance < d.campaign.pointsCost ? "积分不足" : "\(d.campaign.pointsCost) 积分\(d.campaign.kind == "wheel" ? "转一次" : "参与奖池")") { confirming = true }
                .buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity).tint(Color.accentDefault)
                .disabled(busy || d.mine != nil || d.campaign.phase != "open" || error != nil || d.pointsBalance < d.campaign.pointsCost || d.campaign.pointsCost < 1)
        }.padding(.horizontal, 16).padding(.vertical, 10).frame(maxWidth: .infinity).background(Color.bgPrimary).overlay(alignment: .top) { Rectangle().fill(Color.accentDefault.opacity(0.2)).frame(height: 1) }
    }
    @MainActor private func load() async {
        do {
            guard id > 0 else { error = "此活动已停用，请返回积分活动选择本期好礼"; return }
            let loaded: RewardDetail = try await APIClient.shared.request(.rewardDetail(id))
            try Task.checkCancellation(); detail = loaded; onBalanceChange?(loaded.pointsBalance)
            error = nil
            if !spinning { rotation = detail.map { $0.campaign.wheelAngle(for: $0.mine) } ?? 0 }
        } catch is CancellationError {} catch { self.error = error.localizedDescription }
    }
    @MainActor private func participate() async {
        guard !busy, let c = detail?.campaign, c.kind == "wheel" || detail?.mine == nil else { return }
        busy = true; error = nil; defer { busy = false; spinning = false }
        do {
            let keyName = "reward-attempt:\(auth.userId):\(id)"
            let requestKey = UserDefaults.standard.string(forKey: keyName) ?? UUID().uuidString
            UserDefaults.standard.set(requestKey, forKey: keyName)
            let entry: RewardEntry = try await APIClient.shared.request(.rewardJoin(id, c.pointsCost, requestKey))
            UserDefaults.standard.removeObject(forKey: keyName)
            try Task.checkCancellation(); spinning = true; motionID += 1
            if c.kind == "wheel" {
                let target = c.wheelAngle(for: entry)
                withAnimation(reduceMotion ? nil : .timingCurve(0.23, 1, 0.32, 1, duration: 3.7)) { rotation += 2520 + (target - rotation.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) }
                if !reduceMotion { try await Task.sleep(for: .milliseconds(3700)) }
            } else if !reduceMotion { try await Task.sleep(for: .milliseconds(1400)) }
            try Task.checkCancellation(); await load(); result = entry
        } catch is CancellationError {} catch { self.error = error.localizedDescription }
    }
}
/// The wheel is an instant draw. Participation metrics and audit stay in secondary sheets.
struct RewardWheelExperience: View {
    let detail: RewardDetail
    let busy, spinning: Bool
    let rotation: Double
    let hasError: Bool
    let onJoin, onResult: () -> Void
    @State private var showRules = false
    @State private var selectedPrize: RewardPrize?
    @State private var showRecords = false
    private var c: RewardCampaign { detail.campaign }
    private var blocked: Bool { busy || hasError || (c.phase != "open" || detail.pointsBalance < c.pointsCost || c.pointsCost < 1) }
    private var actionLabel: String {
        if busy { return "正在揭晓…" }
        if c.phase != "open" { return c.phaseText }
        return detail.pointsBalance < c.pointsCost ? "积分不足" : "\(c.pointsCost) 积分转一次"
    }
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 10) {
                HStack(spacing: 6) { Circle().fill(Color.brandDefault).frame(width: 5, height: 5); Text(c.phaseText) }.font(AppTypography.caption).foregroundStyle(.secondary)
                Text(c.title).font(AppTypography.title(25)).multilineTextAlignment(.center)
                RewardWheelArt(rotation: spinning ? rotation : c.wheelAngle(for: detail.mine), spinning: busy, cost: c.pointsCost, prizes: c.displayPrizes, slots: c.wheelSlots, actionLabel: actionLabel, actionDisabled: blocked, onDraw: onJoin, onPrize: { selectedPrize = $0 })
                    .frame(maxWidth: 360).aspectRatio(1, contentMode: .fit).padding(.vertical, 8)
                Text("可用 \(detail.pointsBalance) 积分").font(AppTypography.caption).foregroundStyle(.secondary)
                if blocked && !busy { Text(hasError ? "加载失败，请重试" : actionLabel).font(AppTypography.caption).foregroundStyle(.secondary) }
            }.padding(18).frame(maxWidth: .infinity).background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 22)).overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.accentDefault.opacity(0.16), lineWidth: 1))
            if let mine = detail.mine { Button("上次：\(mine.outcomeText) · 查看结果", action: onResult).font(.caption).tint(Color.accentDefault) }
            HStack {
                Button("抽奖记录") { showRecords = true }.frame(maxWidth: .infinity)
                Divider().frame(height: 14)
                NavigationLink("我的奖品") { PointsHistoryView(initialTab: 4) }.frame(maxWidth: .infinity)
                Divider().frame(height: 14)
                Button("活动规则") { showRules = true }.frame(maxWidth: .infinity)
            }.font(AppTypography.caption).tint(Color.accentDefault).disabled(busy).padding(.vertical, 8)
        }
        .sheet(item: $selectedPrize) { RewardPrizeSheet(prize: $0, campaign: c) }
        .sheet(isPresented: $showRules) { RewardWheelInfoSheet(detail: detail, records: false) }
        .sheet(isPresented: $showRecords) { RewardWheelInfoSheet(detail: detail, records: true) }
    }
}
struct RewardPrizeSheet: View {
    let prize: RewardPrize
    let campaign: RewardCampaign
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 14) {
                        Group {
                            if let url = URL(string: prize.image), !prize.image.isEmpty {
                                AsyncImage(url: url) { image in image.resizable().scaledToFit() } placeholder: { Image(systemName: "gift") }
                            } else { Image(systemName: prize.kind == "physical" ? "gift" : "ticket").font(.largeTitle) }
                        }.frame(width: 120, height: 120).foregroundStyle(Color.accentDefault)
                        Text(prize.kindText).font(.caption).foregroundStyle(.secondary)
                        Text(prize.name).font(AppTypography.title(24)).multilineTextAlignment(.center)
                    }.frame(maxWidth: .infinity).padding(.vertical, 12)
                    LabeledContent("中奖概率", value: rewardProbabilityText(campaign.probability(for: prize)))
                    LabeledContent(prize.kind == "code" ? "面值" : "参考价值", value: String(format: "¥%.2f", Double(prize.value) / 100))
                    if !prize.platform.isEmpty { LabeledContent("使用平台", value: prize.platform) }
                    if prize.expiresAt > 0 { LabeledContent("有效期至", value: rewardDate(prize.expiresAt)) }
                }
                Section {
                    Text(prize.instructions.isEmpty ? (prize.kind == "physical" ? "中奖后在“我的奖品”填写收货地址。" : "中奖后在“我的奖品”查看兑换凭证。") : prize.instructions).font(.subheadline)
                }
            }.scrollContentBackground(.hidden).background(Color.bgPrimary).navigationTitle("奖品详情").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("关闭") { dismiss() } } }
        }.tint(Color.accentDefault)
    }
}
private struct RewardWheelInfoSheet: View {
    let detail: RewardDetail
    let records: Bool
    @Environment(\.dismiss) private var dismiss
    private var c: RewardCampaign { detail.campaign }
    var body: some View {
        NavigationStack {
            List {
                if records {
                    if let e = detail.mine {
                        Section {
                            Text(e.outcomeText).font(AppTypography.card).foregroundStyle(Color.accentDefault)
                            Text("\(rewardDate(e.createdAt)) · 消耗 \(e.pointsSpent) 积分").font(AppTypography.caption)
                            Text(e.code).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                            if e.outcome == "won" { NavigationLink("查看奖品与领奖") { PointsHistoryView(initialTab: 4) } }
                        }
                    } else { Text("本期还没有抽奖记录，转一次试试手气。").font(.subheadline).foregroundStyle(.secondary) }
                    if !c.announcement.isEmpty || !detail.winners.isEmpty {
                        DisclosureGroup("本期开奖留档") {
                            Text(c.announcement.isEmpty ? "本期转盘实时中奖记录。" : c.announcement)
                            if c.drawnAt > 0 { Text("实际开奖 \(rewardDate(c.drawnAt))") }
                            ForEach(detail.winners) { Text($0.code).font(.system(.caption, design: .monospaced)).textSelection(.enabled) }
                            if !c.poolDigest.isEmpty { Text(c.algorithm); Text(c.poolDigest).textSelection(.enabled) }
                        }.font(AppTypography.caption)
                    }
                    NavigationLink("查看全部参与记录") { PointsHistoryView(initialTab: 2) }
                } else {
                    Section { Text(c.description); Text(c.rules) }.font(.subheadline)
                    Section {
                        LabeledContent("活动时间", value: "\(rewardDate(c.startsAt)) 至 \(rewardDate(c.endsAt))")
                        LabeledContent("每次消耗", value: "\(c.pointsCost) 积分")
                    }.font(AppTypography.caption)
                    Section("奖品与概率") {
                        ForEach(c.displayPrizes) { p in
                            LabeledContent(p.name, value: rewardProbabilityText(c.probability(for: p)))
                        }
                        LabeledContent("谢谢参与", value: rewardProbabilityText(c.noPrizeProbability))
                    }
                    Text("可多次抽奖，每次成功参与扣除 \(c.pointsCost) 积分，无论是否中奖均不退回；失败不扣分，重复请求不重复扣分。" + (c.hasFixedOdds ? "活动期间按公示的固定概率抽取。" : "本期沿用原有规则，以上为下一次抽奖的即时概率。") + "扇区大小不代表中奖概率。").font(AppTypography.caption).foregroundStyle(.secondary)
                }
            }.navigationTitle(records ? "抽奖记录" : "活动规则").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("关闭") { dismiss() } } }
        }.tint(Color.accentDefault)
    }
}
private extension View {
    func rewardPanel() -> some View { padding(18).frame(maxWidth: .infinity).background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.accentDefault.opacity(0.16), lineWidth: 1)) }
}
struct RewardResultSheet: View {
    let entry: RewardEntry
    var prizeName: String? = nil
    var onAgain: (() -> Void)? = nil
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
            ScrollView {
            VStack(spacing: 18) {
                Image(systemName: entry.outcome == "won" ? "sparkles" : entry.outcome == "pending" ? "ticket.fill" : "sparkle").font(.system(size: 48)).foregroundStyle(Color.accentDefault).scaleEffect(appear ? 1 : 0.6)
                Text(entry.outcomeText).font(AppTypography.section)
                if let prizeName { if entry.outcome == "won" { Text(prizeName).font(.headline).foregroundStyle(Color.accentDefault) } } else { Text(entry.code).font(.system(.subheadline, design: .monospaced)).foregroundStyle(Color.accentDefault) }
                Text("已扣 \(entry.pointsSpent) 积分").font(AppTypography.caption)
                if let onAgain { Button("再转一次 · \(entry.pointsSpent) 积分") { dismiss(); onAgain() }.buttonStyle(.borderedProminent).tint(Color.accentDefault) }
                Button("关闭") { dismiss() }.buttonStyle(.bordered).controlSize(.large).tint(Color.accentDefault)
            }.padding(24).frame(maxWidth: .infinity)
            }
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
    var body:some View { NavigationStack { Form { Section(order.prizeName) { Text("平台包邮，填写地址后进入待发货。").font(.subheadline);Text(order.code).font(AppTypography.caption) };Section("收货信息") { TextField("收货人",text:$receiver).textContentType(.name);TextField("联系电话",text:$mobile).keyboardType(.phonePad).textContentType(.telephoneNumber);TextField("省市区、街道与门牌号",text:$address,axis:.vertical).textContentType(.fullStreetAddress).lineLimit(3...5) }.disabled(busy);if let error {Text(error).foregroundStyle(.red)};Section { Text("提交后请等待平台发货，请先核对地址和联系电话。").font(AppTypography.caption);Button(busy ? "提交中…":"确认地址，等待发货") {Task{await submit()}}.disabled(busy||receiver.trimmingCharacters(in:.whitespaces).isEmpty||mobile.count<6||address.count<5) } }.navigationTitle("领奖地址").navigationBarTitleDisplayMode(.inline).toolbar {ToolbarItem(placement:.cancellationAction){Button("稍后填写"){dismiss()}.disabled(busy)}}.interactiveDismissDisabled(busy) } }
    @MainActor private func submit()async {busy=true;error=nil;defer{busy=false};do{let _:PointsActionResult=try await APIClient.shared.request(.rewardClaim(order.id,RewardAddressRequest(receiver:receiver.trimmingCharacters(in:.whitespacesAndNewlines),mobile:mobile.trimmingCharacters(in:.whitespacesAndNewlines),address:address.trimmingCharacters(in:.whitespacesAndNewlines))));dismiss()}catch{self.error=error.localizedDescription}}
}

struct RewardRedemptionSheet: View {
    let order: RewardOrder
    @Environment(\.dismiss) private var dismiss
    @State private var value: RewardRedemption?
    @State private var error: String?
    @State private var copied = false
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(order.prizeName).font(.headline)
                    if let value {
                        Text(value.platform).foregroundStyle(.secondary)
                        Text("有效期至 \(rewardDate(value.expiresAt))").font(AppTypography.caption)
                        if value.expiresAt < Int64(Date().timeIntervalSince1970) { Text("已过有效期").foregroundStyle(.secondary) }
                        Text(value.instructions).font(.subheadline)
                        if !value.code.isEmpty {
                            Text(value.code).font(.system(.title3, design: .monospaced)).textSelection(.enabled)
                            Button(copied ? "已复制" : "复制兑换码") {
                                UIPasteboard.general.setItems([[UIPasteboard.typeAutomatic: value.code]], options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(120)])
                                copied = true
                            }
                        }
                        if let url = value.safeURL { Link("前往 \(url.host ?? "兑换平台") 兑换 ↗", destination: url) }
                    } else if let error { Text(error).foregroundStyle(.red); Button("重新读取") { Task { await load() } } }
                    else { ProgressView("正在读取…") }
                }
            }.navigationTitle(order.prizeKind == "code" ? "兑换码" : "兑换券").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("关闭") { dismiss() } } }
                .task { await load() }
        }.tint(Color.accentDefault)
    }
    @MainActor private func load() async {
        error = nil
        do { let loaded: RewardRedemption = try await APIClient.shared.request(.rewardRedemption(order.id)); try Task.checkCancellation(); value = loaded }
        catch is CancellationError {} catch { self.error = error.localizedDescription }
    }
}
