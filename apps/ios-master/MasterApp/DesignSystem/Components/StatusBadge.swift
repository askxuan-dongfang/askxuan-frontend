//
//  StatusBadge.swift
//  MasterApp
//
//  状态徽章组件：根据状态字符串显示对应配色与文案。
//  覆盖 booking / blessing / withdrawal 等状态。
//

import SwiftUI

/// 状态徽章
struct StatusBadge: View {
    let status: String
    var kind: StatusKind = .booking

    var body: some View {
        let info = displayInfo
        Text(info.text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(info.color)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, 3)
            .background(info.color.opacity(0.15))
            .cornerRadius(AppRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.sm)
                    .stroke(info.color.opacity(0.4), lineWidth: 0.5)
            )
    }

    private var displayInfo: (text: String, color: Color) {
        switch kind {
        case .booking:
            return BookingStatus(rawValue: status)?.badgeInfo
                ?? (status, .textTertiary)
        case .blessing:
            return BlessingTaskStatus(rawValue: status)?.badgeInfo
                ?? (status, .textTertiary)
        case .withdrawal:
            return WithdrawalStatus(rawValue: status)?.badgeInfo
                ?? (status, .textTertiary)
        }
    }
}

/// 状态徽章类型
enum StatusKind {
    case booking
    case blessing
    case withdrawal
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        HStack {
            StatusBadge(status: "pending", kind: .booking)
            StatusBadge(status: "confirmed", kind: .booking)
            StatusBadge(status: "in_progress", kind: .booking)
            StatusBadge(status: "completed", kind: .booking)
            StatusBadge(status: "reviewed", kind: .booking)
            StatusBadge(status: "cancelled", kind: .booking)
        }
        HStack {
            StatusBadge(status: "assigned", kind: .blessing)
            StatusBadge(status: "accepted", kind: .blessing)
            StatusBadge(status: "doing", kind: .blessing)
            StatusBadge(status: "done", kind: .blessing)
        }
    }
    .padding()
    .background(Color.bgPrimary)
    .preferredColorScheme(.dark)
}
