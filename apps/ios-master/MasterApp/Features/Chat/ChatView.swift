//
//  ChatView.swift
//  MasterApp
//
//  对话（页面 8）。
//  信众咨询对话界面：消息气泡 + 输入栏。从站内消息进入时展示该消息上下文。
//  说明：当前后端 message-service 未提供 IM 长连接对话接口，此页为本地会话 UI，
//  发送的消息追加到本地列表，便于后续接入 IM（imToken 已由登录接口下发）。
//

import SwiftUI

struct ChatBubble: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let isMe: Bool
    let time: String
}

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var bubbles: [ChatBubble] = []
    @Published var inputText: String = ""

    let message: MasterMessage?

    init(message: MasterMessage?) {
        self.message = message
        // 以进入消息作为会话起点
        if let m = message {
            bubbles.append(ChatBubble(text: m.content, isMe: false,
                                      time: DFDateFormatter.friendly(m.createdAt)))
        }
        // 接收 OpenIM 实时消息
        OpenIMManager.shared.delegate = self
    }

    /// 发送消息（通过 OpenIM SDK 发送给信众）
    func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        // 信众 OpenIM userID 约定为 "u_" + userId（站内消息发送者）
        guard let userID = message?.userId, !userID.isEmpty else { return }
        let recvID = "u_" + userID
        OpenIMManager.shared.sendMessage(text: text, to: recvID) { [weak self] success in
            guard success else { return }
            self?.bubbles.append(ChatBubble(text: text, isMe: true, time: "刚刚"))
            self?.inputText = ""
        }
    }
}

struct ChatView: View {
    let message: MasterMessage?
    @StateObject private var viewModel: ChatViewModel

    init(message: MasterMessage?) {
        self.message = message
        _viewModel = StateObject(wrappedValue: ChatViewModel(message: message))
    }

    var body: some View {
        VStack(spacing: 0) {
            // 消息列表
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: AppSpacing.md) {
                        ForEach(viewModel.bubbles) { bubble in
                            bubbleRow(bubble)
                                .id(bubble.id)
                        }
                    }
                    .padding(.horizontal, AppSpacing.pageHorizontal)
                    .padding(.vertical, AppSpacing.lg)
                }
                .onChange(of: viewModel.bubbles.count) { _ in
                    if let last = viewModel.bubbles.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            Divider().background(Color.borderDivider)

            // 输入栏
            HStack(spacing: AppSpacing.sm) {
                TextField("输入回复...", text: $viewModel.inputText, axis: .vertical)
                    .font(.body)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1...3)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(Color.bgTertiary)
                    .cornerRadius(AppRadius.xl)
                    .overlay(
                        Capsule().stroke(Color.borderDefault, lineWidth: 1)
                    )

                Button {
                    viewModel.send()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            LinearGradient(colors: [.brandDefault, .brandLight],
                                           startPoint: .top, endPoint: .bottom)
                        )
                        .clipShape(Circle())
                }
                .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, AppSpacing.pageHorizontal)
            .padding(.vertical, AppSpacing.md)
            .background(Color.bgSecondary)
        }
        .background(Color.bgPrimary)
        .navigationTitle(message?.title ?? "对话")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func bubbleRow(_ bubble: ChatBubble) -> some View {
        HStack {
            if bubble.isMe { Spacer(minLength: 60) }
            VStack(alignment: bubble.isMe ? .trailing : .leading, spacing: 4) {
                Text(bubble.text)
                    .font(.body)
                    .foregroundStyle(bubble.isMe ? .white : .textPrimary)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(
                        bubble.isMe
                        ? AnyShapeStyle(LinearGradient(colors: [.brandDefault, .brandDark],
                                                       startPoint: .leading, endPoint: .trailing))
                        : AnyShapeStyle(Color.bgTertiary)
                    )
                    .cornerRadius(AppRadius.lg)
                Text(bubble.time)
                    .font(.micro)
                    .foregroundStyle(.textTertiary)
            }
            if !bubble.isMe { Spacer(minLength: 60) }
        }
    }
}

// MARK: - OpenIM 消息接收
extension ChatViewModel: OpenIMManagerDelegate {
    func onRecvC2CMessage(_ msg: OpenIMMessage) {
        bubbles.append(ChatBubble(text: msg.text ?? "", isMe: false, time: "刚刚"))
    }

    func onConversationListUpdated(_ conversations: [OpenIMConversation]) {
        // 预留：后续可在此刷新会话列表
    }
}

#Preview {
    NavigationStack {
        ChatView(message: nil)
    }
    .preferredColorScheme(.dark)
}
