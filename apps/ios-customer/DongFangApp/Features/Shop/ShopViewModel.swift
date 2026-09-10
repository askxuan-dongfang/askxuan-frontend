//
//  ShopViewModel.swift
//  DongFangApp
//
//  商城列表 ViewModel：商品分页加载 + 分类筛选 + 关键词搜索。
//  对齐产品原型 shop.html。
//

import SwiftUI

@MainActor
final class ShopViewModel: ObservableObject {
    @Published var products: [ShopProduct] = []
    @Published var categories: [ProductCategory] = []
    @Published var selectedCategoryId: Int64?
    @Published var keyword = ""
    @Published var sort = "newest"
    @Published var inStock = false
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var total = 0
    @Published var errorMessage: String?
    @Published var categoryError: String?
    var hasMore: Bool { products.count < total }
    var shopCategories: [ShopCategory] { [ShopCategory(id: nil, name: "全部好物", icon: "square.grid.2x2")] + Self.flatten(categories) }
    static func flatten(_ rows: [ProductCategory], prefix: String = "") -> [ShopCategory] {
        rows.sorted { ($0.sort ?? 0, $0.id) < ($1.sort ?? 0, $1.id) }.flatMap { row in
            [ShopCategory(id: row.id, name: prefix + row.name, icon: "tag")] + flatten(row.children ?? [], prefix: prefix + row.name + " / ")
        }
    }
    private let apiClient: APIClient
    private var currentPage = 1
    private let pageSize = 20
    private var generation = 0
    private var appliedKeyword = ""
    init(apiClient: APIClient = .shared) { self.apiClient = apiClient }
    private func endpoint(page: Int) -> Endpoint {
        .products(categoryId: selectedCategoryId, keyword: appliedKeyword, page: page, size: pageSize, sort: sort, inStock: inStock)
    }
    func load() async {
        generation += 1
        appliedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        let current = generation, request = endpoint(page: 1)
        currentPage = 1; isLoading = true; isLoadingMore = false; errorMessage = nil
        products = []; total = 0
        do {
            let response: PageResponse<ShopProduct> = try await apiClient.request(request)
            guard generation == current else { return }
            products = response.list; total = response.total
        } catch {
            guard generation == current else { return }
            errorMessage = error.localizedDescription
        }
        guard generation == current else { return }
        isLoading = false
    }
    func loadCategories() async {
        categoryError = nil
        do {
            let response: ListResponse<ProductCategory> = try await apiClient.request(.productCategories)
            categories = response.list
        } catch { categoryError = "分类暂未加载，点击重试" }
    }
    func loadMore() async {
        guard hasMore, !isLoading, !isLoadingMore else { return }
        let next = currentPage + 1, current = generation, request = endpoint(page: currentPage + 1)
        isLoadingMore = true; errorMessage = nil
        defer { if generation == current { isLoadingMore = false } }
        do {
            let response: PageResponse<ShopProduct> = try await apiClient.request(request)
            guard generation == current else { return }
            let ids = Set(products.map(\.id))
            products.append(contentsOf: response.list.filter { !ids.contains($0.id) })
            total = response.total; currentPage = next
        } catch {
            if generation == current { errorMessage = error.localizedDescription }
        }
    }
    func selectCategory(_ id: Int64?) { selectedCategoryId = id; search() }
    func search() { Task { await load() } }
    func reset() { selectedCategoryId = nil; keyword = ""; sort = "newest"; inStock = false; search() }

