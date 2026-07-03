//
//  BookingViewModel.swift
//  DongFangApp
//
//  预约下单 ViewModel：服务选择 + 日期时段 + 功德金 + 备注 + 提交。
//

import SwiftUI

/// 可预约的服务项（本地定义，含价格与时长）
struct BookingServiceOption: Identifiable, Hashable {
    let id: String
    let name: String
    let duration: String
    let price: Double
    let serviceType: ServiceType
}

/// 时段
struct TimeSlot: Identifiable, Hashable {
    let id: String
    let label: String       // 上午/下午/晚上
    let range: String       // 9:00-12:00
    let icon: String
}

@MainActor
final class BookingViewModel: ObservableObject {
    let master: Master

    /// 可选服务项
    @Published var services: [BookingServiceOption] = []
    /// 选中的服务下标
    @Published var selectedServiceIndex: Int = 0

    /// 未来 7 天日期
    @Published var dates: [Date] = []
    /// 选中的日期下标
    @Published var selectedDateIndex: Int = 0

    /// 时段
    @Published var timeSlots: [TimeSlot] = []
    /// 选中的时段下标
    @Published var selectedTimeSlotIndex: Int = 0

    /// 功德金档位
    @Published var meritOptions: [Int] = [0, 50, 100, 200]
    /// 选中的功德金下标（-1 表示自定义）
    @Published var selectedMeritIndex: Int = 2
    /// 自定义功德金金额
    @Published var customMeritAmount: String = ""

    /// 备注
    @Published var note: String = ""

    /// 提交态
    @Published var isSubmitting: Bool = false
    /// 是否提交成功
    @Published var isSuccess: Bool = false
    /// 创建成功的订单
    @Published var createdBooking: Booking?
    /// 错误信息
    @Published var errorMessage: String? = nil

    private let apiClient: APIClient

    init(master: Master, apiClient: APIClient = .shared) {
        self.master = master
        self.apiClient = apiClient
        self.services = Self.makeServices(for: master)
        self.dates = Self.makeUpcomingDates(days: 7)
        self.timeSlots = Self.makeTimeSlots()
    }

    // MARK: - 计算属性

    var selectedService: BookingServiceOption? {
        guard services.indices.contains(selectedServiceIndex) else { return nil }
        return services[selectedServiceIndex]
    }

    var selectedDate: Date? {
        guard dates.indices.contains(selectedDateIndex) else { return nil }
        return dates[selectedDateIndex]
    }

    var selectedTimeSlot: TimeSlot? {
        guard timeSlots.indices.contains(selectedTimeSlotIndex) else { return nil }
        return timeSlots[selectedTimeSlotIndex]
    }

    /// 功德金金额
    var meritMoney: Double {
        if selectedMeritIndex == -1 {
            return Double(customMeritAmount) ?? 0
        }
        guard meritOptions.indices.contains(selectedMeritIndex) else { return 0 }
        return Double(meritOptions[selectedMeritIndex])
    }

    /// 功德金档位文本
    var meritTierText: String {
        if selectedMeritIndex == -1 { return "自定义" }
        guard meritOptions.indices.contains(selectedMeritIndex) else { return "随喜" }
        let amount = meritOptions[selectedMeritIndex]
        switch amount {
        case 0:    return "随喜"
        case 50:   return "小额"
        case 100:  return "中额"
        case 200:  return "大额"
        default:   return "随喜"
        }
    }

    /// 服务费用
    var serviceFee: Double {
        selectedService?.price ?? 0
    }

    /// 合计金额
    var totalAmount: Double {
        serviceFee + meritMoney
    }

    /// 是否可提交
    var canSubmit: Bool {
        selectedService != nil && selectedDate != nil && selectedTimeSlot != nil && !isSubmitting
    }

    // MARK: - 日期格式化

    var selectedDateString: String {
        guard let date = selectedDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }

    var selectedTimeSlotString: String {
        selectedTimeSlot?.range ?? ""
    }

    /// 日期展示标签（今天/明天/周X）
    func dateLabel(for index: Int) -> String {
        guard dates.indices.contains(index) else { return "" }
        let date = dates[index]
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "今天" }
        if calendar.isDateInTomorrow(date) { return "明天" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date) // 周日/周一...
    }

    /// 日期数字（M.d）
    func dateNumber(for index: Int) -> String {
        guard dates.indices.contains(index) else { return "" }
        let date = dates[index]
        let formatter = DateFormatter()
        formatter.dateFormat = "M.d"
        return formatter.string(from: date)
    }

    // MARK: - 提交预约

    func submit() async {
        guard let service = selectedService else { return }
        isSubmitting = true
        errorMessage = nil

        let request = CreateBookingRequest(
            templeId: master.templeId,
            templeName: master.templeName,
            masterId: master.id,
            masterName: master.dharmaName,
            serviceId: service.id,
            serviceName: service.name,
            bookingDate: selectedDateString,
            timeSlot: selectedTimeSlotString,
            meritMoney: meritMoney,
            meritMoneyTier: meritTierText,
            note: note
        )

        do {
            let booking: Booking = try await apiClient.request(.createBooking(request))
            self.createdBooking = booking
            self.isSuccess = true
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }

    // MARK: - 数据构造

    private static func makeServices(for master: Master) -> [BookingServiceOption] {
        // 根据师傅擅长领域生成可预约服务项
        var services: [BookingServiceOption] = []
        if master.specialties.contains("禅修") {
            services.append(BookingServiceOption(id: "BS001", name: "禅修指导", duration: "30分钟", price: 388, serviceType: .blessing))
        }
        if master.specialties.contains("祈福") || master.specialties.contains("佛学") || master.specialties.contains("道学") {
            services.append(BookingServiceOption(id: "BS002", name: "祈福法事", duration: "60分钟", price: 588, serviceType: .blessing))
        }
        if master.specialties.contains("开光") {
            services.append(BookingServiceOption(id: "BS003", name: "开光加持", duration: "20分钟", price: 268, serviceType: .consecration))
        }
        if master.specialties.contains("超度") {
            services.append(BookingServiceOption(id: "BS004", name: "超度法事", duration: "90分钟", price: 688, serviceType: .rite))
        }
        if master.specialties.contains("化太岁") {
            services.append(BookingServiceOption(id: "BS005", name: "化太岁法事", duration: "45分钟", price: 488, serviceType: .taisui))
        }
        // 兜底：至少 3 项
        if services.count < 3 {
            services = [
                BookingServiceOption(id: "BS001", name: "禅修指导", duration: "30分钟", price: 388, serviceType: .blessing),
                BookingServiceOption(id: "BS002", name: "祈福法事", duration: "60分钟", price: 588, serviceType: .blessing),
                BookingServiceOption(id: "BS003", name: "开光加持", duration: "20分钟", price: 268, serviceType: .consecration)
            ]
        }
        return services
    }

    private static func makeUpcomingDates(days: Int) -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<days).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }

    private static func makeTimeSlots() -> [TimeSlot] {
        [
            TimeSlot(id: "morning", label: "上午", range: "09:00-12:00", icon: "sun.max.fill"),
            TimeSlot(id: "afternoon", label: "下午", range: "14:00-17:00", icon: "clock.fill"),
            TimeSlot(id: "evening", label: "晚上", range: "19:00-21:00", icon: "moon.stars.fill")
        ]
    }
}
