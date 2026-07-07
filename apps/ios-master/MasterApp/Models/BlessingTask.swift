//
//  BlessingTask.swift
//  MasterApp
//
//  加持任务模型与状态枚举（master-service）。
//

import Foundation
import SwiftUI

/// 加持任务
struct BlessingTask: Identifiable, Decodable {
    let id: Int64
    let taskNo: String
    let diyOrderNo: String
    let templeCode: String
    let masterCode: String
    let status: String
    let certificateUrls: [String]
    let assignTime: String
    let completeTime: String
    let createTime: String
}

/// 加持任务状态
enum BlessingTaskStatus: String, Decodable {
    case assigned     = "assigned"      // 待接单
    case accepted     = "accepted"      // 已接单
    case inProgress   = "in_progress"   // 进行中
    case completed    = "completed"     // 已完成
    case rejected     = "rejected"      // 已拒绝

    /// 是否终态
    var isTerminal: Bool { self == .completed || self == .rejected }

    /// 是否可接单
    var canAccept: Bool { self == .assigned }
    /// 是否可开始
    var canStart: Bool { self == .accepted }
    /// 是否可完成
    var canComplete: Bool { self == .inProgress }
    /// 是否可拒绝
    var canReject: Bool { self == .assigned }

    /// 徽章文案与配色
    var badgeInfo: (text: String, color: Color) {
        switch self {
        case .assigned:    return ("待接单", .stateWarning)
        case .accepted:    return ("已接单", .accentDefault)
        case .inProgress:  return ("进行中", .brandLight)
        case .completed:   return ("已完成", .stateSuccess)
        case .rejected:    return ("已拒绝", .textTertiary)
        }
    }

    var displayName: String { badgeInfo.text }
}

/// 加持任务列表响应
struct BlessingTaskListResponse: Decodable {
    let total: Int64
    let list: [BlessingTask]
    let page: Int
    let size: Int
}

extension BlessingTask {
    var statusEnum: BlessingTaskStatus {
        BlessingTaskStatus(rawValue: status) ?? .assigned
    }

    /// 是否可接单
    var canAccept: Bool { statusEnum == .assigned }
    /// 是否可开始
    var canStart: Bool { statusEnum == .accepted }
    /// 是否可完成
    var canComplete: Bool { statusEnum == .inProgress }
    /// 是否可拒绝
    var canReject: Bool { statusEnum == .assigned }
}
