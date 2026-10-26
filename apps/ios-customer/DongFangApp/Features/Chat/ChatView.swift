//
//  ChatView.swift
//  DongFangApp
//
//  对话页：会话列表与即时通信入口。
//  顶部导航 + 三子 Tab（我的收藏/我的私聊/大师广场）+ 对应面板内容。
//  作为主 Tab 之一。
//

import SwiftUI
import AVKit

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var selectedTab: Int = {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "--smoke-chat-tab"), index + 1 < args.count,
           let tab = Int(args[index + 1]), (0...2).contains(tab) {
            return tab
        }
        #endif
        return 1
    }()
    @State private var unreadOnly = false
    @State private var searchText: String = ""
    @ObservedObject private var chatNotifications=NativeChatNotifications.shared
    @State private var liveRooms: [LiveRoom] = []

    private let tabTitles = ["我的收藏", "我的私聊", "大师广场"]

    init(initialTab: Int? = nil) {
        if let initialTab, (0...2).contains(initialTab) { _selectedTab = State(initialValue: initialTab) }
    }

    var body: some View {
        VStack(spacing: 0) {
            topNav
            subTabs
            panelContent
        }
        .background(Color.bgPrimary)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if viewModel.conversations.isEmpty {
                await viewModel.loadConversations()
            }
            await viewModel.loadUnreadCount()
            if let response: LiveRoomListResponse = try? await APIClient.shared.request(.liveRooms(masterId: nil, limit: 10)) {
                liveRooms = response.list
            }
        }
        .refreshable {
            if selectedTab == 1 {
                await viewModel.loadConversations()
            }
        }
        .navigationDestination(for: ChatConversation.self) { conversation in
            ChatDetailView(conversation: conversation, viewModel: viewModel)
        }
    }

    // MARK: - 顶部导航
    private var topNav: some View {
        ZStack {
            Text(L10n.text("对话"))
                .font(AppTypography.title(17))
                .foregroundStyle(Color.accentDefault)

            HStack(spacing: 6) {
                Spacer()
                connectionIndicator
            }
            .padding(.horizontal, AppSpacing.lg)
        }
        .frame(height: AppSpacing.navTop)
        .frame(maxWidth: .infinity)
        .background(Color.bgPrimary.opacity(0.92).background(.ultraThinMaterial))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.borderDivider).frame(height: 1)
        }
    }

    /// 实时连接状态指示（已连接 / 重连中 / 未连接）
    private var connectionIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(connectionDotColor)
                .frame(width: 6, height: 6)
            Text(L10n.lookup(connectionText))
                .font(AppTypography.micro)
                .foregroundStyle(Color.textTertiary)
        }
    }

    private var connectionDotColor: Color {
        switch viewModel.connectionState {
        case .connected:    return Color.stateSuccess
        case .connecting:   return Color.stateWarning
        case .disconnected: return Color.textTertiary
        }
    }

    private var connectionText: String {
        switch viewModel.connectionState {
        case .connected:    return "已连接"
        case .connecting:   return "连接中"
        case .disconnected: return "未连接"
        }
    }

    // MARK: - 子 Tab
    private var subTabs: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabTitles.enumerated()), id: \.offset) { index, title in
                let isSelected = selectedTab == index
                Button {
                    AppMotion.perform {
                        selectedTab = index
                    }
                } label: {
                    VStack(spacing: 0) {
                        Text(L10n.lookup(title + (index == 1 && chatNotifications.chatUnread > 0 ? " · \(chatNotifications.chatUnread)" : "")))
                            .font(AppTypography.body.weight(isSelected ? .semibold : .medium))
                            .foregroundStyle(isSelected ? Color.brandDefault : Color.textTertiary)
                        Capsule()
                            .fill(isSelected ? Color.brandDefault : Color.clear)
                            .frame(width: 28, height: 3)
                            .padding(.top, 10)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.bgPrimary.opacity(0.85).background(.ultraThinMaterial))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.borderDivider).frame(height: 1)
        }
    }

    // MARK: - 面板内容
    @ViewBuilder
    private var panelContent: some View {
        switch selectedTab {
        case 0: ChatFavoritesPanel()
        case 1: privatePanel
        default: plazaPanel
        }
    }

    // MARK: - Panel 2: 我的私聊
    private var privatePanel: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ChatNotificationPrompt()
                // 搜索栏
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(AppTypography.body)
                        .foregroundStyle(Color.textTertiary)
                    TextField(L10n.text("搜索姓名、服务或消息"), text: $searchText)
                        .font(AppTypography.body)
                        .foregroundStyle(Color.textPrimary)
                    Button { unreadOnly.toggle() } label: {
                        Text(L10n.text("未读")).font(AppTypography.caption.weight(.medium)).foregroundStyle(unreadOnly ? Color.brandDefault : Color.textSecondary).frame(minWidth: 44, minHeight: 44)
                    }.buttonStyle(.plain).accessibilityAddTraits(unreadOnly ? .isSelected : [])
                }
                .padding(.horizontal, 12)
                .frame(height: 48)
                .background(Color.bgSecondary)
                .cornerRadius(18)
                .overlay(Capsule().stroke(Color.borderDefault, lineWidth: 1))
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, 10)
                .padding(.bottom, 6)

                // 会话列表
                ForEach(viewModel.conversations) { conversation in
                    NavigationLink(value: conversation) {
                        conversationRow(conversation)
                    }
                    .buttonStyle(.plain)
                }

                if viewModel.hasMoreConversations {
                    Button(L10n.lookup(viewModel.loadingMoreConversations ? L10n.text("加载中…") : L10n.text("加载更多会话"))) {Task{await viewModel.loadMoreConversations()}}
                        .disabled(viewModel.loadingMoreConversations).padding(18)
                }
                if let error=viewModel.errorMessage {
                    VStack{Text(L10n.lookup(error)).font(.caption);Button(L10n.text("重试")){Task{await viewModel.loadConversations()}}}.padding(16)
                }
                if viewModel.conversations.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(
                        L10n.text("暂无可用私聊"),
                        systemImage: "bubble.left.and.exclamationmark.bubble.right",
                        description: Text(L10n.lookup(viewModel.errorMessage ?? L10n.text("预约并完成支付后，可在这里与对应法师沟通")))
                    )
                    .padding(.top, 48)
                }
                if !viewModel.isLoading && viewModel.errorMessage == nil {
                    VStack(spacing: 6) {
                        Text(L10n.text("每一次对话，都有回应")).font(AppTypography.caption)
                        Text(L10n.text("\(viewModel.conversationTotal) 个会话")).font(AppTypography.micro)
                    }
                    .foregroundStyle(Color.textSecondary)
                    .padding(.top, 24)
                }
                Color.clear.frame(height: AppSpacing.navBottom)
            }
        }
        .task(id:searchText + "|" + String(unreadOnly)){try? await Task.sleep(for:.milliseconds(300));guard !Task.isCancelled else{return};await viewModel.searchConversations(searchText, unreadOnly: unreadOnly)}
        .refreshable{await viewModel.loadConversations()}
    }

    private func conversationRow(_ conversation: ChatConversation) -> some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                RemoteAvatar(urlString: conversation.masterAvatar, size: 52)
                Circle()
                    .fill(conversation.isOnline ? Color.stateSuccess : Color.textTertiary.opacity(0.5))
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Color.bgPrimary, lineWidth: 2))
                    .offset(x: -2, y: -2)
            }
            .overlay(alignment: .topTrailing) {
                if conversation.unreadCount > 0 {
                    Text("\(conversation.unreadCount)")
                        .font(AppTypography.micro.weight(.semibold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 4)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(Color.brandDefault)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.bgPrimary, lineWidth: 2))
                        .offset(x: 4, y: -4)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(conversation.masterName)
                        .font(AppTypography.body.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Text(L10n.lookup(conversation.lastTime))
                        .font(AppTypography.caption)
                        .foregroundStyle(Color.textTertiary)
                }
                Text(L10n.lookup(conversation.lastMessage))
                    .font(AppTypography.supporting)
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.borderDivider).frame(height: 1).padding(.leading, AppSpacing.lg + 52 + 12)
        }
    }

    private func callRecordRow(_ record: (masterId: String, name: String, avatar: String, time: String, duration: String, isVideo: Bool)) -> some View {
        let conversation = ChatConversation(
            bookingId: "call-\(record.masterId)",
            masterId: record.masterId,
            masterName: record.name,
            masterAvatar: record.avatar,
            templeName: "",
            lastMessage: record.duration,
            lastTime: record.time,
            unreadCount: 0,
            isOnline: false
        )
        return NavigationLink {
            ChatDetailView(conversation: conversation, viewModel: viewModel)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(record.isVideo ? Color.brandDefault.opacity(0.15) : Color.stateSuccess.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: record.isVideo ? "video.fill" : "phone.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(record.isVideo ? Color.brandDefault : Color.stateSuccess)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(L10n.lookup(record.name))
                            .font(AppTypography.body.weight(.semibold))
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        Text(L10n.lookup(record.time))
                            .font(AppTypography.caption)
                            .foregroundStyle(Color.textTertiary)
                    }
                    Text(L10n.lookup(record.duration))
                        .font(AppTypography.caption)
                        .foregroundStyle(Color.textTertiary)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, 14)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.borderDivider).frame(height: 1).padding(.leading, AppSpacing.lg + 52 + 12)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Panel 3: 大师广场
    private var plazaPanel: some View {
        CommunityPlazaView(liveRooms: liveRooms)
    }
}