    static let previewProducts: [ShopProduct] = [
        ShopProduct(id: 1, productNo: "P001", name: "灵隐檀香佛珠",
                    categoryId: 1, categoryName: "佛珠",
                    description: "精选檀香木，法师开光加持。",
                    mainImage: "", status: "on_shelf", price: 268, marketPrice: nil,
                    stock: 2380, tags: "开光加持", skus: nil, images: nil,
                    createTime: "2026-06-01", updateTime: "2026-06-01"),
        ShopProduct(id: 2, productNo: "P002", name: "祈福香道套装",
                    categoryId: 2, categoryName: "香道",
                    description: "祈福香道套装，居家供养。",
                    mainImage: "", status: "on_shelf", price: 168, marketPrice: nil,
                    stock: 1856, tags: "热销", skus: nil, images: nil,
                    createTime: "2026-06-01", updateTime: "2026-06-01"),
        ShopProduct(id: 3, productNo: "P003", name: "金边心经抄本",
                    categoryId: 3, categoryName: "经书",
                    description: "金边心经抄本，精装版。",
                    mainImage: "product-jingshu", status: "on_shelf", price: 98, marketPrice: nil,
                    stock: 963, tags: "新品", skus: nil, images: nil,
                    createTime: "2026-06-01", updateTime: "2026-06-01"),
        ShopProduct(id: 4, productNo: "P004", name: "灵隐护身符",
                    categoryId: 4, categoryName: "护身符",
                    description: "灵隐护身符，开光加持。",
                    mainImage: "", status: "on_shelf", price: 58, marketPrice: nil,
                    stock: 3420, tags: "限定", skus: nil, images: nil,
                    createTime: "2026-06-01", updateTime: "2026-06-01"),
        ShopProduct(id: 5, productNo: "P005", name: "祥瑞平安手串",
                    categoryId: 1, categoryName: "佛珠",
                    description: "祥瑞平安手串，天然菩提。",
                    mainImage: "", status: "on_shelf", price: 198, marketPrice: nil,
                    stock: 1205, tags: "开光加持", skus: nil, images: nil,
                    createTime: "2026-06-01", updateTime: "2026-06-01"),
        ShopProduct(id: 6, productNo: "P006", name: "禅意线香礼盒",
                    categoryId: 2, categoryName: "香道",
                    description: "禅意线香礼盒，老山檀香。",
                    mainImage: "", status: "on_shelf", price: 128, marketPrice: nil,
                    stock: 2710, tags: "热销", skus: nil, images: nil,
                    createTime: "2026-06-01", updateTime: "2026-06-01"),
    ]
}

@MainActor
final class ShopCartStore: ObservableObject {
    static let shared = ShopCartStore()

    @Published private(set) var items: [ShopCartItem] = [] {
        didSet { persist() }
    }

    private var storageKey: String { "shop.cart.items.v2." + (AuthStore.shared.isLoggedIn ? AuthStore.shared.userId : "guest") }

