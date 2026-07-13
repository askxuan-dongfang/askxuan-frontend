//
//  ChatView.swift
//  DongFangApp
//
//  对话页：对齐产品原型 chat.html 布局。
//  顶部导航 + 三子 Tab（我的收藏/我的私聊/大师广场）+ 对应面板内容。
//  作为主 Tab 之一。
//

import SwiftUI
import AVKit

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var selectedTab: Int = 0
    @State private var searchText: String = ""
    @State private var liveRooms: [LiveRoom] = []

    private let tabTitles = ["我的收藏", "我的私聊", "大师广场"]

    // MARK: - Mock 数据
    private let followedMasters: [(id: String, name: String, temple: String, avatar: String, isOnline: Bool)] = [
        ("M001", "智海法师", "灵隐寺", "master-avatar-zhihai", true),
        ("M002", "清风道长", "白云观", "master-avatar-qingfeng", false),
        ("M003", "释延心法师", "少林寺", "master-avatar-shimingyuan", true),
        ("M004", "扎西多吉活佛", "大昭寺", "master-avatar-zhaxiduoji", false),
        ("M005", "慧明法师", "普陀山", "master-avatar-miaoyin", false),
        ("M006", "真武道长", "武当山", "master-avatar-zhangzhishun", true)
    ]

    private let callRecords: [(masterId: String, name: String, avatar: String, time: String, duration: String, isVideo: Bool)] = [
        ("M003", "扎西多吉", "master-avatar-zhaxiduoji", "12/18", "语音通话 12分35秒", false),
        ("M004", "智海法师", "master-avatar-zhihai", "12/15", "视频通话 25分18秒", true)
    ]

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
            Text("对话")
                .font(.custom(AppFont.serif[0], size: 17).weight(.bold))
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
            Text(connectionText)
                .font(.system(size: 10))
                .foregroundStyle(Color.textTertiary)
        }
    }

    private var connectionDotColor: Color {
        switch viewModel.connectionState {
        case .connected:    return Color.stateSuccess
        case .reconnecting: return Color.stateWarning
        case .disconnected: return Color.textTertiary
        }
    }

    private var connectionText: String {
        switch viewModel.connectionState {
        case .connected:    return "已连接"
        case .reconnecting: return "重连中"
        case .disconnected: return "未连接"
        }
    }

    // MARK: - 子 Tab
    private var subTabs: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabTitles.enumerated()), id: \.offset) { index, title in
                let isSelected = selectedTab == index
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = index
                    }
                } label: {
                    VStack(spacing: 0) {
                        Text(title)
                            .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
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
        case 0: favoritesPanel
        case 1: privatePanel
        default: plazaPanel
        }
    }

    // MARK: - Panel 1: 我的收藏
    private var favoritesPanel: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text("关注列表")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
                    .padding(.top, 12)
                    .padding(.bottom, 4)
                    .padding(.horizontal, AppSpacing.lg)

                ForEach(Array(followedMasters.enumerated()), id: \.offset) { _, master in
                    followItem(master)
                }
                Color.clear.frame(height: AppSpacing.navBottom)
            }
        }
    }

    private func followItem(_ master: (id: String, name: String, temple: String, avatar: String, isOnline: Bool)) -> some View {
        NavigationLink {
            MasterProfileView(masterId: master.id)
        } label: {
            HStack(spacing: 12) {
                RemoteAvatar(urlString: master.avatar, size: 48)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(master.name)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                        Text("已关注")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.brandDefault)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .overlay(Capsule().stroke(Color.brandDefault.opacity(0.4), lineWidth: 1))
                    }
                    Text(master.temple)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textTertiary)
                }

                Spacer()

                Circle()
                    .fill(master.isOnline ? Color.stateSuccess : Color.textTertiary.opacity(0.5))
                    .frame(width: 10, height: 10)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, 12)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.borderDivider).frame(height: 1).padding(.leading, AppSpacing.lg + 48 + 12)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Panel 2: 我的私聊
    private var privatePanel: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // 搜索栏
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textTertiary)
                    TextField("搜索对话", text: $searchText)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textPrimary)
                }
                .padding(.horizontal, 12)
                .frame(height: 36)
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

                // 通话记录
                ForEach(Array(callRecords.enumerated()), id: \.offset) { _, record in
                    callRecordRow(record)
                }
                Color.clear.frame(height: AppSpacing.navBottom)
            }
        }
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
                        .font(.system(size: 10, weight: .bold))
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
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Text(conversation.lastTime)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textTertiary)
                }
                Text(conversation.lastMessage)
                    .font(.system(size: 13))
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
            id: "call-\(record.masterId)",
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
                        Text(record.name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        Text(record.time)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textTertiary)
                    }
                    Text(record.duration)
                        .font(.system(size: 12))
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

