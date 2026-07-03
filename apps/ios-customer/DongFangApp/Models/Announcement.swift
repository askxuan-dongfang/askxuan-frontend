//
//  Announcement.swift
//  DongFangApp
//
//  系统公告数据模型（对齐 message-service）。
//

import Foundation

/// 系统公告
struct Announcement: Codable, Identifiable, Hashable {
    let id: Int64
    let title: String
    let content: String
    let type: String             // system/activity/maintenance
    let targetAudience: String?  // all/customer/temple_admin/master
    let status: String           // draft/published/offline
    let publishTime: String?
    let createTime: String?

    var typeDisplay: String {
        switch type {
        case "system":       return "系统通知"
        case "activity":     return "活动公告"
        case "maintenance":  return "维护公告"
        default:             return type
        }
    }

    var typeIcon: String {
        switch type {
        case "system":       return "megaphone.fill"
        case "activity":     return "gift.fill"
        case "maintenance":  return "wrench.adjustable.fill"
        default:             return "bell.fill"
        }
    }
}

extension Announcement {
    static let mockAnnouncements: [Announcement] = [
        Announcement(id: 1, title: "岁末祈福大典开启报名",
                     content: "值此岁末，问玄东方联合全国十大寺院举行祈福大典，欢迎信众线上预约，共沐佛恩。",
                     type: "activity", targetAudience: "all", status: "published",
                     publishTime: "2026-06-28 10:00:00", createTime: "2026-06-28"),
        Announcement(id: 2, title: "系统维护通知",
                     content: "为提供更优质服务，平台将于 2026-07-03 凌晨 2:00-4:00 进行系统维护，期间部分功能不可用。",
                     type: "maintenance", targetAudience: "all", status: "published",
                     publishTime: "2026-06-29 18:00:00", createTime: "2026-06-29"),
        Announcement(id: 3, title: "新增 DIY 手串定制功能",
                     content: "DIY 手串定制功能已上线，可自由搭配材料，并由法师开光加持，定制专属法物。",
                     type: "system", targetAudience: "all", status: "published",
                     publishTime: "2026-06-25 09:00:00", createTime: "2026-06-25")
    ]
}
