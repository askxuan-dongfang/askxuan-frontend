//
//  AiDivinationView.swift
//  DongFangApp
//
//  AI 问事直接对话页：历史抽屉、新建会话、异步状态轮询和失败重试。
//

import SwiftUI
import PhotosUI
import UIKit

struct AiSkillOption: Decodable, Identifiable {
    let value: String
    let label: String
    var description: String? = nil
    var id: String { value }
}

struct AiFieldCondition: Decodable { let key: String; let value: String }

struct AiSkillField: Decodable, Identifiable {
    let key: String
    let label: String
    let type: String
    let required: Bool
    let placeholder: String?
    let options: [AiSkillOption]?
    var helpText: String? = nil
    var defaultValue: String? = nil
    var visibleWhen: AiFieldCondition? = nil
    var requiredWhen: AiFieldCondition? = nil
    var validation: String? = nil
    var id: String { key }
    func visible(in inputs: [String: String]) -> Bool { visibleWhen.map { inputs[$0.key] == $0.value } ?? true }
    func needed(in inputs: [String: String]) -> Bool { required || (requiredWhen.map { inputs[$0.key] == $0.value } ?? false) }
    func valid(in inputs: [String: String]) -> Bool {
        guard visible(in: inputs) else { return true }
        let value = (inputs[key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return !needed(in: inputs) }
        if validation == "divination-numbers" { return value.range(of: #"^[0-9]{1,6}([ ,，、\t]+[0-9]{1,6}){1,2}$"#, options: .regularExpression) != nil }
        if key == "birthDate" && inputs["calendarType"] == "lunar" { return value.range(of: #"^(19[0-9]{2}|20[0-9]{2}|2100)-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|30)$"#, options: .regularExpression) != nil }
        if ["date", "time", "datetime"].contains(type) {
            let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(secondsFromGMT: 8 * 3600); formatter.isLenient = false
            formatter.dateFormat = type == "date" ? "yyyy-MM-dd" : type == "time" ? "HH:mm" : "yyyy-MM-dd'T'HH:mm"
            guard let date = formatter.date(from: value), formatter.string(from: date) == value else { return false }
            if key == "birthDate" { let year = Int(value.prefix(4)) ?? 0; return (1900...2100).contains(year) }
        }
        if type == "select" { return options?.contains { $0.value == value } == true }
        return true
    }
}

struct AiSkillInputSchema: Decodable { let fields: [AiSkillField] }

struct AiSkill: Decodable, Identifiable {
    let id: Int64
    let code: String
    let category: String
    let name: String
    let version: String
    let description: String
    let icon: String
    let sourceType: String
    let sourceRef: String
    let inputSchema: AiSkillInputSchema
    let capabilities: [String]
    let riskLevel: String
    let sortOrder: Int
    let status: String
}

struct AiSkillListResponse: Decodable { let list: [AiSkill] }

struct AiConversation: Decodable, Identifiable {
    let id: Int64
    let sessionNo: String
    let userId: String
    let skillCode: String
	let selectionMode: String
	let skillVersion: String
    let title: String
    let status: String
    let createdAt: String
    let updatedAt: String
}

struct AiChatMessage: Decodable, Identifiable {
    let id: Int64
    let sessionId: Int64
    let role: String
    var content: String
	let attachments: [AiImageAttachment]?
	let runId: Int64
    let tokens: Int
    var status: String
	var stage: String
    let errorMessage: String
    let retryable: Bool
    let createdAt: String
}

struct AiSessionCreateResult: Decodable {
    let id: Int64
    let sessionNo: String
    let skillCode: String
    let status: String
    let messageId: Int64?
}

struct AiMessageSendResult: Decodable {
    let sessionId: Int64
    let messageId: Int64
    let status: String
}

@MainActor
final class AiDivinationViewModel: ObservableObject {
    @Published var skills: [AiSkill] = []
    @Published var sessions: [AiConversation] = []
    @Published var messages: [AiChatMessage] = []
    @Published var input = ""
    @Published var selectedSessionId: Int64?
    @Published var selectedSkillCode = "general"
    @Published var structuredInputs: [String: String] = [:]
    @Published var isLoading = false
    @Published var isSending = false
    @Published var errorMessage: String?
	@Published var selectedImages: [Data] = []

    @Published var deletingSession = false
    @Published var deletionError: String?
    private var deletedIDs = Set<Int64>()
    private var selectionEpoch = 0

    private let deleteSessionRequest: (Int64) async throws -> Void
    private let apiClient: APIClient
    private let authStore: AuthStore

    init(apiClient: APIClient = .shared, deleteSessionRequest: ((Int64) async throws -> Void)? = nil) {
        self.apiClient = apiClient
        self.deleteSessionRequest = deleteSessionRequest ?? { id in
            struct Result: Decodable { let id: Int64 }
            let _: Result = try await apiClient.request(.aiSessionDelete(id))
        }
        self.authStore = AuthStore.shared
    }

    var currentTitle: String {
        sessions.first(where: { $0.id == selectedSessionId })?.title ?? "新对话"
    }

    var selectedSkill: AiSkill? {
        skills.first(where: { $0.code == selectedSkillCode })
    }

    func bootstrap() async {
        await loadSkills()
        guard sessions.isEmpty else { return }
        await loadSessions(selectMostRecent: true)
    }

    func loadSkills() async {
        do {
            let response: AiSkillListResponse = try await apiClient.request(.aiSkills)
            skills = response.list

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadSessions(selectMostRecent: Bool = false) async {
        let epoch = selectionEpoch
        do {
            let response: PageResponse<AiConversation> = try await apiClient.request(
                .aiSessions(userId: authStore.userId, page: 1, size: 50)
            )
            sessions = response.list.filter { $0.status != "closed" && !deletedIDs.contains($0.id) }
            if selectMostRecent, epoch == selectionEpoch, selectedSessionId == nil, let first = sessions.first {
                await selectSession(first.id)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectSession(_ id: Int64) async {
        selectionEpoch += 1; isSending = false; messages = []; input = ""
        selectedSessionId = id
        errorMessage = nil
		selectedImages = []
        await loadMessages()
    }

    func newConversation() {
        selectionEpoch += 1; isSending = false; isLoading = false; selectedImages = []
        selectedSessionId = nil
        selectedSkillCode = "general"
        structuredInputs = [:]
        messages = []
        input = ""
        errorMessage = nil
    }

    func deleteSession(_ session: AiConversation) async -> Bool {
        guard !deletingSession else { return false }
        deletingSession = true; deletionError = nil
        defer { deletingSession = false }
        do {
            try await deleteSessionRequest(session.id)
            deletedIDs.insert(session.id)
            sessions.removeAll { $0.id == session.id }
            if selectedSessionId == session.id { newConversation() }
            return true
        } catch { deletionError = error.localizedDescription; return false }
    }

    func send() async {
        let epoch = selectionEpoch
        let content = input.trimmingCharacters(in: .whitespacesAndNewlines)
		guard (!content.isEmpty || !selectedImages.isEmpty), !isSending else { return }
        input = ""
        isSending = true
        errorMessage = nil
        defer { if epoch == selectionEpoch { isSending = false } }

        do {
			let attachments = try await uploadSelectedImages()
            guard epoch == selectionEpoch else { return }
			let question = content.isEmpty ? "请分析我上传的图片" : content
            let sessionId: Int64
            let pendingMessageId: Int64?
            if let selectedSessionId {
                sessionId = selectedSessionId
                let result: AiMessageSendResult = try await apiClient.request(
                    .aiSendMessage(AiMessageSendRequest(
                        sessionId: String(selectedSessionId),
                        userId: authStore.userId,
						content: question,
						inputs: [:],
						attachments: attachments
                    ))
                )
                pendingMessageId = result.messageId
            } else {
                let result: AiSessionCreateResult = try await apiClient.request(
                    .aiSessionCreate(AiSessionCreateRequest(
                        userId: authStore.userId,
                        skillCode: "general",
						question: question,
						inputs: [:],
						attachments: attachments
                    ))
                )
                sessionId = result.id
                pendingMessageId = result.messageId
                guard epoch == selectionEpoch else { await loadSessions(); return }
                selectedSessionId = result.id
            }
            guard epoch == selectionEpoch else { return }
            await loadMessages()
            guard epoch == selectionEpoch else { return }
            if let pendingMessageId, pendingMessageId > 0 {
                await streamUntilSettled(sessionId: sessionId, messageId: pendingMessageId)
            } else {
                await pollUntilSettled(sessionId: sessionId)
            }
            await loadSessions()
            if epoch == selectionEpoch { selectedImages = [] }
        } catch {
            guard epoch == selectionEpoch else { return }
            input = content
            errorMessage = error.localizedDescription
        }
    }

    func retry(_ message: AiChatMessage) async {
        guard message.retryable, !isSending else { return }
        let epoch = selectionEpoch
        isSending = true
        errorMessage = nil
        defer { if epoch == selectionEpoch { isSending = false } }
        do {
            let result: AiMessageSendResult = try await apiClient.request(
                .aiRetryMessage(
                    sessionId: String(message.sessionId),
                    messageId: message.id,
                    userId: authStore.userId
                )
            )
            guard epoch == selectionEpoch else { return }
            await loadMessages()
            await streamUntilSettled(sessionId: message.sessionId, messageId: result.messageId)
        } catch {
            guard epoch == selectionEpoch else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func loadMessages() async {
        guard let selectedSessionId else {
            messages = []
            return
        }
        let epoch = selectionEpoch
        isLoading = true
        defer { if epoch == selectionEpoch { isLoading = false } }
        do {
            let response: PageResponse<AiChatMessage> = try await apiClient.request(
                .aiMessages(
                    sessionId: String(selectedSessionId),
                    userId: authStore.userId,
                    page: 1,
                    size: 100
                )
            )
            guard epoch == selectionEpoch, self.selectedSessionId == selectedSessionId else { return }
            messages = response.list
        } catch {
            guard epoch == selectionEpoch else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func pollUntilSettled(sessionId: Int64) async {
        for _ in 0..<30 {
            guard selectedSessionId == sessionId else { return }
            if !messages.contains(where: { $0.status == "pending" }) { return }
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, selectedSessionId == sessionId else { return }
            await loadMessages()
        }
        if selectedSessionId == sessionId, messages.contains(where: { $0.status == "pending" }) {
            errorMessage = "回答仍在生成，可稍后从历史会话继续查看"
        }
    }

    private func streamUntilSettled(sessionId: Int64, messageId: Int64) async {
        let epoch = selectionEpoch
        guard selectedSessionId == sessionId else { return }
        do {
            try await apiClient.streamAIMessage(sessionId: sessionId, messageId: messageId) { [weak self] event in
                await MainActor.run {
                    guard let self, self.selectionEpoch == epoch, self.selectedSessionId == sessionId else { return }
                    if event.event == "delta", let snapshot = event.snapshot,
                       let index = self.messages.firstIndex(where: { $0.id == messageId }) {
                        self.messages[index].content = snapshot
					} else if event.event == "stage", let stage = event.stage,
					          let index = self.messages.firstIndex(where: { $0.id == messageId }) {
						self.messages[index].stage = stage
                    } else if event.event == "error" {
                        self.errorMessage = event.message ?? "回答生成失败"
                    }
                }
            }
            guard epoch == selectionEpoch else { return }
            await loadMessages()
        } catch {
            guard epoch == selectionEpoch else { return }
            await pollUntilSettled(sessionId: sessionId)
        }
    }

	private func uploadSelectedImages() async throws -> [AiImageAttachment] {
		var attachments: [AiImageAttachment] = []
		for (index, data) in selectedImages.prefix(3).enumerated() {
			let credential: MediaUploadCredential = try await apiClient.request(.mediaUploadCredential(MediaUploadCredentialRequest(fileName: "ai-\(Int(Date().timeIntervalSince1970))-\(index).jpg", mediaType: "image", contentType: "image/jpeg", fileSize: Int64(data.count))))
			guard let uploadURL = URL(string: credential.uploadUrl) else { throw APIError.invalidURL }
			var headers = credential.uploadHeaders
			headers["Content-Type"] = "image/jpeg"
			try await apiClient.upload(data, to: uploadURL, headers: headers)
			let asset: MediaAsset = try await apiClient.request(.mediaComplete(id: credential.mediaId, MediaCompleteRequest(coverMediaId: nil)))
			let rawURL = asset.playbackUrl.isEmpty ? asset.coverUrl : asset.playbackUrl
			attachments.append(AiImageAttachment(mediaId: asset.id, url: absoluteMediaURL(rawURL), contentType: "image/jpeg", width: nil, height: nil))
		}
		return attachments
	}

	private func absoluteMediaURL(_ value: String) -> String {
		if URL(string: value)?.scheme != nil { return value }
		guard let origin = URL(string: "/", relativeTo: AppConfig.baseURL)?.absoluteURL else { return value }
		return URL(string: value, relativeTo: origin)?.absoluteURL.absoluteString ?? value
	}
}

struct AiDivinationView: View {
    @StateObject private var viewModel = AiDivinationViewModel()
    @State private var isDrawerOpen = false
    @State private var deletionTarget: AiConversation?
    @State private var confirmDeletion = false
	@State private var selectedPhotoItems: [PhotosPickerItem] = []
    @FocusState private var focusedInput: String?

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
        .confirmationDialog("删除这段会话？", isPresented: $confirmDeletion, titleVisibility: .visible) {
            Button("确认删除", role: .destructive) {
                if let session = deletionTarget { Task { if await viewModel.deleteSession(session) { deletionTarget = nil } } }
            }
            Button("保留会话", role: .cancel) { deletionTarget = nil }
        } message: { Text("会话将从历史问事移除，无法在此恢复。已购买的专题报告仍可在「我的报告」阅读。") }
        .navigationBarHidden(true)
        .task { await viewModel.bootstrap() }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("AskXuanReportConversation"))) { event in
            if let id = event.object as? Int64 { Task { await viewModel.loadSessions(); await viewModel.selectSession(id) } }
        }
		.onChange(of: selectedPhotoItems) {
			Task {
				var images: [Data] = []
				for item in selectedPhotoItems.prefix(3) {
					if let source = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: source), let jpeg = image.jpegData(compressionQuality: 0.82) { images.append(jpeg) }
				}
				await MainActor.run { viewModel.selectedImages = images }
			}
		}
        .animation(.easeInOut(duration: 0.2), value: isDrawerOpen)
    }

    private var navigationBar: some View {
        HStack(spacing: 12) {
            iconButton("sidebar.left", label: "历史问事") {
                focusedInput = nil
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
                focusedInput = nil
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
            .onTapGesture { focusedInput = nil }
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
            VStack(alignment: .leading, spacing: 12) {
                Text("聊聊当下 · 直接问事").font(AppTypography.caption).foregroundStyle(Color.accentDefault)
                Text("今天想问什么？").font(AppTypography.title(24)).foregroundStyle(Color.textPrimary)
                Text("把困惑写在下方，我们从这件事聊起。").font(AppTypography.body).foregroundStyle(Color.textSecondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
            AiTopicEntrances()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 22)
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
				if let attachments = message.attachments, !attachments.isEmpty {
					ForEach(attachments) { attachment in
						AsyncImage(url: URL(string: attachment.url)) { image in image.resizable().scaledToFill() } placeholder: { ProgressView() }
							.frame(width: 180, height: 140).clipped().clipShape(RoundedRectangle(cornerRadius: 6))
					}
				}
                if message.status == "pending", message.content.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
						Text(stageLabel(message.stage))
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
                    if message.role == "user" { Text(message.content).lineSpacing(4) }
                    else { AiMarkdownText(text: message.content) }
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

            if !viewModel.selectedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(viewModel.selectedImages.enumerated()), id: \.offset) { index, data in
                            if let image = UIImage(data: data) {
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 56, height: 56)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    Button {
                                        viewModel.selectedImages.remove(at: index)
                                        if selectedPhotoItems.indices.contains(index) {
                                            selectedPhotoItems.remove(at: index)
                                        }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(.white, .black.opacity(0.72))
                                    }
                                    .offset(x: 5, y: -5)
                                    .accessibilityLabel("移除图片")
                                }
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }

            HStack(alignment: .bottom, spacing: 10) {
                PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 3, matching: .images) {
                    Image(systemName: "photo").frame(width: 36, height: 40)
                }
                .accessibilityLabel("添加图片")
                TextField("输入你的问题", text: $viewModel.input, axis: .vertical)
                    .lineLimit(1...4)
                    .font(.system(size: 15))
                    .focused($focusedInput, equals: "question")
                    .submitLabel(.send)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.bgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.borderDefault, lineWidth: 1)
                    )
                    .onSubmit { sendMessage() }

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .semibold))
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

    private func stageLabel(_ stage: String) -> String {
        switch stage {
        case "preparing": return "正在准备"
        case "loading_images": return "正在读取图片"
        case "tool_running": return "正在调用专业排盘"
        case "reasoning": return "正在分析"
        default: return "正在生成回答"
        }
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
                    if let error = viewModel.deletionError { Text("删除失败：" + error).font(.footnote).foregroundStyle(.red).padding(12) }
                    if viewModel.sessions.isEmpty { Text("暂无历史问事").font(.subheadline).foregroundStyle(Color.textTertiary).padding(30) }
                    ForEach(viewModel.sessions) { session in
                        HStack(spacing: 0) {
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
                        Button { deletionTarget = session; confirmDeletion = true } label: {
                            Image(systemName: "trash").font(.system(size: 16)).frame(width: 44, height: 48)
                        }.buttonStyle(.plain).foregroundStyle(Color.textTertiary)
                            .accessibilityLabel("删除会话：" + session.title).disabled(viewModel.deletingSession)
                        }
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
        (!viewModel.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !viewModel.selectedImages.isEmpty) && !viewModel.isSending
    }

    private func skillName(_ code: String) -> String {
        viewModel.skills.first(where: { $0.code == code })?.name ?? code
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
        focusedInput = nil
        isDrawerOpen = false
    }

    private func sendMessage() {
        guard canSend else { return }
        focusedInput = nil
        Task { await viewModel.send() }
    }
}

#Preview {
    AiDivinationView()
        .preferredColorScheme(.dark)
}
