import SwiftUI

struct AiTopic: Decodable, Identifiable {
    var id: String { code }
    let code: String; let title: String; let subtitle: String
    let priceCents: Int64; let pointsPrice: Int64; let chapters: [String]; let version: String
    var seal: String { ["bazi":"命","ziwei":"星","marriage":"缘","fengshui":"居","liuyao":"卦","qimen":"局","tarot":"心"][code] ?? "问" }
}
struct AiReport: Decodable, Identifiable {
    let id: Int64; let reportNo: String; let skillCode: String; let title: String; let version: String
    let question: String; let chapters: [String]; let priceCents: Int64; let pointsPrice: Int64
    let status: String; let summary: String; let content: String; let errorMessage: String
    let unlocked: Bool; let createdAt: String
}
struct AiReportCreateRequest: Encodable { let skillCode: String; let question: String; let inputs: [String:String]; let requestKey: String }
struct AiReportUnlockRequest: Encodable { let reportId: Int64; let expectedPoints: Int64 }
private struct ReportConversationResult: Decodable { let sessionId: Int64 }
private struct ReportUnlockResult: Decodable { let unlocked: Bool }
private struct ReportBalance: Decodable { let balance: Int64 }
private let reportGreen = Color(red: 0.19, green: 0.36, blue: 0.28)
private let reportPaper = Color(red: 0.97, green: 0.96, blue: 0.93)

struct AiTopicEntrances: View {
    @State private var topics: [AiTopic] = []
    @State private var selected: AiTopic?
    @State private var library = false
    @State private var error = false
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("EXPLORE · 专题探索").font(.system(size: 10)).tracking(2).opacity(0.7)
                    Text("一事一解，自有章法").font(AppTypography.title(23))
                }
                Spacer()
                Button("我的报告 ↗") { library = true }.font(.system(size: 12))
            }
            if error { Button("专题暂未加载 · 点击重试") { Task { await load() } }.font(.footnote) }
            Text("想系统地了解一个主题？选一份专题，按引导补充资料。").font(.system(size: 12)).foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                ForEach(topics) { topic in Button { selected = topic } label: { AiTopicTile(topic: topic) }.buttonStyle(.plain) }
            }
            Text("免费生成摘要 · 完整解读按专题使用积分").font(.system(size: 10)).foregroundStyle(.secondary).frame(maxWidth: .infinity)

        }.padding(18).foregroundStyle(reportGreen).background(reportPaper).clipShape(RoundedRectangle(cornerRadius: 22))
        .task { await load() }
        .fullScreenCover(item: $selected) { topic in NavigationStack { AiReportWorkspace(topic: topic) } }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("AskXuanReportConversation"))) { _ in selected = nil; library = false }
        .fullScreenCover(isPresented: $library) { NavigationStack { AiReportLibrary() } }
    }
    private func load() async { do { topics = try await APIClient.shared.request(.aiTopics); error = false } catch { self.error = true } }
}

