//
//  DateFormatter.swift
//  MasterApp
//
//  日期/时间格式化辅助。
//

import Foundation

/// 日期格式化工具
enum DFDateFormatter {

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

    /// yyyy-MM-dd HH:mm
    static let minute: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        f.locale = Locale(identifier: "zh_CN")
        return f
    }()

    /// 友好显示：尽量把后端返回的时间字符串转为「MM-dd HH:mm」或原值。
    static func friendly(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "-" }
        // 尝试完整格式解析
        if let d = full.date(from: raw) {
            return minute.string(from: d)
        }
        // 兼容 ISO8601
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: raw) {
            return minute.string(from: d)
        }
        return raw
    }

    /// 仅日期：转为「yyyy-MM-dd」或原值。
    static func dayOnly(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "-" }
        if let d = full.date(from: raw) {
            return day.string(from: d)
        }
        if let d = day.date(from: raw) {
            return day.string(from: d)
        }
        return raw
    }

    /// 今天的日期字符串
    static var todayString: String {
        day.string(from: Date())
    }
}
