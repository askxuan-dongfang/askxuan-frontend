//
//  Withdrawal.swift
//  MasterApp
//
//  提现模型（finance-service）。
//  提现申请走 POST /admin/finance/withdrawals/apply（JWT 保护路由）。
//

import Foundation
import SwiftUI

/// 提现记录
struct Withdrawal: Identifiable, Decodable {
    let id: Int64
    let withdrawalNo: String
    let applicantType: String
    let applicantId: String
    let amount: Double
    let bankCard: String
    let status: String
    let auditTime: String
    let processTime: String
    let createTime: String
}

/// 提现申请响应
struct WithdrawalApplyResponse: Decodable {
    let id: Int64
    let withdrawalNo: String
    let applicantType: String
    let applicantId: String
    let amount: Double
    let status: String
    let createTime: String
}

/// 提现状态
enum WithdrawalStatus: String, Decodable {
    case pending     = "pending"      // 待审核
    case approved    = "approved"     // 已审核
    case processing  = "processing"   // 处理中
    case success     = "success"      // 成功
    case failed      = "failed"       // 失败
    case rejected    = "rejected"     // 已驳回

    /// 徽章文案与配色
    var badgeInfo: (text: String, color: Color) {
        switch self {
        case .pending:    return ("待审核", .stateWarning)
        case .approved:   return ("已审核", .accentDefault)
        case .processing: return ("处理中", .brandLight)
        case .success:    return ("已到账", .stateSuccess)
        case .failed:     return ("失败", .stateError)
        case .rejected:   return ("已驳回", .textTertiary)
        }
    }

    var displayName: String { badgeInfo.text }
}

extension Withdrawal {
    var statusEnum: WithdrawalStatus {
        WithdrawalStatus(rawValue: status) ?? .pending
    }

    var amountText: String {
        "¥\(String(format: "%.2f", amount))"
    }

    /// 银行卡脱敏显示（保留后 4 位）
    var maskedBankCard: String {
        guard bankCard.count > 4 else { return bankCard }
        return "**** \(bankCard.suffix(4))"
    }
}
