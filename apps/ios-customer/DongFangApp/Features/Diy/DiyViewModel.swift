//
//  DiyViewModel.swift
//  DongFangApp
//

import SwiftUI

enum DiyFitState: Equatable {
    case loose(remainingBeads: Int)
    case good
    case tight(excessMm: Double)

    var title: String {
        switch self {
        case .loose(let remaining): return "还可加入约 \(remaining) 颗"
        case .good: return "松紧合适"
        case .tight: return "尺寸偏紧"
        }
    }

    var color: Color {
        switch self {
        case .loose: return .stateWarning
        case .good: return .stateSuccess
        case .tight: return .stateError
        }
    }
}

private struct DiyEditorSnapshot {
    let beads: [DiyBeadSlot]
    let cord: Material?
    let wristSizeMm: Int
}

private struct LegacyDiyDesignEnvelope: Decodable {
    let items: [DiyOrderItem]?
    let materials: [DiyOrderItem]?
}

@MainActor
final class DiyViewModel: ObservableObject {
    // MARK: - Data
    @Published var designs: [DiyDesign] = []
    @Published var materials: [Material] = []
    @Published var orders: [DiyOrder] = []
    @Published var addresses: [UserAddress] = []
    @Published var blessingServices: [BlessingService] = []
    @Published var currentDesign: DiyDesign?
    @Published var currentOrder: DiyOrder?
    @Published var currentPayment: PaymentRecord?

    // MARK: - Editor state
    @Published var selectedCategory = "all"
    @Published private(set) var beadSlots: [DiyBeadSlot] = []
    @Published private(set) var selectedBeadId: String?
    @Published private(set) var selectedCord: Material?
    @Published private(set) var wristSizeMm = 160
    @Published private(set) var cartItems: [DiyCartItem] = []
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    @Published private(set) var draftStateText = "新设计"
    @Published var designName = "我的手串"

    // MARK: - UI state
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    let categories: [(code: String, name: String, icon: String)] = [
        ("all",         "全部",   "circle.grid.3x3"),
        ("main_bead",   "主珠",   "circle.grid.2x2"),
        ("spacer",      "隔珠",   "circle.grid.cross"),
        ("buddha_head", "佛头",   "circle.fill"),
        ("three_way",   "三通",   "sphere"),
        ("pendant",     "吊坠",   "tag"),
        ("tassel",      "流苏",   "wind"),
        ("cord",        "绳线",   "line.diagonal")
    ]

    private let apiClient: APIClient
    private let authStore: AuthStore
    private let draftStore: UserDefaults
    private var undoStack: [DiyEditorSnapshot] = []
    private var redoStack: [DiyEditorSnapshot] = []

    init(apiClient: APIClient = .shared,
         authStore: AuthStore = .shared,
         draftStore: UserDefaults = .standard) {
        self.apiClient = apiClient
        self.authStore = authStore
        self.draftStore = draftStore
        restoreLocalDraft()
    }

    // MARK: - Derived state
    var filteredMaterials: [Material] {
        materials.filter { material in
            (selectedCategory == "all" || material.category == selectedCategory)
                && material.status == "on_shelf"
        }
    }

    var selectedBead: DiyBeadSlot? {
        beadSlots.first { $0.id == selectedBeadId }
    }

    var totalPrice: Double {
        cartItems.reduce(0) { $0 + $1.subtotal }
    }

    var totalPriceText: String { AppDateFormatter.moneyText(totalPrice) }
    var totalQuantity: Int { beadSlots.count + (selectedCord == nil ? 0 : 1) }
    var usedLengthMm: Double { beadSlots.reduce(0) { $0 + $1.diameterMm } }

    var fitState: DiyFitState {
        let difference = usedLengthMm - (Double(wristSizeMm) + 5)
        if difference < -12 {
            return .loose(remainingBeads: max(1, Int(ceil(abs(difference) / 10))))
        }
        if difference > 8 {
            return .tight(excessMm: difference)
        }
        return .good
    }

    func count(for materialId: Int64) -> Int {
        beadSlots.filter { $0.materialId == materialId }.count
            + (selectedCord?.id == materialId ? 1 : 0)
    }

