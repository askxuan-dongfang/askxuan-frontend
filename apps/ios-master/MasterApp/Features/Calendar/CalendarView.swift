//
//  CalendarView.swift
//  MasterApp
//
//  日程日历（页面 7）。
//  月历视图 + 选中日期的日程时段。GET admin/masters/schedules?date=yyyy-MM-dd。
//

import SwiftUI

/// 法师日程（master-service MasterSchedule）
struct MasterSchedule: Identifiable, Decodable {
    let id: Int64
    let masterCode: String
    let date: String
    let timeSlots: [String]
    let status: String          // available/booked/off
    let createTime: String
}

@MainActor
final class CalendarViewModel: ObservableObject {
    @Published var selectedDate: Date = Date()
    @Published var schedules: [MasterSchedule] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private let apiClient: APIClient
    private let calendar = Calendar(identifier: .gregorian)

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    var selectedDateString: String {
        DFDateFormatter.day.string(from: selectedDate)
    }

    /// 选中日期的时段合集
    var timeSlots: [String] {
        schedules.flatMap { $0.timeSlots }.sorted()
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let resp: ScheduleListResponse = try await apiClient.request(
                .masterSchedules(date: selectedDateString, page: 1, size: 50)
            )
            schedules = resp.list
        } catch let error as APIError {
            errorMessage = error.errorDescription
            schedules = []
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
            schedules = []
        }
        isLoading = false
    }

    func selectDate(_ date: Date) async {
        selectedDate = date
        await load()
    }
}

/// 日程列表响应
struct ScheduleListResponse: Decodable {
    let total: Int64
    let list: [MasterSchedule]
    let page: Int
    let size: Int
}

struct CalendarView: View {
    @StateObject private var viewModel = CalendarViewModel()

    private let weeks = ["日", "一", "二", "三", "四", "五", "六"]
    private let calendar = Calendar(identifier: .gregorian)

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                monthHeader
                weekHeader
                calendarGrid
                scheduleSection
            }
            .padding(.horizontal, AppSpacing.pageHorizontal)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(Color.bgPrimary)
        .navigationTitle("日程日历")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    // MARK: - 月份头

    private var monthHeader: some View {
        let title = dateFormatter("yyyy年MM月").string(from: viewModel.selectedDate)
        return HStack {
            Text(title)
                .font(.pageTitle)
                .foregroundStyle(.textPrimary)
            Spacer()
            Button {
                Task { await viewModel.load() }
            } label: {
                Image(systemName: "arrow.clockwise.circle")
                    .foregroundStyle(.accentDefault)
            }
        }
        .padding(.top, AppSpacing.sm)
    }

    private var weekHeader: some View {
        HStack(spacing: 0) {
            ForEach(weeks, id: \.self) { w in
                Text(w)
                    .font(.caption)
                    .foregroundStyle(.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - 日历网格

    private var calendarGrid: some View {
        let days = daysInMonth()
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 6) {
            ForEach(days, id: \.self) { date in
                if date == Date.distantPast {
                    Color.clear.frame(height: 40)
                } else {
                    dayCell(date)
                }
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: viewModel.selectedDate)
        let isToday = calendar.isDateInToday(date)
        let day = calendar.component(.day, from: date)

        return Button {
            Task { await viewModel.selectDate(date) }
        } label: {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(LinearGradient(colors: [.brandDefault, .brandLight],
                                             startPoint: .top, endPoint: .bottom))
                } else if isToday {
                    Circle()
                        .stroke(Color.accentDefault, lineWidth: 1.5)
                }
                Text("\(day)")
                    .font(.system(size: 15, weight: isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected ? .white : (isToday ? .accentDefault : .textPrimary))
            }
            .frame(height: 40)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func daysInMonth() -> [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: viewModel.selectedDate),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: viewModel.selectedDate)) else {
            return []
        }
        let weekday = calendar.component(.weekday, from: firstOfMonth)
        var dates: [Date] = []
        // 前置空位
        for _ in 0..<(weekday - 1) {
            dates.append(Date.distantPast)
        }
        for day in range {
            if let d = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                dates.append(d)
            }
        }
        return dates
    }

    // MARK: - 日程区

    @ViewBuilder
    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("当日时段")
                    .font(.sectionTitle)
                    .foregroundStyle(.textPrimary)
                Spacer()
                Text(DFDateFormatter.dayOnly(viewModel.selectedDateString))
                    .font(.caption)
                    .foregroundStyle(.textTertiary)
            }

            if viewModel.isLoading {
                LoadingView(message: "加载日程...")
                    .frame(maxWidth: .infinity)
            } else if viewModel.timeSlots.isEmpty {
                EmptyState(icon: "clock.badge.questionmark",
                           title: "暂无日程",
                           message: viewModel.errorMessage ?? "当日未设置可用时段")
            } else {
                ForEach(viewModel.timeSlots, id: \.self) { slot in
                    MasterCard(padding: AppSpacing.md) {
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(.accentDefault)
                            Text(slot)
                                .font(.body)
                                .foregroundStyle(.textPrimary)
                            Spacer()
                            Text("可预约")
                                .font(.micro)
                                .foregroundStyle(.stateSuccess)
                                .padding(.horizontal, AppSpacing.sm)
                                .padding(.vertical, 3)
                                .background(Color.stateSuccess.opacity(0.15))
                                .cornerRadius(AppRadius.sm)
                        }
                    }
                }
            }
        }
        .padding(.top, AppSpacing.lg)
    }

    // MARK: - 辅助

    private func dateFormatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.dateFormat = format
        f.locale = Locale(identifier: "zh_CN")
        return f
    }
}

#Preview {
    NavigationStack {
        CalendarView()
    }
    .preferredColorScheme(.dark)
}
