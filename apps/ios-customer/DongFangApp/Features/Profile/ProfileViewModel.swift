//
//  ProfileViewModel.swift
//  DongFangApp
//
//  我的页面 ViewModel：用户资料 + 最近预约 + 收货地址。
//

import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var recentBookings: [Booking] = []
    @Published var addresses: [UserAddress] = []
    @Published var coupons: [UserCoupon] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private let apiClient: APIClient
    private let authStore: AuthStore

    init(apiClient: APIClient = .shared, authStore: AuthStore = .shared) {
        self.apiClient = apiClient
        self.authStore = authStore
    }

    /// 是否已登录
    var isLoggedIn: Bool { authStore.isLoggedIn }

    /// 用户昵称（优先 AuthStore，回退 profile）
    var displayName: String {
        if !authStore.nickname.isEmpty { return authStore.nickname }
        return profile?.nickname ?? "点击登录"
    }

    /// 用户头像 URL
    var avatarURL: String {
        if !authStore.avatar.isEmpty { return authStore.avatar }
        return profile?.avatar ?? ""
    }

    /// 手机号（脱敏）
    var maskedMobile: String {
        if !authStore.mobile.isEmpty {
            return maskPhone(authStore.mobile)
        }
        return profile?.maskedMobile ?? "—"
    }

    /// 预约总数
    var bookingCount: Int { recentBookings.count }

    /// 地址总数
    var addressCount: Int { addresses.count }

    var availableCouponCount: Int { coupons.filter { $0.status == "unused" }.count }

    /// 默认地址
    var defaultAddress: UserAddress? { addresses.first(where: { $0.isDefault }) }

    /// 待确认预约数（用于订单中心角标）
    var pendingBookingCount: Int {
        recentBookings.filter { $0.statusEnum == .pending }.count
    }

    /// 已确认（待进行）预约数（用于订单中心角标）
    var confirmedBookingCount: Int {
        recentBookings.filter { $0.statusEnum == .confirmed }.count
    }

    /// 当前请求是否有数据（用于 View 判断空状态）
    var hasAnyData: Bool {
        profile != nil || !recentBookings.isEmpty || !addresses.isEmpty
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        let userId = authStore.userId

        async let profileResult = fetchProfile()
        async let bookingsResult = fetchRecentBookings(userId: userId)
        async let addressesResult = fetchAddresses()
        async let couponsResult = fetchCoupons(userId: userId)

        let (p, b, a, c) = await (profileResult, bookingsResult, addressesResult, couponsResult)

        // API 失败时不再回退 Mock 数据：置空并记录错误，由 View 展示空状态/错误提示
        var failedParts: [String] = []

        switch p {
        case .success(let prof):
            self.profile = prof
        case .failure:
            self.profile = nil
            failedParts.append("用户资料")
        }

        switch b {
        case .success(let list):
            self.recentBookings = Array(list.prefix(3))
        case .failure:
            self.recentBookings = []
            failedParts.append("订单")
        }

        switch a {
        case .success(let list):
            self.addresses = list
        case .failure:
            self.addresses = []
            failedParts.append("地址")
        }

        switch c {
        case .success(let list):
            self.coupons = list
        case .failure:
            self.coupons = []
            failedParts.append("优惠券")
        }

        if !failedParts.isEmpty {
            self.errorMessage = "加载失败：\(failedParts.joined(separator: "、"))"
        }

        isLoading = false
    }

    func logout() {
        authStore.logout()
        self.profile = nil
        self.recentBookings = []
        self.addresses = []
        self.coupons = []
    }

    // MARK: - 网络请求

    private func fetchProfile() async -> Result<UserProfile, Error> {
        do {
            let prof: UserProfile = try await apiClient.request(.userProfile)
            return .success(prof)
        } catch {
            return .failure(error)
        }
    }

    private func fetchRecentBookings(userId: String) async -> Result<[Booking], Error> {
        do {
            let resp: PageResponse<Booking> = try await apiClient.request(
                .bookings(userId: userId, status: nil, page: 1, size: 5))
            return .success(resp.list)
        } catch {
            return .failure(error)
        }
    }

    private func fetchAddresses() async -> Result<[UserAddress], Error> {
        do {
            let resp: ListResponse<UserAddress> = try await apiClient.request(.addressList)
            return .success(resp.list)
        } catch {
            return .failure(error)
        }
    }

    private func fetchCoupons(userId: String) async -> Result<[UserCoupon], Error> {
        do {
            let resp: PageResponse<UserCoupon> = try await apiClient.request(
                .myCoupons(userId: userId, status: nil, page: 1, size: 100)
            )
            return .success(resp.list)
        } catch {
            return .failure(error)
        }
    }

    // MARK: - 工具

    private func maskPhone(_ phone: String) -> String {
        guard phone.count >= 11 else { return phone }
        let start = phone.prefix(3)
        let end = phone.suffix(4)
        return "\(start)****\(end)"
    }
}
