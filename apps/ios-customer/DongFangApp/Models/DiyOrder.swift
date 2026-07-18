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

/// 可恢复的有序手串设计文档。items 保留给现有服务端下单解析器使用。
struct DiyDesignDocument: Codable, Hashable {
    static let currentVersion = 2

    let version: Int
    var wristSizeMm: Int
    var fitAllowanceMm: Double
    var beads: [DiyBeadSlot]
    var cord: DiyOrderItem?
    var items: [DiyOrderItem]

    init(wristSizeMm: Int, fitAllowanceMm: Double = 5,
         beads: [DiyBeadSlot], cord: DiyOrderItem? = nil, items: [DiyOrderItem]) {
        self.version = Self.currentVersion
        self.wristSizeMm = wristSizeMm
        self.fitAllowanceMm = fitAllowanceMm
        self.beads = beads
        self.cord = cord
        self.items = items
    }
}

/// 一颗珠子的不可变材料快照与可变珠位。
struct DiyBeadSlot: Codable, Identifiable, Hashable {
    let slotId: String
    var position: Int
    let materialId: Int64
    let skuId: Int64?
    let materialName: String
    let spec: String
    let unitPrice: Double
    let subtype: String
    let image: String
    let diameterMm: Double

    var id: String { slotId }

    init(material: Material, position: Int, slotId: String = UUID().uuidString) {
        self.slotId = slotId
        self.position = position
        self.materialId = material.id
        self.skuId = nil
        self.materialName = material.name
        self.spec = material.spec
        self.unitPrice = material.unitPrice
        self.subtype = material.category
        self.image = material.image
        self.diameterMm = material.resolvedDiameterMm
    }

    init(item: DiyOrderItem, position: Int, slotId: String = UUID().uuidString) {
        self.slotId = slotId
        self.position = position
        self.materialId = item.materialId
        self.skuId = item.skuId
        self.materialName = item.materialName
        self.spec = item.spec
        self.unitPrice = item.unitPrice
        self.subtype = item.subtype ?? "main_bead"
        self.image = ""
        self.diameterMm = Material(
            id: item.materialId,
            name: item.materialName,
            spec: item.spec,
            unitPrice: item.unitPrice,
            unit: "颗",
            category: item.subtype ?? "main_bead",
            fiveElements: nil,
            image: "",
            stock: item.quantity,
            status: "on_shelf"
        ).resolvedDiameterMm
    }