private struct ChatFavoritesPanel: View {
    @State private var masters: [Master] = []
    @State private var isLoading = false
    @State private var message: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                if isLoading && masters.isEmpty {
                    ProgressView(L10n.text("正在加载关注"))
                        .tint(Color.accentDefault)
                        .padding(.top, 48)
                } else if masters.isEmpty {
                    ContentUnavailableView(
                        L10n.text("还没有关注的大师"),
                        systemImage: "heart",
                        description: Text(L10n.lookup(message ?? L10n.text("在大师主页关注后，会显示在这里")))
                    )
                    .padding(.top, 48)
                } else {
                    ForEach(masters) { master in
                        NavigationLink {
                            MasterProfileView(masterId: master.id)
                        } label: {
                            HStack(spacing: 12) {
                                RemoteAvatar(urlString: master.avatar, size: 48)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(L10n.lookup(master.dharmaName))
                                        .font(AppTypography.body.weight(.semibold))
                                        .foregroundStyle(Color.textPrimary)
                                    Text(master.templeName.isEmpty ? L10n.text("独立大师") : master.templeName)
                                        .font(AppTypography.caption)
                                        .foregroundStyle(Color.textTertiary)
                                }
                                Spacer()
                                Text(L10n.text("已关注"))
                                    .font(AppTypography.micro)
                                    .foregroundStyle(Color.accentDefault)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .overlay(Capsule().stroke(Color.accentDefault.opacity(0.45), lineWidth: 1))
                            }
                            .padding(.horizontal, AppSpacing.lg)
                            .padding(.vertical, 12)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(Color.borderDivider).frame(height: 1).padding(.leading, 76)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                Color.clear.frame(height: AppSpacing.navBottom)
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    @MainActor
    private func load() async {
        isLoading = true
        message = nil
        defer { isLoading = false }
        do {
            let response: FollowedMastersResponse = try await APIClient.shared.request(.communityMyFollowing)
            masters = await withTaskGroup(of: (String, Master?).self) { group in
                for id in response.list {
                    group.addTask {
                        let master: Master? = try? await APIClient.shared.request(.masterById(id))
                        return (id, master)
                    }
                }
                var values: [String: Master] = [:]
                for await (id, master) in group where master != nil { values[id] = master }
                return response.list.compactMap { values[$0] }
            }
        } catch {
            if (error as? APIError)?.isCancellation == true || error is CancellationError { return }
            message = error.localizedDescription
        }
    }
}

@MainActor
private final class CommunityPlazaViewModel: ObservableObject {
    @Published var posts: [CommunityPost] = []
    @Published var message: String?
    @Published var loading = false
    @Published var total: Int64 = 0
    var filter = "all"; var keyword = ""; var sort = "latest"
    private var page = 1; private var generation = 0
    func load(more: Bool = false) async {
        if more && loading { return }
        generation += 1; let current = generation; loading = true; message = nil
        if !more { posts = []; page = 1; total = 0 }
        let next = more ? page + 1 : 1
        do {
            let response: CommunityPostListResponse = try await APIClient.shared.request(.communityFeed(type: ["article", "video"].contains(filter) ? filter : nil, beliefCode: nil, page: next, size: 20, following: filter == "following", keyword: keyword, sort: sort))
            guard current == generation else { return }
            let known = Set(posts.map(\.id)); posts = more ? posts + response.list.filter { !known.contains($0.id) } : response.list
            total = response.total; page = next
        } catch { if current == generation { message = error.localizedDescription } }
        if current == generation { loading = false }
    }
}

private struct CommunityPlazaView: View {
    let liveRooms: [LiveRoom]
    @StateObject private var viewModel = CommunityPlazaViewModel()
    @State private var filter = "all"
    @State private var keyword = ""
    @State private var popular = false
    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) { Text(L10n.text("在这里，看见另一种生活")).font(AppTypography.section).foregroundStyle(Color.textPrimary) }.padding(.top, 12)
                Picker(L10n.text("内容分类"), selection: $filter) { Text(L10n.text("发现")).tag("all"); Text(L10n.text("关注")).tag("following"); Text(L10n.text("图文")).tag("article"); Text(L10n.text("视频")).tag("video") }.pickerStyle(.segmented)
                HStack { TextField(L10n.text("搜索广场内容"), text: $keyword).onSubmit { refresh() }; Button(L10n.text("搜索")) { refresh() } }.padding(12).background(Color.bgSecondary).clipShape(Capsule())
                HStack { Spacer(); Button(L10n.lookup(popular ? L10n.text("热门 ↓") : L10n.text("最新 ↓"))) { popular.toggle(); refresh() }.font(.caption) }
                ForEach(liveRooms.filter { $0.status == "live" }) { room in NavigationLink { LiveViewerView(room: room) } label: { Label(L10n.lookup(room.title + L10n.text(" · 直播中")), systemImage: "dot.radiowaves.left.and.right").font(.subheadline).foregroundStyle(Color.stateError) } }
                if viewModel.posts.contains(where: { $0.type == "video" }) { NavigationLink { CommunityVideoFeedView(posts: viewModel.posts.filter { $0.type == "video" }) } label: { Label(L10n.text("沉浸浏览视频"), systemImage: "play.rectangle.fill").font(.subheadline) } }
                LazyVGrid(columns: columns, spacing: 12) { ForEach(viewModel.posts) { post in NavigationLink { CommunityPostDetailView(postId: post.id) } label: { CommunityPostCard(post: post) }.buttonStyle(.plain) } }
                if let message = viewModel.message { Text(L10n.lookup(message)).font(.footnote).foregroundStyle(Color.stateWarning); Button(L10n.text("重新加载")) { refresh() } }
                if viewModel.loading { ProgressView().frame(maxWidth: .infinity) }
                else if viewModel.posts.isEmpty && viewModel.message == nil { ContentUnavailableView(filter == "following" ? L10n.text("关注之后，好内容在这里相遇") : L10n.text("新的分享，正在路上"), systemImage: "leaf", description: Text(L10n.text("可以换个分类看看，或稍后刷新。"))) }
                else if Int64(viewModel.posts.count) < viewModel.total { Button(L10n.text("加载更多内容")) { Task { await viewModel.load(more: true) } }.frame(maxWidth: .infinity) }
                Color.clear.frame(height: AppSpacing.navBottom)
            }.padding(.horizontal, AppSpacing.lg)
        }.task { await viewModel.load() }.refreshable { await viewModel.load() }.onChange(of: filter) { _, _ in refresh() }
    }
    private func refresh() { viewModel.filter = filter; viewModel.keyword = String(keyword.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80)); viewModel.sort = popular ? "popular" : "latest"; Task { await viewModel.load() } }
}

