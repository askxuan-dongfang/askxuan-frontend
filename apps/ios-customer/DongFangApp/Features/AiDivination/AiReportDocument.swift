import SwiftUI

enum AiNativeRoute: Hashable { case topic(String), example(String), report(Int64) }

struct AiReportDocument: Codable {
    let version: Int
    let runtime: String
    let modelCalls: Int
    let toolCalls: Int
    let blocks: [AiReportBlock]?
}
struct AiReportBlock: Codable {
    let kind: String
    let title: String
    let source: String
    var note: String?
    var items: [AiReportItem]?
    var columns: [String]?
    var rows: [[String]]?
    var sourceName: String { ["bazi":"八字排盘", "bazi_dayun":"大运流年", "ziwei":"紫微排盘", "liuyao":"六爻排盘", "qimen":"奇门排盘", "tarot":"塔罗抽牌", "almanac":"黄历计算"][source] ?? source }
}
struct AiReportItem: Codable { let label: String; let value: String; var detail: String? }

struct AiReportDocumentView: View {
    let document: AiReportDocument
    var body: some View {
        if let blocks = document.blocks, !blocks.isEmpty {
            VStack(alignment: .leading, spacing: 20) {
                Label("盘面与依据", systemImage: "chart.xyaxis.line").font(AppTypography.section)
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    AiReportBlockView(block: block)
                    Divider()
                }
            }.accessibilityElement(children: .contain).accessibilityLabel("报告图表")
        }
    }
}
struct AiReportBlockView: View {
    let block: AiReportBlock
    var expanded = false
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if block.kind == "table" {
                if expanded {
                    Text(block.title).font(.headline)
                    Text((block.columns ?? []).joined(separator: " / ")).font(.caption.bold())
                    ForEach(Array((block.rows ?? []).enumerated()), id: \.offset) { _, row in Text(row.joined(separator: " / ")).font(.caption) }
                }
                else { DisclosureGroup(block.title) { dataTable.padding(.top, 8) }.font(.subheadline).accessibilityIdentifier("report-table-" + block.title) }
            } else {
                Text(block.title).font(AppTypography.title(20))
                Text(block.sourceName).font(.caption).foregroundStyle(.secondary)
                if let note = block.note { Text(note).font(.caption).foregroundStyle(.secondary) }
                chart
            }
        }
    }
    @ViewBuilder private var chart: some View {
        let items = block.items ?? []
        if expanded, ["timeline", "palaces", "pillars", "pairs", "cards"].contains(block.kind) {
            VStack(spacing: 10) { ForEach(Array(items.enumerated()), id: \.offset) { _, item in tile(item) } }
        } else {
        switch block.kind {
        case "elements":
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 12) {
                    Text(item.label).frame(width: 24)
                    GeometryReader { bounds in
                        Capsule().fill(elementColor(item.label).opacity(0.12))
                        Capsule().fill(elementColor(item.label)).frame(width: bounds.size.width * min(8, max(0, Double(item.value) ?? 0)) / 8)
                    }.frame(height: 6)
                    Text(item.value + " 个").monospacedDigit().font(.caption)
                }.accessibilityElement(children: .ignore).accessibilityLabel(item.label + " " + item.value + " 个")
            }
        case "timeline":
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in tile(item).frame(width: 125) }
                }
            }.accessibilityLabel("大运时间轴，可左右浏览")
        case "palaces":
            LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 240 : 120))], alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    DisclosureGroup {
                        Text(item.value).font(.subheadline).textSelection(.enabled)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.label).font(.headline)
                            Text(item.value.components(separatedBy: " / ").first ?? "").font(.subheadline)
                            if let detail = item.detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
                        }
                    }.padding(12).background(Color.bgPrimary, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        case "hexagram":
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 12) {
                    HStack(spacing: item.label.contains("六") ? 10 : 0) { Capsule().frame(height: 5); Capsule().frame(height: 5) }
                        .frame(width: 66, height: 24).foregroundStyle(Color.accentDefault)
                        .accessibilityLabel(item.label.contains("六") ? "阴爻" : "阳爻")
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.label + " · " + item.value).font(.subheadline)
                        if let detail = item.detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }
        case "pillars", "pairs", "cards":
            LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 240 : block.kind == "pillars" ? 100 : 135))], spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in tile(item) }
            }
        default:
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in tile(item) }
        }
    }
    }
    func tile(_ item: AiReportItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.label).font(.caption).foregroundStyle(.secondary)
            Text(item.value).font(AppTypography.title(block.kind == "pillars" ? 26 : 19))
            if let detail = item.detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
            .background(Color.bgPrimary, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .combine)
    }
    private var dataTable: some View {
        ScrollView(.horizontal) {
            Grid(alignment: .topLeading, horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow { ForEach(Array((block.columns ?? []).enumerated()), id: \.offset) { _, value in cell(value, heading: true) } }
                ForEach(Array((block.rows ?? []).enumerated()), id: \.offset) { _, row in
                    GridRow { ForEach(Array(row.enumerated()), id: \.offset) { _, value in cell(value, heading: false) } }
                }
            }
        }.accessibilityLabel(block.title + "，左右滑动查看表格").textSelection(.enabled)
    }
    private func cell(_ text: String, heading: Bool) -> some View {
        Text(text).font(heading ? .subheadline.bold() : .subheadline).frame(width: 126, alignment: .leading).padding(10)
            .background(heading ? Color.accentDefault.opacity(0.1) : Color.bgPrimary)
            .overlay(Rectangle().stroke(Color.borderDefault, lineWidth: 0.5))
    }
    private func elementColor(_ value: String) -> Color {
        switch value { case "木": return .green; case "火": return .orange; case "土": return .brown; case "金": return .gray; default: return .blue }
    }
}

