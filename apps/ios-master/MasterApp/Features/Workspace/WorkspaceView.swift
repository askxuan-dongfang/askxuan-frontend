//
//  WorkspaceView.swift
//  MasterApp
//
//  工作台首页（页面 1）。
//  今日待办 + 数据统计 + 快捷入口：并发拉取待确认预约、待接单加持任务、收益概览。
//

import SwiftUI
import PhotosUI
import AVKit

@MainActor
final class WorkspaceViewModel: ObservableObject {
    @Published var allBookings: [Booking] = []
    @Published var pendingBookings: [Booking] = []
    @Published var assignedTasks: [BlessingTask] = []
    @Published var earnings: EarningsSummary?
    @Published var reviewTotal: Int64 = 0
    @Published var positiveReviewTotal: Int64 = 0

    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    /// 待办总数
    var todoCount: Int { pendingBookings.count + assignedTasks.count }
    var todayBookings: [Booking] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        return allBookings.filter { $0.bookingDate == today }
    }
    var monthBookingCount: Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let month = formatter.string(from: Date())
        return allBookings.filter { $0.bookingDate.hasPrefix(month) }.count
    }
    var positiveReviewRate: Double {
        guard reviewTotal > 0 else { return 0 }
        return Double(positiveReviewTotal) / Double(reviewTotal) * 100
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        async let bookingsResult = fetchBookings()
        async let tasksResult = fetchBlessingTasks()
        async let earningsResult = fetchEarnings()
        async let reviewsResult = fetchReviewStats()

        let (b, t, e, r) = await (bookingsResult, tasksResult, earningsResult, reviewsResult)

        switch b {
        case .success(let list):
            self.allBookings = list
            self.pendingBookings = list.filter { $0.statusEnum == .pending }
        case .failure:
            self.allBookings = []
            self.pendingBookings = []
        }
        switch t {
        case .success(let list): self.assignedTasks = list
        case .failure: self.assignedTasks = []
        }
        switch e {
        case .success(let summary): self.earnings = summary
        case .failure: self.earnings = nil
        }
        switch r {
        case .success(let stats):
            self.reviewTotal = stats.total
            self.positiveReviewTotal = stats.positive
        case .failure:
            self.reviewTotal = 0
            self.positiveReviewTotal = 0
        }

        isLoading = false
    }

    private func fetchBookings() async -> Result<[Booking], Error> {
        do {
            let resp: BookingListResponse = try await apiClient.request(
                .masterBookings(status: nil, page: 1, size: 100)
            )
            return .success(resp.list)
        } catch { return .failure(error) }
    }

    private func fetchBlessingTasks() async -> Result<[BlessingTask], Error> {
        do {
            let resp: BlessingTaskListResponse = try await apiClient.request(
                .blessingTasks(status: BlessingTaskStatus.assigned.rawValue, page: 1, size: 50)
            )
            return .success(resp.list)
        } catch { return .failure(error) }
    }

    private func fetchEarnings() async -> Result<EarningsSummary, Error> {
        do {
            let summary: EarningsSummary = try await apiClient.request(.earningsSummary)
            return .success(summary)
        } catch { return .failure(error) }
    }

    private func fetchReviewStats() async -> Result<(total: Int64, positive: Int64), Error> {
        do {
            async let all: ReviewListResponse = apiClient.request(.masterReviews(rating: nil, page: 1, size: 1))
            async let four: ReviewListResponse = apiClient.request(.masterReviews(rating: 4, page: 1, size: 1))
            async let five: ReviewListResponse = apiClient.request(.masterReviews(rating: 5, page: 1, size: 1))
            let values = try await (all, four, five)
            return .success((values.0.total, values.1.total + values.2.total))
        } catch { return .failure(error) }
    }
}

private struct WorkspaceStat {
    let value: String
    let label: String
    let highlight: Bool
}

private struct QuickAction {
    let icon: String
    let label: String
}

struct WorkspaceView: View {
    @StateObject private var viewModel = WorkspaceViewModel()
    @EnvironmentObject private var authStore: AuthStore

