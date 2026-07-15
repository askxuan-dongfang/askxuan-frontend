//
//  Booking.swift
//  MasterApp
//
//  预约模型与状态枚举（booking-service）。
//  状态值 snake_case：pending/confirmed/in_progress/completed/cancelled/reviewed。
//  reviewed / cancelled 为终态。
//

import Foundation
import SwiftUI

/// 预约单
struct Booking: Identifiable, Decodable {
    let id: String
    let userId: String
    let templeId: String
    let templeName: String
    let masterId: String
    let masterName: String
    let serviceId: String
    let serviceName: String
    let bookingDate: String
	let slotCode: String?
    let timeSlot: String
	let serviceFee: Double?
    let meritMoney: Double
	let totalFee: Double?
	let paymentStatus: String?
	let paymentNo: String?
    let meritMoneyTier: String
    let status: String
    let note: String
    let createdAt: String
}

/// 预约状态
enum BookingStatus: String, Decodable {
	case pendingPayment = "pending_payment" // 待支付，不可确认
    case pending       = "pending"        // 待确认
    case confirmed     = "confirmed"      // 已确认
    case inProgress    = "in_progress"    // 进行中
    case completed     = "completed"      // 已完成
    case cancelled     = "cancelled"      // 已取消（终态）
    case reviewed      = "reviewed"       // 已评价（终态）

    /// 是否终态
    var isTerminal: Bool { self == .reviewed || self == .cancelled }

    /// 徽章文案与配色
    var badgeInfo: (text: String, color: Color) {
        switch self {
		case .pendingPayment: return ("待支付", .textTertiary)
        case .pending:    return ("待确认", .stateWarning)
        case .confirmed:  return ("已确认", .accentDefault)
        case .inProgress: return ("进行中", .brandLight)
        case .completed:  return ("已完成", .stateSuccess)
        case .cancelled:  return ("已取消", .textTertiary)
        case .reviewed:   return ("已评价", .accentDark)
        }
    }

    var displayName: String { badgeInfo.text }
}

/// 预约列表响应（MasterBookingListResp）
struct BookingListResponse: Decodable {
    let total: Int64
    let list: [Booking]
    let page: Int
    let size: Int
}

/// 状态变更响应
struct BookingStatusResponse: Decodable {
    let id: String
    let status: String
}

extension Booking {
    /// 功德金格式化
    var meritMoneyText: String {
        "¥\(String(format: "%.2f", meritMoney))"
    }

    /// 状态枚举（兜底 unknown）
    var statusEnum: BookingStatus {
        BookingStatus(rawValue: status) ?? .pending
    }
}
