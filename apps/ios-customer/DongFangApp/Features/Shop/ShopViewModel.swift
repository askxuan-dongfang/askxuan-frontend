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
    @Published var selectedCategoryId: Int64? = nil
    @Published var keyword: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    /// 商城分类（含「全部」，对齐 shop.html 原型 8 个分类 + 全部）
    let shopCategories: [ShopCategory] = ShopCategory.all

    private let apiClient: APIClient
    private var currentPage: Int = 1
    private let pageSize: Int = 20
    private var hasMore: Bool = true

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        currentPage = 1
        hasMore = true

        async let productsResult: Result<[ShopProduct], Error> = fetchProducts(isRefresh: true)
        async let categoriesResult: Result<[ProductCategory], Error> = fetchCategories()

        let (productsRes, categoriesRes) = await (productsResult, categoriesResult)

        switch productsRes {
        case .success(let list):
            self.products = list
        case .failure(let error):
            self.products = []
            self.errorMessage = error.localizedDescription
        }

        switch categoriesRes {
        case .success(let list):
            self.categories = list
        case .failure(let error):
            self.categories = []
            if self.errorMessage == nil { self.errorMessage = error.localizedDescription }
        }

        isLoading = false
    }

    func loadMore() async {
        guard hasMore, !isLoading else { return }
        let nextPage = currentPage + 1
        do {
            let resp: PageResponse<ShopProduct> = try await apiClient.request(
                .products(categoryId: selectedCategoryId,
                          keyword: keyword.isEmpty ? nil : keyword,
                          page: nextPage, size: pageSize))
            if !resp.list.isEmpty {
                self.products.append(contentsOf: resp.list)
                self.currentPage = nextPage
            }
            self.hasMore = resp.list.count == pageSize
        } catch {
            self.hasMore = false
        }
    }

    func selectCategory(_ id: Int64?) {
        selectedCategoryId = id
        Task { await load() }
    }

    func search() {
        Task { await load() }
    }

    private func fetchProducts(isRefresh: Bool) async -> Result<[ShopProduct], Error> {
        do {
            let resp: PageResponse<ShopProduct> = try await apiClient.request(
                .products(categoryId: selectedCategoryId,
                          keyword: keyword.isEmpty ? nil : keyword,
                          page: 1, size: pageSize))
            return .success(resp.list)
        } catch {
            return .failure(error)
        }
    }

    private func fetchCategories() async -> Result<[ProductCategory], Error> {
        do {
            let resp: ListResponse<ProductCategory> = try await apiClient.request(.productCategories)
            return .success(resp.list)
        } catch {
            return .failure(error)
        }
    }

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

    private let storageKey = "shop.cart.items.v1"

    private init() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([ShopCartItem].self, from: data) else { return }
        items = decoded.filter { $0.quantity > 0 }
    }

    var itemCount: Int { items.reduce(0) { $0 + $1.quantity } }
    var total: Double { items.reduce(0) { $0 + $1.subtotal } }

    func add(product: ShopProduct, sku: ProductSku?, quantity: Int) {
        let skuId = sku?.id ?? 0
        let key = "\(product.id):\(skuId)"
        let safeQuantity = max(1, min(quantity, sku?.stock ?? product.stock))
        if let index = items.firstIndex(where: { $0.id == key }) {
            var updated = items[index]
            updated.quantity = min(updated.stock, updated.quantity + safeQuantity)
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
            stock: sku?.stock ?? product.stock
        ))
    }

    func setQuantity(for id: String, quantity: Int) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        if quantity <= 0 {
            items.remove(at: index)
        } else {
            items[index].quantity = min(items[index].stock, quantity)
        }
    }

    func remove(_ item: ShopCartItem) { items.removeAll { $0.id == item.id } }
    func clear() { items.removeAll() }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

@MainActor
final class ShopProductDetailViewModel: ObservableObject {
    @Published var product: ShopProduct
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiClient: APIClient

    init(product: ShopProduct, apiClient: APIClient = .shared) {
        self.product = product
        self.apiClient = apiClient
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            product = try await apiClient.request(.productById(product.id))
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
    @Published var completedOrder: ShopOrder?
    @Published var payment: PaymentRecord?

    private let apiClient: APIClient
    private let authStore: AuthStore

    init(apiClient: APIClient = .shared, authStore: AuthStore = .shared) {
        self.apiClient = apiClient
        self.authStore = authStore
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

        let request = ShopOrderCreateRequest(
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
            let created: ShopOrderCreateResult = try await apiClient.request(.shopOrderCreate(request))
            let order: ShopOrder = try await apiClient.request(.shopOrderById(created.id))
            let paymentResult: PaymentCreateResult = try await apiClient.request(
                .paymentCreate(PaymentCreateRequest(orderType: "shop_order", orderNo: order.orderNo,
                                                     amount: order.payAmount, channel: "mock",
                                                     userId: authStore.userId))
            )
            let paymentRecord: PaymentRecord = try await apiClient.request(.paymentById(paymentResult.id))
            completedOrder = order
            payment = paymentRecord
            return paymentRecord.status == "success"
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

    static let all: [ShopCategory] = [
        ShopCategory(id: nil, name: "全部", icon: "square.grid.2x2"),
        ShopCategory(id: 1, name: "佛珠", icon: "circle.hexagongrid"),
        ShopCategory(id: 2, name: "香道", icon: "flame"),
        ShopCategory(id: 3, name: "经书", icon: "book"),
        ShopCategory(id: 4, name: "护身符", icon: "shield"),
        ShopCategory(id: 5, name: "法器", icon: "bell"),
        ShopCategory(id: 6, name: "禅茶", icon: "cup.and.saucer"),
        ShopCategory(id: 7, name: "文具", icon: "pencil"),
        ShopCategory(id: 8, name: "定制", icon: "sparkles"),
    ]
}
