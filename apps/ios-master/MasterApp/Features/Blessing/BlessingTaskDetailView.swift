//
//  BlessingTaskDetailView.swift
//  MasterApp
//
//  开光任务详情（页面 6）：接单/开始/完成/拒绝。
//  GET  admin/masters/blessing-tasks/:id
//  PUT  admin/masters/blessing-tasks/:id/accept
//  PUT  admin/masters/blessing-tasks/:id/start
//  PUT  admin/masters/blessing-tasks/:id/complete  (body: certificateUrls)
//  PUT  admin/masters/blessing-tasks/:id/reject
//

import SwiftUI
import PhotosUI
import UIKit

@MainActor
final class BlessingTaskDetailViewModel: ObservableObject {
    @Published var task: BlessingTask?
    @Published var isLoading: Bool = false
    @Published var isActionLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var successMessage: String? = nil
    @Published var certificateURLs: [String] = []
    @Published var isUploading = false

    let taskId: Int64
    private let apiClient: APIClient

    init(taskId: Int64, apiClient: APIClient = .shared) {
        self.taskId = taskId
        self.apiClient = apiClient
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let task: BlessingTask = try await apiClient.request(.blessingTaskDetail(id: taskId))
            self.task = task
            // 预填已有证书 URL
            if !task.certificateUrls.isEmpty {
                certificateURLs = task.certificateUrls
            }
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
        isLoading = false
    }

    func accept() async {
        await runAction(.blessingTaskAccept(id: taskId), successText: "已接单")
    }

    func start() async {
        await runAction(.blessingTaskStart(id: taskId), successText: "已开始开光")
    }

    func reject() async {
        await runAction(.blessingTaskReject(id: taskId), successText: "已拒绝任务")
    }

    func upload(_ items: [PhotosPickerItem]) async {
        guard !isUploading, !isActionLoading else { return }
        isUploading = true
        errorMessage = nil
        defer { isUploading = false }
        do {
            for item in items.prefix(max(0, 9 - certificateURLs.count)) {
                guard let raw = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: raw),
                      let data = image.jpegData(compressionQuality: 0.85) else { throw APIError.serverError(400, "无法读取凭证图片") }
                guard data.count <= 10 * 1024 * 1024 else {
                    errorMessage = "图片不能超过 10 MB"
                    return
                }
                let credential: MediaUploadCredential = try await apiClient.request(.mediaUploadCredential(
                    MediaUploadCredentialRequest(fileName: "consecration.jpg", mediaType: "image", contentType: "image/jpeg", fileSize: Int64(data.count))))
                guard let uploadURL = URL(string: credential.uploadUrl) else { throw APIError.invalidURL }
                try await apiClient.upload(data, to: uploadURL, headers: credential.uploadHeaders)
                let asset: MediaAsset = try await apiClient.request(.mediaComplete(id: credential.mediaId, coverMediaId: nil))
                let url = asset.playbackUrl.isEmpty ? asset.coverUrl : asset.playbackUrl
                guard !url.isEmpty else { throw APIError.serverError(400, "无法读取凭证图片") }
                certificateURLs.append(url)
            }
        } catch { errorMessage = "凭证上传失败：\(error.localizedDescription)" }
    }

    func complete() async {
        guard !isUploading, !certificateURLs.isEmpty else {
            errorMessage = "请先上传开光照片"
            return
        }
        await runAction(.blessingTaskComplete(id: taskId, certificateUrls: certificateURLs), successText: "开光已完成")
    }

    private func runAction(_ endpoint: Endpoint, successText: String) async {
        guard !isActionLoading, !isUploading else { return }
        isActionLoading = true
        errorMessage = nil
        successMessage = nil
        do {
            let updated: BlessingTask = try await apiClient.request(endpoint)
            self.task = updated
            successMessage = successText
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "操作失败：\(error.localizedDescription)"
        }
        isActionLoading = false
    }
}

struct BlessingTaskDetailView: View {
    let taskId: Int64
    @StateObject private var viewModel: BlessingTaskDetailViewModel
    @State private var selectedPhotos: [PhotosPickerItem] = []

