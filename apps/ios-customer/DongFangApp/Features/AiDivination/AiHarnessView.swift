import SwiftUI

struct AiClarification: Decodable, Identifiable {
    let skillCode: String; let question: String; let fields: [AiSkillField]; let values: [String: String]
    var id: String { skillCode + question }
    private enum CodingKeys: String, CodingKey { case skillCode, question, fields, values }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        skillCode = try container.decode(String.self, forKey: .skillCode)
        question = try container.decode(String.self, forKey: .question)
        fields = try container.decode([AiSkillField].self, forKey: .fields)
        values = (try container.decodeIfPresent([String: ConfirmedValue].self, forKey: .values) ?? [:]).compactMapValues(\.text)
    }
    private struct ConfirmedValue: Decodable {
        let text: String?
        init(from decoder: Decoder) throws {
            let value = try decoder.singleValueContainer()
            if value.decodeNil() { text = nil }
            else if let s = try? value.decode(String.self) { text = s }
            else if let n = try? value.decode(Int64.self) { text = String(n) }
            else if let n = try? value.decode(Double.self) { text = String(n) }
            else if let b = try? value.decode(Bool.self) { text = String(b) }
            else { text = nil }
        }
    }
}
struct AiAgentState: Decodable {
    let runtime: String; let modelCalls: Int; let toolCalls: Int
    var clarification: AiClarification?
    var context: Context?
    struct Context: Decodable { let window: Int; let outputBudget: Int; let estimatedInputTokens: Int; let droppedMessages: Int; let summaryIncluded: Bool }
}
struct AiToolTrace: Decodable {
    let status: String; let tools: [Tool]
    struct Tool: Decodable, Identifiable { let id: Int64; let tool: String; let status: String; let latencyMs: Int }
}
struct AiTraceView: View {
    let message: AiChatMessage
    @State private var trace: AiToolTrace?
    @State private var expanded = false
    @State private var error = ""
    var body: some View {
        DisclosureGroup("查看处理过程", isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 8) {
                if let agent = message.agent {
                    Text("Harness · 模型 \(agent.modelCalls) 次 · 工具 \(agent.toolCalls) 次")
                    if let context = agent.context {
                        Text("上下文估算 \(context.estimatedInputTokens) / \(context.window) token · 输出预算 \(context.outputBudget)")
                        if context.droppedMessages > 0 { Text("已压缩较早消息，保留必要上下文") }
                    }
                }
                if let trace {
                    if trace.tools.isEmpty { Text("本轮未调用计算工具") }
                    ForEach(trace.tools) { tool in
                        HStack { Text(tool.tool); Spacer(); Text(tool.status == "completed" ? "完成" : tool.status == "failed" ? "失败" : tool.status); Text("\(tool.latencyMs) ms") }
                    }
                } else if error.isEmpty { ProgressView() }
                if !error.isEmpty { Text(error); Button("重试") { Task { await load() } } }
            }.font(.caption).foregroundStyle(.secondary).padding(.vertical, 8)
        }.font(.caption).task(id: expanded) { if expanded { await load() } }
    }
    private func load() async {
        error = ""
        do { trace = try await APIClient.shared.request(.aiTrace(message.sessionId, message.id)) }
        catch is CancellationError {} catch { self.error = "处理记录暂未加载" }
    }
}
struct AiNativeFields: View {
    let fields: [AiSkillField]
    @Binding var values: [String: String]
    @State private var dateField: AiSkillField?
    @State private var date = Date()
    private func set(_ field: AiSkillField, _ value: String) {
        values[field.key] = value
        values = values.filter { key, value in !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && fields.contains { $0.key == key && $0.visible(in: values) } }
    }
    private func binding(_ field: AiSkillField) -> Binding<String> { Binding(get: { values[field.key] ?? "" }, set: { set(field, $0) }) }
    private func formatter(_ type: String) -> DateFormatter {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(secondsFromGMT: 28800)
        f.dateFormat = type == "date" ? "yyyy-MM-dd" : type == "time" ? "HH:mm" : "yyyy-MM-dd'T'HH:mm"; return f
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(fields.filter { $0.visible(in: values) }) { field in
                VStack(alignment: .leading, spacing: 8) {
                    Text(field.label + (field.needed(in: values) ? " · 必填" : " · 选填")).font(.subheadline.weight(.medium))
                    if let help = field.helpText { Text(help).font(.caption).foregroundStyle(.secondary) }
                    if field.type == "select" {
                        ForEach(field.options ?? []) { option in
                            Button { set(field, option.value) } label: {
                                HStack { VStack(alignment: .leading, spacing: 4) { Text(option.label); if let description = option.description { Text(description).font(.caption).foregroundStyle(.secondary) } }; Spacer(); Image(systemName: values[field.key] == option.value ? "checkmark.circle.fill" : "circle") }
                                    .padding(12).frame(minHeight: 44).background(Color.bgPrimary, in: RoundedRectangle(cornerRadius: 12))
                            }.buttonStyle(AiExperiencePressStyle()).accessibilityAddTraits(values[field.key] == option.value ? .isSelected : [])
                        }
                    } else if ["date", "time", "datetime"].contains(field.type), !field.lunar(in: values) {
                        Button { date = formatter(field.type).date(from: values[field.key] ?? "") ?? Date(); dateField = field } label: {
                            HStack { Text(values[field.key] ?? "请选择" + field.label); Spacer(); Image(systemName: field.type == "time" ? "clock" : "calendar") }.padding(14).background(Color.bgPrimary, in: RoundedRectangle(cornerRadius: 12))
                        }.accessibilityLabel(field.label).accessibilityValue(values[field.key] ?? "未填写")
                        if field.type == "datetime" { Button("使用当前北京时间") { set(field, formatter(field.type).string(from: Date())) }.font(.caption).frame(minHeight: 44) }
                    } else {
                        TextField(field.lunar(in: values) ? "YYYY-MM-DD，例如 1990-02-30" : field.placeholder ?? "请填写", text: binding(field), axis: field.key == "dream" ? .vertical : .horizontal)
                            .lineLimit(field.key == "dream" ? 4...8 : 1...3).textInputAutocapitalization(.never).autocorrectionDisabled()
                            .keyboardType(field.type == "number" ? .numbersAndPunctuation : .default).padding(14)
                            .background(Color.bgPrimary, in: RoundedRectangle(cornerRadius: 12)).accessibilityLabel(field.label)
                    }
                    if !(values[field.key] ?? "").isEmpty && !field.valid(in: values) {
                        Text("请核对格式和范围。" + (field.helpText ?? "")).font(.caption).foregroundStyle(Color.stateError)
                    }
                }.font(.body)
            }
        }.sheet(item: $dateField) { field in
            NavigationStack {
                DatePicker(field.label, selection: $date, displayedComponents: field.type == "date" ? [.date] : field.type == "time" ? [.hourAndMinute] : [.date, .hourAndMinute])
                    .datePickerStyle(.wheel).labelsHidden().environment(\.locale, Locale(identifier: "zh_CN")).environment(\.timeZone, TimeZone(secondsFromGMT: 28800) ?? .current)
                    .navigationTitle(field.label).navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("确定") { set(field, formatter(field.type).string(from: date)); dateField = nil } }; ToolbarItem(placement: .cancellationAction) { Button("取消") { dateField = nil } } }
            }.appSheetSurface()
        }
    }
}
struct AiClarificationView: View {
    let clarification: AiClarification
    let submit: ([String: String]) async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var values: [String: String]
    init(clarification: AiClarification, submit: @escaping ([String: String]) async -> Void) {
        self.clarification = clarification; self.submit = submit
        _values = State(initialValue: clarification.values)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(clarification.question)
                    AiNativeFields(fields: clarification.fields, values: $values)
                    Button("确认资料并继续") {
                        let confirmed = values.filter { key, value in !value.isEmpty && clarification.fields.contains { $0.key == key && $0.visible(in: values) } }
                        dismiss(); Task { await submit(confirmed) }
                    }.buttonStyle(.borderedProminent).disabled(!clarification.fields.allSatisfy { $0.valid(in: values) })
                    Text("请只填写已确认的资料，不确定时可以取消。").font(.caption).foregroundStyle(.secondary)
                }.padding(20)
            }.scrollDismissesKeyboard(.interactively).background(Color.bgPrimary).navigationTitle("补充资料")
                .navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
        }.presentationDragIndicator(.visible)
    }
}
@MainActor enum AiReportUpload {
    static func image(_ data: Data) async throws -> AiImageAttachment {
        guard data.count <= 8 * 1024 * 1024 else { throw APIError.serverError(400, "图片请小于 8MB") }
        let credential: MediaUploadCredential = try await APIClient.shared.request(.mediaUploadCredential(.init(fileName: "ai-" + UUID().uuidString + ".jpg", mediaType: "image", contentType: "image/jpeg", fileSize: Int64(data.count))))
        guard let url = URL(string: credential.uploadUrl) else { throw APIError.invalidURL }
        var headers = credential.uploadHeaders; headers["Content-Type"] = "image/jpeg"
        try await APIClient.shared.upload(data, to: url, headers: headers)
        let asset: MediaAsset = try await APIClient.shared.request(.mediaComplete(id: credential.mediaId, .init(coverMediaId: nil)))
        let raw = asset.playbackUrl.isEmpty ? asset.coverUrl : asset.playbackUrl
        guard !raw.isEmpty, let origin = URL(string: "/", relativeTo: AppConfig.baseURL), let value = URL(string: raw, relativeTo: origin)?.absoluteURL else { throw APIError.invalidURL }
        return AiImageAttachment(mediaId: asset.id, url: value.absoluteString, contentType: "image/jpeg", width: nil, height: nil)
    }
}
