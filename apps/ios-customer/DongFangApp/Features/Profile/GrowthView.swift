import SwiftUI
import AVKit

struct GrowthView: View {
    @EnvironmentObject private var auth: AuthStore
    @State private var tab = "overview"
    @State private var overview: GrowthOverview?
    @State private var records: GrowthRecords?
    @State private var notes: [GrowthNote] = []
    @State private var contents: [GrowthContent] = []
    @State private var activities: [GrowthActivity] = []
    @State private var support: [GrowthSupport] = []
    @State private var reader: GrowthContent?
    @State private var error: String?
    @State private var notice: String?
    @State private var busy = false
    @State private var page = 1
    @State private var action = ""
    @State private var noteBody = ""
    @State private var supportBody = ""
    @State private var supportCategory = "growth"
    @State private var supportRequest = UUID().uuidString
    @State private var deletion: GrowthNote?
    @State private var period = Self.currentMonth
    @State private var yearly = false
    @State private var summary: GrowthSummary?
    private static var currentMonth: String { let f = DateFormatter(); f.locale = Locale(identifier:"en_US_POSIX"); f.timeZone = TimeZone(identifier:"Asia/Shanghai"); f.dateFormat = "yyyy-MM"; return f.string(from:Date()) }
    var body: some View {
        List {
            Section { Picker(L10n.text("成长中心"), selection: $tab) { Text(L10n.text("档案")).tag("overview"); Text(L10n.text("任务")).tag("tasks"); Text(L10n.text("明细")).tag("records"); Text(L10n.text("权益")).tag("benefits") }.pickerStyle(.segmented) }
            if let error { Section { Text(L10n.lookup(error)).foregroundStyle(.red); Button(L10n.text("重试")) { Task { await load() } }.disabled(busy) } }
            if let notice { Text(L10n.lookup(notice)).accessibilityAddTraits(.updatesFrequently) }
            if busy { ProgressView() }
            if let v = overview {
                switch tab {
                case "tasks": tasks(v)
                case "records": history
                case "benefits": benefits(v)
                default: archive(v)
                }
            }
        }.navigationTitle(L10n.text("我的成长"))
            .task(id: "\(auth.sessionID)-\(tab)") { await load() }
            .refreshable { await load() }
            .sheet(item: $reader, onDismiss: { Task { await load() } }) { GrowthLearningView(content: $0) }
            .confirmationDialog(L10n.text("删除这条私人记录？成长值不受影响。"), isPresented: Binding(get: { deletion != nil }, set: { if !$0 { deletion = nil } })) { Button(L10n.text("删除"), role: .destructive) { if let n = deletion { Task { await mutate("notes/delete", ["day":n.day]); deletion = nil } } } }
    }
    @ViewBuilder private func archive(_ v: GrowthOverview) -> some View {
        Section {
            HStack { Text("L\(v.level.code)").font(.title2.weight(.semibold)).padding(12).overlay(Circle().stroke(Color.accentColor)); VStack(alignment: .leading) { Text(L10n.lookup(v.level.name)).font(.title2); Text("\(v.total) "+L10n.text("成长值")).font(.largeTitle).monospacedDigit() } }
            ProgressView(value: v.nextThreshold > 0 ? Double(v.total-v.level.threshold) : 1, total: v.nextThreshold > 0 ? Double(v.nextThreshold-v.level.threshold) : 1)
            Text(v.remaining > 0 ? L10n.text("距下一级还需")+" \(v.remaining) "+L10n.text("成长值") : L10n.text("已达到最高等级")).font(.caption)
            LabeledContent(L10n.text("待入账"), value: "\(v.pending)")
            LabeledContent(L10n.text("本月任务"), value: "\(v.monthlyEarned) / \(v.monthlyLimit)")
        }
        Section(L10n.text("每一步，都算数")) {
            Text(L10n.text("成长值记录个人成长，不可支付、兑换或转赠。积分和钱包各自独立。"))
            Text(L10n.text("成长值不按年清零，退款与纠错可能影响等级。等级不代表宗教修行或专业资质。"))
            Text(L10n.text("符合规则的真实现金消费按实付每 1 元计 1 成长值，订单完成并经过 7 天观察期后入账。不含自愿随喜、运费、充值、押金、积分和模拟支付。"))
            Button(L10n.text("开始今日成长")) { tab = "tasks" }
        }
        Section {
            Toggle(L10n.text("展示我的等级徽章"), isOn: Binding(get: { v.badgeVisible }, set: { value in Task { await mutate("preferences", ["badgeVisible":value]) } })).disabled(busy)
            Text(L10n.text("行动记录仅自己可见。"))
        }
    }
    @ViewBuilder private func tasks(_ v: GrowthOverview) -> some View {
        Section(L10n.text("今日成长")) {
            ForEach(v.tasks) { task in
                VStack(alignment: .leading, spacing: 6) {
                    HStack { Text(GrowthAPI.label(task.kind)); Spacer(); Text("+\(task.award)").foregroundStyle(.secondary) }
                    Text("\(min(task.used,task.limit)) / \(task.limit) · "+L10n.lookup(task.period == "day" ? L10n.text("每日") : task.period == "month" ? L10n.text("每月") : L10n.text("一次"))).font(.caption)
                    if task.kind == "profile" { Button(L10n.lookup(task.used > 0 ? L10n.text("已完成") : L10n.text("核验昵称与头像"))) { Task { await mutate("profile", [:]) } }.disabled(busy || task.used > 0) }
                    if !task.available { Text(L10n.text("暂无开放内容")).font(.caption) }
                }.padding(.vertical, 4)
            }
            NavigationLink(L10n.text("查看订单与评价")) { OrderListView() }
            Text(L10n.text("周期任务每月最多 200 成长值，完善资料的一次性奖励单独计算。"))
        }
        Section(L10n.text("记录今日行动")) {
            TextField(L10n.text("今天做了什么"), text: $action).onChange(of: action) { _, value in action = String(value.prefix(120)) }
            TextEditor(text: $noteBody).frame(minHeight: 100).accessibilityLabel(L10n.text("给自己的记录")).onChange(of: noteBody) { _, value in noteBody = String(value.prefix(2000)) }
            Text(L10n.text("仅自己可见。每日首次记录获得成长值，编辑和删除不重复奖励。" )).font(.caption)
            Button(L10n.text("保存今日记录")) { Task { await mutate("notes", ["action":action,"body":noteBody]) } }.disabled(busy || action.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            ForEach(notes) { n in DisclosureGroup(n.day+" · "+n.action) { Text(n.body); Button(L10n.text("删除"), role: .destructive) { deletion = n }.disabled(busy) } }
        }
        Section(L10n.text("每日学习")) {
            Text(L10n.text("文章需前台阅读满 60 秒并读至结尾；音视频需有效观看至少 80%。同一内容只计一次。" )).font(.caption)
            if contents.isEmpty { Text(L10n.text("学习内容准备中")) }
            ForEach(contents) { c in Button(L10n.lookup(c.title)) { reader = c } }
        }
        Section(L10n.text("官方活动")) {
            if activities.isEmpty { Text(L10n.text("暂无开放活动")) }
            ForEach(activities) { a in VStack(alignment: .leading, spacing: 8) {
                Text(L10n.lookup(a.title)).font(.headline); Text(L10n.lookup(a.description)); Text(GrowthAPI.date(a.startsAt)+" — "+GrowthAPI.date(a.endsAt)).font(.caption)
                Button(L10n.lookup(a.verifiedAt > 0 ? L10n.text("已核验") : a.registeredAt > 0 ? L10n.text("等待参与核验") : L10n.text("登记参与"))) { Task { await mutate("activities/register", ["id":a.id]) } }.disabled(busy || a.registeredAt > 0 || a.endsAt < Int64(Date().timeIntervalSince1970))
            } }
        }
    }
    @ViewBuilder private var history: some View {
        if let records {
            Section(L10n.text("待入账")) { if records.pending.isEmpty { Text(L10n.text("暂无待入账记录")) }; ForEach(records.pending) { r in VStack(alignment:.leading,spacing:6) { HStack {Text(r.referenceNo);Spacer();Text("+\(r.amount)")};Text(GrowthAPI.label(r.reason)).font(.caption); if r.eligibleAt > 0 { Text(GrowthAPI.date(r.eligibleAt)).font(.caption) } } } }
            Section(L10n.text("成长明细")) {
                if records.entries.isEmpty { Text(L10n.text("完成第一项成长任务，留下你的记录")) }
                ForEach(records.entries) { r in HStack { VStack(alignment:.leading,spacing:6) {Text(GrowthAPI.label(r.kind));Text(GrowthAPI.date(r.createdAt)+" · "+r.referenceNo).font(.caption).foregroundStyle(.secondary)};Spacer();VStack(alignment:.trailing) {Text(r.delta > 0 ? "+\(r.delta)" : "\(r.delta)");Text(L10n.text("累计")+" \(r.totalAfter)").font(.caption)} } }
                if records.hasMore { Button(L10n.text("加载更多")) { Task { await moreRecords() } }.disabled(busy) }
            }
        }
    }
    @ViewBuilder private func benefits(_ v: GrowthOverview) -> some View {
        Section(L10n.text("五级权益")) {
            ForEach(v.levels) { l in VStack(alignment: .leading, spacing: 8) {
                HStack {Text("L\(l.code) "+L10n.lookup(l.name)).font(.headline);Spacer();Text("\(l.threshold) "+L10n.text("成长值起")).font(.caption)}
                Text(L10n.text("指定商品")+" "+GrowthAPI.rate(l.goodsRateBps)+" · "+L10n.text("指定服务")+" "+GrowthAPI.rate(l.serviceRateBps)).font(.subheadline)
                Text(L10n.lookup(l.benefit));if l.couponValueCents > 0 {Text(L10n.text("首次升级礼券")+" ¥"+GrowthAPI.money(l.couponMinimumCents)+"−"+GrowthAPI.money(l.couponValueCents)).font(.caption)}
            }.padding(.vertical, 5) }
            Text(L10n.text("权益逐级累积。折扣仅适用于已加入的商品和固定价服务，平台承担补贴；等级优惠、活动价和一张礼券择优使用，不叠加。"))
            Text(L10n.text("手工制作费、自愿随喜、运费、充值、押金、积分与模拟订单不参与折扣。单单商品优惠最高 100 元、服务最高 50 元，每月等级优惠最高 300 元，以收银台报价为准。"))
            if !v.discountsEnabled { Text(L10n.text("等级折扣尚未启用，当前按商品原定价格结算。")) }
        }
        Section(L10n.text("升级礼券")) {
            if v.coupons.isEmpty { Text(L10n.text("达到同行等级后解锁首次升级礼券")) }
            ForEach(v.coupons) { c in VStack(alignment:.leading,spacing:6) { Text("¥"+GrowthAPI.money(c.valueCents)+" · "+L10n.text("满")+" ¥"+GrowthAPI.money(c.minimumCents));Text("L\(c.level) · "+GrowthAPI.label(c.status));if c.expiresAt > 0 {Text(GrowthAPI.date(c.expiresAt)).font(.caption)} } }
            Text(L10n.text("每级仅发一次，有效期 30 天。额度准备中会显示待发放；降级撤回未用高等级券，再升级不重复发放。"))
        }
        if v.level.code >= 3 { summarySection(v) }
        Section(L10n.text("平台客服")) {
            Text(L10n.text("致远及以上在同紧急程度下优先分流，不承诺即时响应。"))
            Picker(L10n.text("问题类型"), selection:$supportCategory) {Text(L10n.text("成长权益")).tag("growth");Text(L10n.text("订单")).tag("order");Text(L10n.text("退款")).tag("refund")}
            TextEditor(text:$supportBody).frame(minHeight:100).accessibilityLabel(L10n.text("问题说明")).onChange(of:supportBody) {_,v in supportBody=String(v.prefix(2000))}
            Button(L10n.text("提交问题")) { Task { await mutate("support",["requestId":supportRequest,"category":supportCategory,"body":supportBody]);if error == nil {supportRequest=UUID().uuidString;supportBody=""} } }.disabled(busy || supportBody.count < 2)
            ForEach(support) { s in DisclosureGroup(s.body) {Text(L10n.lookup(s.status == "replied" ? L10n.text("已回复") : L10n.text("处理中")));Text(s.reply)} }
        }
    }
    @ViewBuilder private func summarySection(_ v: GrowthOverview) -> some View {
        Section(L10n.lookup(yearly ? L10n.text("年度成长纪念卡") : L10n.text("月度成长回顾"))) {
            Toggle(L10n.text("年度回顾 · 恒久权益"), isOn:$yearly).disabled(v.level.code < 5).onChange(of:yearly) {_,value in period=value ? String(period.prefix(4)) : String(period.prefix(4))+"-01";summary=nil}
            TextField(L10n.text("回顾期间"),text:$period).keyboardType(.numbersAndPunctuation)
            Button(L10n.text("查看回顾")) { Task {busy=true;error=nil;summary=nil;defer{busy=false};do{summary=try await GrowthAPI.request("summary?period=\(period)&yearly=\(yearly)")}catch{self.error=error.localizedDescription}} }.disabled(busy)
            if let s=summary {Text(s.period).font(.headline);Text(L10n.text("新增")+" +\(s.added) · "+L10n.text("回退")+" \(s.reversed)");ForEach(s.bySource){r in Text(GrowthAPI.label(r.kind)+" · \(r.count) "+L10n.text("次")+" · \(r.amount)")} }
        }
    }
    @MainActor private func load() async {
        busy=true;error=nil;defer{busy=false}
        do {
            let v:GrowthOverview=try await GrowthAPI.request("overview");guard !Task.isCancelled else{return};overview=v
            switch tab {
            case "tasks":async let c:[GrowthContent]=GrowthAPI.request("contents");async let a:[GrowthActivity]=GrowthAPI.request("activities");async let n:[GrowthNote]=GrowthAPI.request("notes");let data=try await(c,a,n);guard !Task.isCancelled else{return};contents=data.0;activities=data.1;notes=data.2
            case "records":let r:GrowthRecords=try await GrowthAPI.request("records?page=1");guard !Task.isCancelled else{return};records=r;page=1
            case "benefits":support=try await GrowthAPI.request("support")
            default:break
            }
        } catch is CancellationError {} catch {self.error=error.localizedDescription}
    }
    @MainActor private func mutate(_ path:String,_ body:[String:Any]) async {
        guard !busy else{return};busy=true;error=nil;notice=nil
        do {let _:GrowthAck=try await GrowthAPI.request(path,body:body);notice=L10n.text("已保存");await load()}catch{self.error=error.localizedDescription};busy=false
    }
    @MainActor private func moreRecords() async {
        guard !busy,let old=records else{return};busy=true;defer{busy=false}
        do {var next:GrowthRecords=try await GrowthAPI.request("records?page=\(page+1)");next.entries=old.entries+next.entries;records=next;page += 1}catch{self.error=error.localizedDescription}
    }
}

private struct GrowthEndPreference:PreferenceKey {static var defaultValue:CGFloat=CGFloat.infinity;static func reduce(value:inout CGFloat,nextValue:()->CGFloat){value=nextValue()}}
private struct GrowthLearningView:View {
    let content:GrowthContent
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var session:GrowthLearning?
    @State private var error:String?
    @State private var reachedEnd=false
    @State private var player:AVPlayer?
    var body:some View {
        NavigationStack {
            GeometryReader { viewport in
                ScrollView {VStack(alignment:.leading,spacing:20) {
                    Text(L10n.lookup(content.title)).font(.title2)
                    Text(session?.completed == true ? L10n.text("学习已记录") : L10n.text("有效阅读")+" \(session?.elapsedSeconds ?? 0) / \(content.kind == "media" ? (content.durationSeconds*8+9)/10 : 60) "+L10n.text("秒")).font(.caption)
                    if let error {Text(L10n.lookup(error)).foregroundStyle(.red)}
                    if content.kind == "media" {VideoPlayer(player:player).frame(height:260)} else {Text(content.body).lineSpacing(8)}
                    Text(L10n.text("已读至结尾")).frame(maxWidth:.infinity).background(GeometryReader {proxy in Color.clear.preference(key:GrowthEndPreference.self,value:proxy.frame(in:.named("growthViewport")).maxY)})
                    Text(L10n.text("成长值以服务端核验和每日额度为准。" )).font(.caption)
                }.padding(20)}.onPreferenceChange(GrowthEndPreference.self){reachedEnd=$0>=0 && $0<=viewport.size.height}
            }.coordinateSpace(name:"growthViewport")
            .navigationTitle(L10n.text("每日学习")).navigationBarTitleDisplayMode(.inline)
            .toolbar{ToolbarItem(placement:.cancellationAction){Button(L10n.text("完成")){dismiss()}}}
            .task {await learn()}.onDisappear{player?.pause()}
        }
    }
    @MainActor private func learn() async {
        do {
            if content.kind == "media",let url=URL(string:content.mediaUrl){player=AVPlayer(url:url)}
            session=try await GrowthAPI.request("learning/start",body:["id":content.id])
            while !Task.isCancelled,let s=session,!s.completed {
                try await Task.sleep(for:.seconds(10))
                let visible=phase == .active && (content.kind != "media" || (player?.rate ?? 0)>0)
                let end=content.kind == "media" ? (player?.currentTime().seconds ?? 0)>=Double(content.durationSeconds)*0.8 : reachedEnd
                session=try await GrowthAPI.request("learning/heartbeat",body:["sessionId":s.sessionId,"visible":visible,"reachedEnd":end])
            }
        }catch is CancellationError {}catch{self.error=error.localizedDescription}
    }
}
