//
//  UserProfile.swift
//  DongFangApp
//
//  用户资料 + 收货地址（对齐 user-service）+ 请求体。
//

import Foundation

/// 用户资料
struct UserProfile: Codable {
    let userId: Int64?
    let nickname: String
    let avatar: String
    let mobile: String
    let gender: String          // male/female/unknown
    let birthday: String?
    let region: String?
    let bio: String?

    var genderDisplay: String {
        switch gender {
        case "male":   return "男"
        case "female": return "女"
        default:       return "未知"
        }
    }

    var maskedMobile: String {
        guard mobile.count >= 11 else { return mobile }
        let start = mobile.prefix(3)
        let end = mobile.suffix(4)
        return "\(start)****\(end)"
    }

    // MARK: - 资产/统计相关展示字段
    // 注：当前 user-service 暂未返回功德值/积分/优惠券/功德金余额字段，
    // 以下计算属性返回 nil，由 View 层显示 "—" 占位；后端补齐后在此接入即可。
    var meritValueText: String? { nil }
    var pointsText: String? { nil }
    var couponCountText: String? { nil }
    var meritBalanceText: String? { nil }
}

extension UserProfile {
    static let mock = UserProfile(
        userId: 1001, nickname: "善信居士", avatar: "",
        mobile: "13800138000", gender: "male", birthday: "1990-01-01",
        region: "浙江杭州", bio: "愿以善念，广结善缘。"
    )
}

/// 收货地址
struct UserAddress: Codable, Identifiable, Hashable {
    let id: Int64
    let userId: Int64?
    let name: String
    let phone: String
    let province: String
    let city: String
    let district: String
    let detail: String
    let isDefault: Bool
    let createTime: String?

    var fullAddress: String {
        "\(province)\(city)\(district)\(detail)"
    }

    var maskedPhone: String {
        guard phone.count >= 11 else { return phone }
        return "\(phone.prefix(3))****\(phone.suffix(4))"
    }
}

extension UserAddress {
    static let mockAddresses: [UserAddress] = [
        UserAddress(id: 1, userId: 1001, name: "张三", phone: "13800138000",
                    province: "浙江省", city: "杭州市", district: "西湖区",
                    detail: "文三路 100 号 3 栋 501 室", isDefault: true, createTime: "2026-06-01"),
        UserAddress(id: 2, userId: 1001, name: "张三", phone: "13800138000",
                    province: "北京市", city: "北京市", district: "海淀区",
                    detail: "中关村大街 1 号", isDefault: false, createTime: "2026-06-15")
    ]
}

// MARK: - 认证请求体

struct LoginRequest: Codable {
    let phone: String
    let code: String?
    let account: String?
    let password: String?
}

/// 注册请求体（user-service /user/register）
struct RegisterRequest: Codable {
    let mobile: String
    let code: String
    let nickname: String
}

/// 注册响应
struct RegisterResponse: Codable {
    let userId: Int64?
}

/// 登录响应
struct LoginResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int64?
    let userInfo: LoginUserInfo?
    let imToken: String?
}

struct LoginUserInfo: Codable {
    let userId: Int64?
    let nickname: String?
    let avatar: String?
    let mobile: String?
}

/// 刷新响应
struct RefreshResponse: Codable {
    let accessToken: String
    let expiresIn: Int64?
}

// MARK: - 用户资料请求体

struct UpdateProfileRequest: Codable {
    let nickname: String?
    let avatar: String?
    let gender: String?
    let birthday: String?
    let region: String?
    let bio: String?
}

// MARK: - 地址请求体

struct AddressCreateRequest: Codable {
    let name: String
    let phone: String
    let province: String
    let city: String
    let district: String
    let detail: String
    let isDefault: Bool
}

struct AddressUpdateRequest: Codable {
    let name: String?
    let phone: String?
    let province: String?
    let city: String?
    let district: String?
    let detail: String?
    let isDefault: Bool?
}

struct UserReview: Codable, Identifiable {
    let id: Int64
    let reviewNo: String
    let userId: String
    let targetType: String
    let targetId: String
    let masterCode: String
    let rating: Int
    let content: String
    let images: String
    let status: String
    let createTime: String
}

struct UserCoupon: Codable, Identifiable {
    let id: Int64
    let couponId: Int64
    let couponNo: String
    let userId: String
    let status: String
    let orderNo: String
    let useTime: String
    let createdAt: String
    let name: String
    let type: String
    let value: Double
    let minAmount: Double
    let endTime: String

    var valueText: String {
        type == "discount" ? "\(Int(value * 10))折" : String(format: "¥%.0f", value)
    }

    var statusText: String {
        switch status {
        case "used": return "已使用"
        case "expired": return "已过期"
        default: return "可使用"
        }
    }
}

/// 未读数响应
struct UnreadCountResponse: Codable {
    let count: Int64
}