private struct CommunityPostCard: View {
    let post: CommunityPost
    @State private var media: MediaAsset?
    @State private var author: Master?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Color.bgTertiary
                if let urlString = post.coverUrl ?? (post.type == "video" ? media?.coverUrl : media?.playbackUrl), !urlString.isEmpty,
                   let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { ProgressView() }
                } else {
                    Image(systemName: post.type == "video" ? "video" : "photo.on.rectangle")
                        .font(.title2).foregroundStyle(Color.textTertiary)
                }
                if post.type == "video" {
                    Image(systemName: "play.circle.fill").font(.title).foregroundStyle(.white)
                }
            }
            .frame(height: post.type == "video" ? 210 : 150)
            .clipped()

            Text(L10n.lookup(post.title)).font(.subheadline.weight(.semibold)).foregroundStyle(Color.textPrimary).lineLimit(2)
            HStack {
                Text(L10n.lookup(author?.dharmaName ?? L10n.text("广场作者"))).font(AppTypography.caption).foregroundStyle(Color.textTertiary).lineLimit(1)
                Spacer()
                Label("\(post.likeCount)", systemImage: post.liked ? "heart.fill" : "heart").font(.caption2).foregroundStyle(Color.textSecondary)
            }
        }
        .background(Color.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task {
            author = try? await APIClient.shared.request(.masterById(post.masterId))
            let id = post.coverMediaId > 0 ? post.coverMediaId : (post.assets.first?.mediaId ?? 0)
            if id > 0 { media = try? await APIClient.shared.request(.mediaDetail(id)) }
        }
    }
}

