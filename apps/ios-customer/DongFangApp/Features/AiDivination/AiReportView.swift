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
private let reportPaper = Color(red: 0.96, green: 0.96, blue: 0.93)

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
                    Text("一事一解，自有章法").font(.system(size: 23, design: .serif))
                }
                Spacer()
                Button("我的报告 ↗") { library = true }.font(.system(size: 12))
            }
            if error { Button("专题暂未加载 · 点击重试") { Task { await load() } }.font(.footnote) }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 10) {
                ForEach(topics) { topic in
                    Button { selected = topic } label: {
                        VStack(spacing: 8) {
                            Text(topic.seal).font(.system(size: 23, design: .serif)).frame(width: 38, height: 38).background(.white.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 12))
                            Text(topic.title).font(.system(size: 12, weight: .medium)).lineLimit(1).minimumScaleFactor(0.8)
                            Text("专题解读 ↗").font(.system(size: 9)).opacity(0.65)
                        }.frame(maxWidth: .infinity).padding(.vertical, 12).background(.white.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 14))
                    }.buttonStyle(.plain)
                }
            }
        }.padding(18).foregroundStyle(Color.white).background(LinearGradient(colors: [reportGreen, Color(red: 0.13, green: 0.24, blue: 0.20)], startPoint: .topLeading, endPoint: .bottomTrailing)).clipShape(RoundedRectangle(cornerRadius: 22))
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
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if !error.isEmpty { Text(error).font(.footnote).foregroundStyle(.red).padding().accessibilityLabel("错误：" + error) }
                if loading { ProgressView("正在整理内容…").frame(maxWidth: .infinity).padding(40) }
                if let report { reportBody(report) }
                else if let topic { topicBody(topic) }
                Text("问玄东方 · 以文化为镜，以生活为本").font(.system(size: 11)).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 25)
            }.padding(20).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }.background(reportPaper).foregroundStyle(reportGreen)
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("返回问事") { dismiss() } }; ToolbarItem(placement: .principal) { Text("问玄 · 专题").font(.system(.headline, design: .serif)) } }
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .task(id: report?.status) {
            guard report?.status == "generating" else { return }
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(3)); guard let id = report?.id else { return }; let next: AiReport = try await APIClient.shared.request(.aiReport(id)); report = next; if next.status != "generating" { return } }
                catch { if !Task.isCancelled { self.error = error.localizedDescription }; return }
            }
        }
        .sheet(item: $dateField) { field in
            NavigationStack {
                DatePicker(field.label, selection: $pickedDate, displayedComponents: field.type == "date" ? [.date] : field.type == "time" ? [.hourAndMinute] : [.date, .hourAndMinute]).datePickerStyle(.wheel).labelsHidden().environment(\.locale, Locale(identifier: "zh_CN")).padding()
                    .navigationTitle(field.label).navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("确定") { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = field.type == "date" ? "yyyy-MM-dd" : field.type == "time" ? "HH:mm" : "yyyy-MM-dd'T'HH:mm"; inputs[field.key] = f.string(from: pickedDate); dateField = nil } }; ToolbarItem(placement: .cancellationAction) { Button("取消") { dateField = nil } } }
            }.presentationDetents([.height(340)])
        }
        .confirmationDialog("确认购买完整报告？", isPresented: $confirm, titleVisibility: .visible) {
            if let report { Button("使用 \(report.pointsPrice) 积分解锁") { Task { await unlock(report) } } }
            Button("取消", role: .cancel) {}
        } message: { Text("购买后可重复阅读。积分将从您的账户扣除。") }
    }
    private func hero(_ title: String, subtitle: String) -> some View {
        VStack(spacing: 14) { Text("PERSONAL INSIGHT").font(.system(size: 10)).tracking(3).opacity(0.6); Text(title).font(.system(size: 34, design: .serif)); Text(subtitle).font(.system(size: 14)).lineSpacing(6).foregroundStyle(.secondary).multilineTextAlignment(.center) }.frame(maxWidth: .infinity).padding(.vertical, 25)
    }
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16, content: content).padding(22).frame(maxWidth: .infinity, alignment: .leading).background(Color.white.opacity(0.9)).clipShape(RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(reportGreen.opacity(0.10)))
    }
    private func chapters(_ list: [String]) -> some View {
        ForEach(Array(list.enumerated()), id: \.offset) { index, title in HStack(spacing: 16) { Text(String(format: "%02d", index + 1)).font(.system(.body, design: .serif)).opacity(0.5); Text(title).font(.system(size: 14)); Spacer() }.padding(.vertical, 5) }
    }
    private func primary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(busy ? "正在处理…" : title).font(.system(size: 14, weight: .medium)).frame(maxWidth: .infinity).padding(16).background(reportGreen).foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 12)) }.disabled(busy)
    }
    @ViewBuilder private func topicBody(_ topic: AiTopic) -> some View {
        hero(topic.title, subtitle: topic.subtitle)
        card { Text("01 / 您将获得").font(.caption).opacity(0.6); Text("让问题得到完整梳理").font(.system(.title2, design: .serif)); chapters(topic.chapters); Text("先生成免费摘要，再决定是否使用 \(topic.pointsPrice) 积分购买。现金支付暂未开放。传统文化参考，不承诺预测结果。").font(.footnote).foregroundStyle(.secondary) }
        card {
            Text("02 / 分析资料").font(.caption).opacity(0.6)
            Text("从了解您的问题开始").font(.system(.title2, design: .serif))
            if let skill { ForEach(skill.inputSchema.fields) { field in fieldView(field) } }
            Text("最想了解的问题 *").font(.subheadline)
            TextEditor(text: $question).frame(minHeight: 110).padding(8).scrollContentBackground(.hidden).background(reportPaper).clipShape(RoundedRectangle(cornerRadius: 10))
            Text("缺少的信息会明确标注，不会虚构排盘或测算结果。").font(.footnote).foregroundStyle(.secondary)
            primary("生成免费摘要 →") { Task { await create(topic) } }.disabled(skill == nil || question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
    private func binding(_ key: String) -> Binding<String> { Binding(get: { inputs[key] ?? "" }, set: { inputs[key] = $0 }) }
    @ViewBuilder private func fieldView(_ field: AiSkillField) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(field.label + (field.required ? " *" : "（选填）")).font(.subheadline)
            if field.type == "select" {
                Picker(field.label, selection: binding(field.key)) { Text("请选择").tag(""); ForEach(field.options ?? []) { Text($0.label).tag($0.value) } }.tint(reportGreen)
            } else if ["date", "time", "datetime"].contains(field.type) {
                Button { dateField = field } label: { HStack { Text(inputs[field.key] ?? "请选择" + field.label); Spacer(); Image(systemName: field.type == "time" ? "clock" : "calendar") }.padding(13).background(reportPaper).clipShape(RoundedRectangle(cornerRadius: 10)) }.tint(reportGreen)
            } else {
                TextField(field.type == "date" ? "YYYY-MM-DD" : field.type == "time" ? "HH:mm" : field.type == "datetime" ? "YYYY-MM-DDTHH:mm" : (field.placeholder ?? "请填写"), text: binding(field.key)).textInputAutocapitalization(.never).autocorrectionDisabled().padding(13).background(reportPaper).clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }
    @ViewBuilder private func reportBody(_ r: AiReport) -> some View {
        hero(r.title, subtitle: r.question)
        if r.status == "generating" {
            card { ProgressView(); Text("正在整理您的专题报告").font(.headline); Text("您可以离开，稍后在我的报告查看。当前尚未扣款；超过五分钟可恢复生成。").font(.subheadline); primary("检查并恢复生成") { Task { await retry(r) } } }
        } else if r.status == "failed" {
            card { Text("这次生成未能完成").font(.headline); Text(r.errorMessage); primary("免费重试") { Task { await retry(r) } } }
        } else {
            card { Text("分析摘要").font(.system(.title2, design: .serif)); Text(r.summary).lineSpacing(7) }
            if r.unlocked {
                card { Text("完整分析 · 已解锁").font(.system(.title2, design: .serif)); Text(.init(r.content)).textSelection(.enabled).lineSpacing(8); ShareLink(item: r.title + "\n\n" + r.content) { Label("保存或分享报告", systemImage: "square.and.arrow.up") }; primary("围绕这份报告继续问事 →") { Task { await followup(r) } }; Text("自动带入报告内容，聊天按账户正常额度使用。").font(.footnote).foregroundStyle(.secondary) }
            } else {
                card { Text("把线索，展开成完整答案").font(.system(.title2, design: .serif)); chapters(r.chapters); HStack(alignment: .firstTextBaseline) { Text("\(r.pointsPrice)").font(.system(size: 36, design: .serif)); Text("积分"); Spacer(); Text("一次购买 · 随时回看").font(.caption) }; Text("可用积分：" + (balance.map(String.init) ?? "暂未获取") + "。现金支付暂未开放。").font(.footnote).foregroundStyle(.secondary); primary("解锁完整报告") { confirm = true } }
            }
        }
    }
    private func load() async {
        loading = true; defer { loading = false }
        do { if let reportID { report = try await APIClient.shared.request(.aiReport(reportID)) }; if let topic { let response: AiSkillListResponse = try await APIClient.shared.request(.aiSkills); skill = response.list.first { $0.code == topic.code } }; let b: ReportBalance = try await APIClient.shared.request(.pointsAccount); balance = b.balance }
        catch { self.error = error.localizedDescription }
    }
    private func create(_ topic: AiTopic) async {
        guard !busy else { return }; busy = true; error = ""; defer { busy = false }
        do { report = try await APIClient.shared.request(.aiReportCreate(.init(skillCode: topic.code, question: question, inputs: inputs, requestKey: requestKey))) } catch { self.error = error.localizedDescription }
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
        do { let _: ReportUnlockResult = try await APIClient.shared.request(.aiReportUnlock(.init(reportId: r.id, expectedPoints: r.pointsPrice))); report = try await APIClient.shared.request(.aiReport(r.id)) } catch { self.error = error.localizedDescription }
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
                Text("每一次探索，都有迹可循。").font(.system(.title2, design: .serif)).padding(.vertical, 20)
                if !error.isEmpty { Text(error).foregroundStyle(.red); Button("重试") { Task { await load() } } }
                if reports.isEmpty && !busy { Text("还没有专题报告，从一个关心的问题开始。").foregroundStyle(.secondary).padding(.vertical, 40) }
                ForEach(reports) { report in NavigationLink { AiReportWorkspace(reportID: report.id) } label: { VStack(alignment: .leading, spacing: 10) { HStack { Text(report.title).font(.system(.title3, design: .serif)); Spacer(); Image(systemName: "arrow.up.right") }; Text(report.question).font(.subheadline).lineLimit(2); Text(report.status == "ready" ? "查看报告" : report.status == "failed" ? "生成失败，可重试" : "生成中").font(.caption).foregroundStyle(.secondary) }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(.white).clipShape(RoundedRectangle(cornerRadius: 18)) } }
                if busy { ProgressView() } else if more && !reports.isEmpty { Button("加载更多") { Task { await load() } } }
            }.padding(20)
        }.background(reportPaper).foregroundStyle(reportGreen).navigationTitle("我的报告")
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("返回问事") { dismiss() } } }
        .task { if reports.isEmpty { await load() } }
    }
    private func load() async { guard !busy else { return }; busy = true; defer { busy = false }; do { let rows: [AiReport] = try await APIClient.shared.request(.aiReports(page)); reports += rows; page += 1; more = rows.count == 20; error = "" } catch { self.error = error.localizedDescription } }
}