struct AiReportWorkspace: View {
    var topic: AiTopic? = nil
    var reportID: Int64? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var skill: AiSkill?
    @State private var inputs: [String:String] = [:]
    @State private var question = ""
    @State private var requestKey = UUID().uuidString
    @State private var report: AiReport?
    @State private var balance: Int64?
    @State private var busy = false
    @State private var loading = true
    @State private var error = ""
    @State private var dateField: AiSkillField?
    @State private var pickedDate = Date()
    @State private var confirm = false
    @State private var step = 0
    @State private var submittedRequest: AiReportCreateRequest?
    @State private var largeType = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var accent: Color { AiTopicPresentation(code: topic?.code ?? report?.skillCode ?? "fengshui").color }
    private var fieldsReady: Bool { (skill?.inputSchema.fields ?? []).allSatisfy { $0.valid(in: inputs) } }
    private var visibleFields: [AiSkillField] { (skill?.inputSchema.fields ?? []).filter { $0.visible(in: inputs) } }
    private var cleanInputs: [String: String] { Dictionary(uniqueKeysWithValues: visibleFields.compactMap { field in let value = (inputs[field.key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines); return value.isEmpty ? nil : (field.key, value) }) }
    private func setInput(_ key: String, _ value: String) { inputs[key] = value; inputs = cleanInputs }
    private func dateFormatter(_ type: String) -> DateFormatter { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(secondsFromGMT: 8 * 3600); f.dateFormat = type == "date" ? "yyyy-MM-dd" : type == "time" ? "HH:mm" : "yyyy-MM-dd'T'HH:mm"; return f }
    private var questionReady: Bool { !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && question.count <= 1500 }

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if !error.isEmpty { Text(error).font(.footnote).foregroundStyle(.red).padding().accessibilityLabel("错误：" + error) }
                if loading { ProgressView("正在整理内容…").frame(maxWidth: .infinity).padding(40) }
                if let report { reportBody(report, proxy: proxy) }
                else if let topic { topicBody(topic) }
                Text("问玄东方 · 以文化为镜，以生活为本").font(.system(size: 11)).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 25)
            }.padding(20).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        }.background(reportPaper).foregroundStyle(accent).preferredColorScheme(.light)
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("返回问事") { dismiss() } }; ToolbarItem(placement: .principal) { Text("问玄 · 专题").font(AppTypography.navigation) } }
        .navigationBarTitleDisplayMode(.inline)
        .task { await load(); await refreshBalance() }
        .task(id: report?.status) {
            guard report?.status == "generating" else { return }
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(3)); guard let id = report?.id else { return }; let next: AiReport = try await APIClient.shared.request(.aiReport(id)); report = next; if next.status != "generating" { return } }
                catch { if !Task.isCancelled { self.error = error.localizedDescription }; return }
            }
        }
        .sheet(item: $dateField) { field in
            NavigationStack {
                DatePicker(field.label, selection: $pickedDate, displayedComponents: field.type == "date" ? [.date] : field.type == "time" ? [.hourAndMinute] : [.date, .hourAndMinute]).datePickerStyle(.wheel).labelsHidden().environment(\.locale, Locale(identifier: "zh_CN")).environment(\.timeZone, TimeZone(secondsFromGMT: 8 * 3600)!).padding()
                    .navigationTitle(field.label).navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("确定") { setInput(field.key, dateFormatter(field.type).string(from: pickedDate)); dateField = nil } }; ToolbarItem(placement: .cancellationAction) { Button("取消") { dateField = nil } } }
            }.presentationDetents([.height(340)])
        }
        .confirmationDialog("确认购买完整报告？", isPresented: $confirm, titleVisibility: .visible) {
            if let report { Button("使用 \(report.pointsPrice) 积分解锁") { Task { await unlock(report) } }.disabled(busy || balance == nil || (balance ?? 0) < report.pointsPrice) }
            Button("取消", role: .cancel) {}
        } message: { if let report, let balance { Text("当前余额 \(balance) 积分，解锁后剩余 \(balance - report.pointsPrice) 积分。购买后可重复阅读。") } }
    }
    private func hero(_ title: String, subtitle: String) -> some View {
        HStack(spacing: 5) {
            VStack(alignment: .leading, spacing: 12) {
                Text("EXPLORE / 专题解读").font(.system(size: 9)).tracking(2).opacity(0.6)
                Text(title).font(AppTypography.title(28)).foregroundStyle(accent)
                Text(subtitle).font(.system(size: 13)).lineSpacing(5).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
            AiTopicArtwork(code: topic?.code ?? report?.skillCode ?? "fengshui").frame(width: 116, height: 135)
        }.padding(.vertical, 23)
    }
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16, content: content).padding(22).frame(maxWidth: .infinity, alignment: .leading).background(Color.white.opacity(0.9)).clipShape(RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(accent.opacity(0.10)))
    }
    private func chapters(_ list: [String]) -> some View {
        ForEach(Array(list.enumerated()), id: \.offset) { index, title in HStack(spacing: 16) { Text(String(format: "%02d", index + 1)).font(AppTypography.title(14)).opacity(0.5); Text(title).font(.system(size: 14)); Spacer() }.padding(.vertical, 5) }
    }
    private func primary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(busy ? "正在处理…" : title).font(.system(size: 14, weight: .medium)).frame(maxWidth: .infinity).padding(16).background(accent).foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 12)) }.disabled(busy)
    }
    @ViewBuilder private func topicBody(_ topic: AiTopic) -> some View {
        hero(topic.title, subtitle: topic.subtitle)
        HStack { Text("摘要免费"); Text("·"); Text("完整解读 \(topic.pointsPrice) 积分") }.font(.system(size: 11)).foregroundStyle(accent).padding(.bottom, 5)
        card {
            HStack(spacing: 12) {
                Label("补充资料", systemImage: step == 1 ? "checkmark.circle.fill" : "1.circle.fill").opacity(step == 0 ? 1 : 0.6)
                Rectangle().frame(height: 1).opacity(0.2)
                Label("说说问题", systemImage: "2.circle.fill").opacity(step == 1 ? 1 : 0.4)
            }.font(.system(size: 12))
            Text(step == 0 ? "为这次解读，补充一点线索" : "这一次，您最在意什么？").font(AppTypography.section).padding(.top, 8)
            if step == 0 {
                Text("补充标注“必填”的资料；选填内容不确定时可以留空。").font(.footnote).foregroundStyle(.secondary)
                ForEach(visibleFields) { field in fieldView(field) }
                primary("下一步，说说问题 →") { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { step = 1 } }.disabled(skill == nil || !fieldsReady)
            } else {
                ForEach(AiTopicPresentation(code: topic.code).prompts, id: \.self) { prompt in
                    Button { question = prompt } label: { HStack { Text(prompt).multilineTextAlignment(.leading); Spacer(); Image(systemName: "plus") }.font(.system(size: 12)).padding(13).frame(maxWidth: .infinity, alignment: .leading).background(accent.opacity(0.07)).clipShape(RoundedRectangle(cornerRadius: 12)) }.buttonStyle(.plain).disabled(submittedRequest != nil)
                }
                Text("最想了解的问题 *").font(.subheadline)
                TextEditor(text: $question).frame(minHeight: 125).padding(8).scrollContentBackground(.hidden).background(reportPaper).clipShape(RoundedRectangle(cornerRadius: 10)).accessibilityLabel("最想了解的问题").disabled(submittedRequest != nil)
                Text("\(question.count) / 1500").font(.caption2).foregroundStyle(question.count > 1500 ? .red : .secondary).frame(maxWidth: .infinity, alignment: .trailing)
                if !(skill?.inputSchema.fields.isEmpty ?? true) { Button("← 修改资料") { step = 0 }.font(.footnote).disabled(busy || submittedRequest != nil) }
                primary(submittedRequest == nil ? "生成免费摘要 →" : "重试提交") { Task { await create(topic) } }.disabled(skill == nil || !fieldsReady || !questionReady)
                Text(submittedRequest == nil ? "生成摘要不扣积分，阅读后再决定是否解锁。" : "若提交超时，重试会查询同一次请求，也可前往我的报告查看。").font(.footnote).foregroundStyle(.secondary)
            }
        }
        card { DisclosureGroup("这份解读，将为您梳理哪些线索？") { VStack(alignment: .leading, spacing: 12) { chapters(topic.chapters); Text("传统文化参考，不承诺预测结果。主题图形用于视觉表达，不代表您的排盘或抽牌结果。").font(.footnote).foregroundStyle(.secondary) }.padding(.top, 14) }.font(.subheadline).tint(accent) }
    }
    private func binding(_ key: String) -> Binding<String> { Binding(get: { inputs[key] ?? "" }, set: { setInput(key, $0) }) }
    @ViewBuilder private func fieldView(_ field: AiSkillField) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text(field.label).font(AppTypography.body); Text(field.needed(in: inputs) ? "必填" : "选填").font(AppTypography.caption).foregroundStyle(.secondary) }
            if let help = field.helpText { Text(help).font(AppTypography.caption).foregroundStyle(.secondary).lineSpacing(5) }
            if field.type == "select" {
                VStack(spacing: 9) {
                    ForEach(field.options ?? []) { option in
                        Button { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { setInput(field.key, option.value) } } label: {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 5) { Text(option.label).font(AppTypography.body); if let description = option.description { Text(description).font(AppTypography.caption).foregroundStyle(.secondary) } }
                                Spacer(minLength: 8)
                                Image(systemName: inputs[field.key] == option.value ? "checkmark.circle.fill" : "circle").foregroundStyle(accent)
                            }.multilineTextAlignment(.leading).padding(14).frame(maxWidth: .infinity, alignment: .leading).background(inputs[field.key] == option.value ? accent.opacity(0.09) : reportPaper).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(inputs[field.key] == option.value ? accent : accent.opacity(0.13)))
                        }.buttonStyle(.plain).accessibilityLabel(option.label).accessibilityValue(inputs[field.key] == option.value ? "已选择" : "未选择").accessibilityAddTraits(inputs[field.key] == option.value ? [.isSelected] : [])
                    }
                }
            } else if field.key == "birthDate" && inputs["calendarType"] == "lunar" {
                TextField("YYYY-MM-DD，例如 1990-02-30", text: binding(field.key)).font(AppTypography.body).textInputAutocapitalization(.never).autocorrectionDisabled().padding(14).background(reportPaper).clipShape(RoundedRectangle(cornerRadius: 12)).accessibilityLabel("农历出生日期")
            } else if ["date", "time", "datetime"].contains(field.type) {
                Button { pickedDate = dateFormatter(field.type).date(from: inputs[field.key] ?? "") ?? Date(); dateField = field } label: { HStack { Text(inputs[field.key] ?? "请选择" + field.label); Spacer(); Image(systemName: field.type == "time" ? "clock" : "calendar") }.padding(14).background(reportPaper).clipShape(RoundedRectangle(cornerRadius: 12)) }.tint(accent)
                if field.type == "datetime" { Button { setInput(field.key, dateFormatter("datetime").string(from: Date())) } label: { Label("使用当前北京时间", systemImage: "clock") }.font(AppTypography.caption).tint(accent).padding(.vertical, 5) }
            } else {
                TextField(field.placeholder ?? "请填写", text: binding(field.key)).font(AppTypography.body).textInputAutocapitalization(.never).autocorrectionDisabled().padding(14).background(reportPaper).clipShape(RoundedRectangle(cornerRadius: 12)).accessibilityLabel(field.label)
                if !(inputs[field.key] ?? "").isEmpty && !field.valid(in: inputs) { Text("请填写 2–3 个 0–999999 的整数，以空格或逗号分隔。").font(AppTypography.caption).foregroundStyle(.red) }
            }
        }
    }
    @ViewBuilder private func reportBody(_ r: AiReport, proxy: ScrollViewProxy) -> some View {
        hero(r.title, subtitle: r.question)
        if r.status == "generating" {
            card { AiTopicArtwork(code: r.skillCode).frame(height: 150).frame(maxWidth: .infinity); ProgressView("报告生成中 · 尚未扣除积分").font(.footnote); Text("正在整理您的专题报告").font(.headline); Text("您可以离开，稍后在我的报告查看。当前尚未扣款；超过五分钟可恢复生成。").font(.subheadline); primary("检查并恢复生成") { Task { await retry(r) } } }
        } else if r.status == "failed" {
            card { Text("这次生成未能完成").font(.headline); Text(r.errorMessage); primary("免费重试") { Task { await retry(r) } } }
        } else {
            card { Text("分析摘要").font(AppTypography.section); Text(r.summary).lineSpacing(7) }
            if r.unlocked {
                card {
                    HStack { Text("完整分析 · 已解锁").font(AppTypography.section); Spacer(); Button(largeType ? "标准字号" : "放大字号") { largeType.toggle() }.font(AppTypography.caption) }
                    DisclosureGroup("章节导航") {
                        ForEach(Array(r.content.components(separatedBy: "\n").enumerated()), id: \.offset) { index, line in
                            if line.hasPrefix("#") { Button(line.trimmingCharacters(in: CharacterSet(charactersIn: "# "))) { withAnimation(reduceMotion ? nil : .easeInOut) { proxy.scrollTo("chapter-\(index)", anchor: .top) } }.font(.subheadline).padding(.vertical, 5) }
                        }
                    }
                    ForEach(Array(r.content.components(separatedBy: "\n").enumerated()), id: \.offset) { index, line in
                        if line.hasPrefix("#") { Text(line.trimmingCharacters(in: CharacterSet(charactersIn: "# "))).font(AppTypography.title(largeType ? 24 : 20)).foregroundStyle(accent).padding(.top, 20).id("chapter-\(index)") }
                        else if !line.isEmpty { Text(.init(line)).font(largeType ? .title3 : .body).foregroundStyle(Color(red: 0.26, green: 0.31, blue: 0.25)).textSelection(.enabled).lineSpacing(8) }
                    }
                    Text("✦ 让解读回到生活，让行动带来答案。").font(AppTypography.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 20);
 ShareLink(item: r.title + "\n\n" + r.content) { Label("保存或分享报告", systemImage: "square.and.arrow.up") }; primary("围绕这份报告继续问事 →") { Task { await followup(r) } }; Text("自动带入报告内容，聊天按账户正常额度使用。").font(.footnote).foregroundStyle(.secondary) }
            } else {
                card { Text("把线索，展开成完整答案").font(AppTypography.section); chapters(r.chapters); HStack(alignment: .firstTextBaseline) { Text("\(r.pointsPrice)").font(AppTypography.title(36)); Text("积分"); Spacer(); Text("一次购买 · 随时回看").font(AppTypography.caption) }; Text("可用积分：" + (balance.map(String.init) ?? "暂未获取") + "。现金支付暂未开放。").font(.footnote).foregroundStyle(.secondary); if let balance {
                    if balance >= r.pointsPrice { primary("解锁完整报告") { confirm = true } }
                    else { Text("还差 \(r.pointsPrice - balance) 积分，摘要已为您保留。").font(.footnote).padding(14).frame(maxWidth: .infinity).background(accent.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 10)) }
                } else { Button("重新获取积分余额") { Task { await refreshBalance() } } } }
            }
        }
    }
    private func load() async {
        loading = true; defer { loading = false }
        do { if let reportID { report = try await APIClient.shared.request(.aiReport(reportID)) }; if let topic { let response: AiSkillListResponse = try await APIClient.shared.request(.aiSkills); skill = response.list.first { $0.code == topic.code }; if inputs.isEmpty { inputs = Dictionary(uniqueKeysWithValues: (skill?.inputSchema.fields ?? []).compactMap { field in guard let value = field.defaultValue, field.options?.contains(where: { $0.value == value }) == true else { return nil }; return (field.key, value) }) }; if skill?.inputSchema.fields.isEmpty == true { step = 1 } } }
        catch { self.error = error.localizedDescription }
    }
    private func refreshBalance() async {
        do { let b: ReportBalance = try await APIClient.shared.request(.pointsAccount); balance = b.balance }
        catch { balance = nil }
    }
    private func create(_ topic: AiTopic) async {
        guard !busy else { return }; busy = true; error = ""; defer { busy = false }
        do { if submittedRequest == nil { submittedRequest = .init(skillCode: topic.code, question: question.trimmingCharacters(in: .whitespacesAndNewlines), inputs: cleanInputs, requestKey: requestKey) }; if let request = submittedRequest { report = try await APIClient.shared.request(.aiReportCreate(request)) } } catch { self.error = error.localizedDescription }
    }
    private func retry(_ r: AiReport) async {
        guard !busy else { return }; busy = true; error = ""; defer { busy = false }
        do { report = try await APIClient.shared.request(.aiReportRetry(r.id)) } catch { self.error = error.localizedDescription }
    }
    private func followup(_ r: AiReport) async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do { let result: ReportConversationResult = try await APIClient.shared.request(.aiReportConversation(r.id)); NotificationCenter.default.post(name: Notification.Name("AskXuanReportConversation"), object: result.sessionId); dismiss() } catch { self.error = error.localizedDescription }
    }
    private func unlock(_ r: AiReport) async {
        guard !busy else { return }; busy = true; error = ""; defer { busy = false }
        do { let _: ReportUnlockResult = try await APIClient.shared.request(.aiReportUnlock(.init(reportId: r.id, expectedPoints: r.pointsPrice))); report = try await APIClient.shared.request(.aiReport(r.id)); await refreshBalance() } catch { self.error = error.localizedDescription }
    }
}
struct AiReportLibrary: View {
    @Environment(\.dismiss) private var dismiss
    @State private var reports: [AiReport] = []
    @State private var page = 1
    @State private var more = true
    @State private var busy = false
    @State private var error = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("每一次探索，都有迹可循。").font(AppTypography.section).padding(.vertical, 20)
                if !error.isEmpty { Text(error).foregroundStyle(.red); Button("重试") { Task { await load() } } }
                if reports.isEmpty && !busy { Text("还没有专题报告，从一个关心的问题开始。").foregroundStyle(.secondary).padding(.vertical, 40) }
                ForEach(reports) { report in NavigationLink { AiReportWorkspace(reportID: report.id) } label: { VStack(alignment: .leading, spacing: 10) { HStack { AiTopicArtwork(code: report.skillCode).frame(width: 62, height: 52); Text(report.title).font(AppTypography.card); Spacer(); Image(systemName: "arrow.up.right") }; Text(report.question).font(.subheadline).lineLimit(2); Text(report.status == "ready" ? "查看报告" : report.status == "failed" ? "生成失败，可重试" : "生成中").font(AppTypography.caption).foregroundStyle(.secondary) }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(.white).clipShape(RoundedRectangle(cornerRadius: 18)) } }
                if busy { ProgressView() } else if more && !reports.isEmpty { Button("加载更多") { Task { await load() } } }
            }.padding(20)
        }.background(reportPaper).foregroundStyle(reportGreen).navigationTitle("我的报告")
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("返回问事") { dismiss() } } }
        .task { if reports.isEmpty { await load() } }
    }
    private func load() async { guard !busy else { return }; busy = true; defer { busy = false }; do { let rows: [AiReport] = try await APIClient.shared.request(.aiReports(page)); reports += rows; page += 1; more = rows.count == 20; error = "" } catch { self.error = error.localizedDescription } }
}