struct CommunityPostDetailView: View {
    let postId: String
    @State private var post: CommunityPost?
    @State private var comments: [CommunityComment] = []
    @State private var media: [Int64: MediaAsset] = [:]
    @State private var commentText = ""
    @State private var liked = false
    @State private var likeCount: Int64 = 0
    @State private var following = false
    @State private var busy = false
    @State private var commentsPage = 1
    @State private var commentsTotal: Int64 = 0
    @State private var author: Master?
    @State private var message: String?

    var body: some View {
        ScrollView {
            if let post {
                VStack(alignment: .leading, spacing: 16) {
                    if post.type == "video", let asset = post.assets.first(where: { $0.assetType == "video" }) {
                        CommunityVideoPlayer(media: media[asset.mediaId])
                            .frame(height: 480)
                    } else {
                        TabView {
                            ForEach(post.assets.filter { $0.assetType == "image" }) { asset in
                                CommunityImage(media: media[asset.mediaId])
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .automatic))
                        .frame(height: 360)
                    }

                    NavigationLink { MasterProfileView(masterId: post.masterId) } label: { Label(L10n.lookup(author?.dharmaName ?? L10n.text("广场作者")), systemImage: "person.crop.circle").font(.subheadline) }
                    Text(L10n.lookup(post.title)).font(AppTypography.section).foregroundStyle(Color.textPrimary)
                    Text(post.content).font(AppTypography.body).foregroundStyle(Color.textSecondary)

                    HStack(spacing: 12) {
                        Button { Task { await toggleLike() } } label: {
                            Label("\(likeCount)", systemImage: liked ? "heart.fill" : "heart")
                        }
                        Button { Task { await toggleFollow() } } label: {
                            Label(L10n.lookup(following ? L10n.text("已关注") : L10n.text("关注大师")), systemImage: following ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.plus")
                        }
                    }
                    .buttonStyle(SecondaryActionButtonStyle()).disabled(busy)

                    Divider()
                    Text(L10n.text("评论 · \(commentsTotal)")).font(.headline)
                    HStack {
                        TextField(L10n.text("写下评论，审核通过后展示"), text: $commentText, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                        Button { Task { await submitComment() } } label: { Image(systemName: "paperplane.fill") }
                            .buttonStyle(.borderedProminent)
                            .disabled(busy || commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || commentText.count > 500)
                    }
                    ForEach(comments) { comment in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(comment.content).foregroundStyle(Color.textPrimary)
                            Text(L10n.lookup(comment.status == "pending" ? L10n.text("我 · 待审核，仅自己可见") : L10n.text("同修"))).font(AppTypography.caption).foregroundStyle(Color.textTertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                    }
                    if comments.filter({ $0.status == "approved" }).count < commentsTotal { Button(L10n.text("查看更多评论")) { Task { await loadMoreComments() } }.disabled(busy) }
                    if let message { Text(L10n.lookup(message)).font(AppTypography.caption).foregroundStyle(Color.stateWarning) }
                }
                .padding(AppSpacing.lg)
            } else if let message {
                ContentUnavailableView(L10n.text("内容暂不可用"), systemImage: "doc.text.magnifyingglass", description: Text(L10n.lookup(message)))
            } else {
                ProgressView().frame(maxWidth: .infinity).padding(.top, 80)
            }
        }
        .navigationTitle(L10n.text("大师广场"))
        .task { await load() }
    }

    private func load() async {
        do {
            let detail: CommunityPost = try await APIClient.shared.request(.communityPostById(postId))
            post = detail
            liked = detail.liked
            following = detail.following ?? false
            author = try? await APIClient.shared.request(.masterById(detail.masterId))
            likeCount = detail.likeCount
            for asset in detail.assets {
                media[asset.mediaId] = try? await APIClient.shared.request(.mediaDetail(asset.mediaId))
            }
            let response: CommunityCommentListResponse = try await APIClient.shared.request(.communityComments(postId: postId, page: 1, size: 20))
            comments = response.list; commentsTotal = response.total; commentsPage = 1
        } catch {
            message = error.localizedDescription
        }
    }

    private func toggleLike() async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do {
            let response: CommunityLikeResponse = try await APIClient.shared.request(liked ? .communityPostUnlike(postId) : .communityPostLike(postId))
            liked = response.liked
            likeCount = response.likeCount
        } catch { message = error.localizedDescription }
    }

    private func toggleFollow() async {
        guard !busy, let masterId = post?.masterId else { return }; busy = true; defer { busy = false }
        do {
            let response: CommunityFollowResponse = try await APIClient.shared.request(following ? .communityMasterUnfollow(masterId) : .communityMasterFollow(masterId))
            following = response.following
        } catch { message = error.localizedDescription }
    }

    private func loadMoreComments() async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do { let response: CommunityCommentListResponse = try await APIClient.shared.request(.communityComments(postId: postId, page: commentsPage + 1, size: 20)); let known = Set(comments.map(\.id)); comments += response.list.filter { !known.contains($0.id) }; commentsTotal = response.total; commentsPage += 1 } catch { message = error.localizedDescription }
    }

    private func submitComment() async {
        let content = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !busy, !content.isEmpty, content.count <= 500 else { return }; busy = true; defer { busy = false }
        do {
            let created: CommunityComment = try await APIClient.shared.request(.communityCommentCreate(postId: postId, .init(content: content)))
            comments.insert(created, at: 0)
            commentText = ""
            message = "评论已提交，审核通过后展示"
        } catch { message = error.localizedDescription }
    }
}

private struct CommunityImage: View {
    let media: MediaAsset?
    var body: some View {
        ZStack {
            Color.bgTertiary
            if let media, let url = URL(string: media.playbackUrl), !media.playbackUrl.isEmpty {
                AsyncImage(url: url) { image in image.resizable().scaledToFit() } placeholder: { ProgressView() }
            } else { ContentUnavailableView(L10n.text("图片暂不可用"), systemImage: "photo") }
        }
    }
}

private struct CommunityVideoPlayer: View {
    let media: MediaAsset?
    @State private var player: AVPlayer?
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        Group { if let player { VideoPlayer(player: player) } else { ContentUnavailableView(L10n.text("视频暂不可播放"), systemImage: "video.slash") } }
        .task(id: media?.playbackUrl) { player?.pause(); player = nil; if let media, media.status == "ready", !media.playbackUrl.isEmpty, let url = URL(string: media.playbackUrl) { player = AVPlayer(url: url) } }
        .onDisappear { player?.pause() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { player?.pause() } }
    }
}

