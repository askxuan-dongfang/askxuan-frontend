//
//  Booking.swift
//  DongFangApp
//
//  预约订单数据模型 + 创建请求体。
//

import Foundation

/// 预约状态枚举（rawValue 与后端中文状态对齐）
enum BookingStatus: String, Codable, Hashable {
    case pending     = "待确认"
    case confirmed   = "已确认"
    case inProgress  = "进行中"
    case completed   = "已完成"
    case cancelled   = "已取消"

    /// 展示颜色
    var displayColor: String {
        switch self {
        case .pending:    return "stateWarning"
        case .confirmed:  return "accentDefault"
        case .inProgress: return "brandDefault"
        case .completed:  return "stateSuccess"
        case .cancelled:  return "textTertiary"
        }
    }
}

/// 预约订单
struct Booking: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let templeId: String
    /// 寺院名称（接口返回）
    var templeName: String?
    let masterId: String
    /// 师傅名称（接口返回）
    var masterName: String?
    let serviceId: String
    let serviceName: String
    /// 预约日期，如「2026-07-05」
    let bookingDate: String
    /// 时段，如「09:00-10:00」或「上午」
    let timeSlot: String
    /// 功德金金额
    let meritMoney: Double
    /// 功德金档位
    var meritMoneyTier: String?
    /// 状态（中文，与 BookingStatus.rawValue 对齐）
    let status: String
    /// 备注
    let note: String
    /// 创建时间
    let createdAt: String

    /// 解析后的状态枚举
    var statusEnum: BookingStatus {
        BookingStatus(rawValue: status) ?? .pending
    }

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
        self.status = try c.decodeIfPresent(String.self, forKey: .status) ?? "待确认"
        self.note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        self.createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
    }

    /// 功德金展示文本
    var meritMoneyText: String {
        meritMoney > 0 ? "¥\(Int(meritMoney))" : "随喜"
    }
}

/// 创建预约请求体（POST /bookings）
struct CreateBookingRequest: Codable {
    let templeId: String
    let templeName: String
    let masterId: String
    let masterName: String
    let serviceId: String
    let serviceName: String
    let bookingDate: String
    let timeSlot: String
    let meritMoney: Double
    let meritMoneyTier: String
    let note: String
    let userId: String?

    init(templeId: String, templeName: String, masterId: String, masterName: String,
         serviceId: String, serviceName: String, bookingDate: String, timeSlot: String,
         meritMoney: Double, meritMoneyTier: String, note: String, userId: String? = "U001") {
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
        self.note = note
        self.userId = userId
    }
}