struct AiTopicPresentation {
    let code: String
    var color: Color {
        let values: [String: (Double, Double, Double)] = ["bazi":(0.65,0.40,0.20),"ziwei":(0.47,0.40,0.62),"marriage":(0.71,0.42,0.48),"fengshui":(0.33,0.49,0.40),"liuyao":(0.35,0.52,0.55),"qimen":(0.54,0.47,0.27),"tarot":(0.56,0.41,0.58)]
        let v = values[code] ?? values["fengshui"]!
        return Color(red: v.0, green: v.1, blue: v.2)
    }
    var caption: String { ["bazi":"认识自己，找到方向","ziwei":"循着星光，梳理人生","marriage":"走近彼此，学会相处","fengshui":"安顿空间，也安顿心","liuyao":"一事一问，理清选择","qimen":"看清条件，从容行动","tarot":"倾听内心，发现可能"][code] ?? "从问题出发，探索生活" }
    var prompts: [String] {
        switch code {
        case "bazi": return ["我想梳理适合自己的职业方向", "如何发挥我的性格优势？", "现阶段可以怎样调整生活节奏？"]
        case "ziwei": return ["我想了解个人发展的重点", "如何平衡事业与关系？", "怎样看待我目前的转变？"]
        case "marriage": return ["我们经常因小事争执，如何沟通？", "如何理解彼此不同的需求？", "我想梳理这段关系的相处方式"]
        case "fengshui": return ["我想改善家中的采光与动线", "工作空间怎样布置更舒适？", "如何让卧室更适合休息？"]
        case "liuyao": return ["面对两个选择，我该如何梳理？", "这件事有哪些容易忽视的因素？", "我想明确下一步可做的行动"]
        case "qimen": return ["如何评估一个新机会？", "当前计划有哪些可以调整的地方？", "我想比较不同方案的利弊"]
        default: return ["我想理解最近反复出现的情绪", "怎样看清自己真正重视的事？", "面对变化，如何照顾自己的感受？"]
        }
    }
}

