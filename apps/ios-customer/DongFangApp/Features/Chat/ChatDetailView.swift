//
//  ChatDetailView.swift
//  DongFangApp
//
//  对话详情页：顶部法师信息 + 消息流 + 底部输入框。
//

import SwiftUI

struct ChatDetailView: View {
    let conversation: ChatConversation
    @StateObject private var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    init(conversation: ChatConversation, viewModel: ChatViewModel) {
        self.conversation = conversation
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            messagesList
            inputBar
        }
        .background(Color.bgPrimary)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if viewModel.currentConversation?.id != conversation.id {
                viewModel.enterConversation(conversation)
            }
        }
    }

    // MARK: - 顶部导航
    private var topBar: some View {
        HStack(spacing: AppSpacing.md) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.accentDefault)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            ZStack {
                RemoteAvatar(urlString: conversation.masterAvatar, size: 40)
                if conversation.isOnline {
                    Circle()
                        .fill(Color.stateSuccess)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(Color.bgPrimary, lineWidth: 1.5))
                        .offset(x: 14, y: 14)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(conversation.masterName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text(conversation.isOnline ? "在线" : "离线")
                    .font(.system(size: 11))
                    .foregroundStyle(conversation.isOnline ? Color.stateSuccess : Color.textTertiary)
            }

            Spacer()

            Button {
                // 跳转法师主页（简化）
            } label: {
                Image(systemName: "person.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.accentDefault)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppSpacing.lg)
        .frame(height: AppSpacing.navTop)
        .background(Color.bgPrimary.opacity(0.85).background(.ultraThinMaterial))
        .overlay(alignment: .bottom) { Rectangle().fill(Color.borderDivider).frame(height: 1) }
    }

    // MARK: - 消息列表
    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: AppSpacing.md) {
                    ForEach(viewModel.messages) { message in
                        messageBubble(message)
                            .id(message.id)
                    }
                    Spacer().frame(height: 8).id("bottom")
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.md)
            }
            .onChange(of: viewModel.messages.count) { _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    private func messageBubble(_ message: ChatBubble) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            if message.isFromMe {
                Spacer()
            } else {
                RemoteAvatar(urlString: conversation.masterAvatar, size: 32)
            }

            VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: 2) {
                Text(message.text)
                    .font(.system(size: 14))
                    .foregroundStyle(message.isFromMe ? Color.white : Color.textPrimary)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(
                        message.isFromMe ?
                        LinearGradient(colors: [Color.brandDefault, Color.brandLight],
                                       startPoint: .leading, endPoint: .trailing) :
                        LinearGradient(colors: [Color.bgSecondary, Color.bgSecondary],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(AppRadius.lg)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.lg)
                            .stroke(message.isFromMe ? Color.clear : Color.borderDefault, lineWidth: 1)
                    )

                HStack(spacing: 4) {
                    if message.isFromMe {
                        sendStatusView(message.status)
                    }
                    Text(message.time)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.textTertiary)
                }
            }

            if !message.isFromMe {
                Spacer()
            }
        }
    }

    /// 发送状态标识（发送中 / 已发送 / 发送失败）
    @ViewBuilder
    private func sendStatusView(_ status: SendStatus) -> some View {
        switch status {
        case .pending:
            HStack(spacing: 2) {
                Image(systemName: "clock")
                    .font(.system(size: 9))
                Text("发送中")
                    .font(.system(size: 10))
            }
            .foregroundStyle(Color.textTertiary)
        case .sent:
            Image(systemName: "checkmark")
                .font(.system(size: 10))
                .foregroundStyle(Color.stateSuccess)
        case .failed:
            HStack(spacing: 2) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9))
                Text("发送失败")
                    .font(.system(size: 10))
            }
            .foregroundStyle(Color.stateError)
        }
    }

    // MARK: - 底部输入栏
    private var inputBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppSpacing.sm) {
                Button {
                    // 附加功能（简化）
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.accentDefault)
                }
                .buttonStyle(.plain)

                HStack(spacing: 8) {
                    TextField("输入消息...", text: $viewModel.inputText, axis: .vertical)
                        .lineLimit(1...4)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textPrimary)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(Color.bgSecondary)
                .cornerRadius(20)
                .overlay(Capsule().stroke(Color.borderDefault, lineWidth: 1))

                Button {
                    viewModel.sendMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(viewModel.inputText.isEmpty ? Color.textTertiary : Color.white)
                        .frame(width: 36, height: 36)
                        .background(
                            viewModel.inputText.isEmpty ? Color.bgTertiary : Color.brandDefault
                        )
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.inputText.isEmpty)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.sm)
        }
        .background(
            Color.bgPrimary.opacity(0.95)
                .background(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) { Rectangle().fill(Color.borderDivider).frame(height: 1) }
    }
}

#Preview {
    NavigationStack {
        ChatDetailView(conversation: ChatConversation.mockConversations[0],
                       viewModel: ChatViewModel())
    }
    .preferredColorScheme(.dark)
}
