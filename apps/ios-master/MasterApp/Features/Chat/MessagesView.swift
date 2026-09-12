//
//  MessagesView.swift
//  MasterApp
//
//  消息列表（页面 9）。
//  GET admin/messages/master（master-scoped from JWT）
//  PUT  admin/messages/master/:id/read
//
//  通知列表来源于 message-service，咨询列表来源于 booking-service 的付费咨询与预约（真实 API）。
//  OpenIM 负责咨询消息实时到达，站内通知通过 WebSocketManager 的 HTTP 轮询刷新。
//

import SwiftUI
import Combine

@MainActor
final class MessagesViewModel: ObservableObject {
    @Published var messages: [MasterMessage] = []
    @Published var chats: [MasterBookingChatConversation] = []
    @Published var chatHasMore=false
    @Published var chatLoading=false
    private var chatPage=1
    private var chatQuery=""
    private var chatEpoch=0
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
            await self?.loadChats()
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

    func loadChats() async {
        let epoch=chatEpoch;chatLoading=true
        do {
            var list:[MasterBookingChatConversation]=[];var total:Int64=0
            for page in 1...chatPage {
                let response:MasterBookingChatListResponse=try await ChatNativeAPI.conversations(page:page,query:chatQuery)
                list+=response.list;total=response.total;if list.count>=total{break}
            }
            guard epoch==chatEpoch else{return}
            var seen=Set<String>();chats=list.filter{seen.insert($0.id).inserted};chatHasMore=chats.count<total;errorMessage=nil
        }catch{if epoch==chatEpoch{errorMessage=error.localizedDescription}}
        if epoch==chatEpoch{chatLoading=false}
    }
    func searchChats(_ query:String) async {chatQuery=query;chatPage=1;chatEpoch+=1;await loadChats()}
    func moreChats() async {guard chatHasMore && !chatLoading else{return};chatPage+=1;await loadChats()}

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
    @State private var chatSearch=""
    @ObservedObject private var chatNotifications=NativeChatNotifications.shared
    @StateObject private var viewModel = MessagesViewModel()
    @State private var selectedTab: Int = {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "--smoke-message-tab"), index + 1 < args.count,
           let tab = Int(args[index + 1]), (0...1).contains(tab) {
            return tab
        }
        #endif
        return 1
    }() // 0=通知, 1=咨询

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
        .task {
            await viewModel.load()
            await viewModel.loadChats()
        }
        .refreshable {
            await viewModel.load()
            await viewModel.loadChats()
        }
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
                    .font(AppTypography.body.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .textPrimary : .textTertiary)
                if badge > 0 {
                    Text("\(badge)")
                        .font(AppTypography.micro.weight(.semibold))
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
            AppMotion.perform { selectedTab = index }
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
                        noticeItem(message)
                            .contentShape(Rectangle())
                            .onTapGesture { Task { await viewModel.markRead(message) } }
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
                        .font(AppTypography.body.weight(.medium))
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
                    .font(AppTypography.caption)
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

    // MARK: - 已付费预约会话

    private var chatList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ChatNotificationPrompt()
                HStack {Image(systemName:"magnifyingglass");TextField("搜索姓名、服务或消息",text:$chatSearch)}
                    .font(AppTypography.body).padding(13).background(Color.bgTertiary,in:RoundedRectangle(cornerRadius:14)).padding(.horizontal,18).padding(.vertical,8)
                if viewModel.chats.isEmpty && !viewModel.isLoading {
                    EmptyState(icon: "bubble.left.slash",
                               title: "暂无咨询",
                               message: viewModel.errorMessage ?? "信众购买即时咨询或完成预约支付后，对话会显示在这里")
                        .padding(.top, 60)
                } else {
                    ForEach(viewModel.chats) { conversation in
                        NavigationLink {
                            ChatView(conversation: conversation)
                        } label: {
                            chatItem(conversation)
                        }
                        .buttonStyle(CardPressButtonStyle())
                    }
                }
            }
            .padding(.bottom, 70)
            if viewModel.chatHasMore {Button(viewModel.chatLoading ? "加载中…" : "加载更多会话"){Task{await viewModel.moreChats()}}.disabled(viewModel.chatLoading).padding()}
            if let error=viewModel.errorMessage {VStack{Text(error).font(.caption);Button("重试"){Task{await viewModel.loadChats()}}}.padding()}
        }
        .softScrollEdge(.bottom)
        .task(id:chatSearch){try? await Task.sleep(for:.milliseconds(300));guard !Task.isCancelled else{return};await viewModel.searchChats(chatSearch)}
    }

    private func chatItem(_ conversation: MasterBookingChatConversation) -> some View {
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
                    Text(conversation.peerName)
                        .font(AppTypography.body.weight(.medium))
                        .foregroundStyle(.textPrimary)
                    Spacer()
                    Text(DFDateFormatter.friendly(conversation.lastMessageAt))
                        .font(.micro)
                        .foregroundStyle(.textTertiary)
                }
                Text(conversation.lastMessage)
                    .font(AppTypography.caption)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if conversation.unreadCount>0 {Text(conversation.unreadCount>99 ? "99+" : String(conversation.unreadCount)).font(AppTypography.micro).foregroundStyle(.white).padding(5).background(Color.brandDefault,in:Capsule())}
            Image(systemName: "chevron.right")
                .font(AppTypography.caption)
                .foregroundStyle(.textTertiary)
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