private struct CommunityVideoFeedView: View {
    let posts: [CommunityPost]
    var body: some View {
        GeometryReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(posts) { post in
                        CommunityVideoPage(post: post)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.paging)
        }
        .background(.black)
        .navigationTitle(L10n.text("视频"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CommunityVideoPage: View {
    let post: CommunityPost
    @State private var media: MediaAsset?
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CommunityVideoPlayer(media: media)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.text("大师 \(post.masterId)")).font(.subheadline.weight(.semibold))
                Text(L10n.lookup(post.title)).font(.headline)
                Label("\(post.likeCount)", systemImage: "heart.fill").font(AppTypography.caption)
            }
            .foregroundStyle(.white)
            .padding(20)
            .background(.black.opacity(0.45))
        }
        .task {
            if let id = post.assets.first(where: { $0.assetType == "video" })?.mediaId {
                media = try? await APIClient.shared.request(.mediaDetail(id))
            }
        }
    }
}

private struct MediaPlaybackView: View {
    let mediaId: Int64
    let title: String
    @State private var media: MediaAsset?
    @State private var message: String?

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            if let media, media.status == "ready", let url = URL(string: media.playbackUrl), !media.playbackUrl.isEmpty {
                VideoPlayer(player: AVPlayer(url: url))
                    .aspectRatio(9 / 16, contentMode: .fit)
                Text(L10n.lookup(title)).font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                Text(L10n.text("审核状态：\(media.auditStatus)")).font(AppTypography.caption).foregroundStyle(.secondary)
            } else if let message {
                ContentUnavailableView(L10n.text("视频暂不可用"), systemImage: "video.slash", description: Text(L10n.lookup(message)))
            } else {
                ProgressView()
            }
        }
        .padding()
        .navigationTitle(L10n.text("短视频"))
        .task {
            do {
                media = try await APIClient.shared.request(.mediaDetail(mediaId))
            } catch {
                message = error.localizedDescription
            }
        }
    }
}