/// Decorative topic motifs only; these are not a user's computed chart or drawn cards.
struct AiTopicArtwork: View {
    let code: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24, paused: reduceMotion)) { timeline in
            Canvas { original, size in
                var ctx = original
                ctx.scaleBy(x: size.width / 240, y: size.height / 200)
                let color = AiTopicPresentation(code: code).color
                let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                func stroke(_ points: [CGPoint], width: Double = 1.6, opacity: Double = 1) {
                    var p = Path(); p.addLines(points); ctx.stroke(p, with: .color(color.opacity(opacity)), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
                }
                func line(_ values: [(Double, Double)], width: Double = 1.6, opacity: Double = 1) { stroke(values.map { CGPoint(x: $0.0, y: $0.1) }, width: width, opacity: opacity) }
                func oval(_ rect: CGRect, fill: Double = 0, opacity: Double = 1) { let p = Path(ellipseIn: rect); if fill > 0 { ctx.fill(p, with: .color(color.opacity(fill))) }; ctx.stroke(p, with: .color(color.opacity(opacity)), lineWidth: 1.5) }
                func box(_ rect: CGRect, radius: Double = 7) { let p = Path(roundedRect: rect, cornerRadius: radius); ctx.fill(p, with: .color(color.opacity(0.06))); ctx.stroke(p, with: .color(color), lineWidth: 1.5) }
                ctx.fill(Path(ellipseIn: CGRect(x: 40, y: 20, width: 160, height: 160)), with: .color(color.opacity(0.05)))
                var orbit = ctx; orbit.translateBy(x: 120, y: 100); orbit.rotate(by: .radians(reduceMotion ? 0 : time / 20))
                orbit.stroke(Path(ellipseIn: CGRect(x: -76, y: -76, width: 152, height: 152)), with: .color(color.opacity(0.22)), style: StrokeStyle(lineWidth: 1, dash: [2, 8]))
                ctx.translateBy(x: 0, y: reduceMotion ? 0 : sin(time / 1.8) * 3)
                switch code {
                case "bazi":
                    oval(CGRect(x: 91, y: 40, width: 58, height: 58), fill: 0.08); oval(CGRect(x: 99, y: 48, width: 42, height: 42))
                    for n in 0..<4 { let x = Double(60 + n * 33); box(CGRect(x: x, y: 112, width: 21, height: 43)); for y in [125.0,133,141] { line([(x+6,y),(x+15,y)]) } }
                    line([(55,165),(185,165)], opacity: 0.5)
                case "ziwei":
                    let stars: [(Double,Double)] = [(66,118),(88,63),(126,90),(153,50),(177,113),(141,145),(126,90)]
                    line(stars, opacity: 0.5)
                    for (i, s) in stars.enumerated() { oval(CGRect(x: s.0-5,y:s.1-5,width:10,height:10), fill: 0.12, opacity: 0.3); ctx.fill(Path(ellipseIn: CGRect(x:s.0-2,y:s.1-2,width:4,height:4)), with:.color(color.opacity(reduceMotion ? 1 : 0.7 + sin(time + Double(i)) * 0.3))) }
                case "marriage":
                    oval(CGRect(x:60,y:54,width:78,height:101),fill:0.07);oval(CGRect(x:102,y:54,width:78,height:101),fill:0.07)
                    line([(104,101),(120,119),(137,100)],width:3);line([(113,37),(127,37)]);line([(120,30),(120,44)])
                case "fengshui":
                    line([(52,78),(120,34),(188,78)]);line([(64,80),(64,160),(176,160),(176,80)])
                    box(CGRect(x:99,y:103,width:42,height:57),radius:20);box(CGRect(x:77,y:87,width:15,height:22),radius:1);box(CGRect(x:148,y:87,width:15,height:22),radius:1)
                    oval(CGRect(x:169,y:36,width:20,height:20),fill:0.08);line([(49,152),(49,112)],opacity:0.7);line([(36,118),(49,130),(62,110)],opacity:0.7)
                case "liuyao":
                    oval(CGRect(x:61,y:41,width:118,height:118),opacity:0.4)
                    for n in 0..<6 { let y=Double(66+n*14);if n % 2 == 0 { line([(91,y),(149,y)],width:5) } else { line([(91,y),(112,y)],width:5);line([(128,y),(149,y)],width:5) } }
                case "qimen":
                    line([(120,26),(194,100),(120,174),(46,100),(120,26)],opacity:0.35);box(CGRect(x:77,y:57,width:86,height:86),radius:4)
                    for offset in [-14.0,14.0] { line([(120+offset,57),(120+offset,143)],opacity:0.5);line([(77,100+offset),(163,100+offset)],opacity:0.5) }
                    line([(120,74),(130,100),(120,126),(110,100),(120,74)])
                default:
                    box(CGRect(x:56,y:65,width:55,height:94));box(CGRect(x:130,y:65,width:55,height:94));box(CGRect(x:87,y:41,width:66,height:112));box(CGRect(x:95,y:49,width:50,height:96),radius:5)
                    oval(CGRect(x:106,y:78,width:29,height:29),fill:0.1);line([(116,126),(120,132),(124,126),(120,120),(116,126)])
                }
                line([(194,57),(194,69)],opacity:0.6);line([(188,63),(200,63)],opacity:0.6)
            }
        }.aspectRatio(1.2, contentMode: .fit).accessibilityHidden(true)
    }
}
struct AiTopicTile: View {
    let topic: AiTopic
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            AiTopicArtwork(code: topic.code).frame(width: 120, height: 105).opacity(0.8).offset(x: 16, y: 17)
            VStack(alignment: .leading, spacing: 9) {
                Text(topic.seal).font(AppTypography.title(11)).foregroundStyle(AiTopicPresentation(code: topic.code).color)
                Text(topic.title).font(AppTypography.title(19))
                Text(AiTopicPresentation(code: topic.code).caption).font(.system(size: 10)).foregroundStyle(.secondary).lineSpacing(4).frame(maxWidth: 95, alignment: .leading)
                Spacer(minLength: 10)
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
        }.frame(height: 143).background(AiTopicPresentation(code: topic.code).color.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(AiTopicPresentation(code: topic.code).color.opacity(0.2)))
    }
}
