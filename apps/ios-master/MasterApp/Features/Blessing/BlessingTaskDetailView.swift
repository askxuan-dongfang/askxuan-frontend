//
//  BlessingTaskDetailView.swift
//  MasterApp
//
//  加持任务详情（页面 6）：接单/开始/完成/拒绝。
//  GET  admin/masters/blessing-tasks/:id
//  PUT  admin/masters/blessing-tasks/:id/accept
//  PUT  admin/masters/blessing-tasks/:id/start
//  PUT  admin/masters/blessing-tasks/:id/complete  (body: certificateUrls)
//  PUT  admin/masters/blessing-tasks/:id/reject
//

import SwiftUI

@MainActor
final class BlessingTaskDetailViewModel: ObservableObject {
    @Published var task: BlessingTask?
    @Published var isLoading: Bool = false
    @Published var isActionLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var successMessage: String? = nil
    /// 完成时填写的证书图片 URL（逗号分隔）
    @Published var certificateInput: String = ""

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
                certificateInput = task.certificateUrls.joined(separator: ",")
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
        await runAction(.blessingTaskStart(id: taskId), successText: "已开始加持")
    }

    func reject() async {
        await runAction(.blessingTaskReject(id: taskId), successText: "已拒绝任务")
    }

    func complete() async {
        let urls = certificateInput
            .split(whereSeparator: { $0 == "," || $0 == "，" })
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        await runAction(.blessingTaskComplete(id: taskId, certificateUrls: urls), successText: "加持已完成")
    }

    private func runAction(_ endpoint: Endpoint, successText: String) async {
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

                    infoCard(title: "任务信息", icon: "sparkles") {
                        infoRow("任务编号", task.taskNo)
                        infoRow("DIY 订单", task.diyOrderNo)
                        infoRow("寺院编码", task.templeCode)
                        infoRow("分配时间", DFDateFormatter.friendly(task.assignTime))
                        infoRow("完成时间", task.completeTime.isEmpty ? "—" : DFDateFormatter.friendly(task.completeTime))
                        infoRow("创建时间", DFDateFormatter.friendly(task.createTime))
                    }

                    if !task.certificateUrls.isEmpty {
                        infoCard(title: "加持证书", icon: "doc.richtext") {
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                ForEach(Array(task.certificateUrls.enumerated()), id: \.offset) { _, url in
                                    Link(destination: URL(string: url) ?? URL(string: "about:blank")!) {
                                        HStack {
                                            Image(systemName: "link.circle")
                                                .foregroundStyle(.accentDefault)
                                            Text(url)
                                                .font(.caption)
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
                           title: "加载失败",
                           message: viewModel.errorMessage) {
                    Task { await viewModel.load() }
                }
            }
        }
        .background(Color.bgPrimary)
        .navigationTitle("任务详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await viewModel.load() }
        .alert("提示", isPresented: Binding(
            get: { viewModel.successMessage != nil },
            set: { if !$0 { viewModel.successMessage = nil } }
        )) {
            Button("好的") { viewModel.successMessage = nil }
        } message: {
            Text(viewModel.successMessage ?? "")
        }
    }

    private func statusHeader(_ task: BlessingTask) -> some View {
        MasterCard(padding: AppSpacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("加持任务")
                        .font(.pageTitle)
                        .foregroundStyle(.textPrimary)
                    Text("编号：\(task.taskNo)")
                        .font(.caption)
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
                        .font(.system(size: 14))
                        .foregroundStyle(.accentDefault)
                    Text(title)
                        .font(.cardTitle)
                        .foregroundStyle(.textPrimary)
                }
                content()
            }
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.textTertiary)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.body)
                .foregroundStyle(.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func actionSection(_ task: BlessingTask) -> some View {
        if let error = viewModel.errorMessage {
            Text(error)
                .font(.caption)
                .foregroundStyle(.stateError)
                .frame(maxWidth: .infinity, alignment: .leading)
        }

        let status = task.statusEnum
        if status.isTerminal {
            Text("该任务已结束")
                .font(.caption)
                .foregroundStyle(.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
        } else {
            VStack(spacing: AppSpacing.md) {
                // 完成前需要填写证书 URL
                if status == .doing {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("加持证书 URL（多个用逗号分隔）")
                            .font(.caption)
                            .foregroundStyle(.textSecondary)
                        TextField("https://..., https://...", text: $viewModel.certificateInput, axis: .vertical)
                            .font(.body)
                            .foregroundStyle(.textPrimary)
                            .padding(AppSpacing.md)
                            .background(Color.bgTertiary)
                            .cornerRadius(AppRadius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.md)
                                    .stroke(Color.borderDefault, lineWidth: 1)
                            )
                            .lineLimit(2...4)
                    }
                }

                if status.canAccept {
                    PrimaryButton(title: "接单", icon: "hand.thumbsup.fill",
                                  isLoading: viewModel.isActionLoading) {
                        Task { await viewModel.accept() }
                    }
                    SecondaryButton(title: "拒绝", icon: "xmark.circle") {
                        Task { await viewModel.reject() }
                    }
                }
                if status.canStart {
                    PrimaryButton(title: "开始加持", icon: "play.circle.fill",
                                  isLoading: viewModel.isActionLoading) {
                        Task { await viewModel.start() }
                    }
                }
                if status.canComplete {
                    PrimaryButton(title: "完成加持", icon: "checkmark.seal.fill",
                                  isEnabled: !viewModel.certificateInput.trimmingCharacters(in: .whitespaces).isEmpty,
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
