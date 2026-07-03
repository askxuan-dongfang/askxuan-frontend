//
//  BookingViewModel.swift
//  DongFangApp
//
//  预约下单 ViewModel：选服务/选时间/填信息/提交。
//  状态值 snake_case：pending/confirmed/in_progress/reviewed/cancelled
//

import SwiftUI

@MainActor
final class BookingViewModel: ObservableObject {
    /// 预约的法师
    let master: Master

    // MARK: - 表单字段
    @Published var selectedService: ServiceType = .blessing
    @Published var selectedDateIndex: Int = 0
    @Published var selectedTimeSlot: String = "09:00-10:00"
    @Published var selectedMeritTier: MeritTier = .medium
    @Published var customMeritMoney: String = ""
    @Published var note: String = ""

    // MARK: - 状态
    @Published var isLoading: Bool = false
    @Published var isSubmitting: Bool = false
    @Published var errorMessage: String? = nil
    @Published var submittedBooking: Booking? = nil
    @Published var showSuccess: Bool = false

    // MARK: - 选项数据
    let serviceOptions: [ServiceType] = ServiceType.allCases.filter { $0 != .diy }
    let timeSlots: [String] = [
        "06:00-07:00", "08:00-09:00", "09:00-10:00", "10:00-11:00",
        "11:00-12:00", "13:00-14:00", "14:00-15:00", "15:00-16:00",
        "16:00-17:00", "18:00-19:00"
    ]
    let meritTiers: [MeritTier] = MeritTier.allCases

    /// 可选日期（未来 14 天）
    lazy var upcomingDates: [Date] = AppDateFormatter.upcomingDates(days: 14)

    private let apiClient: APIClient
    private let authStore: AuthStore

    init(master: Master,
         apiClient: APIClient = .shared,
         authStore: AuthStore = .shared) {
        self.master = master
        self.apiClient = apiClient
        self.authStore = authStore
    }

    // MARK: - 计算属性
    var selectedDate: Date {
        upcomingDates[selectedDateIndex]
    }

    var selectedDateText: String {
        let day = AppDateFormatter.day.string(from: selectedDate)
        let label = AppDateFormatter.dayLabel(for: selectedDate)
        return "\(day) \(label)"
    }

    var finalMeritMoney: Double {
        if !customMeritMoney.isEmpty, let v = Double(customMeritMoney), v > 0 {
            return v
        }
        return selectedMeritTier.amount
    }

    var meritMoneyText: String {
        AppDateFormatter.moneyText(finalMeritMoney)
    }

    var canSubmit: Bool {
        !isSubmitting && !selectedTimeSlot.isEmpty
    }

    // MARK: - 提交
    func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        errorMessage = nil

        let bookingDate = AppDateFormatter.day.string(from: selectedDate)
        let request = CreateBookingRequest(
            templeId: master.templeId,
            templeName: master.templeName,
            masterId: master.id,
            masterName: master.dharmaName,
            serviceId: selectedService.id,
            serviceName: selectedService.rawValue,
            bookingDate: bookingDate,
            timeSlot: selectedTimeSlot,
            meritMoney: finalMeritMoney,
            meritMoneyTier: selectedMeritTier.rawValue,
            note: note,
            userId: authStore.userId
        )

        do {
            let booking: Booking = try await apiClient.request(.createBooking(request))
            self.submittedBooking = booking
            self.showSuccess = true
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}

// MARK: - 功德金档位
enum MeritTier: String, CaseIterable, Identifiable {
    case small    = "随喜"
    case medium   = "中额"
    case large    = "大额"
    case jia      = "加增"

    var id: String { rawValue }

    var amount: Double {
        switch self {
        case .small:  return 50
        case .medium: return 100
        case .large:  return 200
        case .jia:    return 500
        }
    }

    var desc: String {
        switch self {
        case .small:  return "¥50 起 · 随喜功德"
        case .medium: return "¥100 · 中额供养"
        case .large:  return "¥200 · 大额供养"
        case .jia:    return "¥500 · 加增供养"
        }
    }
}
