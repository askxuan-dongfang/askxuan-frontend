//
//  BookingsView.swift
//  MasterApp
//
//  预约列表（页面 3）。
//  顶部状态筛选 Tab，下拉刷新，分页加载。GET admin/masters/bookings。
//

import SwiftUI

@MainActor
final class BookingsViewModel: ObservableObject {
    @Published var bookings: [Booking] = []
    @Published var selectedStatus: BookingStatus? = nil
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
            let resp: BookingListResponse = try await apiClient.request(
                .masterBookings(status: statusFilter, page: page, size: size)
            )
            if reset {
                bookings = resp.list
            } else {
                bookings.append(contentsOf: resp.list)
            }
            total = resp.total
            hasMore = bookings.count < Int(total)
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

    func switchStatus(_ status: BookingStatus?) async {
        selectedStatus = status
        await load(reset: true)
    }
}

private struct TabFilterItem {
    let title: String
    let status: BookingStatus?
}

struct BookingsView: View {
    @StateObject private var viewModel = BookingsViewModel()
    @State private var selectedTabIndex: Int = 0

    private let tabs: [TabFilterItem] = [
        TabFilterItem(title: "全部", status: nil),
        TabFilterItem(title: "待确认", status: .pending),
        TabFilterItem(title: "已确认", status: .confirmed),
        TabFilterItem(title: "进行中", status: .inProgress),
        TabFilterItem(title: "已完成", status: .completed)
    ]

    var body: some View {
        VStack(spacing: 0) {
            tabFilters
            bookingList
        }
        .background(Color.bgPrimary)
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    // MARK: - Tab 筛选器

    private var tabFilters: some View {
        HStack(spacing: 0) {
            ForEach(tabs.indices, id: \.self) { index in
                let tab = tabs[index]
                let isSelected = selectedTabIndex == index
                VStack(spacing: 0) {
                    HStack(spacing: 4) {
                        Text(tab.title)
                            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? .brandDefault : .textTertiary)
                        if isSelected {
                            Text("\(viewModel.total)")
                            .font(.system(size: 10))
                            .foregroundStyle(.brandDefault)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.brandDefault.opacity(0.15))
                            .cornerRadius(AppRadius.sm)
                        }
                    }
                    .padding(.vertical, 12)
                    // 底部下划线
                    Rectangle()
                        .fill(isSelected ? Color.brandDefault : Color.clear)
                        .frame(width: 24, height: 3)
                        .cornerRadius(2)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard selectedTabIndex != index else { return }
                    selectedTabIndex = index
                    Task { await viewModel.switchStatus(tab.status) }
                }
            }
        }
        .padding(.horizontal, AppSpacing.pageHorizontal)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.borderDefault)
                .frame(height: 1)
        }
    }

    // MARK: - 预约列表

    @ViewBuilder
    private var bookingList: some View {
        if viewModel.isLoading && viewModel.bookings.isEmpty {
            LoadingView(fullScreen: true)
        } else if let error = viewModel.errorMessage, viewModel.bookings.isEmpty {
            EmptyState(icon: "exclamationmark.triangle.fill", title: "加载失败", message: error) {
                Task { await viewModel.load() }
            }
        } else if viewModel.bookings.isEmpty {
            EmptyState(icon: "calendar.badge.checkmark", title: "暂无预约", message: "当前状态下没有预约记录")
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.bookings) { booking in
                        NavigationLink {
                            BookingDetailView(bookingId: booking.id)
                        } label: {
                            bookingCard(booking)
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            guard booking.id == viewModel.bookings.last?.id else { return }
                            Task { await viewModel.loadMore() }
                        }
                    }
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.brandDefault)
                            .padding(.vertical, AppSpacing.lg)
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 70)
            }
            .softScrollEdge(.bottom)
        }
    }

    private func bookingCard(_ booking: Booking) -> some View {
        let badge = booking.statusEnum.badgeInfo
        return HStack(alignment: .center, spacing: 12) {
            // 头像
            Image(systemName: "person.fill")
                .font(.system(size: 20))
                .foregroundStyle(.textTertiary)
                .frame(width: 44, height: 44)
                .background(Color.bgTertiary)
                .clipShape(Circle())

            // 中间信息
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(booking.userId.isEmpty ? "匿名信众" : booking.userId)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.textPrimary)
                    Text(booking.serviceName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.accentDefault)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, 2)
                        .background(Color.accentDefault.opacity(0.15))
                        .cornerRadius(AppRadius.sm)
                }
                Text("\(booking.bookingDate) \(booking.timeSlot) · \(booking.templeName)")
                    .font(.system(size: 12))
                    .foregroundStyle(.textSecondary)
                Text("查看详情")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.brandDefault)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 右侧金额和状态
            VStack(alignment: .trailing, spacing: 4) {
                Text(booking.meritMoneyText)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.accentDefault)
                Text(badge.text)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(badge.color)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 3)
                    .background(badge.color.opacity(0.15))
                    .cornerRadius(AppRadius.sm)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, 14)
        .background(Color.bgSecondary)
        .cornerRadius(AppRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(Color.borderDefault, lineWidth: 1)
        )
        .padding(.horizontal, AppSpacing.pageHorizontal)
        .padding(.top, 10)
    }
}

#Preview {
    NavigationStack {
        BookingsView()
    }
    .preferredColorScheme(.dark)
}
