//
//  DiyViewModel.swift
//  DongFangApp
//
//  DIY 共享 ViewModel：管理材料库 / 设计列表 / 当前编辑中的设计 / 订单。
//  支持的页面：DiyBraceletView（入口）、DiyDesignView（编辑器）、
//  DiyDetailView（作品详情）、DiyOrderView（下单）。
//

import SwiftUI

@MainActor
final class DiyViewModel: ObservableObject {
    // MARK: - 数据
    @Published var designs: [DiyDesign] = []
    @Published var materials: [Material] = []
    @Published var orders: [DiyOrder] = []
    @Published var currentDesign: DiyDesign? = nil
    @Published var currentOrder: DiyOrder? = nil

    // MARK: - 编辑器状态
    @Published var selectedCategory: String = "main_bead"
    @Published var cartItems: [DiyCartItem] = []
    @Published var designName: String = "我的手串"

    // MARK: - UI 状态
    @Published var isLoading: Bool = false
    @Published var isSubmitting: Bool = false
    @Published var errorMessage: String? = nil
    @Published var successMessage: String? = nil

    // MARK: - 选项
    let categories: [(code: String, name: String, icon: String)] = [
        ("main_bead",   "主珠",   "circle.grid.2x2"),
        ("spacer",      "隔珠",   "circle.grid.cross"),
        ("buddha_head", "佛头",   "circle.fill"),
        ("three_way",   "三通",   "sphere"),
        ("pendant",     "吊坠",   "tag"),
        ("tassel",      "流苏",   "wind"),
        ("cord",        "绳子",   "line.diagonal")
    ]

    private let apiClient: APIClient
    private let authStore: AuthStore

    init(apiClient: APIClient = .shared,
         authStore: AuthStore = .shared) {
        self.apiClient = apiClient
        self.authStore = authStore
    }

    // MARK: - 计算属性
    var filteredMaterials: [Material] {
        materials.filter { $0.category == selectedCategory }
    }

    var totalPrice: Double {
        cartItems.reduce(0) { $0 + $1.subtotal }
    }

    var totalPriceText: String {
        AppDateFormatter.moneyText(totalPrice)
    }

    var totalQuantity: Int {
        cartItems.reduce(0) { $0 + $1.quantity }
    }

