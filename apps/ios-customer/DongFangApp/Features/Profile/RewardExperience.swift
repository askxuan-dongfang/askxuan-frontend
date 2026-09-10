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
    var oddsText: String {
        let n = kind == "pool" ? participantCount : capacity - participantCount
        let k = kind == "pool" ? min(prizeQuantity, n) : prizeQuantity - awardedCount
        return n > 0 ? String(format: "%.2f%%", Double(k) / Double(n) * 100) : "—"
    }
}
struct RewardEntry: Codable, Identifiable {
    var id, campaignId, createdAt, pointsSpent: Int64
    var code, outcome, title: String
    var outcomeText: String { ["pending":"等待开奖","won":"恭喜中奖","lost":"本期未中奖"][outcome] ?? outcome }
}
struct RewardOrder: Codable, Identifiable {
    var id, campaignId, entryId, createdAt, claimedAt, shippedAt, completedAt: Int64
    var prizeName, code, status, receiver, mobile, address, carrier, trackingNo: String
    var statusText: String { ["awaiting_address":"待填写地址","pending":"待发货","shipped":"已发货","completed":"已完成"][status] ?? status }
}
struct RewardDetail: Decodable { let campaign: RewardCampaign; var mine: RewardEntry?; let winners: [RewardEntry]; let pointsBalance: Int64 }
struct RewardAddressRequest: Encodable { let receiver, mobile, address: String }
func rewardDate(_ n: Int64) -> String {
    Date(timeIntervalSince1970: Double(n)).formatted(.dateTime.month().day().hour().minute())
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
                    Text("安").font(AppTypography.title(36)).foregroundStyle(Color(red: 1, green: 0.88, blue: 0.66)).frame(maxHeight: .infinity)
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
                    Text("缘").font(AppTypography.title(25)).foregroundStyle(Color.accentDefault)
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
                            Image(systemName: i.isMultiple(of: 2) ? "gift.fill" : "sparkle").font(AppTypography.caption)
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
                    Text(c.phaseText).font(.caption2.bold()).padding(8).background(Color.bgPrimary.opacity(0.85), in: Capsule())
                }.frame(height: 190).padding(8).background(Color.accentDefault.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                Text(c.title).font(.title3.bold()).foregroundStyle(Color.textPrimary)
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
    init(initialTab: Int = 1) { _tab = State(initialValue: initialTab) }
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
    @State private var generation = 0
    private var count: Int { tab < 2 ? campaigns.count : tab == 2 ? entries.count : orders.count }
    private var wheel: RewardCampaign? { campaigns.first { $0.id == selectedWheel } ?? campaigns.first { $0.phase == "open" } ?? campaigns.first { $0.phase == "scheduled" } ?? campaigns.first }
    var body: some View {
        VStack(spacing: 0) {
            Picker("活动分类", selection: $tab) {
                Text("转盘").tag(1); Text("大奖池").tag(0); Text("参与记录").tag(2); Text("我的奖品").tag(3)
            }.pickerStyle(.segmented).padding(.horizontal, 16).padding(.vertical, 10)
            if let error { VStack { Text(error).font(AppTypography.caption).foregroundStyle(.red); Button("重新加载") { Task { await load() } } }.padding() }
            if loading { ProgressView("正在准备活动…").padding() }
            if tab == 1, let wheel {
                if campaigns.count > 1 {
                    Picker("选择转盘活动", selection: Binding(get: { wheel.id }, set: { selectedWheel = $0 })) {
                        ForEach(campaigns) { Text($0.title).tag($0.id) }
                    }.tint(Color.accentDefault).padding(.horizontal)
                }
                RewardDetailView(id: wheel.id, embedded: true).id(wheel.id)
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
                    if tab == 3 { ForEach(orders) { orderCard($0) } }
                    if !loading && error == nil && count == 0 {
                        ContentUnavailableView(tab == 2 ? "还没有参与记录" : tab == 3 ? "还没有中奖礼物" : "下一份惊喜，正在准备", systemImage: "gift", description: Text("活动上线后即可使用积分参与，结果与领奖进度在这里查看。"))
                    }
                    if page > 1 || count >= 20 {
                        HStack { Button("上一页") { page -= 1 }.disabled(page == 1 || loading); Spacer(); Text("第 \(page) 页"); Spacer(); Button("下一页") { page += 1 }.disabled(count < 20 || loading) }.font(AppTypography.caption)
                    }
                    Text("功德值独立记录成长，与活动概率无关。").font(AppTypography.caption).foregroundStyle(.secondary)
                }.scrollContentBackground(.hidden).refreshable { await load() }
            }
        }.background(Color.bgPrimary)
        .navigationTitle("积分活动").navigationBarTitleDisplayMode(.inline)
        .task(id: "\(tab)-\(page)-\(auth.userId)") { await load() }
        .onChange(of: tab) { _, _ in page = 1; selectedWheel = nil }
        .sheet(item: $claim, onDismiss: { Task { await load() } }) { RewardClaimSheet(order: $0) }
        .alert("确认已收到奖品？", isPresented: Binding(get: { completing != nil }, set: { if !$0 { completing = nil } })) {
            Button("取消", role: .cancel) { completing = nil }
            Button("确认收货") { if let o = completing { Task { await complete(o) } } }
        } message: { Text("确认后本次实物领奖流程完成。") }
    }
    private func orderCard(_ o: RewardOrder) -> some View {
        Section {
            HStack { Text(o.prizeName).font(.headline); Spacer(); Text(o.statusText).font(AppTypography.caption).foregroundStyle(Color.accentDefault) }
            RewardDeliverySteps(status: o.status)
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
            if tab < 2 { let rows: [RewardCampaign] = try await APIClient.shared.request(.rewardCampaigns(page, tab == 0 ? "pool" : "wheel")); try Task.checkCancellation(); guard version == generation else { return }; campaigns = rows }
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
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) { proxy.scrollTo("reward-art", anchor: .top) }
            }
        }
        .background(Color.bgPrimary)
        .safeAreaInset(edge: .bottom) { if let d = detail, d.campaign.kind != "wheel" { actionBar(d) } }
        .navigationTitle(embedded ? "积分活动" : detail?.campaign.kind == "wheel" ? "幸运转盘" : "活动详情").navigationBarTitleDisplayMode(.inline)
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
        .sheet(item: $result) { entry in RewardResultSheet(entry: entry, prizeName: detail?.campaign.kind == "wheel" ? detail?.campaign.prizeName : nil).presentationDetents([.height(440)]).presentationDragIndicator(.visible) }
    }
    private func hero(_ d: RewardDetail) -> some View {
        VStack(spacing: 16) {
            Text("\(d.campaign.kind == "wheel" ? "LUCKY WHEEL" : "THE PRIZE POOL") · 第 \(id) 期").font(.caption2).tracking(2).foregroundStyle(Color.accentDefault)
            Text(d.campaign.title).font(AppTypography.title(28)).multilineTextAlignment(.center)
            Text(d.campaign.phaseText).font(AppTypography.caption).padding(.horizontal, 12).padding(.vertical, 6).background(Color.accentDefault.opacity(0.15), in: Capsule())
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
        VStack(spacing: 7) { Text(value).font(.title3.bold()).foregroundStyle(Color.accentDefault); Text(title).font(.system(size: 10)).foregroundStyle(.secondary) }
    }
    private func ticket(_ e: RewardEntry) -> some View {
        VStack(spacing: 14) {
            Text("我的专属参与码").font(AppTypography.caption)
            Text(e.code).font(.system(.title3, design: .monospaced)).foregroundStyle(Color.accentDefault).textSelection(.enabled)
            Text(spinning ? "正在揭晓…" : e.outcomeText).font(.headline)
            Text("消耗 \(e.pointsSpent) 积分 · \(rewardDate(e.createdAt))").font(AppTypography.caption).foregroundStyle(.secondary)
            if e.outcome == "won" && !spinning { NavigationLink("查看我的奖品并领奖") { RewardsView(initialTab: 3) }.buttonStyle(.borderedProminent) }
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
            try Task.checkCancellation(); detail = loaded
            error = nil
            if !spinning { rotation = detail?.mine?.outcome == "lost" ? 315 : 0 }
        } catch is CancellationError {} catch { self.error = error.localizedDescription }
    }
    @MainActor private func participate() async {
        guard !busy, detail?.mine == nil, let c = detail?.campaign else { return }
        busy = true; error = nil; defer { busy = false; spinning = false }
        do {
            let entry: RewardEntry = try await APIClient.shared.request(.rewardJoin(id, c.pointsCost))
            try Task.checkCancellation(); spinning = true; motionID += 1
            if c.kind == "wheel" {
                let target = entry.outcome == "won" ? 0.0 : 315.0
                withAnimation(reduceMotion ? nil : .timingCurve(0.12, 0.64, 0.1, 1, duration: 3.7)) { rotation += 2520 + (target - rotation.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) }
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
    @State private var showRecords = false
    private var c: RewardCampaign { detail.campaign }
    private var blocked: Bool { busy || hasError || (detail.mine == nil && (c.phase != "open" || detail.pointsBalance < c.pointsCost || c.pointsCost < 1)) }
    private var actionLabel: String {
        if busy { return "正在揭晓…" }
        if detail.mine != nil { return "查看本次结果" }
        if c.phase != "open" { return c.phaseText }
        return detail.pointsBalance < c.pointsCost ? "积分不足" : "\(c.pointsCost) 积分转一次"
    }
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 10) {
                Text("LUCKY WHEEL").font(.caption2).tracking(3).foregroundStyle(Color.accentDefault)
                Text(c.title).font(AppTypography.title(25)).multilineTextAlignment(.center)
                Text("积分抽好礼 · 即转即开").font(.caption2).foregroundStyle(.secondary)
                RewardWheelArt(rotation: spinning ? rotation : (detail.mine?.outcome == "lost" ? 315 : 0), spinning: spinning, cost: c.pointsCost).frame(height: 280).padding(.vertical, 8)
                HStack(spacing: 12) {
                    Group {
                        if let url = URL(string: c.image), !c.image.isEmpty {
                            AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { RewardGiftArt(kind: "wheel").frame(width: 100, height: 100).scaleEffect(0.45).frame(width: 52, height: 52) }
                        } else { RewardGiftArt(kind: "wheel").frame(width: 100, height: 100).scaleEffect(0.45).frame(width: 52, height: 52) }
                    }.frame(width: 52, height: 52).background(Color.accentDefault.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 4) { Text("本期好礼").font(.caption2).foregroundStyle(.secondary); Text(c.prizeName).font(.subheadline).foregroundStyle(Color.accentDefault) }
                }.padding(.bottom, 8)
                Button(action: detail.mine == nil ? onJoin : onResult) {
                    Text(actionLabel).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 15)
                        .foregroundStyle(Color.bgPrimary).background(LinearGradient(colors: [Color(red: 0.93, green: 0.83, blue: 0.63), Color.accentDefault], startPoint: .leading, endPoint: .trailing), in: Capsule())
                }.buttonStyle(.plain).disabled(blocked).opacity(blocked ? 0.5 : 1).accessibilityIdentifier("reward-wheel-draw")
                Text("可用 \(detail.pointsBalance) 积分 · \(detail.mine == nil ? "每期一次" : "本期已抽奖")").font(.caption2).foregroundStyle(.secondary)
            }.padding(18).frame(maxWidth: .infinity).background(LinearGradient(colors: [Color.brown.opacity(0.35), Color.bgSecondary], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 22))
            HStack {
                Button("抽奖记录") { showRecords = true }.frame(maxWidth: .infinity)
                Divider().frame(height: 14)
                NavigationLink("我的奖品") { RewardsView(initialTab: 3) }.frame(maxWidth: .infinity)
                Divider().frame(height: 14)
                Button("活动规则") { showRules = true }.frame(maxWidth: .infinity)
            }.font(AppTypography.caption).tint(Color.accentDefault).disabled(busy).padding(.vertical, 8)
        }
        .sheet(isPresented: $showRules) { RewardWheelInfoSheet(detail: detail, records: false) }
        .sheet(isPresented: $showRecords) { RewardWheelInfoSheet(detail: detail, records: true) }
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
                            Text(e.outcomeText).font(.title3.bold()).foregroundStyle(Color.accentDefault)
                            Text("\(rewardDate(e.createdAt)) · 消耗 \(e.pointsSpent) 积分").font(AppTypography.caption)
                            Text(e.code).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                            if e.outcome == "won" { NavigationLink("查看奖品与领奖") { RewardsView(initialTab: 3) } }
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
                    NavigationLink("查看全部参与记录") { RewardsView(initialTab: 2) }
                } else {
                    Section { Text(c.description); Text(c.rules) }.font(.subheadline)
                    Section {
                        LabeledContent("活动时间", value: "\(rewardDate(c.startsAt)) 至 \(rewardDate(c.endsAt))")
                        LabeledContent("奖品数量", value: "\(c.prizeQuantity) 份")
                        LabeledContent("参与情况", value: "\(c.participantCount) / \(c.capacity) 人 · \(c.phaseText)")
                        LabeledContent("下一位即时概率", value: c.oddsText)
                    }.font(AppTypography.caption)
                    Text("每个账号每期一次，参与成功扣除 \(c.pointsCost) 积分，无论中奖与否均不退回；失败不扣分，重复请求不重复扣分。当前概率为剩余奖品除以剩余名额，奖品预算由平台承担。转盘扇区仅作动画展示，不代表中奖概率。").font(AppTypography.caption).foregroundStyle(.secondary)
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
                Text("A LITTLE JOY").font(.caption2).tracking(2).foregroundStyle(Color.accentDefault)
                Text(entry.outcomeText).font(.title2.bold())
                Text(entry.outcome == "pending" ? "参与码已为你生成，静候这一期的惊喜。" : entry.outcome == "won" ? "这份小欢喜，属于你。" : "谢谢参与，愿下一份好运与你相逢。").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                if let prizeName { if entry.outcome == "won" { Text(prizeName).font(.headline).foregroundStyle(Color.accentDefault) } } else { Text(entry.code).font(.system(.subheadline, design: .monospaced)).foregroundStyle(Color.accentDefault) }
                Text("已扣 \(entry.pointsSpent) 积分").font(AppTypography.caption)
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
    var body:some View { NavigationStack { Form { Section(order.prizeName) { Text("平台包邮，填写地址后进入待发货。").font(.subheadline);Text(order.code).font(AppTypography.caption) };Section("收货信息") { TextField("收货人",text:$receiver).textContentType(.name);TextField("联系电话",text:$mobile).keyboardType(.phonePad).textContentType(.telephoneNumber);TextField("省市区、街道与门牌号",text:$address,axis:.vertical).textContentType(.fullStreetAddress).lineLimit(3...5) }.disabled(busy);if let error {Text(error).foregroundStyle(.red)};Section { Text("提交后请等待平台发货，请先核对地址和联系电话。").font(AppTypography.caption);Button(busy ? "提交中…":"确认地址，等待发货") {Task{await submit()}}.disabled(busy||receiver.trimmingCharacters(in:.whitespaces).isEmpty||mobile.count<6||address.count<5) } }.navigationTitle("领奖地址").navigationBarTitleDisplayMode(.inline).toolbar {ToolbarItem(placement:.cancellationAction){Button("稍后填写"){dismiss()}.disabled(busy)}}.interactiveDismissDisabled(busy) } }
    @MainActor private func submit()async {busy=true;error=nil;defer{busy=false};do{let _:PointsActionResult=try await APIClient.shared.request(.rewardClaim(order.id,RewardAddressRequest(receiver:receiver.trimmingCharacters(in:.whitespacesAndNewlines),mobile:mobile.trimmingCharacters(in:.whitespacesAndNewlines),address:address.trimmingCharacters(in:.whitespacesAndNewlines))));dismiss()}catch{self.error=error.localizedDescription}}
}
