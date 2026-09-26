import SwiftUI

struct AiDiscoveryView: View {
    @ObservedObject var viewModel: AiDivinationViewModel
    @Binding var naming: AiNamingInput
    @Binding var decision: AiDecisionInput
    let openChat: () -> Void
    private var hasDraft: Bool {
        !viewModel.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !viewModel.selectedImages.isEmpty
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("今天想问什么？").font(AppTypography.title(27))
                    Text("描述事情和顾虑，和 AI 一起梳理思路。")
                        .font(.subheadline).foregroundStyle(Color.textSecondary)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text(hasDraft ? "继续补充你的问题" : "写下你想聊的事")
                        .font(.caption).foregroundStyle(Color.textSecondary)
                    TextField("例如：想换工作，但担心新工作的稳定性…", text: $viewModel.input, axis: .vertical)
                        .lineLimit(2...5).font(.body).disabled(viewModel.isSending)
                        .accessibilityLabel("写下你想聊的事").accessibilityIdentifier("ai-discovery-question")
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) { entryHint; Spacer(minLength: 0); chatButton }
                        VStack(alignment: .leading, spacing: 10) { entryHint; chatButton }
                    }
                }.padding(16).background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.accentDefault.opacity(0.28), lineWidth: 1))
                if !hasDraft && !viewModel.isSending {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 4) { examples }
                        VStack(alignment: .leading, spacing: 4) { examples }
                    }
                }
                if let recent = viewModel.sessions.first {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("继续上次").font(AppTypography.section)
                        Button {
                            openChat()
                            Task { await viewModel.selectSession(recent.id) }
                        } label: {
                            HStack { Text(recent.title).lineLimit(2); Spacer(); Image(systemName: "arrow.up.right") }
                                .font(.subheadline).padding(.vertical, 12).frame(maxWidth: .infinity, alignment: .leading)
                        }.buttonStyle(AiExperiencePressStyle())
                    }
                }
                AiTopicEntrances()
                VStack(alignment: .leading, spacing: 0) {
                    HStack { Text("实用小工具").font(AppTypography.section); Spacer(); Text("免费体验").font(.caption).foregroundStyle(Color.textSecondary) }
                    NavigationLink { AiExperienceView(skill: "naming", naming: $naming, decision: $decision) } label: {
                        entrance("姓名灵感", subtitle: "按风格挑名字，查看字义并收藏候选", symbol: "character.book.closed")
                    }.buttonStyle(AiExperiencePressStyle()).accessibilityIdentifier("ai-naming")
                    Divider()
                    NavigationLink { AiExperienceView(skill: "decision", naming: $naming, decision: $decision) } label: {
                        entrance("比较两个选择", subtitle: "按你在意的因素评分，比较两边的取舍", symbol: "scale.3d")
                    }.buttonStyle(AiExperiencePressStyle()).accessibilityIdentifier("ai-decision")
                }
            }.padding(18).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }.scrollDismissesKeyboard(.interactively).background(Color.bgPrimary)
    }
    private var entryHint: some View {
        Text(viewModel.isSending ? "回答正在生成，可进入对话查看" : "可继续补充，发送后开始回答")
            .font(.caption).foregroundStyle(Color.textSecondary)
    }
    private var chatButton: some View {
        Button(action: openChat) {
            HStack { Text(hasDraft || viewModel.isSending ? "继续问事" : "进入对话"); Image(systemName: "arrow.up.right") }
                .font(.subheadline.weight(.medium)).padding(.horizontal, 16).frame(minHeight: 44)
                .foregroundStyle(.white).background(Color.brandDefault, in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(AiExperiencePressStyle()).accessibilityIdentifier("ai-open-chat")
    }
    @ViewBuilder private var examples: some View {
        Text("试着问").font(.caption).foregroundStyle(Color.textSecondary)
        example("工作去留", question: "我想换工作，但担心新工作的稳定性。请先问我几个关键问题，帮我梳理需要考虑的因素。")
        example("关系沟通", question: "最近和一个重要的人沟通不顺。请先了解发生了什么，再帮我想想怎么表达。")
        example("理清烦恼", question: "最近有些事情让我烦恼，但还没理清原因。请一步一步提问，帮我说清最在意的事情。")
    }
    private func example(_ title: String, question: String) -> some View {
        Button {
            viewModel.newConversation()
            viewModel.input = question
            openChat()
        } label: {
            Text(title).font(.caption).padding(.horizontal, 10).frame(minHeight: 44)
                .foregroundStyle(Color.textPrimary)
        }.buttonStyle(AiExperiencePressStyle())
    }
    private func entrance(_ title: String, subtitle: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 23, weight: .light))
                .frame(width: 30).foregroundStyle(Color.accentDefault)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.subheadline.weight(.medium))
                Text(subtitle).font(.caption).foregroundStyle(Color.textSecondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption)
        }.padding(.vertical, 16).frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(Color.textPrimary)
    }
}