@MainActor
private final class CommunityPlazaViewModel: ObservableObject {
    @Published var posts: [CommunityPost] = []
    @Published var message: String?

    func load() async {
        do {
            let response: CommunityPostListResponse = try await APIClient.shared.request(.communityFeed(type: nil, beliefCode: nil, page: 1, size: 30))
            posts = response.list
            message = nil
        } catch {
            message = error.localizedDescription
        }
    }
}

private struct CommunityPlazaView: View {
    let liveRooms: [LiveRoom]
    @StateObject private var viewModel = CommunityPlazaViewModel()
    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                ForEach(liveRooms) { room in
                    NavigationLink { LiveViewerView(room: room) } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "dot.radiowaves.left.and.right").foregroundStyle(Color.stateError)
                            Text(room.title).font(.subheadline.weight(.semibold)).foregroundStyle(Color.textPrimary)
                            Spacer()
                            Text("直播中").font(.caption).foregroundStyle(Color.stateError)
                        }
                        .padding(.horizontal, AppSpacing.lg)
                        .frame(height: 46)
                    }
                    .buttonStyle(.plain)
                }

                if !viewModel.posts.filter({ $0.type == "video" }).isEmpty {
                    NavigationLink { CommunityVideoFeedView(posts: viewModel.posts.filter { $0.type == "video" }) } label: {
                        Label("全屏视频", systemImage: "play.rectangle.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.horizontal, AppSpacing.lg)
                    }
                }

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(viewModel.posts) { post in
                        NavigationLink { CommunityPostDetailView(postId: post.id) } label: {
                            CommunityPostCard(post: post)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppSpacing.lg)

                if viewModel.posts.isEmpty, let message = viewModel.message {
                    ContentUnavailableView("内容加载失败", systemImage: "wifi.exclamationmark", description: Text(message))
                }
                Color.clear.frame(height: AppSpacing.navBottom)
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }
}

private struct CommunityPostCard: View {
    let post: CommunityPost
    @State private var media: MediaAsset?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Color.bgTertiary
                if let urlString = media?.coverUrl.isEmpty == false ? media?.coverUrl : media?.playbackUrl,
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

            Text(post.title).font(.subheadline.weight(.semibold)).foregroundStyle(Color.textPrimary).lineLimit(2)
            HStack {
                Text("大师 \(post.masterId)").font(.caption).foregroundStyle(Color.textTertiary).lineLimit(1)
                Spacer()
                Label("\(post.likeCount)", systemImage: "heart").font(.caption2).foregroundStyle(Color.textSecondary)
            }
        }
        .background(Color.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .task {
            let id = post.coverMediaId > 0 ? post.coverMediaId : (post.assets.first?.mediaId ?? 0)
            if id > 0 { media = try? await APIClient.shared.request(.mediaDetail(id)) }
        }
    }
}

private struct CommunityPostDetailView: View {
    let postId: String
    @State private var post: CommunityPost?
    @State private var comments: [CommunityComment] = []
    @State private var media: [Int64: MediaAsset] = [:]
    @State private var commentText = ""
    @State private var liked = false
    @State private var likeCount: Int64 = 0
    @State private var following = false
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

                    Text(post.title).font(.title3.weight(.bold)).foregroundStyle(Color.textPrimary)
                    Text(post.content).font(.body).foregroundStyle(Color.textSecondary)

