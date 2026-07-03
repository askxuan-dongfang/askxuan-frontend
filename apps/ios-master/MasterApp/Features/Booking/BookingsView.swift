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

// MARK: - Mock 数据

private struct MockBookingListCard {
    let name: String
    let serviceName: String
    let serviceBadgeColor: Color
    let dateTime: String
    let amount: String
    let statusText: String
    let statusColor: Color
}

private struct TabFilterItem {
    let title: String
    let count: Int
}

struct BookingsView: View {
    @StateObject private var viewModel = BookingsViewModel()
    @State private var selectedTabIndex: Int = 0

    private let tabs: [TabFilterItem] = [
        TabFilterItem(title: "待处理", count: 3),
        TabFilterItem(title: "已确认", count: 5),
        TabFilterItem(title: "已完成", count: 12),
        TabFilterItem(title: "已取消", count: 1)
    ]

    private let mockBookings: [MockBookingListCard] = [
        MockBookingListCard(name: "张三", serviceName: "祈福法会",
                            serviceBadgeColor: .accentDefault,
                            dateTime: "2026-06-29 09:00-10:00 · 灵隐寺",
                            amount: "¥200", statusText: "待处理", statusColor: .stateWarning),
        MockBookingListCard(name: "王五", serviceName: "开光加持",
                            serviceBadgeColor: .brandDefault,
                            dateTime: "2026-06-29 16:00-17:00 · 灵隐寺",
                            amount: "¥168", statusText: "待处理", statusColor: .stateWarning),
        MockBookingListCard(name: "赵六", serviceName: "命理咨询",
                            serviceBadgeColor: Color(hex: "5B7AAA"),
                            dateTime: "2026-06-30 10:00-11:00 · 线上视频",
                            amount: "¥100", statusText: "待处理", statusColor: .stateWarning)
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
                        Text("\(tab.count)")
                            .font(.system(size: 10))
                            .foregroundStyle(isSelected ? .brandDefault : .textTertiary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                (isSelected ? Color.brandDefault : Color.textTertiary).opacity(0.15)
                            )
                            .cornerRadius(AppRadius.sm)
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
                    selectedTabIndex = index
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
        ScrollView {
            VStack(spacing: 0) {
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
            .padding(.top, 10)
            .padding(.bottom, 70)
        }
    }

    private func bookingCard(_ booking: MockBookingListCard) -> some View {
        HStack(alignment: .center, spacing: 12) {
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
                    Text(booking.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.textPrimary)
                    Text(booking.serviceName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(booking.serviceBadgeColor)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, 2)
                        .background(booking.serviceBadgeColor.opacity(0.15))
                        .cornerRadius(AppRadius.sm)
                }
                Text(booking.dateTime)
                    .font(.system(size: 12))
                    .foregroundStyle(.textSecondary)
                // 查看详情按钮
                    NavigationLink {
                        BookingDetailView(bookingId: "mock-detail")
                    } label: {
                        Text("查看详情")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .frame(height: 30)
                            .background(
                                LinearGradient(colors: [.brandDefault, .brandDark],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(AppRadius.sm)
                    }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 右侧金额和状态
            VStack(alignment: .trailing, spacing: 4) {
                Text(booking.amount)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.accentDefault)
                Text(booking.statusText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(booking.statusColor)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 3)
                    .background(booking.statusColor.opacity(0.15))
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