    private let quickActions: [QuickAction] = [
        QuickAction(icon: "calendar", label: "设置日程"),
        QuickAction(icon: "clock", label: "休息请假"),
        QuickAction(icon: "person", label: "个人主页"),
        QuickAction(icon: "yensign", label: "收入提现")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                greetingSection
                statsRow
                quickActionsSection
                mediaStudioSection
                todayBookingsSection
                blessingTaskSection
            }
            .padding(.bottom, 70)
        }
        .softScrollEdge(.bottom)
        .background(Color.bgPrimary)
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private var mediaStudioSection: some View {
        NavigationLink {
            MediaStudioView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "video.badge.plus")
                    .font(.system(size: 20))
                    .foregroundStyle(.accentDefault)
                VStack(alignment: .leading, spacing: 3) {
                    Text("内容与直播")
                        .font(.headline)
                        .foregroundStyle(.textPrimary)
                    Text("上传短视频并管理直播状态")
                        .font(.caption)
                        .foregroundStyle(.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.textTertiary)
            }
            .padding(AppSpacing.lg)
            .background(Color.bgSecondary)
            .overlay(RoundedRectangle(cornerRadius: AppRadius.md).stroke(Color.borderDefault))
            .cornerRadius(AppRadius.md)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, AppSpacing.pageHorizontal)
        .padding(.bottom, AppSpacing.lg)
    }

    // MARK: - 问候区

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("阿弥陀佛，\(authStore.nickname ?? "智海法师")")
                .font(.pageTitle)
                .foregroundStyle(.textPrimary)
            Text("今日有 \(viewModel.pendingBookings.count) 个预约待处理，\(viewModel.assignedTasks.count) 个加持任务")
                .font(.caption)
                .foregroundStyle(.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 24)
        .padding(.horizontal, AppSpacing.pageHorizontal)
        .padding(.bottom, AppSpacing.lg)
    }

    // MARK: - 统计行

    private var statsRow: some View {
        let stats = [
            WorkspaceStat(value: "\(viewModel.monthBookingCount)", label: "本月预约", highlight: false),
            WorkspaceStat(value: String(format: "¥%.2f", viewModel.earnings?.monthIncome ?? 0), label: "本月收入", highlight: true),
            WorkspaceStat(value: String(format: "%.1f%%", viewModel.positiveReviewRate), label: "好评率", highlight: false)
        ]
        return HStack(spacing: 10) {
            ForEach(stats.indices, id: \.self) { index in
                let stat = stats[index]
                VStack(spacing: 4) {
                    Text(stat.value)
                        .font(.system(size: stat.highlight ? 18 : 22, weight: .bold))
                        .foregroundStyle(stat.highlight ? .accentDefault : .textPrimary)
                    Text(stat.label)
                        .font(.micro)
                        .foregroundStyle(.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.bgSecondary)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.borderDefault, lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, AppSpacing.pageHorizontal)
    }

    // MARK: - 快捷操作

    private var quickActionsSection: some View {
        return HStack(spacing: 12) {
            ForEach(quickActions.indices, id: \.self) { index in
                let action = quickActions[index]
                quickActionItem(action)
            }
        }
        .padding(AppSpacing.lg)
    }

    private func quickActionItem(_ action: QuickAction) -> some View {
        NavigationLink {
            quickActionDestination(action.label)
        } label: {
            VStack(spacing: AppSpacing.sm) {
                Image(systemName: action.icon)
                    .font(.system(size: 22))
                    .foregroundStyle(.accentDefault)
                    .frame(width: 48, height: 48)
                    .background(Color.bgSecondary)
                    .cornerRadius(AppRadius.md)
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.md).stroke(Color.borderDefault))
                Text(action.label)
                    .font(.micro)
                    .foregroundStyle(.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func quickActionDestination(_ label: String) -> some View {
        switch label {
        case "设置日程", "休息请假": CalendarView()
        case "个人主页": ProfileView()
        default: EarningsView()
        }
    }

    // MARK: - 今日预约

    private var todayBookingsSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("今日预约")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.textPrimary)
                Spacer()
                NavigationLink {
                    BookingsView()
                } label: {
                    Text("查看全部")
                        .font(.caption)
                        .foregroundStyle(.textSecondary)
                }
            }
            .padding(.horizontal, AppSpacing.pageHorizontal)
            .padding(.top, AppSpacing.lg)
            .padding(.bottom, AppSpacing.sm)

            if viewModel.todayBookings.isEmpty {
                Text("今日暂无预约")
                    .font(.caption)
                    .foregroundStyle(.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.lg)
            }
            ForEach(viewModel.todayBookings) { booking in
                NavigationLink {
                    BookingDetailView(bookingId: booking.id)
                } label: {
                    bookingCard(booking)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func bookingCard(_ booking: Booking) -> some View {
        let times = booking.timeSlot.split(separator: "-", maxSplits: 1).map(String.init)
        let badge = booking.statusEnum.badgeInfo
        return HStack(spacing: 12) {
            // 时间块
            VStack(spacing: 2) {
                Text(times.first ?? booking.timeSlot)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.textPrimary)
                Text(times.count > 1 ? times[1] : "")
                    .font(.micro)
                    .foregroundStyle(.textTertiary)
            }
            .frame(minWidth: 56)

            // 预约信息
            VStack(alignment: .leading, spacing: 2) {
                Text(booking.serviceName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.textPrimary)
                Text("\(booking.userId) · \(booking.templeName)")
                    .font(.system(size: 12))
                    .foregroundStyle(.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 状态徽章
            Text(badge.text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(badge.color)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, 3)
                .background(badge.color.opacity(0.15))
                .cornerRadius(AppRadius.sm)
        }
        .padding(14)
        .background(Color.bgSecondary)
        .cornerRadius(AppRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(Color.borderDefault, lineWidth: 1)
        )
        .padding(.horizontal, AppSpacing.pageHorizontal)
        .padding(.top, 10)
    }

    // MARK: - 加持任务

    private var blessingTaskSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("加持任务")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.textPrimary)
                Spacer()
                NavigationLink {
                    BlessingTasksView()
                } label: {
                    Text("查看全部 >")
                        .font(.system(size: 12))
                        .foregroundStyle(.accentDefault)
                }
            }
            .padding(.horizontal, AppSpacing.pageHorizontal)
            .padding(.top, 16)
            .padding(.bottom, 10)

            if let task = viewModel.assignedTasks.first {
                NavigationLink {
                    BlessingTaskDetailView(taskId: task.id)
                } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("加持任务 \(task.taskNo)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.textPrimary)
                        Text("订单 \(task.diyOrderNo) · \(task.assignTime)")
                            .font(.micro)
                            .foregroundStyle(.textTertiary)
                    }
                    Spacer()
                    Text(task.statusEnum.badgeInfo.text)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.brandDefault)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, 3)
                        .background(Color.brandDefault.opacity(0.15))
                        .cornerRadius(6)
                }
                .padding(AppSpacing.md)
                .background(Color.bgSecondary)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(hex: "3D2E28"), lineWidth: 1)
                )
                .padding(.horizontal, AppSpacing.pageHorizontal)
            }
            .buttonStyle(.plain)
            } else {
                Text("暂无待接单加持任务")
                    .font(.caption)
                    .foregroundStyle(.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.lg)
            }
        }
    }
}