    // MARK: - 加载设计列表
    func loadDesigns() async {
        isLoading = true
        errorMessage = nil
        do {
            let resp: PageResponse<DiyDesign> = try await apiClient.request(
                .diyDesigns(page: 1, size: 20))
            self.designs = resp.list
        } catch {
            self.designs = DiyDesign.mockDesigns
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - 加载材料库
    func loadMaterials() async {
        isLoading = true
        errorMessage = nil
        do {
            let resp: PageResponse<Material> = try await apiClient.request(
                .diyMaterials(category: nil, page: 1, size: 100))
            self.materials = resp.list
        } catch {
            self.materials = Material.mockMaterials
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - 加载设计详情
    func loadDesign(id: Int64) async {
        isLoading = true
        errorMessage = nil
        do {
            let design: DiyDesign = try await apiClient.request(.diyDesignById(id))
            self.currentDesign = design
            // 解析 designData 还原购物车（简化：跳过 JSON 解析）
        } catch {
            self.currentDesign = DiyDesign.mockDesigns.first(where: { $0.id == id })
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - 加载订单详情
    func loadOrder(id: Int64) async {
        isLoading = true
        errorMessage = nil
        do {
            let order: DiyOrder = try await apiClient.request(.diyOrderById(id))
            self.currentOrder = order
        } catch {
            self.currentOrder = DiyOrder.mockOrder
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - 加载我的订单列表
    func loadOrders() async {
        isLoading = true
        errorMessage = nil
        do {
            let resp: PageResponse<DiyOrder> = try await apiClient.request(
                .diyOrders(userId: authStore.userId, status: nil, page: 1, size: 20))
            self.orders = resp.list
        } catch {
            self.orders = [DiyOrder.mockOrder]
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - 编辑器操作
    func selectCategory(_ category: String) {
        selectedCategory = category
    }

    func addToCart(_ material: Material) {
        if let idx = cartItems.firstIndex(where: { $0.material.id == material.id }) {
            cartItems[idx].quantity += 1
        } else {
            cartItems.append(DiyCartItem(material: material, quantity: 1))
        }
    }

    func removeFromCart(_ item: DiyCartItem) {
        cartItems.removeAll { $0.material.id == item.material.id }
    }

    func changeQuantity(_ item: DiyCartItem, delta: Int) {
        if let idx = cartItems.firstIndex(where: { $0.material.id == item.material.id }) {
            cartItems[idx].quantity = max(1, cartItems[idx].quantity + delta)
        }
    }

    func clearCart() {
        cartItems.removeAll()
    }

    // MARK: - 保存设计
    func saveDesign() async -> Bool {
        guard !cartItems.isEmpty else {
            errorMessage = "请至少选择一种材料"
            return false
        }
        isSubmitting = true
        errorMessage = nil

        let designData = encodeDesignData()
        let request = DiyDesignSaveRequest(
            userId: authStore.userId,
            name: designName,
            designData: designData,
            totalPrice: totalPrice,
            status: "private",
            blessServiceCode: nil
        )

        do {
            let design: DiyDesign = try await apiClient.request(.diyDesignSave(request))
            self.currentDesign = design
            self.successMessage = "设计已保存"
            isSubmitting = false
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            isSubmitting = false
            return false
        }
    }

    // MARK: - 创建订单
    func createOrder(designId: Int64, addressId: Int64,
                     blessServiceCode: String?) async -> DiyOrder? {
        isSubmitting = true
        errorMessage = nil

        let items = cartItems.map { cartItem in
            DiyOrderItem(
                materialId: cartItem.material.id,
                materialName: cartItem.material.name,
                spec: cartItem.material.spec,
                unitPrice: cartItem.material.unitPrice,
                quantity: cartItem.quantity,
                subtype: cartItem.material.category
            )
        }

        let request = DiyOrderCreateRequest(
            userId: authStore.userId,
            designId: designId,
            items: items,
            blessServiceCode: blessServiceCode,
            addressId: addressId
        )

        do {
            let order: DiyOrder = try await apiClient.request(.diyOrderCreate(request))
            self.currentOrder = order
            self.successMessage = "订单已创建"
            isSubmitting = false
            return order
        } catch {
            self.errorMessage = error.localizedDescription
            isSubmitting = false
            return nil
        }
    }

    func createOrderFromDesign(designId: Int64, addressId: Int64,
                               blessServiceCode: String?) async -> DiyOrder? {
        isSubmitting = true
        errorMessage = nil

        let request = DiyDesignOrderCreateRequest(
            userId: authStore.userId,
            blessServiceCode: blessServiceCode,
            addressId: addressId
        )

        do {
            let order: DiyOrder = try await apiClient.request(.diyOrderCreateFromDesign(designId, request))
            self.currentOrder = order
            self.successMessage = "订单已创建"
            isSubmitting = false
            return order
        } catch {
            self.errorMessage = error.localizedDescription
            isSubmitting = false
            return nil
        }
    }

    // MARK: - 私有辅助
    private func encodeDesignData() -> String {
        let items = cartItems.map { item -> [String: Any] in
            [
                "materialId": item.material.id,
                "materialName": item.material.name,
                "subtype": item.material.category,
                "spec": item.material.spec,
                "unitPrice": item.material.unitPrice,
                "quantity": item.quantity
            ]
        }
        return (try? JSONSerialization.data(withJSONObject: items).asString()) ?? "[]"
    }
}

// MARK: - 购物车项
struct DiyCartItem: Identifiable, Hashable {
    let id = UUID()
    let material: Material
    var quantity: Int

    var subtotal: Double { material.unitPrice * Double(quantity) }
    var subtotalText: String { AppDateFormatter.moneyText(subtotal) }
}

// MARK: - JSON Data 扩展
private extension Data {
    func asString() -> String? {
        String(data: self, encoding: .utf8)
    }
}

// MARK: - DiyOrder Mock
extension DiyOrder {
    static let mockOrder = DiyOrder(
        id: 1001, orderNo: "D20260701001", userId: "U001",
        designId: 1, materialFee: 388, blessFee: 100, totalFee: 488,
        status: "pending", addressId: 1, items: nil, blessingTask: nil,
        createTime: "2026-07-01"
    )
}
