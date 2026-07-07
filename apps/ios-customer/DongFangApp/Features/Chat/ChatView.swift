//
//  ChatView.swift
//  DongFangApp
//
//  对话页：对齐产品原型 chat.html 布局。
//  顶部导航 + 三子 Tab（我的收藏/我的私聊/大师广场）+ 对应面板内容。
//  作为主 Tab 之一。
//

import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var selectedTab: Int = 0
    @State private var searchText: String = ""

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

    private let videoFeed: [(masterId: String, master: String, avatar: String, desc: String, likes: String, comments: String)] = [
        ("M001", "智海法师", "master-avatar-zhihai", "禅修入门：观呼吸法门 | 三分钟学会止观", "2.3万", "186"),
        ("M003", "释延心法师", "master-avatar-shimingyuan", "少林禅武合一演示", "5.1万", "892"),
        ("M002", "清风道长", "master-avatar-qingfeng", "道家内丹术基础讲解", "9686", "156"),
        ("M004", "扎西多吉活佛", "master-avatar-zhaxiduoji", "藏密灌顶加持法会纪实", "3.4万", "445"),
        ("M005", "慧明法师", "master-avatar-miaoyin", "净土念佛法门开示", "1.2万", "267")
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

    // MARK: - Panel 3: 大师广场（视频信息流）
    private var plazaPanel: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(Array(videoFeed.enumerated()), id: \.offset) { _, video in
                    videoCard(video)
                }
                Color.clear.frame(height: AppSpacing.navBottom)
            }
        }
    }

    private func videoCard(_ video: (masterId: String, master: String, avatar: String, desc: String, likes: String, comments: String)) -> some View {
        NavigationLink {
            MasterProfileView(masterId: video.masterId)
        } label: {
            ZStack(alignment: .bottom) {
                // 视频缩略图占位
                LinearGradient(
                    colors: [Color.bgTertiary, Color.bgSecondary],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity)

                // 播放图标
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.white.opacity(0.8))
                    .frame(maxHeight: .infinity)

                // 底部信息覆盖层
                VStack(alignment: .leading, spacing: 10) {
                    // 法师信息行
                    HStack(spacing: 10) {
                        RemoteAvatar(urlString: video.avatar, size: 36)
                        Text(video.master)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        Text("关注")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 4)
                            .background(Color.brandDefault)
                            .clipShape(Capsule())
                    }

                    // 描述
                    Text(video.desc)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    // 互动栏
                    HStack(spacing: 20) {
                        interactionItem(icon: "heart", text: video.likes)
                        interactionItem(icon: "message", text: video.comments)
                        interactionItem(icon: "square.and.arrow.up", text: "分享")
                    }
                }
                .padding(16)
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0.75), Color.black.opacity(0.3), Color.clear],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
            }
            .frame(maxWidth: .infinity)
            .clipped()
        }
        .buttonStyle(.plain)
    }

    private func interactionItem(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color.textPrimary)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)
        }
    }
}

#Preview {
    NavigationStack { ChatView() }
        .preferredColorScheme(.dark)
}
