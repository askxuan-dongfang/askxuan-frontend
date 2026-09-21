import SwiftUI

struct AiDiscoveryView: View {
    @ObservedObject var viewModel: AiDivinationViewModel
    @Binding var naming: AiNamingInput
    @Binding var decision: AiDecisionInput
    let openChat: () -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("从一件小事，理清心中所想").font(AppTypography.title(27))
                Text("聊聊近况，试一种思考方式，把有用的发现留下来。")
                    .font(.subheadline).foregroundStyle(Color.textSecondary)
                NavigationLink { AiExperienceView(skill: "decision", naming: $naming, decision: $decision) } label: {
                    entrance("两难梳理", subtitle: "把纠结摊开，看见你真正重视的事", symbol: "scale.3d", prominent: true)
                }.buttonStyle(AiExperiencePressStyle()).accessibilityIdentifier("ai-decision")
                NavigationLink { AiExperienceView(skill: "naming", naming: $naming, decision: $decision) } label: {
                    entrance("姓名灵感", subtitle: "看字义、挑风格，收藏并比较喜欢的名字", symbol: "character.book.closed")
                }.buttonStyle(AiExperiencePressStyle()).accessibilityIdentifier("ai-naming")
                Button(action: openChat) {
                    entrance("随心聊聊", subtitle: "关于生活、关系和当下的心事", symbol: "bubble.left.and.bubble.right")
                }.buttonStyle(AiExperiencePressStyle())
                if let recent = viewModel.sessions.first {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("继续上次").font(AppTypography.section)
                        Button {
                            openChat()
                            Task { await viewModel.selectSession(recent.id) }
                        } label: {
                            HStack { Text(recent.title).lineLimit(2); Spacer(); Image(systemName: "arrow.up.right") }
                                .font(.subheadline).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 16))
                        }.buttonStyle(AiExperiencePressStyle())
                    }
                }
                AiTopicEntrances()
            }.padding(18).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }.background(Color.bgPrimary)
    }
    private func entrance(_ title: String, subtitle: String, symbol: String, prominent: Bool = false) -> some View {
        HStack(spacing: 16) {
            Image(systemName: symbol).font(.system(size: 25, weight: .light))
                .frame(width: 46, height: 52).foregroundStyle(Color.accentDefault)
            VStack(alignment: .leading, spacing: 7) {
                Text(title).font(AppTypography.title(prominent ? 24 : 21))
                Text(subtitle).font(.subheadline).foregroundStyle(Color.textSecondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption)
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(Color.textPrimary)
            .background(prominent ? Color.brandDefault.opacity(0.10) : Color.bgSecondary, in: RoundedRectangle(cornerRadius: 20))
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
                    ContentUnavailableView("还没有手记", systemImage: "book.closed", description: Text("在姓名灵感或两难梳理中，保存一次自己的发现。"))
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
