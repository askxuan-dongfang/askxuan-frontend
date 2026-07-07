//
//  BlessingTasksView.swift
//  MasterApp
//
//  加持任务列表（页面 5）。
//  顶部状态筛选，下拉刷新，分页加载。GET admin/masters/blessing-tasks。
//

import SwiftUI

@MainActor
final class BlessingTasksViewModel: ObservableObject {
    @Published var tasks: [BlessingTask] = []
    @Published var selectedStatus: BlessingTaskStatus? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var total: Int64 = 0

    private let apiClient: APIClient
    private var page: Int = 1
    private let size: Int = 20
    private var hasMore: Bool = true

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    var statusFilter: String? { selectedStatus?.rawValue }

    func load(reset: Bool = true) async {
        if reset {
            page = 1
            hasMore = true
        }
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            let resp: BlessingTaskListResponse = try await apiClient.request(
                .blessingTasks(status: statusFilter, page: page, size: size)
            )
            if reset {
                tasks = resp.list
            } else {
                tasks.append(contentsOf: resp.list)
            }
            total = resp.total
            hasMore = tasks.count < Int(total)
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

    func switchStatus(_ status: BlessingTaskStatus?) async {
        selectedStatus = status
        await load(reset: true)
    }
}

struct BlessingTasksView: View {
    @StateObject private var viewModel = BlessingTasksViewModel()

    private let tabs: [(BlessingTaskStatus?, String)] = [
        (nil, "全部"),
        (.assigned, "待接单"),
        (.accepted, "已接单"),
        (.inProgress, "进行中"),
        (.completed, "已完成"),
        (.rejected, "已拒绝")
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(tabs, id: \.1) { tab in
                        let isActive = viewModel.selectedStatus == tab.0
                        Text(tab.1)
                            .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                            .foregroundStyle(isActive ? .white : .textSecondary)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, 7)
                            .background(isActive ? AnyShapeStyle(LinearGradient(colors: [.brandDefault, .brandLight], startPoint: .leading, endPoint: .trailing)) : AnyShapeStyle(Color.bgTertiary))
                            .cornerRadius(AppRadius.md)
                    }
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.vertical, AppSpacing.md)
            }
            .background(Color.bgPrimary)

            taskList
        }
        .background(Color.bgPrimary)
        .navigationTitle("加持任务")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    @ViewBuilder
    private var taskList: some View {
        if viewModel.isLoading && viewModel.tasks.isEmpty {
            LoadingView(fullScreen: true)
        } else if viewModel.tasks.isEmpty {
            EmptyState(icon: "sparkles",
                       title: "暂无加持任务",
                       message: viewModel.errorMessage) {
                Task { await viewModel.load() }
            }
        } else {
            ScrollView {
                LazyVStack(spacing: AppSpacing.md) {
                    ForEach(viewModel.tasks) { task in
                        NavigationLink {
                            BlessingTaskDetailView(taskId: task.id)
                        } label: {
                            taskCard(task)
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            if task.id == viewModel.tasks.last?.id {
                                Task { await viewModel.loadMore() }
                            }
                        }
                    }
                    if viewModel.isLoading {
                        LoadingView(message: "加载更多...")
                    }
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.xl)
            }
        }
    }

    private func taskCard(_ task: BlessingTask) -> some View {
        MasterCard(padding: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack {
                    Text("加持任务")
                        .font(.cardTitle)
                        .foregroundStyle(.textPrimary)
                    Spacer()
                    StatusBadge(status: task.status, kind: .blessing)
                }
                HStack(spacing: AppSpacing.lg) {
                    Label(task.taskNo, systemImage: "number")
                    Label(DFDateFormatter.dayOnly(task.assignTime), systemImage: "calendar")
                }
                .font(.caption)
                .foregroundStyle(.textSecondary)

                HStack {
                    Text("DIY 订单：\(task.diyOrderNo)")
                        .font(.caption)
                        .foregroundStyle(.textTertiary)
                    Spacer()
                    if task.canAccept {
                        Text("待接单")
                            .font(.micro)
                            .foregroundStyle(.stateWarning)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        BlessingTasksView()
    }
    .preferredColorScheme(.dark)
}
