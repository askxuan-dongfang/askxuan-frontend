//
//  Booking.swift
//  DongFangApp
//
//  预约订单数据模型 + 创建请求体（对齐 booking-service）。
//  状态值 snake_case：pending/confirmed/in_progress/reviewed/cancelled
//  （reviewed 和 cancelled 是终态，无 completed）
//

import Foundation

/// 预约状态枚举（snake_case，与后端对齐）
enum BookingStatus: String, Codable, Hashable, CaseIterable {
	case pendingPayment = "pending_payment"
    case pending      = "pending"
    case confirmed    = "confirmed"
    case inProgress   = "in_progress"
    case reviewed     = "reviewed"
    case cancelled    = "cancelled"
	case completed    = "completed"

    /// 中文展示文本
    var displayText: String {
        switch self {
		case .pendingPayment: return "待支付"
        case .pending:     return "待确认"
        case .confirmed:   return "已确认"
        case .inProgress:  return "进行中"
        case .reviewed:    return "已评价"
        case .cancelled:   return "已取消"
		case .completed:   return "已完成"
        }
    }

    /// 是否终态
    var isTerminal: Bool {
        self == .reviewed || self == .cancelled
    }
}

/// 预约订单
struct Booking: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let templeId: String
    var templeName: String?
    let masterId: String
    var masterName: String?
    let serviceId: String
    let serviceName: String
    let bookingDate: String
    let timeSlot: String
    let meritMoney: Double
    var meritMoneyTier: String?
    let status: String
    let note: String
    let createdAt: String

    /// 解析后的状态枚举
    var statusEnum: BookingStatus {
        BookingStatus(rawValue: status) ?? .pending
    }

    /// 中文状态文本
    var statusDisplayText: String { statusEnum.displayText }

    enum CodingKeys: String, CodingKey {
        case id, userId, templeId, templeName, masterId, masterName
        case serviceId, serviceName, bookingDate, timeSlot, meritMoney
        case meritMoneyTier, status, note, createdAt
    }

    init(id: String, userId: String, templeId: String, templeName: String?,
         masterId: String, masterName: String?, serviceId: String, serviceName: String,
         bookingDate: String, timeSlot: String, meritMoney: Double,
         meritMoneyTier: String?, status: String, note: String, createdAt: String) {
        self.id = id
        self.userId = userId
        self.templeId = templeId
        self.templeName = templeName
        self.masterId = masterId
        self.masterName = masterName
        self.serviceId = serviceId
        self.serviceName = serviceName
        self.bookingDate = bookingDate
        self.timeSlot = timeSlot
        self.meritMoney = meritMoney
        self.meritMoneyTier = meritMoneyTier
        self.status = status
        self.note = note
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.userId = try c.decodeIfPresent(String.self, forKey: .userId) ?? ""
        self.templeId = try c.decodeIfPresent(String.self, forKey: .templeId) ?? ""
        self.templeName = try c.decodeIfPresent(String.self, forKey: .templeName)
        self.masterId = try c.decodeIfPresent(String.self, forKey: .masterId) ?? ""
        self.masterName = try c.decodeIfPresent(String.self, forKey: .masterName)
        self.serviceId = try c.decodeIfPresent(String.self, forKey: .serviceId) ?? ""
        self.serviceName = try c.decodeIfPresent(String.self, forKey: .serviceName) ?? ""
        self.bookingDate = try c.decodeIfPresent(String.self, forKey: .bookingDate) ?? ""
        self.timeSlot = try c.decodeIfPresent(String.self, forKey: .timeSlot) ?? ""
        self.meritMoney = try c.decodeIfPresent(Double.self, forKey: .meritMoney) ?? 0
        self.meritMoneyTier = try c.decodeIfPresent(String.self, forKey: .meritMoneyTier)
        self.status = try c.decodeIfPresent(String.self, forKey: .status) ?? "pending"
        self.note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        self.createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
    }

    var meritMoneyText: String {
        meritMoney > 0 ? "¥\(Int(meritMoney))" : "随喜"
    }
}

/// 创建预约请求体（POST /booking）
struct CreateBookingRequest: Codable {
	let requestId: String
    let templeId: String
    let templeName: String
    let masterId: String
    let masterName: String
    let serviceId: String
    let serviceName: String
    let bookingDate: String
	let slotCode: String
    let timeSlot: String
    let meritMoney: Double
    let meritMoneyTier: String
    let note: String
    let userId: String?

	init(requestId: String, templeId: String, templeName: String, masterId: String, masterName: String,
		 serviceId: String, serviceName: String, bookingDate: String, slotCode: String, timeSlot: String,
         meritMoney: Double, meritMoneyTier: String, note: String, userId: String? = nil) {
		self.requestId = requestId
		self.templeId = templeId
        self.templeName = templeName
        self.masterId = masterId
        self.masterName = masterName
        self.serviceId = serviceId
        self.serviceName = serviceName
        self.bookingDate = bookingDate
		self.slotCode = slotCode
        self.timeSlot = timeSlot
        self.meritMoney = meritMoney
        self.meritMoneyTier = meritMoneyTier
        self.note = note
        self.userId = userId
    }
}

struct CreateBookingResponse: Codable {
	let id: String
	let status: String
	let paymentStatus: String
	let paymentNo: String
	let serviceFee: Double
	let meritMoney: Double
	let totalFee: Double
	let simulated: Bool
}

struct BookingAvailabilityResponse: Codable {
	let templeId: String
	let serviceId: String
	let serviceName: String
	let bookingDate: String
	let serviceFee: Double
	let slots: [AvailableBookingSlot]
}

struct AvailableBookingSlot: Codable, Identifiable, Hashable {
	let slotCode: String
	let label: String
	let timeRange: String
	let capacity: Int
	let remaining: Int
	let available: Bool

	var id: String { slotCode }
}

extension Booking {
    static let mockData: [Booking] = [
        Booking(id: "B20260701001", userId: "U001", templeId: "T001",
                templeName: "灵隐寺", masterId: "M001", masterName: "智海法师",
                serviceId: "S001", serviceName: "祈福法事",
                bookingDate: "2026-07-05", timeSlot: "09:00-10:00",
                meritMoney: 100, meritMoneyTier: "中额", status: "confirmed",
                note: "为家人祈福", createdAt: "2026-07-01 10:23:00"),
        Booking(id: "B20260701002", userId: "U001", templeId: "T002",
                templeName: "白云观", masterId: "M002", masterName: "清风道长",
                serviceId: "S005", serviceName: "化太岁法事",
                bookingDate: "2026-07-08", timeSlot: "14:00-15:00",
                meritMoney: 200, meritMoneyTier: "大额", status: "pending",
                note: "本命年化太岁", createdAt: "2026-07-01 11:05:00")
    ]
}
