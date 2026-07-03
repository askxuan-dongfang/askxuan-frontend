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
    @Published var cartCount: Int = 3

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
            self.products = ShopViewModel.mockProducts
            self.errorMessage = error.localizedDescription
        }

        switch categoriesRes {
        case .success(let list):
            self.categories = list
        case .failure:
            self.categories = mockCategories
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

    // MARK: - Mock 兜底（对齐 shop.html 原型商品）
    private var mockCategories: [ProductCategory] {
        [
            ProductCategory(id: 1, parentId: nil, name: "佛珠", level: 1, sort: 1, children: nil),
            ProductCategory(id: 2, parentId: nil, name: "香道", level: 1, sort: 2, children: nil),
            ProductCategory(id: 3, parentId: nil, name: "经书", level: 1, sort: 3, children: nil),
            ProductCategory(id: 4, parentId: nil, name: "护身符", level: 1, sort: 4, children: nil),
            ProductCategory(id: 5, parentId: nil, name: "法器", level: 1, sort: 5, children: nil),
            ProductCategory(id: 6, parentId: nil, name: "禅茶", level: 1, sort: 6, children: nil),
            ProductCategory(id: 7, parentId: nil, name: "文具", level: 1, sort: 7, children: nil),
            ProductCategory(id: 8, parentId: nil, name: "定制", level: 1, sort: 8, children: nil),
        ]
    }

    static let mockProducts: [ShopProduct] = [
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