                    HStack(spacing: 12) {
                        Button { Task { await toggleLike() } } label: {
                            Label("\(likeCount)", systemImage: liked ? "heart.fill" : "heart")
                        }
                        Button { Task { await toggleFollow() } } label: {
                            Label(following ? "已关注" : "关注大师", systemImage: following ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.plus")
                        }
                    }
                    .buttonStyle(.bordered)

                    Divider()
                    Text("评论").font(.headline)
                    HStack {
                        TextField("写下评论，审核通过后展示", text: $commentText, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                        Button { Task { await submitComment() } } label: { Image(systemName: "paperplane.fill") }
                            .buttonStyle(.borderedProminent)
                            .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    ForEach(comments) { comment in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(comment.content).foregroundStyle(Color.textPrimary)
                            Text("用户 \(comment.userId)").font(.caption).foregroundStyle(Color.textTertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                    }
                    if let message { Text(message).font(.caption).foregroundStyle(Color.stateWarning) }
                }
                .padding(AppSpacing.lg)
            } else if let message {
                ContentUnavailableView("内容暂不可用", systemImage: "doc.text.magnifyingglass", description: Text(message))
            } else {
                ProgressView().frame(maxWidth: .infinity).padding(.top, 80)
            }
        }
        .navigationTitle("大师广场")
        .task { await load() }
    }

    private func load() async {
        do {
            let detail: CommunityPost = try await APIClient.shared.request(.communityPostById(postId))
            post = detail
            liked = detail.liked
            likeCount = detail.likeCount
            for asset in detail.assets {
                media[asset.mediaId] = try? await APIClient.shared.request(.mediaDetail(asset.mediaId))
            }
            let response: CommunityCommentListResponse = try await APIClient.shared.request(.communityComments(postId: postId, page: 1, size: 50))
            comments = response.list
        } catch {
            message = error.localizedDescription
        }
    }

    private func toggleLike() async {
        do {
            let response: CommunityLikeResponse = try await APIClient.shared.request(liked ? .communityPostUnlike(postId) : .communityPostLike(postId))
            liked = response.liked
            likeCount = response.likeCount
        } catch { message = error.localizedDescription }
    }

    private func toggleFollow() async {
        guard let masterId = post?.masterId else { return }
        do {
            let response: CommunityFollowResponse = try await APIClient.shared.request(following ? .communityMasterUnfollow(masterId) : .communityMasterFollow(masterId))
            following = response.following
        } catch { message = error.localizedDescription }
    }

    private func submitComment() async {
        let content = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        do {
            let _: CommunityComment = try await APIClient.shared.request(.communityCommentCreate(postId: postId, .init(content: content)))
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
            } else { ProgressView() }
        }
    }
}

private struct CommunityVideoPlayer: View {
    let media: MediaAsset?
    var body: some View {
        if let media, media.status == "ready", let url = URL(string: media.playbackUrl), !media.playbackUrl.isEmpty {
            VideoPlayer(player: AVPlayer(url: url))
        } else {
            ContentUnavailableView("视频处理中", systemImage: "video.badge.clock")
        }
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
        .navigationTitle("视频")
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
                Text("大师 \(post.masterId)").font(.subheadline.weight(.semibold))
                Text(post.title).font(.headline)
                Label("\(post.likeCount)", systemImage: "heart.fill").font(.caption)
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
                Text(title).font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                Text("审核状态：\(media.auditStatus)").font(.caption).foregroundStyle(.secondary)
            } else if let message {
                ContentUnavailableView("视频暂不可用", systemImage: "video.slash", description: Text(message))
            } else {
                ProgressView()
            }
        }
        .padding()
        .navigationTitle("短视频")
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
                ContentUnavailableView("直播流暂不可用", systemImage: "video.slash")
            }
            HStack {
                TextField("发送群聊消息", text: $chatText)
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
            if !sendState.isEmpty { Text(sendState).font(.caption).foregroundStyle(.secondary) }
        }
        .padding()
        .navigationTitle(room.title)
    }
}

#Preview {
    NavigationStack { ChatView() }
        .preferredColorScheme(.dark)
}