    private init() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([ShopCartItem].self, from: data) else { return }
        items = decoded.filter { $0.quantity > 0 }
    }

    func reloadForAccount() {
        if let data=UserDefaults.standard.data(forKey:storageKey),let decoded=try? JSONDecoder().decode([ShopCartItem].self,from:data){items=decoded.filter{$0.quantity>0}}else{items=[]}
    }
    var itemCount: Int { items.reduce(0) { $0 + $1.quantity } }
    var total: Double { items.reduce(0) { $0 + $1.subtotal } }

    func add(product: ShopProduct, sku: ProductSku?, quantity: Int) {
        let skuId = sku?.id ?? 0
        let key = "\(product.id):\(skuId)"
        guard product.status == "on_shelf", (sku?.stock ?? product.stock) > 0 else { return }
        let safeQuantity = max(1, min(99, min(quantity, sku?.stock ?? product.stock)))
        if let index = items.firstIndex(where: { $0.id == key }) {
            var updated = items[index]
            updated.quantity = min(99, min(updated.stock, updated.quantity + safeQuantity))
            items[index] = updated
            return
        }
        items.append(ShopCartItem(
            productId: product.id,
            skuId: skuId,
            productName: product.name,
            skuSpec: sku.map { "\($0.specName)：\($0.specValue)" } ?? "默认规格",
            image: product.mainImage,
            unitPrice: sku?.price ?? product.price,
            quantity: safeQuantity,
            stock: sku?.stock ?? product.stock,
            isExperience: product.isExperience
        ))
    }

    func setQuantity(for id: String, quantity: Int) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        if quantity <= 0 {
            items.remove(at: index)
        } else {
            items[index].quantity = min(99, min(items[index].stock, quantity))
        }
    }

    func remove(_ item: ShopCartItem) { items.removeAll { $0.id == item.id } }
    func clear() { items.removeAll() }
    /// Only remove the purchased quantities, preserving unselected and subsequently added items.
    func consume(_ purchased: [ShopCartItem]) {
        items = Self.remaining(items, after: purchased)
    }
    static func remaining(_ items: [ShopCartItem], after purchased: [ShopCartItem]) -> [ShopCartItem] {
        items.compactMap { item in
            var remaining = item
            remaining.quantity -= purchased.filter { $0.id == item.id }.reduce(0) { $0 + $1.quantity }
            return remaining.quantity > 0 ? remaining : nil
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

@MainActor
final class ShopProductDetailViewModel: ObservableObject {
    @Published var product: ShopProduct
    @Published var isLoading = false
    @Published var verified = false
    @Published var errorMessage: String?

    private let apiClient: APIClient

    init(product: ShopProduct, apiClient: APIClient = .shared) {
        self.product = product
        self.apiClient = apiClient
    }

    func load() async {
        isLoading = true
        verified = false
        defer { isLoading = false }
        do {
            product = try await apiClient.request(.productById(product.id))
            verified = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class ShopCheckoutViewModel: ObservableObject {
    @Published var addresses: [UserAddress] = []
    @Published var selectedAddressId: Int64?
    @Published var note = ""
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    private var pendingRequest:ShopOrderCreateRequest?
    private var createdOrderID:Int64?
    @Published var completedOrder: ShopOrder?
    @Published var payment: PaymentRecord?

    private let apiClient: APIClient
    private let authStore: AuthStore

    init(apiClient: APIClient = .shared, authStore: AuthStore? = nil) {
        self.apiClient = apiClient
        self.authStore = authStore ?? .shared
    }

    func loadAddresses() async {
        guard authStore.isLoggedIn else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let response: ListResponse<UserAddress> = try await apiClient.request(.addressList)
            addresses = response.list
            selectedAddressId = response.list.first(where: { $0.isDefault })?.id ?? response.list.first?.id
            errorMessage = nil
        } catch {
            addresses = []
            errorMessage = error.localizedDescription
        }
    }

    func submit(items: [ShopCartItem]) async -> Bool {
        guard !isSubmitting, let addressId = selectedAddressId, !items.isEmpty else { return false }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        let account = authStore.userId
        guard authStore.isLoggedIn, pendingRequest == nil || pendingRequest?.userId == account else { return false }
        let request = pendingRequest ?? ShopOrderCreateRequest(
            requestId: UUID().uuidString.lowercased(),
            userId: authStore.userId,
            addressId: addressId,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            items: items.map {
                ShopOrderItemRequest(productId: $0.productId, skuId: $0.skuId,
                                     quantity: $0.quantity, productName: $0.productName,
                                     skuSpec: $0.skuSpec, price: $0.unitPrice, image: $0.image)
            }
        )

        do {
            if pendingRequest == nil {
                guard !items.contains(where: { $0.isExperience == true }) || items.allSatisfy({ $0.isExperience == true }) else { throw NSError(domain: "Commerce", code: 409, userInfo: [NSLocalizedDescriptionKey: "体验商品与普通商品请分开结算"]) }
                for item in items {
                    let p:ShopProduct=try await apiClient.request(.productById(item.productId))
                    let sku=p.skus?.first(where:{$0.id==item.skuId})
                    guard (p.isExperience == true) == (item.isExperience == true) else { throw NSError(domain: "Commerce", code: 409, userInfo: [NSLocalizedDescriptionKey: "商品信息已更新，请重新选择后结算"]) }
                    guard p.status=="on_shelf",(item.skuId==0 || sku != nil),(sku?.stock ?? p.stock)>=item.quantity,abs((sku?.price ?? p.price)-item.unitPrice)<0.005 else {throw NSError(domain:"Commerce",code:409,userInfo:[NSLocalizedDescriptionKey:"\(item.productName) 的价格或库存已变化，请重新加入购物车后确认"])}
                }
                guard authStore.userId == account else { return false }
                pendingRequest=request
            }
            if createdOrderID == nil {let created:ShopOrderCreateResult=try await apiClient.request(.shopOrderCreate(pendingRequest!));createdOrderID=created.id}
            guard authStore.userId == account else { return false }
            let order: ShopOrder = try await apiClient.request(.shopOrderById(createdOrderID!))
            guard authStore.userId == account else { return false }
            completedOrder=order
            let paymentResult: PaymentCreateResult = try await apiClient.request(
                .paymentCreate(PaymentCreateRequest(orderType: "shop_order", orderNo: order.orderNo,
                                                     amount: order.payAmount, channel: "mock",
                                                     userId: authStore.userId))
            )
            let paymentRecord: PaymentRecord = try await apiClient.request(.paymentById(paymentResult.id))
            completedOrder = order
            payment = paymentRecord
            return authStore.userId == account && paymentRecord.status == "success"
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

@MainActor
final class ShopOrderListViewModel: ObservableObject {
    @Published var orders: [ShopOrder] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) { self.apiClient = apiClient }

    func load(status: String? = nil) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response: PageResponse<ShopOrder> = try await apiClient.request(.shopOrders(status: status, page: 1, size: 50))
            orders = response.list
            errorMessage = nil
        } catch {
            orders = []
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - 商城分类（含图标，对齐 shop.html）
struct ShopCategory: Identifiable, Hashable {
    let id: Int64?       // nil 表示「全部」
    let name: String
    let icon: String     // SF Symbol 名称


}
