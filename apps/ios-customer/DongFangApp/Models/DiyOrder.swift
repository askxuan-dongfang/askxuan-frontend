//
//  DiyOrder.swift
//  DongFangApp
//
//  DIY 手串数据模型（对齐 diy-service）：设计 / 订单 / 材料 / 加持任务。
//

import Foundation

/// DIY 设计
struct DiyDesign: Codable, Identifiable, Hashable {
    let id: Int64
    let designNo: String?
    let userId: String?
    let name: String
    let designData: String?      // JSON: 材料配置
    let totalPrice: Double
    let status: String           // private/public/pending_review/approved/rejected
    let blessServiceCode: String?
    let createTime: String?

    enum CodingKeys: String, CodingKey {
        case id, name, status
        case designNo, userId, designData, totalPrice, blessServiceCode, createTime
    }
}

/// DIY 订单
struct DiyOrder: Codable, Identifiable, Hashable {
    let id: Int64
    let orderNo: String
    let userId: String?
    let designId: Int64
    let materialFee: Double
    let blessFee: Double
    let totalFee: Double
    let status: String
    let addressId: Int64?
    var items: [DiyOrderItem]?
    var blessingTask: BlessingTask?
    let createTime: String?

    enum CodingKeys: String, CodingKey {
        case id, orderNo, userId, designId, materialFee, blessFee
        case totalFee, status, addressId, items, blessingTask, createTime
    }

    var totalFeeText: String { "¥\(Int(totalFee))" }
    var statusDisplayText: String {
        switch status {
        case "pending":        return "待付款"
        case "paid":           return "已付款"
        case "making":         return "制作中"
        case "blessing":       return "加持中"
        case "shipped":        return "已发货"
        case "completed":      return "已完成"
        case "cancelled":      return "已取消"
        default:               return status
        }
    }
}

/// DIY 订单明细项
struct DiyOrderItem: Codable, Identifiable, Hashable {
    let id: Int64?
    let orderId: Int64?
    let materialId: Int64
    let materialName: String
    let spec: String
    let unitPrice: Double
    let quantity: Int
    let subtype: String?

    enum CodingKeys: String, CodingKey {
        case id, orderId, materialId, materialName, spec
        case unitPrice, quantity, subtype
    }

    init(materialId: Int64, materialName: String, spec: String,
         unitPrice: Double, quantity: Int, subtype: String? = nil) {
        self.id = nil
        self.orderId = nil
        self.materialId = materialId
        self.materialName = materialName
        self.spec = spec
        self.unitPrice = unitPrice
        self.quantity = quantity
        self.subtype = subtype
    }
}

/// 材料
struct Material: Codable, Identifiable, Hashable {
    let id: Int64
    let name: String
    let spec: String
    let unitPrice: Double
    let unit: String
    let category: String         // main_bead/spacer/buddha_head/pendant/tassel/three_way/cord
    let fiveElements: String?
    let image: String
    let stock: Int
    let status: String

    var priceText: String { "¥\(String(format: "%.2f", unitPrice))/\(unit)" }

    var categoryDisplay: String {
        switch category {
        case "main_bead":   return "主珠"
        case "spacer":      return "隔珠"
        case "buddha_head": return "佛头"
        case "pendant":     return "吊坠"
        case "tassel":      return "流苏"
        case "three_way":   return "三通"
        case "cord":        return "绳子"
        default:            return category
        }
    }
}

/// 加持任务
struct BlessingTask: Codable, Identifiable, Hashable {
    let id: Int64
    let taskNo: String?
    let diyOrderNo: String?
    let templeCode: String?
    let masterCode: String?
    let status: String            // dispatched/assigned/accepted/in_progress/completed/rejected
    let certificateUrls: [String]?
    let assignTime: String?
    let completeTime: String?
}

// MARK: - 请求体

struct DiyDesignSaveRequest: Codable {
    let userId: String
    let name: String
    let designData: String
    let totalPrice: Double
    let status: String
    let blessServiceCode: String?
}

struct DiyOrderCreateRequest: Codable {
    let userId: String
    let designId: Int64
    let items: [DiyOrderItem]
    let blessServiceCode: String?
    let addressId: Int64
}

// MARK: - Mock 数据
extension Material {
    static let mockMaterials: [Material] = [
        Material(id: 1, name: "星月菩提", spec: "8mm", unitPrice: 3.5, unit: "颗",
                 category: "main_bead", fiveElements: "木", image: "", stock: 999, status: "on_shelf"),
        Material(id: 2, name: "金刚菩提", spec: "15mm", unitPrice: 8.0, unit: "颗",
                 category: "main_bead", fiveElements: "木", image: "", stock: 500, status: "on_shelf"),
        Material(id: 3, name: "南红玛瑙", spec: "6mm", unitPrice: 15.0, unit: "颗",
                 category: "spacer", fiveElements: "火", image: "", stock: 300, status: "on_shelf"),
        Material(id: 4, name: "绿松石", spec: "8mm", unitPrice: 25.0, unit: "颗",
                 category: "spacer", fiveElements: "木", image: "", stock: 200, status: "on_shelf"),
        Material(id: 5, name: "蜜蜡佛头", spec: "12mm", unitPrice: 188.0, unit: "个",
                 category: "buddha_head", fiveElements: "土", image: "", stock: 50, status: "on_shelf"),
        Material(id: 6, name: "银质三通", spec: "标准", unitPrice: 68.0, unit: "个",
                 category: "three_way", fiveElements: "金", image: "", stock: 100, status: "on_shelf"),
        Material(id: 7, name: "红绳流苏", spec: "标准", unitPrice: 28.0, unit: "个",
                 category: "tassel", fiveElements: "火", image: "", stock: 300, status: "on_shelf"),
        Material(id: 8, name: "弹力绳", spec: "1mm", unitPrice: 5.0, unit: "条",
                 category: "cord", fiveElements: "木", image: "", stock: 999, status: "on_shelf")
    ]
}

extension DiyDesign {
    static let mockDesigns: [DiyDesign] = [
        DiyDesign(id: 1, designNo: "D20260701001", userId: "U001",
                  name: "平安祈福手串", designData: "", totalPrice: 388,
                  status: "public", blessServiceCode: nil, createTime: "2026-07-01"),
        DiyDesign(id: 2, designNo: "D20260701002", userId: "U001",
                  name: "本命年化太岁手串", designData: "", totalPrice: 666,
                  status: "public", blessServiceCode: nil, createTime: "2026-07-01")
    ]
}
