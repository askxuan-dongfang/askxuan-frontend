//
//  Earnings.swift
//  MasterApp
//
//  收益模型（master-service earnings）。
//

import Foundation

/// 收益概览响应
struct EarningsSummary: Decodable {
    let monthIncome: Double
    let totalIncome: Double
    let withdrawable: Double
    let trend: [EarningsTrendItem]
}

/// 收益趋势项
struct EarningsTrendItem: Identifiable, Decodable {
    let month: String
    let amount: Double

    var id: String { month }
}

/// 收益明细项
struct EarningsDetailItem: Identifiable, Decodable {
    let id: Int64
    let date: String
    let serviceType: String
    let userName: String
    let amount: Double
    let settleStatus: String
}

/// 收益明细列表响应
struct EarningsDetailResponse: Decodable {
    let total: Int64
    let list: [EarningsDetailItem]
    let page: Int
    let size: Int
}

extension EarningsSummary {
    func amountText(_ value: Double) -> String {
        "¥\(String(format: "%.2f", value))"
    }
}

extension EarningsDetailItem {
    /// 服务类型文案
    var serviceTypeText: String {
        switch serviceType {
        case "booking":        return "预约法事"
        case "diy_blessing":   return "加持任务"
        case "diy_material":   return "法物"
        case "shop_order":     return "商城订单"
        default:               return serviceType
        }
    }

    /// 结算状态文案
    var settleStatusText: String {
        switch settleStatus {
        case "pending":   return "待结算"
        case "settled":   return "已结算"
        case "paid":      return "已打款"
        default:          return settleStatus
        }
    }
}