struct AiExperiencePressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct AiNotebookView: View {
    @State private var notes: [AiExperienceNote] = []
    @State private var page = 1
    @State private var hasMore = false
    @State private var loading = false
    @State private var error = ""
    @State private var deleteTarget: AiExperienceNote?
    @State private var deleting = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack { Text("我的手记").font(AppTypography.title(26)); Spacer(); NavigationLink("我的报告") { AiReportLibrary() } }
                Text("把有用的发现留给自己，随时回来看看。只有你可以查看这些记录。")
                    .font(.subheadline).foregroundStyle(Color.textSecondary)
                if !error.isEmpty { Text(error).font(.footnote).foregroundStyle(.red); Button("重试") { Task { await load(reset: true) } } }
                if notes.isEmpty && !loading && error.isEmpty {
                    ContentUnavailableView("还没有手记", systemImage: "book.closed", description: Text("在姓名灵感或选择比较中，保存一次自己的发现。"))
                }
                ForEach(notes) { item in
                    HStack(alignment: .top) {
                        NavigationLink { AiSavedNoteView(id: item.id) } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(item.title).font(.headline)
                                Text(item.data.result.summary).font(.subheadline).lineLimit(2)
                                Text(item.createdAt.replacingOccurrences(of: "T", with: " ").prefix(16)).font(.caption).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }.buttonStyle(.plain)
                        Button { deleteTarget = item } label: { Image(systemName: "trash").frame(width: 44, height: 44) }
                            .accessibilityLabel("删除" + item.title).disabled(deleting)
                    }.padding(16).background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 16))
                }
                if loading { ProgressView().frame(maxWidth: .infinity) }
                if hasMore { Button("加载更多") { Task { await load(reset: false) } }.disabled(loading) }
            }.padding(18).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }.background(Color.bgPrimary).task { await load(reset: true) }.refreshable { await load(reset: true) }
            .confirmationDialog("删除这篇手记？", isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }), titleVisibility: .visible) {
                if let item = deleteTarget { Button("确认删除", role: .destructive) { Task { await delete(item) } } }
                Button("保留手记", role: .cancel) { deleteTarget = nil }
            } message: { Text("删除后无法恢复，原专题报告和聊天记录不受影响。") }
    }
    private func load(reset: Bool) async {
        guard !loading else { return }; loading = true; error = ""
        defer { loading = false }
        let nextPage = reset ? 1 : page + 1
        do {
            let next: [AiExperienceNote] = try await APIClient.shared.request(.aiNotes(nextPage))
            try Task.checkCancellation()
            notes = reset ? next : notes + next.filter { n in !notes.contains { $0.id == n.id } }
            page = nextPage; hasMore = next.count == 20
        } catch is CancellationError {} catch { self.error = error.localizedDescription }
    }
    private func delete(_ item: AiExperienceNote) async {
        deleting = true; defer { deleting = false }
        do {
            struct Deleted: Decodable { let deleted: Bool }
            let _: Deleted = try await APIClient.shared.request(.aiNoteDelete(item.id))
            notes.removeAll { $0.id == item.id }; deleteTarget = nil
        } catch is CancellationError {} catch { self.error = error.localizedDescription }
    }
}

struct AiSavedNoteView: View {
    let id: Int64
    @State private var note: AiExperienceNote?
    @State private var error = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let note {
                    Text(note.title).font(AppTypography.title(27))
                    Text(note.createdAt).font(.caption).foregroundStyle(.secondary)
                    AiExperienceResultView(input: note.data.input, result: note.data.result, favorites: .constant(Set(note.data.favorites)), editable: false)
                    if !note.data.note.isEmpty { Text("当时的想法").font(.headline); Text(note.data.note).textSelection(.enabled) }
                } else if !error.isEmpty {
                    Text(error).foregroundStyle(.red); Button("重试") { Task { await load() } }
                } else { ProgressView("正在打开手记…") }
            }.padding(18).frame(maxWidth: 760).frame(maxWidth: .infinity, alignment: .leading)
        }.background(Color.bgPrimary).navigationTitle("手记").navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar).task { await load() }
    }
    private func load() async {
        error = ""
        do { note = try await APIClient.shared.request(.aiNote(id)) }
        catch is CancellationError {} catch { self.error = error.localizedDescription }
    }
}
