//
//  AiDivinationView.swift
//  DongFangApp
//
//  AI 问事直接对话页：历史抽屉、新建会话、异步状态轮询和失败重试。
//

import SwiftUI

struct AiConversation: Decodable, Identifiable {
    let id: Int64
    let sessionNo: String
    let userId: String
    let skillCode: String
    let title: String
    let status: String
    let createdAt: String
    let updatedAt: String
}

struct AiChatMessage: Decodable, Identifiable {
    let id: Int64
    let sessionId: Int64
    let role: String
    let content: String
    let tokens: Int
    let status: String
    let errorMessage: String
    let retryable: Bool
    let createdAt: String
}

struct AiSessionCreateResult: Decodable {
    let id: Int64
    let sessionNo: String
    let skillCode: String
    let status: String
}

struct AiMessageSendResult: Decodable {
    let sessionId: Int64
    let messageId: Int64
    let status: String
}

@MainActor
final class AiDivinationViewModel: ObservableObject {
    @Published var sessions: [AiConversation] = []
    @Published var messages: [AiChatMessage] = []
    @Published var input = ""
    @Published var selectedSessionId: Int64?
    @Published var selectedSkillCode: String?
    @Published var isLoading = false
    @Published var isSending = false
    @Published var errorMessage: String?

    private let apiClient: APIClient
    private let authStore: AuthStore

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
        self.authStore = AuthStore.shared
    }

    var currentTitle: String {
        sessions.first(where: { $0.id == selectedSessionId })?.title ?? "新对话"
    }

    func bootstrap() async {
        guard sessions.isEmpty else { return }
        await loadSessions(selectMostRecent: true)
    }

    func loadSessions(selectMostRecent: Bool = false) async {
        do {
            let response: PageResponse<AiConversation> = try await apiClient.request(
                .aiSessions(userId: authStore.userId, page: 1, size: 50)
            )
            sessions = response.list
            if selectMostRecent, selectedSessionId == nil, let first = sessions.first {
                await selectSession(first.id)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectSession(_ id: Int64) async {
        selectedSessionId = id
        errorMessage = nil
        await loadMessages()
    }

    func newConversation() {
        selectedSessionId = nil
        selectedSkillCode = nil
        messages = []
        input = ""
        errorMessage = nil
    }

    func send() async {
        let content = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, !isSending else { return }
        input = ""
        isSending = true
        errorMessage = nil
        defer { isSending = false }

        do {
            let sessionId: Int64
            if let selectedSessionId {
                sessionId = selectedSessionId
                let _: AiMessageSendResult = try await apiClient.request(
                    .aiSendMessage(AiMessageSendRequest(
                        sessionId: String(selectedSessionId),
                        userId: authStore.userId,
                        content: content
                    ))
                )
            } else {
                let result: AiSessionCreateResult = try await apiClient.request(
                    .aiSessionCreate(AiSessionCreateRequest(
                        userId: authStore.userId,
                        skillCode: selectedSkillCode,
                        question: content
                    ))
                )
                sessionId = result.id
                selectedSessionId = result.id
            }
            await loadMessages()
            await pollUntilSettled(sessionId: sessionId)
            await loadSessions()
        } catch {
            input = content
            errorMessage = error.localizedDescription
        }
    }

    func retry(_ message: AiChatMessage) async {
        guard message.retryable, !isSending else { return }
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        do {
            let _: AiMessageSendResult = try await apiClient.request(
                .aiRetryMessage(
                    sessionId: String(message.sessionId),
                    messageId: message.id,
                    userId: authStore.userId
                )
            )
            await loadMessages()
            await pollUntilSettled(sessionId: message.sessionId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadMessages() async {
        guard let selectedSessionId else {
            messages = []
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let response: PageResponse<AiChatMessage> = try await apiClient.request(
                .aiMessages(
                    sessionId: String(selectedSessionId),
                    userId: authStore.userId,
                    page: 1,
                    size: 100
                )
            )
            messages = response.list
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func pollUntilSettled(sessionId: Int64) async {
        for _ in 0..<30 {
            guard selectedSessionId == sessionId else { return }
            if !messages.contains(where: { $0.status == "pending" }) { return }
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await loadMessages()
        }
        if messages.contains(where: { $0.status == "pending" }) {
            errorMessage = "回答仍在生成，可稍后从历史会话继续查看"
        }
    }
}

struct AiDivinationView: View {
    @StateObject private var viewModel = AiDivinationViewModel()
    @State private var isDrawerOpen = false

    private let skillOptions = [
        (code: nil as String?, name: "直接问事"),
        (code: "bazi", name: "八字命理"),
        (code: "marriage", name: "姻缘测算"),
        (code: "tarot", name: "塔罗牌"),
        (code: "fengshui", name: "风水分析"),
        (code: "qimen", name: "奇门遁甲"),
        (code: "ziwei", name: "紫微斗数"),
        (code: "liuyao", name: "六爻梅花")
    ]

    var body: some View {
        ZStack(alignment: .leading) {
            VStack(spacing: 0) {
                navigationBar
                Divider().overlay(Color.borderDivider)
                conversation
                composer
            }
            .background(Color.bgPrimary)

            if isDrawerOpen {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture { closeDrawer() }

                historyDrawer
                    .frame(maxWidth: 320)
                    .transition(.move(edge: .leading))
            }
        }
        .navigationBarHidden(true)
        .task { await viewModel.bootstrap() }
        .animation(.easeInOut(duration: 0.2), value: isDrawerOpen)
    }

    private var navigationBar: some View {
        HStack(spacing: 12) {
            iconButton("sidebar.left", label: "历史问事") {
                isDrawerOpen = true
            }

            VStack(spacing: 2) {
                Text("AI问事")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text(viewModel.currentTitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)

            iconButton("square.and.pencil", label: "新建问事") {
                viewModel.newConversation()
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 52)
    }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    if viewModel.messages.isEmpty, !viewModel.isLoading {
                        emptyConversation
                    } else {
                        ForEach(viewModel.messages) { message in
                            messageRow(message)
                                .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.count) {
                if let last = viewModel.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyConversation: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 30))
                .foregroundStyle(Color.accentDefault)
                .frame(width: 64, height: 64)
                .background(Color.accentDefault.opacity(0.12))
                .clipShape(Circle())

            Text("今天想问什么？")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.textPrimary)

            Text("默认直接问事，也可选择一个术数方向")
                .font(.system(size: 13))
                .foregroundStyle(Color.textSecondary)

            Menu {
                ForEach(Array(skillOptions.enumerated()), id: \.offset) { _, option in
                    Button(option.name) { viewModel.selectedSkillCode = option.code }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.3")
                    Text(selectedSkillName)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.brandDefault)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(Color.brandDefault.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 72)
    }

    private func messageRow(_ message: AiChatMessage) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == "user" { Spacer(minLength: 52) }

            if message.role == "assistant" {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.accentDefault)
                    .frame(width: 28, height: 28)
                    .background(Color.accentDefault.opacity(0.12))
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 8) {
                if message.status == "pending" {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("正在生成回答")
                    }
                } else if message.status == "failed" {
                    Text(message.errorMessage.isEmpty ? "回答生成失败" : message.errorMessage)
                    if message.retryable {
                        Button {
                            Task { await viewModel.retry(message) }
                        } label: {
                            Label("重试", systemImage: "arrow.clockwise")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.brandDefault)
                    }
                } else {
                    Text(message.content)
                        .lineSpacing(4)
                }
            }
            .font(.system(size: 15))
            .foregroundStyle(message.role == "user" ? Color.white : Color.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(message.role == "user" ? Color.brandDefault : Color.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                if message.role == "assistant" {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.borderDefault, lineWidth: 1)
                }
            }

            if message.role == "assistant" { Spacer(minLength: 36) }
        }
        .frame(maxWidth: .infinity)
    }

    private var composer: some View {
        VStack(spacing: 8) {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.stateError)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(alignment: .bottom, spacing: 10) {
                TextField("输入你的问题", text: $viewModel.input, axis: .vertical)
                    .lineLimit(1...4)
                    .font(.system(size: 15))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.bgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.borderDefault, lineWidth: 1)
                    )
                    .onSubmit { Task { await viewModel.send() } }

                Button {
                    Task { await viewModel.send() }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(canSend ? Color.brandDefault : Color.textTertiary)
                        .clipShape(Circle())
                }
                .disabled(!canSend)
                .accessibilityLabel("发送")
            }

            Text("AI 内容仅供参考，不替代医疗、法律或财务专业意见")
                .font(.system(size: 10))
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Color.bgPrimary)
        .overlay(alignment: .top) { Divider().overlay(Color.borderDivider) }
    }

    private var historyDrawer: some View {
        VStack(spacing: 0) {
            HStack {
                Text("历史问事")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                iconButton("xmark", label: "关闭历史") { closeDrawer() }
            }
            .padding(.horizontal, 16)
            .frame(height: 54)

            Button {
                viewModel.newConversation()
                closeDrawer()
            } label: {
                Label("新建问事", systemImage: "square.and.pencil")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.brandDefault)
            .background(Color.brandDefault.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 12)
            .padding(.bottom, 10)

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(viewModel.sessions) { session in
                        Button {
                            Task {
                                await viewModel.selectSession(session.id)
                                closeDrawer()
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "bubble.left")
                                    .foregroundStyle(Color.textTertiary)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(session.title)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Color.textPrimary)
                                        .lineLimit(1)
                                    Text(skillName(session.skillCode))
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.textTertiary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 52)
                            .background(
                                session.id == viewModel.selectedSessionId
                                    ? Color.brandDefault.opacity(0.1)
                                    : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .frame(maxHeight: .infinity)
        .background(Color.bgSecondary)
        .shadow(color: .black.opacity(0.25), radius: 16, x: 6)
        .ignoresSafeArea(edges: .bottom)
    }

    private var canSend: Bool {
        !viewModel.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isSending
    }

    private var selectedSkillName: String {
        skillOptions.first(where: { $0.code == viewModel.selectedSkillCode })?.name ?? "直接问事"
    }

    private func skillName(_ code: String) -> String {
        skillOptions.first(where: { $0.code == code })?.name ?? code
    }

    private func iconButton(_ systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.textPrimary)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func closeDrawer() {
        isDrawerOpen = false
    }
}

#Preview {
    AiDivinationView()
        .preferredColorScheme(.dark)
}
