//
//  ServiceViewModel.swift
//  DongFangApp
//
//  服务详情共享 ViewModel：根据 ServiceType 加载对应服务列表。
//  支持 7 种法事/供养服务：祈福/开光/敬香/点灯/法事/太岁/许愿。
//

import SwiftUI

@MainActor
final class ServiceViewModel: ObservableObject {
    let serviceType: ServiceType

    @Published var blessingServices: [BlessingService] = []
    @Published var masters: [Master] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var selectedMasterId: String? = nil

    private let apiClient: APIClient

    init(serviceType: ServiceType, apiClient: APIClient = .shared) {
        self.serviceType = serviceType
        self.apiClient = apiClient
    }

    /// 价格区间展示
    var priceRangeText: String {
        let prices = blessingServices.map { $0.price }.filter { $0 > 0 }
        guard let min = prices.min(), let max = prices.max() else {
            return "¥\(defaultMin) - ¥\(defaultMax)"
        }
        return min == max ? "¥\(Int(min))" : "¥\(Int(min)) - ¥\(Int(max))"
    }

    private var defaultMin: Double {
        switch serviceType {
        case .blessing, .vow:        return 88
        case .lamp, .incense:        return 38
        case .consecration:          return 168
        case .rite:                  return 388
        case .taisui:                return 268
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
        case .failure:
            self.masters = Master.mockData
            self.selectedMasterId = Master.mockData.first?.id
        }

        switch servicesRes {
        case .success(let list):
            self.blessingServices = list
        case .failure(let error):
            self.blessingServices = mockServices
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func fetchMasters() async -> Result<[Master], Error> {
        do {
            let resp: PageResponse<Master> = try await apiClient.request(
                .masters(type: nil, templeId: nil, page: 1, size: 20))
            return .success(resp.list)
        } catch {
            return .failure(error)
        }
    }

    private func fetchServices() async -> Result<[BlessingService], Error> {
        // 暂用第一个寺院的服务列表作为服务数据源
        do {
            let templeResp: PageResponse<Temple> = try await apiClient.request(
                .temples(sect: nil, type: nil, page: 1, size: 1))
            guard let templeId = templeResp.list.first?.id else {
                return .success([])
            }
            let services: [TempleServiceInfo] = try await apiClient.request(
                .templeServices(templeId))
            let mapped = services
                .filter { $0.serviceName.contains(serviceType.rawValue) || $0.serviceCode.contains(serviceType.rawValue) }
                .map { info in
                    BlessingService(id: info.id,
                                    serviceCode: info.serviceCode,
                                    serviceName: info.serviceName,
                                    templeCode: info.templeCode,
                                    templeName: "",
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

    // MARK: - Mock 数据兜底
    private var mockServices: [BlessingService] {
        [
            BlessingService(id: 1, serviceCode: "S001",
                            serviceName: "\(serviceType.rawValue)·基础",
                            templeCode: "T001", templeName: "灵隐寺",
                            masterCode: "M001", masterName: "智海法师",
                            price: defaultMin, description: "基础 \(serviceType.rawValue) 法事",
                            status: "on_shelf"),
            BlessingService(id: 2, serviceCode: "S002",
                            serviceName: "\(serviceType.rawValue)·标准",
                            templeCode: "T002", templeName: "白云观",
                            masterCode: "M002", masterName: "清风道长",
                            price: defaultMin * 2,
                            description: "标准 \(serviceType.rawValue) 法事，含完整仪轨",
                            status: "on_shelf"),
            BlessingService(id: 3, serviceCode: "S003",
                            serviceName: "\(serviceType.rawValue)·尊享",
                            templeCode: "T004", templeName: "大昭寺",
                            masterCode: "M004", masterName: "扎西多吉活佛",
                            price: defaultMax,
                            description: "尊享 \(serviceType.rawValue) 法事，活佛主持",
                            status: "on_shelf")
        ]
    }
}
