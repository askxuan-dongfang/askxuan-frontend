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
    /// 待确认预约数
    @Published var pendingBookings: [Booking] = []
    /// 待接单加持任务数
    @Published var assignedTasks: [BlessingTask] = []
    /// 收益概览
    @Published var earnings: EarningsSummary?

    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    /// 待办总数
    var todoCount: Int { pendingBookings.count + assignedTasks.count }

    func load() async {
        isLoading = true
        errorMessage = nil

        async let bookingsResult = fetchBookings()
        async let tasksResult = fetchBlessingTasks()
        async let earningsResult = fetchEarnings()

        let (b, t, e) = await (bookingsResult, tasksResult, earningsResult)

        switch b {
        case .success(let list): self.pendingBookings = list
        case .failure: self.pendingBookings = []
        }
        switch t {
        case .success(let list): self.assignedTasks = list
        case .failure: self.assignedTasks = []
        }
        switch e {
        case .success(let summary): self.earnings = summary
        case .failure: self.earnings = nil
        }

        isLoading = false
    }

    private func fetchBookings() async -> Result<[Booking], Error> {
        do {
            let resp: BookingListResponse = try await apiClient.request(
                .masterBookings(status: BookingStatus.pending.rawValue, page: 1, size: 50)
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
}

// MARK: - Mock 数据

private struct MockStat {
    let value: String
    let label: String
    let highlight: Bool
}

private struct MockBookingItem {
    let startTime: String
    let endTime: String
    let title: String
    let user: String
    let statusText: String
    let statusColor: Color
}

private struct QuickAction {
    let icon: String
    let label: String
}

struct WorkspaceView: View {
    @StateObject private var viewModel = WorkspaceViewModel()
    @EnvironmentObject private var authStore: AuthStore

    private let mockStats: [MockStat] = [
        MockStat(value: "28", label: "本月预约", highlight: false),
        MockStat(value: "¥8,560", label: "本月收入", highlight: true),
        MockStat(value: "98.5%", label: "好评率", highlight: false)
    ]

    private let mockBookings: [MockBookingItem] = [
        MockBookingItem(startTime: "09:00", endTime: "10:00", title: "祈福法会",
                        user: "张三 · 灵隐寺大雄宝殿", statusText: "待处理", statusColor: .stateWarning),
        MockBookingItem(startTime: "14:00", endTime: "15:00", title: "命理咨询",
                        user: "李四 · 线上视频", statusText: "已确认", statusColor: Color(hex: "5B7AAA")),
        MockBookingItem(startTime: "16:00", endTime: "17:00", title: "开光加持",
                        user: "王五 · 灵隐寺", statusText: "待处理", statusColor: .stateWarning)
    ]

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
            Text("今日有 3 个预约待处理，1 个加持任务")
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
        HStack(spacing: 10) {
            ForEach(mockStats.indices, id: \.self) { index in
                let stat = mockStats[index]
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
        HStack(spacing: 12) {
            ForEach(quickActions.indices, id: \.self) { index in
                let action = quickActions[index]
                quickActionItem(action)
            }
        }
        .padding(AppSpacing.lg)
    }

    private func quickActionItem(_ action: QuickAction) -> some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: action.icon)
                .font(.system(size: 22))
                .foregroundStyle(.accentDefault)
                .frame(width: 48, height: 48)
                .background(Color.bgSecondary)
                .cornerRadius(AppRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .stroke(Color.borderDefault, lineWidth: 1)
                )
            Text(action.label)
                .font(.micro)
                .foregroundStyle(.textSecondary)
        }
        .frame(maxWidth: .infinity)
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
                    BlessingTasksView()
                } label: {
                    Text("查看全部")
                        .font(.caption)
                        .foregroundStyle(.textSecondary)
                }
            }
            .padding(.horizontal, AppSpacing.pageHorizontal)
            .padding(.top, AppSpacing.lg)
            .padding(.bottom, AppSpacing.sm)

            ForEach(mockBookings.indices, id: \.self) { index in
                let booking = mockBookings[index]
                NavigationLink {
                    BookingDetailView(bookingId: "mock-\(index)")
                } label: {
                    bookingCard(booking)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func bookingCard(_ booking: MockBookingItem) -> some View {
        HStack(spacing: 12) {
            // 时间块
            VStack(spacing: 2) {
                Text(booking.startTime)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.textPrimary)
                Text(booking.endTime)
                    .font(.micro)
                    .foregroundStyle(.textTertiary)
            }
            .frame(minWidth: 56)

            // 预约信息
            VStack(alignment: .leading, spacing: 2) {
                Text(booking.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.textPrimary)
                Text(booking.user)
                    .font(.system(size: 12))
                    .foregroundStyle(.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 状态徽章
            Text(booking.statusText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(booking.statusColor)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, 3)
                .background(booking.statusColor.opacity(0.15))
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

            NavigationLink {
                BlessingTaskDetailView(taskId: 0)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("紫檀·静心 · 开光加持")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.textPrimary)
                        Text("用户·王芳 | 今天 15:00")
                            .font(.micro)
                            .foregroundStyle(.textTertiary)
                    }
                    Spacer()
                    Text("待处理")
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
        }
    }
}

@MainActor
private final class MediaStudioViewModel: ObservableObject {
    @Published var media: MediaAsset?
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
    @State private var liveTitle = "线上开示"
    @State private var openIMGroupId = ""

    var body: some View {
        Form {
            Section("短视频") {
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
        .task { await viewModel.loadCapabilities() }
        .onChange(of: coverItem) { _, item in
            Task { coverData = try? await item?.loadTransferable(type: Data.self) }
        }
        .onChange(of: videoItem) { _, item in
            Task { videoData = try? await item?.loadTransferable(type: Data.self) }
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
