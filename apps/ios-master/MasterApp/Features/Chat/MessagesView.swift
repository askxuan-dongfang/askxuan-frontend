//
//  MessagesView.swift
//  MasterApp
//
//  消息列表（页面 9）。
//  GET admin/messages/master（master-scoped from JWT）
//  PUT  admin/messages/master/:id/read
//
//  通知列表 / 咨询列表均来源于 message-service 站内消息（真实 API）。
//  实时新消息通过 WebSocketManager（HTTP 轮询，后端暂无 WS）拉取。
//

import SwiftUI
import Combine

@MainActor
final class MessagesViewModel: ObservableObject {
    @Published var messages: [MasterMessage] = []
    @Published var filter: Int = -1      // -1 全部 / 0 未读 / 1 已读
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var unreadCount: Int = 0
    @Published var connectionState: WebSocketManager.ConnectionState = .disconnected

    let socketManager: WebSocketManager
    private let apiClient: APIClient
    private var page: Int = 1
    private let size: Int = 20
    private var hasMore: Bool = true

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
        self.socketManager = WebSocketManager(apiClient: apiClient)

        // 同步轮询管理器的状态 / 未读数到本 VM
        socketManager.$connectionState.assign(to: &$connectionState)
        socketManager.$unreadCount.assign(to: &$unreadCount)

        // 轮询到新数据时刷新消息列表
        socketManager.onDataRefresh = { [weak self] in
            await self?.load(reset: true)
        }

        // 启动实时消息（HTTP 轮询）
        socketManager.connect()
    }

    func load(reset: Bool = true) async {
        if reset {
            page = 1
            hasMore = true
        }
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            let resp: MessageListResponse = try await apiClient.request(
                .masterMessages(isRead: filter, page: page, size: size)
            )
            if reset {
                messages = resp.list
            } else {
                messages.append(contentsOf: resp.list)
            }
            hasMore = messages.count < Int(resp.total)
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
        isLoading = false
    }

    func loadMore() async {
        guard hasMore, !isLoading else { return }
        page += 1
        await load(reset: false)
    }

    func markRead(_ message: MasterMessage) async {
        guard message.isRead == 0 else { return }
        do {
            let _: MessageReadResponse = try await apiClient.request(.masterMessageRead(id: message.id))
            if let idx = messages.firstIndex(where: { $0.id == message.id }) {
                let m = messages[idx]
                messages[idx] = MasterMessage(id: m.id, userId: m.userId, title: m.title,
                                              content: m.content, bizType: m.bizType, bizId: m.bizId,
                                              isRead: 1, createdAt: m.createdAt)
                unreadCount = max(0, unreadCount - 1)
            }
        } catch {
            // 静默失败，不影响列表
        }
    }

    func switchFilter(_ value: Int) async {
        filter = value
        await load(reset: true)
    }
}

struct MessagesView: View {
    @StateObject private var viewModel = MessagesViewModel()
    @State private var selectedTab: Int = 0  // 0=通知, 1=咨询

    /// 咨询列表：取 bizType == "consult" 的消息
    private var consults: [MasterMessage] {
        viewModel.messages.filter { $0.bizType == "consult" }
    }

    var body: some View {
        VStack(spacing: 0) {
            subTabs
            if selectedTab == 0 {
                noticeList
            } else {
                chatList
            }
        }
        .background(Color.bgPrimary)
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    // MARK: - 子 Tab

    private var subTabs: some View {
        HStack(spacing: 0) {
            subTabItem(title: "通知", index: 0, badge: viewModel.unreadCount)
            subTabItem(title: "咨询", index: 1, badge: 0)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.borderDefault)
                .frame(height: 1)
        }
    }

