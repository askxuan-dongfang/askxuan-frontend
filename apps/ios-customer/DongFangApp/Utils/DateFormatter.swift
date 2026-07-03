//
//  DateFormatter.swift
//  DongFangApp
//
//  日期格式化工具（避免与 Foundation.DateFormatter 命名冲突，命名为 AppDateFormatter）。
//

import Foundation

enum AppDateFormatter {
    /// yyyy-MM-dd
    static let day: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "zh_CN")
        return f
    }()

    /// yyyy-MM-dd HH:mm:ss
    static let full: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "zh_CN")
        return f
    }()

    /// HH:mm
    static let time: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.locale = Locale(identifier: "zh_CN")
        return f
    }()

    /// M.d
    static let shortDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M.d"
        f.locale = Locale(identifier: "zh_CN")
        return f
    }()

    /// 周X
    static let weekday: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "EEEE"
        return f
    }()

    /// 生成未来 N 天日期
    static func upcomingDates(days: Int) -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<days).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }

    /// 日期标签（今天/明天/周X）
    static func dayLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "今天" }
        if calendar.isDateInTomorrow(date) { return "明天" }
        return weekday.string(from: date)
    }

    /// 金额格式化（去小数）
    static func moneyText(_ value: Double) -> String {
        "¥\(Int(value))"
    }

    /// 友好显示：把后端时间字符串转为「M.d HH:mm」或原值
    static func friendly(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "-" }
        if let d = full.date(from: raw) {
            return shortDay.string(from: d) + " " + time.string(from: d)
        }
        return raw
    }
}