    // MARK: - Loading
    func loadDesigns() async {
        isLoading = true
        errorMessage = nil
        do {
            let response: PageResponse<DiyDesign> = try await apiClient.request(
                .diyDesigns(page: 1, size: 20))
            designs = response.list
        } catch {
            designs = []
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadMaterials() async {
        isLoading = true
        errorMessage = nil
        do {
            let response: PageResponse<Material> = try await apiClient.request(
                .diyMaterials(category: nil, page: 1, size: 100))
            materials = response.list
            syncCartItems()
        } catch {
            materials = []
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadDesign(id: Int64) async {
        isLoading = true
        errorMessage = nil
        do {
            let design: DiyDesign = try await apiClient.request(.diyDesignById(id))
            currentDesign = design
            designName = design.name
            if let data = design.designData {
                restoreDesignData(data)
            }
        } catch {
            currentDesign = nil
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadOrder(id: Int64) async {
        isLoading = true
        errorMessage = nil
        do {
            currentOrder = try await apiClient.request(.diyOrderById(id))
        } catch {
            currentOrder = nil
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadOrders() async {
        isLoading = true
        errorMessage = nil
        do {
            let response: PageResponse<DiyOrder> = try await apiClient.request(
                .diyOrders(userId: authStore.userId, status: nil, page: 1, size: 20))
            orders = response.list
        } catch {
            orders = []
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadCheckoutOptions() async {
        guard authStore.isLoggedIn else {
            addresses = []
            blessingServices = []
            errorMessage = "请先登录后下单"
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let addressResponse: ListResponse<UserAddress> = apiClient.request(.addressList)
            async let serviceResponse: PageResponse<BlessingService> = apiClient.request(
                .diyBlessingServices(page: 1, size: 50))
            let (addressResult, serviceResult) = try await (addressResponse, serviceResponse)
            addresses = addressResult.list
            blessingServices = serviceResult.list.filter { $0.status == nil || $0.status == "on_shelf" }
        } catch {
            addresses = []
            blessingServices = []
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Editor operations
    func selectCategory(_ category: String) {
        selectedCategory = category
    }

    func selectBead(_ id: String?) {
        selectedBeadId = id
    }

    func addToCart(_ material: Material) {
        if material.category == "cord" {
            setCord(material)
        } else {
            addBead(material)
        }
    }

    func addBead(_ material: Material) {
        guard beadSlots.count < 30 else {
            errorMessage = "一条手串最多配置 30 颗珠子"
            return
        }
        guard count(for: material.id) < material.stock else {
            errorMessage = "\(material.name)库存不足"
            return
        }
        recordMutation()
        let bead = DiyBeadSlot(material: material, position: beadSlots.count)
        beadSlots.append(bead)
        selectedBeadId = bead.id
        finishMutation()
    }

    func setCord(_ material: Material) {
        guard selectedCord?.id != material.id else { return }
        recordMutation()
        selectedCord = material
        finishMutation()
    }

    func duplicateSelectedBead() {
        guard let selectedBeadId,
              let index = beadSlots.firstIndex(where: { $0.id == selectedBeadId }),
              beadSlots.count < 30 else { return }
        let source = beadSlots[index]
        if let material = materials.first(where: { $0.id == source.materialId }),
           count(for: material.id) >= material.stock {
            errorMessage = "\(material.name)库存不足"
            return
        }
        recordMutation()
        let copy = DiyBeadSlot(material: source.materialSnapshot, position: index + 1)
        beadSlots.insert(copy, at: index + 1)
        self.selectedBeadId = copy.id
        finishMutation()
    }

    func removeSelectedBead() {
        guard let selectedBeadId else { return }
        removeBead(id: selectedBeadId)
    }

    func removeBead(id: String) {
        guard let index = beadSlots.firstIndex(where: { $0.id == id }) else { return }
        recordMutation()
        beadSlots.remove(at: index)
        selectedBeadId = beadSlots.indices.contains(index)
            ? beadSlots[index].id
            : beadSlots.last?.id
        finishMutation()
    }

    func moveBead(id: String, to targetIndex: Int) {
        guard let sourceIndex = beadSlots.firstIndex(where: { $0.id == id }),
              beadSlots.count > 1 else { return }
        let destination = min(max(0, targetIndex), beadSlots.count - 1)
        guard sourceIndex != destination else { return }
        recordMutation()
        let bead = beadSlots.remove(at: sourceIndex)
        beadSlots.insert(bead, at: destination)
        selectedBeadId = id
        finishMutation()
    }

    func setWristSize(_ value: Int) {
        guard value != wristSizeMm, (140...200).contains(value) else { return }
        recordMutation()
        wristSizeMm = value
        finishMutation()
    }

    func removeFromCart(_ item: DiyCartItem) {
        recordMutation()
        if item.material.category == "cord" {
            selectedCord = nil
        } else {
            beadSlots.removeAll { $0.materialId == item.material.id }
            if selectedBeadId.map({ id in beadSlots.contains { $0.id == id } }) != true {
                selectedBeadId = beadSlots.first?.id
            }
        }
        finishMutation()
    }

    func changeQuantity(_ item: DiyCartItem, delta: Int) {
        if delta > 0 {
            addToCart(item.material)
        } else if let bead = beadSlots.last(where: { $0.materialId == item.material.id }) {
            removeBead(id: bead.id)
        }
    }

    func clearCart() {
        guard !beadSlots.isEmpty || selectedCord != nil else { return }
        recordMutation()
        beadSlots.removeAll()
        selectedCord = nil
        selectedBeadId = nil
        finishMutation()
    }

    func undo() {
        guard let snapshot = undoStack.popLast() else { return }
        redoStack.append(currentSnapshot())
        apply(snapshot)
        updateHistoryState()
        persistDraft(stateText: "已撤销")
    }

    func redo() {
        guard let snapshot = redoStack.popLast() else { return }
        undoStack.append(currentSnapshot())
        apply(snapshot)
        updateHistoryState()
        persistDraft(stateText: "已重做")
    }

    // MARK: - Design document
    func designDocument() -> DiyDesignDocument {
        let orderedBeads = beadSlots.enumerated().map { index, bead -> DiyBeadSlot in
            var value = bead
            value.position = index
            return value
        }
        let cordItem = cartItems.first(where: { $0.material.category == "cord" }).map(makeOrderItem)
        return DiyDesignDocument(
            wristSizeMm: wristSizeMm,
            beads: orderedBeads,
            cord: cordItem,
            items: cartItems.map(makeOrderItem)
        )
    }

    func restoreDesignData(_ raw: String) {
        guard let data = raw.data(using: .utf8) else { return }
        let decoder = JSONDecoder()
        if let document = try? decoder.decode(DiyDesignDocument.self, from: data),
           document.version == DiyDesignDocument.currentVersion {
            apply(document)
            persistDraft(stateText: "已恢复设计")
            return
        }

        let legacyItems: [DiyOrderItem]?
        if let direct = try? decoder.decode([DiyOrderItem].self, from: data) {
            legacyItems = direct
        } else if let wrapped = try? decoder.decode(LegacyDiyDesignEnvelope.self, from: data) {
            legacyItems = wrapped.items ?? wrapped.materials
        } else {
            legacyItems = nil
        }
        guard let legacyItems else { return }
        applyLegacyItems(legacyItems)
        persistDraft(stateText: "旧设计已转换")
    }

    // MARK: - Saving and checkout
    func saveDesign() async -> Bool {
        guard !beadSlots.isEmpty else {
            errorMessage = "请至少选择一颗珠子"
            return false
        }
        guard let designData = encodeDesignData() else {
            errorMessage = "设计数据生成失败"
            return false
        }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        let request = DiyDesignSaveRequest(
            userId: authStore.userId,
            name: designName,
            designData: designData,
            totalPrice: totalPrice,
            status: "private",
            blessServiceCode: nil
        )

        do {
            let response: DiyDesignSaveResponse = try await apiClient.request(.diyDesignSave(request))
            currentDesign = DiyDesign(
                id: response.id,
                designNo: nil,
                userId: authStore.userId,
                name: designName,
                designData: designData,
                totalPrice: totalPrice,
                status: "private",
                blessServiceCode: nil,
                createTime: nil
            )
            successMessage = "设计已保存"
            persistDraft(stateText: "设计已同步")
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func createOrder(designId: Int64, addressId: Int64,
                     blessServiceCode: String?) async -> DiyOrder? {
        isSubmitting = true
        errorMessage = nil
        let request = DiyOrderCreateRequest(
            userId: authStore.userId,
            designId: designId,
            items: cartItems.map(makeOrderItem),
            blessServiceCode: blessServiceCode,
            addressId: addressId
        )

        do {
            let order: DiyOrder = try await apiClient.request(.diyOrderCreate(request))
            currentOrder = order
            successMessage = "订单已创建"
            isSubmitting = false
            return order
        } catch {
            errorMessage = error.localizedDescription
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
            currentOrder = order
            successMessage = "订单已创建"
            isSubmitting = false
            return order
        } catch {
            errorMessage = error.localizedDescription
            isSubmitting = false
            return nil
        }
    }

    func createPayment(for order: DiyOrder, channel: String) async -> PaymentCreateResult? {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            return try await apiClient.request(
                .paymentCreate(PaymentCreateRequest(
                    orderType: "diy_order",
                    orderNo: order.orderNo,
                    amount: order.totalFee,
                    channel: channel,
                    userId: authStore.userId
                )))
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func loadPayment(id: Int64) async -> PaymentRecord? {
        do {
            let payment: PaymentRecord = try await apiClient.request(.paymentById(id))
            currentPayment = payment
            return payment
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Private editor helpers
    private var draftKey: String {
        "askxuan.diy.document.v2.\(authStore.userId.isEmpty ? "guest" : authStore.userId)"
    }

    private func recordMutation() {
        undoStack.append(currentSnapshot())
        if undoStack.count > 50 { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    private func finishMutation() {
        normalizePositions()
        syncCartItems()
        updateHistoryState()
        persistDraft(stateText: "草稿已自动保存")
    }

    private func currentSnapshot() -> DiyEditorSnapshot {
        DiyEditorSnapshot(beads: beadSlots, cord: selectedCord, wristSizeMm: wristSizeMm)
    }

    private func apply(_ snapshot: DiyEditorSnapshot) {
        beadSlots = snapshot.beads
        selectedCord = snapshot.cord
        wristSizeMm = snapshot.wristSizeMm
        selectedBeadId = beadSlots.first?.id
        normalizePositions()
        syncCartItems()
    }

    private func apply(_ document: DiyDesignDocument) {
        beadSlots = document.beads.sorted { $0.position < $1.position }
        wristSizeMm = min(max(document.wristSizeMm, 140), 200)
        let cordItem = document.cord ?? document.items.first { $0.subtype == "cord" }
        selectedCord = cordItem.map(material(from:))
        selectedBeadId = beadSlots.first?.id
        undoStack.removeAll()
        redoStack.removeAll()
        normalizePositions()
        syncCartItems()
        updateHistoryState()
    }

    private func applyLegacyItems(_ items: [DiyOrderItem]) {
        beadSlots.removeAll()
        selectedCord = nil
        for item in items where item.quantity > 0 {
            if item.subtype == "cord" {
                selectedCord = material(from: item)
                continue
            }
            for _ in 0..<min(item.quantity, 30 - beadSlots.count) {
                beadSlots.append(DiyBeadSlot(item: item, position: beadSlots.count))
            }
        }
        selectedBeadId = beadSlots.first?.id
        undoStack.removeAll()
        redoStack.removeAll()
        normalizePositions()
        syncCartItems()
        updateHistoryState()
    }

    private func normalizePositions() {
        for index in beadSlots.indices {
            beadSlots[index].position = index
        }
    }

    private func syncCartItems() {
        var order: [String] = []
        var grouped: [String: DiyCartItem] = [:]
        for bead in beadSlots {
            let key = "\(bead.materialId)|\(bead.skuId ?? 0)|\(bead.spec)"
            if grouped[key] == nil {
                order.append(key)
                let liveMaterial = materials.first { $0.id == bead.materialId && $0.spec == bead.spec }
                grouped[key] = DiyCartItem(material: liveMaterial ?? bead.materialSnapshot, quantity: 1)
            } else {
                grouped[key]?.quantity += 1
            }
        }
        cartItems = order.compactMap { grouped[$0] }
        if let selectedCord {
            cartItems.append(DiyCartItem(material: selectedCord, quantity: 1))
        }
    }

    private func updateHistoryState() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }

    private func makeOrderItem(_ cartItem: DiyCartItem) -> DiyOrderItem {
        DiyOrderItem(
            materialId: cartItem.material.id,
            materialName: cartItem.material.name,
            spec: cartItem.material.spec,
            unitPrice: cartItem.material.unitPrice,
            quantity: cartItem.quantity,
            subtype: cartItem.material.category
        )
    }

    private func material(from item: DiyOrderItem) -> Material {
        Material(
            id: item.materialId,
            name: item.materialName,
            spec: item.spec,
            unitPrice: item.unitPrice,
            unit: item.subtype == "cord" ? "条" : "颗",
            category: item.subtype ?? "main_bead",
            fiveElements: nil,
            image: "",
            stock: max(item.quantity, 1),
            status: "on_shelf"
        )
    }

    private func encodeDesignData() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try? encoder.encode(designDocument()).asString()
    }

    private func persistDraft(stateText: String) {
        guard let data = try? JSONEncoder().encode(designDocument()) else { return }
        draftStore.set(data, forKey: draftKey)
        draftStateText = stateText
    }

    private func restoreLocalDraft() {
        guard let data = draftStore.data(forKey: draftKey),
              let document = try? JSONDecoder().decode(DiyDesignDocument.self, from: data),
              document.version == DiyDesignDocument.currentVersion else { return }
        apply(document)
        draftStateText = "已恢复本机草稿"
    }
}

struct DiyCartItem: Identifiable, Hashable {
    let id = UUID()
    let material: Material
    var quantity: Int

    var subtotal: Double { material.unitPrice * Double(quantity) }
    var subtotalText: String { AppDateFormatter.moneyText(subtotal) }
}

private extension Data {
    func asString() -> String? {
        String(data: self, encoding: .utf8)
    }
}
