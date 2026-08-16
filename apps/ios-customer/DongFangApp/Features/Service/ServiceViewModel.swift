//
//  ServiceViewModel.swift
//  DongFangApp
//
//  服务详情共享 ViewModel：根据 ServiceType 加载对应服务列表。
//  支持平台 13 种标准服务。
//  双轨制：从寺院详情进入时携带寺院上下文（本寺价格 + 本寺可指定法师 + 立即预约）；
//  无寺院上下文时回退为「首个开通该服务的寺院」并同样支持直接预约。
//

import SwiftUI

@MainActor
final class ServiceViewModel: ObservableObject {
    let serviceType: ServiceType
    /// 寺院上下文（从寺院详情进入时非空）
    let templeId: String?
    let templeName: String?

    @Published var blessingServices: [BlessingService] = []
    @Published var masters: [Master] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var selectedMasterId: String? = nil
    /// 指定本寺法师（nil = 全寺执行）
    @Published var selectedTempleMasterId: String? = nil

    private let apiClient: APIClient

    init(serviceType: ServiceType, templeId: String? = nil, templeName: String? = nil, apiClient: APIClient = .shared) {
        self.serviceType = serviceType
        self.templeId = templeId
        self.templeName = templeName
        self.apiClient = apiClient
    }

    /// 实际预约的寺院（有上下文用上下文，否则用服务列表第一条的寺院）
    var resolvedTempleId: String? {
        templeId ?? blessingServices.first?.templeCode
    }
    var resolvedTempleName: String? {
        templeName ?? blessingServices.first?.templeName
    }
    /// 用户选中的本寺法师（nil = 全寺执行）
    var selectedTempleMaster: Master? {
        masters.first { $0.id == selectedTempleMasterId }
    }

    /// 价格区间展示
    var priceRangeText: String {
        let prices = blessingServices.map { $0.price }.filter { $0 > 0 }
        guard let min = prices.min(), let max = prices.max() else {
            return "暂无报价"
        }
        return min == max ? "¥\(Int(min))" : "¥\(Int(min)) - ¥\(Int(max))"
    }

    private var defaultMin: Double {
        switch serviceType {
        case .blessing, .vow, .love, .career, .health, .study: return 88
        case .lamp, .incense:        return 38
        case .consecration, .wealth: return 168
        case .rite:                  return 388
        case .taisui, .fengshui:     return 268
        case .diy:                   return 188
        }
    }

    private var defaultMax: Double { defaultMin * 3 }

    /// 加载服务数据：拉取法师列表 + 服务列表
    func load() async {
        isLoading = true
        errorMessage = nil

        async let mastersResult: Result<[Master], Error> = fetchMasters()
        async let servicesResult: Result<[BlessingService], Error> = fetchServices()

        let (mastersRes, servicesRes) = await (mastersResult, servicesResult)

        switch mastersRes {
        case .success(let list):
            self.masters = list
            self.selectedMasterId = list.first?.id
            if self.selectedTempleMasterId == nil || !list.contains(where: { $0.id == self.selectedTempleMasterId }) {
                self.selectedTempleMasterId = nil
            }
        case .failure(let error):
            self.masters = []
            self.selectedMasterId = nil
            self.selectedTempleMasterId = nil
            self.errorMessage = error.localizedDescription
        }

        switch servicesRes {
        case .success(let list):
            self.blessingServices = list
        case .failure(let error):
            self.blessingServices = []
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// 法师列表：寺院上下文存在时仅取本寺、且按当前服务可执行筛选（可指定本寺法师）；
    /// 无上下文时取全平台可按该服务执行的大师（兼容从首页分类进入）。
    private func fetchMasters() async -> Result<[Master], Error> {
        do {
            let resp: PageResponse<Master> = try await apiClient.request(
                .masters(type: nil, templeId: templeId, manageBy: "temple",
                         serviceCode: serviceType.code, page: 1, size: 20))
            return .success(resp.list)
        } catch {
            return .failure(error)
        }
    }

    /// 服务套餐：有寺院上下文时读取该寺院服务（本寺价格）；否则取首个开通该服务的寺院。
    private func fetchServices() async -> Result<[BlessingService], Error> {
        do {
            if let tid = templeId, !tid.isEmpty {
                let services: [TempleServiceInfo] = try await apiClient.request(.templeServices(tid))
                let mapped = services
                    .filter { $0.status == "on_shelf" && ServiceType.from(serviceCode: $0.serviceCode) == serviceType }
                    .map { info in
                        BlessingService(id: info.id,
                                        serviceCode: info.serviceCode,
                                        serviceName: info.serviceName,
                                        templeCode: info.templeCode,
                                        templeName: templeName ?? "",
                                        masterCode: nil,
                                        masterName: "",
                                        price: info.price,
                                        description: "",
                                        status: info.status)
                    }
                return .success(mapped)
            }

            // 无寺院上下文：按标准服务编码找到已开通的寺院，再读取其实际服务。
            let templeResp: PageResponse<Temple> = try await apiClient.request(
                .temples(sect: nil, type: nil, serviceCode: serviceType.code, page: 1, size: 1))
            guard let temple = templeResp.list.first else {
                return .success([])
            }
            let services: [TempleServiceInfo] = try await apiClient.request(.templeServices(temple.id))
            let mapped = services
                .filter { ServiceType.from(serviceCode: $0.serviceCode) == serviceType }
                .map { info in
                    BlessingService(id: info.id,
                                    serviceCode: info.serviceCode,
                                    serviceName: info.serviceName,
                                    templeCode: info.templeCode,
                                    templeName: temple.name,
                                    masterCode: nil,
                                    masterName: "",
                                    price: info.price,
                                    description: "",
                                    status: info.status)
                }
            return .success(mapped)
        } catch {
            return .failure(error)
        }
    }

}