struct AiReportExample: Decodable, Identifiable {
    let code: String; let title: String; let summary: String; let content: String
    var document: AiReportDocument?
    var id: String { code }
    var topic: AiTopic { AiTopic(code: code, title: title, subtitle: AiReportCatalog.subtitle(code), priceCents: 0, pointsPrice: 0, chapters: [], version: "example") }
}
enum AiReportCatalog {
    static let order = ["bazi","ziwei","marriage","face_palm","naming","liuyao","dream","fengshui","date_select","fortune","qimen","tarot"]
    static let examples: [AiReportExample] = {
        guard let url = Bundle.main.url(forResource: "AiReportExamples", withExtension: "json"), let data = try? Data(contentsOf: url), let rows = try? JSONDecoder().decode([AiReportExample].self, from: data) else { return [] }
        return rows.sorted { (order.firstIndex(of: $0.code) ?? 99) < (order.firstIndex(of: $1.code) ?? 99) }
    }()
    static func icon(_ code: String) -> String {
        ["bazi":"square.grid.2x2", "ziwei":"sparkles", "marriage":"heart", "face_palm":"hand.raised", "naming":"character.book.closed", "liuyao":"line.3.horizontal", "dream":"moon.stars", "fengshui":"house", "date_select":"calendar", "fortune":"sun.max", "qimen":"safari", "tarot":"rectangle.on.rectangle.angled"][code] ?? "sparkles"
    }
    static func subtitle(_ code: String) -> String {
        ["bazi":"四柱命盘、五行分布与大运流年", "ziwei":"十二宫位、星曜与发展主题", "marriage":"双方独立排盘，比较相处与沟通", "face_palm":"可见特征与传统术语图解", "naming":"从音、形、义比较名字", "liuyao":"一事一问，梳理变化与选择", "dream":"整理梦境意象与现实联想", "fengshui":"采光、动线与空间布局建议", "date_select":"对照备选日期，安排重要事项", "fortune":"今日黄历与日常计划", "qimen":"时空盘面与方案比较", "tarot":"牌阵、象征与问题梳理"][code] ?? "专题解读"
    }
}
struct AiReportExampleView: View {
    let example: AiReportExample
    @State private var largeType = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(example.title).font(AppTypography.title(28))
                Text(example.summary).foregroundStyle(.secondary)
                Text("公开版式示例 · 原创说明与合成测试资料，不是你的个人测算。正式报告依据你填写的资料生成。")
                    .font(.caption).padding(14).background(Color.accentDefault.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                if let document = example.document { AiReportDocumentView(document: document) }
                Button(largeType ? "标准字号" : "放大字号") { largeType.toggle() }
                AiMarkdownText(text: example.content, large: largeType)
                NavigationLink("开始生成个人报告", value: AiNativeRoute.topic(example.code)).buttonStyle(.borderedProminent)
                ShareLink(item: example.title + "\n\n" + example.content) { Label("分享示例正文", systemImage: "square.and.arrow.up") }
            }.padding(20).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }.background(Color.bgPrimary).navigationTitle("示例报告").navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
    }
}
struct AiReportTopicEntry: View {
    let code: String
    @State private var topic: AiTopic?
    @State private var error = ""
    var body: some View {
        Group {
            if let topic { AiReportWorkspace(topic: topic) }
            else { VStack(spacing: 16) { if error.isEmpty { ProgressView("正在加载专题…") } else { Text(error); Button("重试") { Task { await load() } } } }.task { await load() } }
        }.requireAuth(title: "登录后生成个人报告", subtitle: "请确认自己的资料后开始，示例不会用于个人测算")
        .navigationTitle("专题资料").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
    }
    private func load() async {
        guard AuthStore.shared.isLoggedIn else { return }
        do { let topics: [AiTopic] = try await APIClient.shared.request(.aiTopics); topic = topics.first { $0.code == code }; if topic == nil { error = "该专题暂未开放" } }
        catch { self.error = error.localizedDescription }
    }
}