    private func subTabItem(title: String, index: Int, badge: Int) -> some View {
        let isSelected = selectedTab == index
        return VStack(spacing: 0) {
            HStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .textPrimary : .textTertiary)
                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 16, minHeight: 16)
                        .padding(.horizontal, 4)
                        .background(Color.brandDefault)
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, 14)
            Rectangle()
                .fill(isSelected ? Color.brandDefault : Color.clear)
                .frame(width: 24, height: 3)
                .cornerRadius(2)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedTab = index
        }
    }

    // MARK: - 通知列表（真实数据）

    private var noticeList: some View {
        ScrollView {
            VStack(spacing: 0) {
                if viewModel.messages.isEmpty && !viewModel.isLoading {
                    EmptyState(icon: "bell.slash",
                               title: "暂无通知",
                               message: viewModel.errorMessage ?? "暂无站内消息")
                        .padding(.top, 60)
                } else {
                    ForEach(viewModel.messages) { message in
                        NavigationLink {
                            ChatView(message: message)
                        } label: {
                            noticeItem(message)
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(
                            TapGesture().onEnded {
                                Task { await viewModel.markRead(message) }
                            }
                        )
                    }
                }
            }
            .padding(.bottom, 70)
        }
        .softScrollEdge(.bottom)
    }

    private func noticeItem(_ m: MasterMessage) -> some View {
        let meta = bizMeta(m.bizType)
        return HStack(alignment: .top, spacing: 12) {
            // 图标
            Image(systemName: meta.icon)
                .font(.system(size: 18))
                .foregroundStyle(meta.color)
                .frame(width: 40, height: 40)
                .background(Color.bgTertiary)
                .cornerRadius(AppRadius.md)

            // 内容
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(m.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.textPrimary)
                    Spacer()
                    if m.isRead == 0 {
                        Circle()
                            .fill(Color.brandDefault)
                            .frame(width: 8, height: 8)
                    }
                    Text(DFDateFormatter.friendly(m.createdAt))
                        .font(.micro)
                        .foregroundStyle(.textTertiary)
                }
                Text(m.content)
                    .font(.system(size: 12))
                    .foregroundStyle(.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, 14)
        .background(Color.bgSecondary)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.borderDefault)
                .frame(height: 1)
                .padding(.leading, 52)
        }
    }

    // MARK: - 咨询列表（真实数据：bizType == consult）

    private var chatList: some View {
        ScrollView {
            VStack(spacing: 0) {
                if consults.isEmpty && !viewModel.isLoading {
                    EmptyState(icon: "bubble.left.slash",
                               title: "暂无咨询",
                               message: "暂无咨询消息")
                        .padding(.top, 60)
                } else {
                    ForEach(consults) { message in
                        NavigationLink {
                            ChatView(message: message)
                        } label: {
                            chatItem(message)
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(
                            TapGesture().onEnded {
                                Task { await viewModel.markRead(message) }
                            }
                        )
                    }
                }
            }
            .padding(.bottom, 70)
        }
        .softScrollEdge(.bottom)
    }

    private func chatItem(_ m: MasterMessage) -> some View {
        HStack(spacing: 12) {
            // 头像
            Image(systemName: "person.fill")
                .font(.system(size: 18))
                .foregroundStyle(.textTertiary)
                .frame(width: 40, height: 40)
                .background(Color.bgTertiary)
                .clipShape(Circle())

            // 内容
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(m.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.textPrimary)
                    Spacer()
                    Text(DFDateFormatter.friendly(m.createdAt))
                        .font(.micro)
                        .foregroundStyle(.textTertiary)
                }
                Text(m.content)
                    .font(.system(size: 12))
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 未读数
            if m.isRead == 0 {
                Text("1")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 18, minHeight: 18)
                    .padding(.horizontal, 5)
                    .background(Color.brandDefault)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, 14)
        .background(Color.bgSecondary)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.borderDefault)
                .frame(height: 1)
                .padding(.leading, 52)
        }
    }

    // MARK: - 业务类型 → 图标 / 颜色

    private func bizMeta(_ bizType: String) -> (icon: String, color: Color) {
        switch bizType {
        case "booking":  return ("calendar", .brandDefault)
        case "system":   return ("info.circle", .accentDefault)
        case "consult":  return ("message", .stateSuccess)
        case "income":   return ("yensign", .stateWarning)
        case "audit":    return ("checkmark.shield", .accentLight)
        default:         return ("bell", .textTertiary)
        }
    }
}

#Preview {
    NavigationStack {
        MessagesView()
    }
    .preferredColorScheme(.dark)
}