    init(taskId: Int64) {
        self.taskId = taskId
        _viewModel = StateObject(wrappedValue: BlessingTaskDetailViewModel(taskId: taskId))
    }

    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                LoadingView(fullScreen: true)
            } else if let task = viewModel.task {
                VStack(spacing: AppSpacing.lg) {
                    statusHeader(task)

                    infoCard(title: L10n.text("任务信息"), icon: "sparkles") {
                        infoRow("任务编号", task.taskNo)
                        infoRow("DIY 订单", task.diyOrderNo)
                        infoRow("寺院编码", task.templeCode)
                        infoRow("分配时间", DFDateFormatter.friendly(task.assignTime))
                        infoRow("完成时间", task.completeTime.isEmpty ? "—" : DFDateFormatter.friendly(task.completeTime))
                        infoRow("创建时间", DFDateFormatter.friendly(task.createTime))
                    }

                    if !task.certificateUrls.isEmpty {
                        infoCard(title: L10n.text("开光证书"), icon: "doc.richtext") {
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                ForEach(Array(task.certificateUrls.enumerated()), id: \.offset) { _, url in
                                    Link(destination: URL(string: url) ?? URL(string: "about:blank")!) {
                                        HStack {
                                            Image(systemName: "link.circle")
                                                .foregroundStyle(.accentDefault)
                                            Text(L10n.text("查看开光凭证"))
                                                .font(AppTypography.caption)
                                                .foregroundStyle(.accentDefault)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    actionSection(task)
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.bottom, AppSpacing.xl)
            } else {
                EmptyState(icon: "exclamationmark.triangle.fill",
                           title: L10n.text("加载失败"),
                           message: viewModel.errorMessage) {
                    Task { await viewModel.load() }
                }
            }
        }
        .background(Color.bgPrimary)
        .navigationTitle(L10n.text("任务详情"))
        .navigationBarTitleDisplayMode(.inline)

        .task { await viewModel.load() }
        .onChange(of: selectedPhotos) { _, items in
            guard !items.isEmpty else { return }
            Task { await viewModel.upload(items); selectedPhotos = [] }
        }
        .alert(L10n.text("提示"), isPresented: Binding(
            get: { viewModel.successMessage != nil },
            set: { if !$0 { viewModel.successMessage = nil } }
        )) {
            Button(L10n.text("好的")) { viewModel.successMessage = nil }
        } message: {
            Text(L10n.lookup(viewModel.successMessage ?? ""))
        }
    }

    private func statusHeader(_ task: BlessingTask) -> some View {
        MasterCard(padding: AppSpacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.text("开光任务"))
                        .font(.pageTitle)
                        .foregroundStyle(.textPrimary)
                    Text(L10n.text("编号：\(task.taskNo)"))
                        .font(AppTypography.caption)
                        .foregroundStyle(.textTertiary)
                }
                Spacer()
                StatusBadge(status: task.status, kind: .blessing)
            }
        }
    }

    private func infoCard<Content: View>(title: String, icon: String,
                                         @ViewBuilder content: () -> Content) -> some View {
        MasterCard(padding: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(AppTypography.body)
                        .foregroundStyle(.accentDefault)
                    Text(L10n.lookup(title))
                        .font(.cardTitle)
                        .foregroundStyle(.textPrimary)
                }
                content()
            }
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(L10n.lookup(label))
                .font(AppTypography.caption)
                .foregroundStyle(.textTertiary)
                .frame(width: 72, alignment: .leading)
            Text(L10n.lookup(value))
                .font(AppTypography.body)
                .foregroundStyle(.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func actionSection(_ task: BlessingTask) -> some View {
        if let error = viewModel.errorMessage {
            Text(L10n.lookup(error))
                .font(AppTypography.caption)
                .foregroundStyle(.stateError)
                .frame(maxWidth: .infinity, alignment: .leading)
        }

        let status = task.statusEnum
        if status.isTerminal {
            Text(L10n.text("该任务已结束"))
                .font(AppTypography.caption)
                .foregroundStyle(.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
        } else {
            VStack(spacing: AppSpacing.md) {
                if status == .inProgress {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.text("开光凭证")).font(.cardTitle)
                        PhotosPicker(selection: $selectedPhotos, maxSelectionCount: max(1, 9 - viewModel.certificateURLs.count), matching: .images) {
                            Label(L10n.lookup(viewModel.isUploading ? L10n.text("正在上传…") : L10n.text("从相册选择照片")), systemImage: "photo.on.rectangle")
                                .frame(maxWidth: .infinity).padding()
                                .background(Color.bgTertiary).clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                        }
                        .disabled(viewModel.isUploading || viewModel.isActionLoading || viewModel.certificateURLs.count >= 9)
                        ForEach(Array(viewModel.certificateURLs.enumerated()), id: \.offset) { index, raw in
                            HStack {
                                AsyncImage(url: URL(string: raw)) { image in image.resizable().scaledToFill() } placeholder: { Image(systemName: "photo") }
                                    .frame(width: 96, height: 72).clipped().clipShape(RoundedRectangle(cornerRadius: 8))
                                Text(L10n.text("凭证 \(index + 1)"))
                                Spacer()
                                Button(L10n.text("移除")) { viewModel.certificateURLs.remove(at: index) }
                                    .disabled(viewModel.isUploading || viewModel.isActionLoading)
                            }
                        }
                    }
                }

                if status.canAccept {
                    PrimaryButton(title: L10n.text("接单"), icon: "hand.thumbsup.fill",
                                  isLoading: viewModel.isActionLoading) {
                        Task { await viewModel.accept() }
                    }
                    SecondaryButton(title: L10n.text("拒绝"), icon: "xmark.circle") {
                        Task { await viewModel.reject() }
                    }
                }
                if status.canStart {
                    PrimaryButton(title: L10n.text("开始开光"), icon: "play.circle.fill",
                                  isLoading: viewModel.isActionLoading) {
                        Task { await viewModel.start() }
                    }
                }
                if status.canComplete {
                    PrimaryButton(title: L10n.text("完成开光"), icon: "checkmark.seal.fill",
                                  isEnabled: !viewModel.certificateURLs.isEmpty && !viewModel.isUploading,
                                  isLoading: viewModel.isActionLoading) {
                        Task { await viewModel.complete() }
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        BlessingTaskDetailView(taskId: 1001)
    }
    .preferredColorScheme(.dark)
}