private struct LiveViewerView: View {
    let room: LiveRoom
    @State private var chatText = ""
    @State private var sendState = ""

    var body: some View {
        VStack(spacing: 12) {
            if let url = URL(string: room.watchUrl), !room.watchUrl.isEmpty {
                VideoPlayer(player: AVPlayer(url: url))
                    .aspectRatio(9 / 16, contentMode: .fit)
            } else {
                ContentUnavailableView(L10n.text("直播流暂不可用"), systemImage: "video.slash")
            }
            HStack {
                TextField(L10n.text("发送群聊消息"), text: $chatText)
                    .textFieldStyle(.roundedBorder)
                Button {
                    let text = chatText
                    OpenIMManager.shared.sendGroupMessage(text: text, groupID: room.openimGroupId) { success in
                        sendState = success ? "已发送" : "发送失败"
                        if success { chatText = "" }
                    }
                } label: {
                    Image(systemName: "paperplane.fill")
                }
                .disabled(chatText.isEmpty || room.openimGroupId.isEmpty)
            }
            if !sendState.isEmpty { Text(L10n.lookup(sendState)).font(AppTypography.caption).foregroundStyle(.secondary) }
        }
        .padding()
        .navigationTitle(L10n.lookup(room.title))
    }
}

#Preview {
    NavigationStack { ChatView() }
        .preferredColorScheme(.dark)
}