    var materialSnapshot: Material {
        Material(
            id: materialId,
            name: materialName,
            spec: spec,
            unitPrice: unitPrice,
            unit: subtype == "cord" ? "条" : "颗",
            category: subtype,
            fiveElements: nil,
            image: image,
            stock: 1,
            status: "on_shelf"
        )
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
    let paymentStatus: String?
    let addressId: Int64?
    let source: String?
    let creatorId: String?
    let creatorShareRate: Double?
    let originalMaterialFee: Double?
    let priceChanged: Bool?
    let designSnapshot: String?
    let pricingSnapshot: String?
    var items: [DiyOrderItem]?
    var blessingTask: BlessingTask?
    let createTime: String?

    enum CodingKeys: String, CodingKey {
        case id, orderNo, userId, designId, materialFee, blessFee
        case totalFee, status, paymentStatus, addressId, source, creatorId, creatorShareRate
        case originalMaterialFee, priceChanged, designSnapshot, pricingSnapshot
        case items, blessingTask, createTime
    }

    var totalFeeText: String { "¥\(Int(totalFee))" }
    var statusDisplayText: String {
        if status == "pending_review" {
            return paymentStatus == "success" ? "待审核" : "待付款"
        }
        switch status {
        case "pending": return "待付款"
        case "paid":           return "已付款"
        case "making", "in_making": return "制作中"
        case "blessing", "awaiting_blessing", "blessing_in_progress": return "加持中"
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
    let skuId: Int64?
    let materialName: String
    let spec: String
    let unitPrice: Double
    let quantity: Int
    let subtype: String?

    enum CodingKeys: String, CodingKey {
        case id, orderId, materialId, skuId, materialName, spec
        case unitPrice, quantity, subtype
    }

    init(materialId: Int64, skuId: Int64? = nil, materialName: String, spec: String,
         unitPrice: Double, quantity: Int, subtype: String? = nil) {
        self.id = nil
        self.orderId = nil
        self.materialId = materialId
        self.skuId = skuId
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

    var resolvedDiameterMm: Double {
        let numeric = spec
            .replacingOccurrences(of: "毫米", with: "")
            .replacingOccurrences(of: "mm", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let value = Double(numeric), (4...30).contains(value) {
            return value
        }
        switch category {
        case "spacer": return 8
        case "buddha_head", "three_way": return 12
        case "pendant", "tassel": return 14
        case "cord": return 0
        default: return 10
        }
    }

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

struct DiyDesignSaveResponse: Codable {
    let id: Int64
}

struct DiyOrderCreateRequest: Codable {
    let userId: String
    let designId: Int64
    let items: [DiyOrderItem]
    let blessServiceCode: String?
    let addressId: Int64
}

struct PaymentCreateRequest: Codable {
    let orderType: String
    let orderNo: String
    let amount: Double
    let channel: String
    let userId: String
}

struct PaymentCreateResult: Codable {
    let id: Int64
    let paymentNo: String
    let payUrl: String?
}

struct PaymentRecord: Codable, Identifiable {
    let id: Int64
    let paymentNo: String
    let orderType: String
    let orderNo: String
    let amount: Double
    let channel: String
    let status: String
    let tradeNo: String?
    let createTime: String
}

// MARK: - Mock 数据
extension Material {
    static let mockMaterials: [Material] = [
        Material(id: 1, name: "小叶紫檀圆珠", spec: "10mm", unitPrice: 28, unit: "颗",
                 category: "main_bead", fiveElements: "wood", image: "/assets/materials/rosewood.jpg", stock: 500, status: "on_shelf"),
        Material(id: 2, name: "星月菩提", spec: "10mm", unitPrice: 18, unit: "颗",
                 category: "main_bead", fiveElements: "wood", image: "/assets/materials/bodhi.jpg", stock: 500, status: "on_shelf"),
        Material(id: 3, name: "凤眼菩提", spec: "10mm", unitPrice: 22, unit: "颗",
                 category: "main_bead", fiveElements: "wood", image: "/assets/materials/rudraksha.jpg", stock: 500, status: "on_shelf"),
        Material(id: 4, name: "白玉", spec: "8mm", unitPrice: 35, unit: "颗",
                 category: "main_bead", fiveElements: "earth", image: "/assets/materials/jade.jpg", stock: 300, status: "on_shelf"),
        Material(id: 5, name: "青金石", spec: "10mm", unitPrice: 25, unit: "颗",
                 category: "main_bead", fiveElements: "water", image: "/assets/materials/lapis.jpg", stock: 300, status: "on_shelf"),
        Material(id: 6, name: "南红玛瑙", spec: "8mm", unitPrice: 32, unit: "颗",
                 category: "main_bead", fiveElements: "fire", image: "/assets/materials/agate.jpg", stock: 300, status: "on_shelf"),
        Material(id: 7, name: "蜜蜡", spec: "10mm", unitPrice: 45, unit: "颗",
                 category: "main_bead", fiveElements: "earth", image: "/assets/materials/amber.jpg", stock: 260, status: "on_shelf"),
        Material(id: 8, name: "黑曜石", spec: "10mm", unitPrice: 12, unit: "颗",
                 category: "main_bead", fiveElements: "water", image: "/assets/materials/obsidian.jpg", stock: 500, status: "on_shelf"),
        Material(id: 9, name: "藏银三通", spec: "10mm", unitPrice: 48, unit: "个",
                 category: "three_way", fiveElements: "metal", image: "/assets/materials/silver-three-way.jpg", stock: 120, status: "on_shelf"),
        Material(id: 10, name: "蜜蜡佛头", spec: "12mm", unitPrice: 68, unit: "个",
                 category: "buddha_head", fiveElements: "earth", image: "/assets/materials/amber-head.jpg", stock: 120, status: "on_shelf"),
        Material(id: 11, name: "花丝莲花吊坠", spec: "15mm", unitPrice: 20, unit: "个",
                 category: "pendant", fiveElements: "metal", image: "/assets/materials/lotus-pendant.jpg", stock: 200, status: "on_shelf"),
        Material(id: 12, name: "白水晶隔片", spec: "6mm", unitPrice: 2.5, unit: "颗",
                 category: "spacer", fiveElements: "water", image: "/assets/materials/crystal-spacer.jpg", stock: 1_000, status: "on_shelf"),
        Material(id: 13, name: "流苏配饰", spec: "", unitPrice: 28, unit: "个",
                 category: "tassel", fiveElements: "fire", image: "/assets/materials/tassel.jpg", stock: 180, status: "on_shelf"),
        Material(id: 14, name: "弹力绳", spec: "", unitPrice: 2, unit: "根",
                 category: "cord", fiveElements: "wood", image: "/assets/materials/cord.jpg", stock: 1_000, status: "on_shelf")
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