@MainActor
private final class MediaStudioViewModel: ObservableObject {
    @Published var media: MediaAsset?
    @Published var imageMedia: [MediaAsset] = []
    @Published var posts: [MasterCommunityPost] = []
    @Published var capabilities: LiveCapabilities?
    @Published var room: LiveRoom?
    @Published var isUploading = false
    @Published var errorMessage: String?

    func loadCapabilities() async {
        do {
            capabilities = try await APIClient.shared.request(.liveCapabilities)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadPosts() async {
        do {
            let response: MasterCommunityPostList = try await APIClient.shared.request(.masterCommunityPosts(status: nil, page: 1, size: 50))
            posts = response.list
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func upload(video: Data, cover: Data?) async {
        isUploading = true
        errorMessage = nil
        defer { isUploading = false }
        do {
            var coverId: Int64?
            if let cover {
                let uploadedCover = try await uploadAsset(
                    data: cover, fileName: "cover.jpg", mediaType: "image", contentType: "image/jpeg", coverMediaId: nil
                )
                coverId = uploadedCover.id
            }
            media = try await uploadAsset(
                data: video, fileName: "video.mov", mediaType: "video", contentType: "video/quicktime", coverMediaId: coverId
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func upload(images: [Data]) async {
        isUploading = true
        errorMessage = nil
        defer { isUploading = false }
        do {
            var uploaded: [MediaAsset] = []
            for (index, data) in images.prefix(9).enumerated() {
                uploaded.append(try await uploadAsset(
                    data: data, fileName: "article-\(index + 1).jpg", mediaType: "image", contentType: "image/jpeg", coverMediaId: nil
                ))
            }
            imageMedia = uploaded
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func savePost(id: String?, type: String, title: String, content: String, beliefCode: String, submit: Bool) async -> Bool {
        let assets: [MasterContentAsset]
        let coverMediaId: Int64?
        if type == "video", let media {
            assets = [.init(mediaId: media.id, assetType: "video", sort: 0)]
            coverMediaId = media.coverMediaId > 0 ? media.coverMediaId : nil
        } else {
            assets = imageMedia.enumerated().map { .init(mediaId: $0.element.id, assetType: "image", sort: $0.offset) }
            coverMediaId = imageMedia.first?.id
        }
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !assets.isEmpty else {
            errorMessage = "请填写标题并上传内容素材"
            return false
        }
        let request = MasterContentCreateRequest(
            type: type, title: title, content: content, coverMediaId: coverMediaId,
            beliefCode: beliefCode.isEmpty ? nil : beliefCode, assets: assets, submit: submit
        )
        do {
            if let id {
                let _: MasterCommunityPost = try await APIClient.shared.request(.masterCommunityPostUpdate(id: id, request))
            } else {
                let _: MasterCommunityPost = try await APIClient.shared.request(.masterCommunityPostCreate(request))
            }
            await loadPosts()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func changeStatus(_ post: MasterCommunityPost, status: String) async {
        do {
            let _: MasterCommunityPost = try await APIClient.shared.request(.masterCommunityPostStatus(id: post.id, status: status))
            await loadPosts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createAndStartLive(title: String, groupId: String) async {
        guard capabilities?.canStart == true else { return }
        do {
            var created: LiveRoom = try await APIClient.shared.request(
                .liveRoomCreate(LiveRoomCreateRequest(title: title, coverMediaId: media?.coverMediaId, openimGroupId: nil))
            )
            created = try await APIClient.shared.request(.liveRoomBindOpenIM(id: created.id, groupId: groupId))
            room = try await APIClient.shared.request(.liveRoomStart(id: created.id))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func uploadAsset(data: Data, fileName: String, mediaType: String, contentType: String, coverMediaId: Int64?) async throws -> MediaAsset {
        let credential: MediaUploadCredential = try await APIClient.shared.request(
            .mediaUploadCredential(MediaUploadCredentialRequest(
                fileName: fileName, mediaType: mediaType, contentType: contentType, fileSize: Int64(data.count)
            ))
        )
        guard let uploadURL = URL(string: credential.uploadUrl) else { throw APIError.invalidURL }
        try await APIClient.shared.upload(data, to: uploadURL, headers: credential.uploadHeaders)
        return try await APIClient.shared.request(.mediaComplete(id: credential.mediaId, coverMediaId: coverMediaId))
    }
}

private struct MediaStudioView: View {
    @StateObject private var viewModel = MediaStudioViewModel()
    @State private var videoItem: PhotosPickerItem?
    @State private var coverItem: PhotosPickerItem?
    @State private var videoData: Data?
    @State private var coverData: Data?
    @State private var imageItems: [PhotosPickerItem] = []
    @State private var imageData: [Data] = []
    @State private var postType = "video"
    @State private var postTitle = ""
    @State private var postContent = ""
    @State private var beliefCode = ""
    @State private var editingId: String?
    @State private var liveTitle = "线上开示"
    @State private var openIMGroupId = ""

    var body: some View {
        Form {
            Section("发布内容") {
                Picker("类型", selection: $postType) {
                    Text("短视频").tag("video")
                    Text("图文").tag("article")
                }
                .pickerStyle(.segmented)
                TextField("标题", text: $postTitle)
                TextField("正文", text: $postContent, axis: .vertical)
                Picker("信仰流派", selection: $beliefCode) {
                    Text("不限定").tag("")
                    Text("汉传佛教").tag("han_buddhism")
                    Text("藏传佛教").tag("tibetan_buddhism")
                    Text("道教").tag("daoism")
                    Text("民间信仰").tag("folk")
                }

                if postType == "video" {
                    PhotosPicker(selection: $coverItem, matching: .images) {
                        Label(coverData == nil ? "选择封面" : "已选择封面", systemImage: "photo")
                    }
                    PhotosPicker(selection: $videoItem, matching: .videos) {
                        Label(videoData == nil ? "选择视频" : "已选择视频", systemImage: "video")
                    }
                    Button {
                        guard let videoData else { return }
                        Task { await viewModel.upload(video: videoData, cover: coverData) }
                    } label: {
                        Label(viewModel.isUploading ? "上传中" : "上传", systemImage: "arrow.up.circle")
                    }
                    .disabled(videoData == nil || viewModel.isUploading)

                    if let media = viewModel.media {
                        Text(media.status == "ready" ? "可播放 · 审核\(media.auditStatus)" : media.status)
                        if media.status == "ready", let url = URL(string: media.playbackUrl), !media.playbackUrl.isEmpty {
                            VideoPlayer(player: AVPlayer(url: url))
                                .frame(minHeight: 220)
                        }
                    }
                } else {
                    PhotosPicker(selection: $imageItems, maxSelectionCount: 9, matching: .images) {
                        Label(imageData.isEmpty ? "选择图片（最多 9 张）" : "已选择 \(imageData.count) 张", systemImage: "photo.stack")
                    }
                    Button {
                        Task { await viewModel.upload(images: imageData) }
                    } label: {
                        Label(viewModel.isUploading ? "上传中" : "上传图片", systemImage: "arrow.up.circle")
                    }
                    .disabled(imageData.isEmpty || viewModel.isUploading)
                    if !viewModel.imageMedia.isEmpty {
                        Text("已上传 \(viewModel.imageMedia.count) 张图片").foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Button("保存草稿") { Task { await save(submit: false) } }
                    Button("提交审核") { Task { await save(submit: true) } }
                        .buttonStyle(.borderedProminent)
                }
                if editingId != nil {
                    Button("取消编辑") { resetEditor() }.foregroundStyle(.secondary)
                }
            }

            Section("我的内容") {
                if viewModel.posts.isEmpty { Text("暂无内容").foregroundStyle(.secondary) }
                ForEach(viewModel.posts) { post in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(post.title).font(.headline)
                            Spacer()
                            Text(statusText(post.status)).font(.caption).foregroundStyle(statusColor(post.status))
                        }
                        Text("点赞 \(post.likeCount) · 评论 \(post.commentCount)").font(.caption).foregroundStyle(.secondary)
                        if let remark = post.auditRemark, !remark.isEmpty {
                            Text("驳回原因：\(remark)").font(.caption).foregroundStyle(.red)
                        }
                        HStack {
                            if ["draft", "rejected"].contains(post.status) {
                                Button { beginEditing(post) } label: { Label("编辑", systemImage: "pencil") }
                                Button("提交") { Task { await viewModel.changeStatus(post, status: "submit") } }
                            }
                            if post.status == "approved" {
                                Button("下架", role: .destructive) { Task { await viewModel.changeStatus(post, status: "off_shelf") } }
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("直播") {
                if viewModel.capabilities?.canStart == true {
                    TextField("直播标题", text: $liveTitle)
                    TextField("OpenIM 群组 ID", text: $openIMGroupId)
                    Button {
                        Task { await viewModel.createAndStartLive(title: liveTitle, groupId: openIMGroupId) }
                    } label: {
                        Label("开始直播", systemImage: "dot.radiowaves.left.and.right")
                    }
                    .disabled(liveTitle.isEmpty || openIMGroupId.isEmpty)
                } else {
                    Label("直播能力未开放", systemImage: "video.slash")
                        .foregroundStyle(.secondary)
                }
                if let room = viewModel.room {
                    Text("房间 \(room.roomNo) · \(room.status)")
                }
            }

            if let message = viewModel.errorMessage {
                Section { Text(message).foregroundStyle(.red) }
            }
        }
        .navigationTitle("内容与直播")
        .task {
            await viewModel.loadCapabilities()
            await viewModel.loadPosts()
        }
        .onChange(of: coverItem) { _, item in
            Task { coverData = try? await item?.loadTransferable(type: Data.self) }
        }
        .onChange(of: videoItem) { _, item in
            Task { videoData = try? await item?.loadTransferable(type: Data.self) }
        }
        .onChange(of: imageItems) { _, items in
            Task {
                var values: [Data] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self) { values.append(data) }
                }
                imageData = values
            }
        }
    }

    private func save(submit: Bool) async {
        if await viewModel.savePost(id: editingId, type: postType, title: postTitle, content: postContent, beliefCode: beliefCode, submit: submit) {
            resetEditor()
        }
    }

    private func beginEditing(_ post: MasterCommunityPost) {
        editingId = post.id
        postType = post.type
        postTitle = post.title
        postContent = post.content
        beliefCode = post.beliefCode
        if post.type == "video", let asset = post.assets.first {
            Task { viewModel.media = try? await APIClient.shared.request(.mediaDetail(id: asset.mediaId)) }
        } else {
            Task {
                var values: [MediaAsset] = []
                for asset in post.assets {
                    if let media: MediaAsset = try? await APIClient.shared.request(.mediaDetail(id: asset.mediaId)) { values.append(media) }
                }
                viewModel.imageMedia = values
            }
        }
    }

    private func resetEditor() {
        editingId = nil
        postTitle = ""
        postContent = ""
        beliefCode = ""
        videoData = nil
        coverData = nil
        imageData = []
        imageItems = []
        viewModel.media = nil
        viewModel.imageMedia = []
    }

    private func statusText(_ status: String) -> String {
        ["draft": "草稿", "pending": "审核中", "approved": "已发布", "rejected": "已驳回", "off_shelf": "已下架"][status] ?? status
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "approved": return .green
        case "rejected": return .red
        case "pending": return .orange
        default: return .secondary
        }
    }
}

#Preview {
    NavigationStack {
        WorkspaceView()
            .environmentObject(AuthStore.shared)
    }
    .preferredColorScheme(.dark)
}
