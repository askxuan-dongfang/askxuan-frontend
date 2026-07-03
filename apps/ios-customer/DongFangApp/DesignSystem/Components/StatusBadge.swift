//
//  StatusBadge.swift
//  DongFangApp
//
//  DFStatusBadge 状态徽章：根据状态值展示对应颜色胶囊标签。
//  booking 状态值 snake_case：pending/confirmed/in_progress/reviewed/cancelled
//  （reviewed 和 cancelled 是终态，无 completed）
//

import SwiftUI

/// 状态徽章
struct DFStatusBadge: View {
    let status: String

    var body: some View {
        Text(displayText)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(color)
            .clipShape(Capsule())
    }

    /// 状态展示文本（中文）
    private var displayText: String {
        switch status.lowercased() {
        case "pending":      return "待确认"
        case "confirmed":    return "已确认"
        case "in_progress":  return "进行中"
        case "reviewed":     return "已评价"
        case "cancelled":    return "已取消"
        case "completed":    return "已完成"
        case "on_shelf":     return "上架"
        case "off_shelf":    return "下架"
        case "draft":        return "草稿"
        case "published":    return "已发布"
        case "offline":      return "已下线"
        case "dispatched":   return "已派单"
        case "assigned":     return "已分配"
        case "accepted":     return "已接单"
        case "rejected":     return "已拒绝"
        default:             return status
        }
    }

    /// 状态对应颜色
    private var color: Color {
        switch status.lowercased() {
        case "pending", "draft":          return .stateWarning
        case "confirmed", "on_shelf":     return .accentDefault
        case "in_progress", "dispatched", "assigned", "accepted":
            return .brandDefault
        case "reviewed", "completed", "published":
            return .stateSuccess
        case "cancelled", "rejected", "offline", "off_shelf":
            return .textTertiary
        default:                          return .textTertiary
        }
    }
}

#Preview {
    VStack(spacing: 8) {
        DFStatusBadge(status: "pending")
        DFStatusBadge(status: "confirmed")
        DFStatusBadge(status: "in_progress")
        DFStatusBadge(status: "reviewed")
        DFStatusBadge(status: "cancelled")
    }
    .padding()
    .background(Color.bgPrimary)
    .preferredColorScheme(.dark)
}
