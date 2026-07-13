//
//  Endpoint.swift
//  MasterApp
//
//  API 端点定义：路径、HTTP 方法、查询参数、请求体。
//  路径均为相对路径（不含 /api/v1 前缀，BaseURL 已包含）。
//  管理台路径前缀 /admin；法师身份由 JWT Claims 携带，禁止 URL 传参。
//

import Foundation

/// HTTP 方法
enum HTTPMethod: String {
    case GET
    case POST
    case PUT
    case DELETE
    case PATCH
}

/// API 端点枚举（法师工作台）
enum Endpoint {
    // MARK: - 认证
    /// POST auth/admin/login（管理台登录，role=master）
    case adminLogin(AdminLoginRequest)
    /// POST auth/refresh
    case authRefresh(refreshToken: String)

    // MARK: - 预约（法师工作台）
    /// GET admin/masters/bookings
    case masterBookings(status: String?, page: Int, size: Int)
    /// GET admin/masters/bookings/{id}
    case masterBookingDetail(id: String)
    /// PUT admin/masters/bookings/{id}/confirm
    case masterBookingConfirm(id: String, remark: String?)
    /// PUT admin/masters/bookings/{id}/complete
    case masterBookingComplete(id: String, remark: String?)

    // MARK: - 加持任务
    /// GET admin/masters/blessing-tasks
    case blessingTasks(status: String?, page: Int, size: Int)
    /// GET admin/masters/blessing-tasks/{id}
    case blessingTaskDetail(id: Int64)
    /// PUT admin/masters/blessing-tasks/{id}/accept
    case blessingTaskAccept(id: Int64)
    /// PUT admin/masters/blessing-tasks/{id}/start
    case blessingTaskStart(id: Int64)
    /// PUT admin/masters/blessing-tasks/{id}/complete
    case blessingTaskComplete(id: Int64, certificateUrls: [String])
    /// PUT admin/masters/blessing-tasks/{id}/reject
    case blessingTaskReject(id: Int64)

    // MARK: - 日程
    /// GET admin/masters/schedules
    case masterSchedules(date: String?, page: Int, size: Int)
    /// PUT admin/masters/schedules
    case masterScheduleUpdate(date: String, timeSlots: [String], status: String)

    // MARK: - 收益
    /// GET admin/masters/earnings/summary
    case earningsSummary
    /// GET admin/masters/earnings/details
    case earningsDetails(serviceType: String?, page: Int, size: Int)

    // MARK: - 法师资料
    /// GET admin/masters/profile
    case masterProfile
    /// PUT admin/masters/profile
    case masterProfileUpdate(MasterProfileUpdateRequest)

    // MARK: - 消息（master-scoped from JWT）
    /// GET admin/messages/master
    case masterMessages(isRead: Int, page: Int, size: Int)
    /// PUT admin/messages/master/{id}/read
    case masterMessageRead(id: Int64)
    /// POST messages/device-token
    case registerDeviceToken(DeviceTokenRegisterRequest)

    // MARK: - 评价
    /// GET admin/masters/reviews
    case masterReviews(rating: Int?, page: Int, size: Int)

    // MARK: - 社区内容 / 大师广场
    /// GET admin/masters/community/posts
    case masterCommunityPosts(status: String?, page: Int, size: Int)
    /// POST admin/masters/community/posts
    case masterCommunityPostCreate(MasterContentCreateRequest)
    /// PUT admin/masters/community/posts/{id}
    case masterCommunityPostUpdate(id: String, MasterContentCreateRequest)
    /// PUT admin/masters/community/posts/{id}/status
    case masterCommunityPostStatus(id: String, status: String)

    // MARK: - 媒体与直播
    case mediaUploadCredential(MediaUploadCredentialRequest)
    case mediaComplete(id: Int64, coverMediaId: Int64?)
    case mediaDetail(id: Int64)
    case liveCapabilities
    case liveRoomCreate(LiveRoomCreateRequest)
    case liveRoomBindOpenIM(id: Int64, groupId: String)
    case liveRoomStart(id: Int64)
    case liveRoomClose(id: Int64)

    // MARK: - 提现（finance-service，JWT 保护路由）
    /// POST admin/finance/withdrawals/apply
    case withdrawalApply(WithdrawalApplyRequest)

    /// 相对路径（不含 BaseURL 前缀）
    var path: String {
        switch self {
        // 认证
        case .adminLogin:
            return "auth/admin/login"
        case .authRefresh:
            return "auth/refresh"
        // 预约
        case .masterBookings:
            return "admin/masters/bookings"
        case .masterBookingDetail(let id):
            return "admin/masters/bookings/\(id)"
        case .masterBookingConfirm(let id, _):
            return "admin/masters/bookings/\(id)/confirm"
        case .masterBookingComplete(let id, _):
            return "admin/masters/bookings/\(id)/complete"
        // 加持任务
        case .blessingTasks:
            return "admin/masters/blessing-tasks"
        case .blessingTaskDetail(let id):
            return "admin/masters/blessing-tasks/\(id)"
        case .blessingTaskAccept(let id):
            return "admin/masters/blessing-tasks/\(id)/accept"
        case .blessingTaskStart(let id):
            return "admin/masters/blessing-tasks/\(id)/start"
        case .blessingTaskComplete(let id, _):
            return "admin/masters/blessing-tasks/\(id)/complete"
        case .blessingTaskReject(let id):
            return "admin/masters/blessing-tasks/\(id)/reject"
        // 日程
        case .masterSchedules:
            return "admin/masters/schedules"
        case .masterScheduleUpdate:
            return "admin/masters/schedules"
        // 收益
        case .earningsSummary:
            return "admin/masters/earnings/summary"
        case .earningsDetails:
            return "admin/masters/earnings/details"
        // 资料
        case .masterProfile:
            return "admin/masters/profile"
        case .masterProfileUpdate:
            return "admin/masters/profile"
        // 消息
        case .masterMessages:
            return "admin/messages/master"
        case .masterMessageRead(let id):
            return "admin/messages/master/\(id)/read"
        case .registerDeviceToken:
            return "messages/device-token"
        // 评价
        case .masterReviews:
            return "admin/masters/reviews"
        // 社区内容
        case .masterCommunityPosts:
            return "admin/masters/community/posts"
        case .masterCommunityPostCreate:
            return "admin/masters/community/posts"
        case .masterCommunityPostUpdate(let id, _):
            return "admin/masters/community/posts/\(id)"
        case .masterCommunityPostStatus(let id, _):
            return "admin/masters/community/posts/\(id)/status"
        case .mediaUploadCredential:
            return "media/uploads/credentials"
        case .mediaComplete(let id, _):
            return "media/\(id)/complete"
        case .mediaDetail(let id):
            return "media/\(id)"
        case .liveCapabilities:
            return "live/capabilities"
        case .liveRoomCreate:
            return "live/rooms"
        case .liveRoomBindOpenIM(let id, _):
            return "live/rooms/\(id)/openim"
        case .liveRoomStart(let id):
            return "live/rooms/\(id)/start"
        case .liveRoomClose(let id):
            return "live/rooms/\(id)/close"
        // 提现
        case .withdrawalApply:
            return "admin/finance/withdrawals/apply"
        }
    }

    /// HTTP 方法
    var httpMethod: HTTPMethod {
        switch self {
        case .adminLogin, .authRefresh, .withdrawalApply, .registerDeviceToken,
             .masterCommunityPostCreate, .mediaUploadCredential, .mediaComplete,
             .liveRoomCreate, .liveRoomStart, .liveRoomClose:
            return .POST
        case .masterScheduleUpdate, .masterProfileUpdate,
             .masterBookingConfirm, .masterBookingComplete,
             .blessingTaskAccept, .blessingTaskStart, .blessingTaskComplete, .blessingTaskReject,
             .masterMessageRead, .masterCommunityPostUpdate, .masterCommunityPostStatus,
             .liveRoomBindOpenIM:
            return .PUT
        default:
            return .GET
        }
    }

    /// 查询参数
    var queryItems: [URLQueryItem]? {
        switch self {
        case .masterBookings(let status, let page, let size):
            var items = [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "size", value: String(size))
            ]
            if let status, !status.isEmpty {
                items.append(URLQueryItem(name: "status", value: status))
            }
            return items
        case .blessingTasks(let status, let page, let size):
            var items = [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "size", value: String(size))
            ]
            if let status, !status.isEmpty {
                items.append(URLQueryItem(name: "status", value: status))
            }
            return items
        case .masterSchedules(let date, let page, let size):
            var items = [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "size", value: String(size))
            ]
            if let date, !date.isEmpty {
                items.append(URLQueryItem(name: "date", value: date))
            }
            return items
        case .earningsDetails(let serviceType, let page, let size):
            var items = [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "size", value: String(size))
            ]
            if let serviceType, !serviceType.isEmpty {
                items.append(URLQueryItem(name: "serviceType", value: serviceType))
            }
            return items
        case .masterMessages(let isRead, let page, let size):
            return [
                URLQueryItem(name: "isRead", value: String(isRead)),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "size", value: String(size))
            ]
        case .masterReviews(let rating, let page, let size):
            var items = [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "size", value: String(size))
            ]
            if let rating, rating > 0 {
                items.append(URLQueryItem(name: "rating", value: String(rating)))
            }
            return items
        case .masterCommunityPosts(let status, let page, let size):
            var items = [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "size", value: String(size))
            ]
            if let status, !status.isEmpty {
                items.append(URLQueryItem(name: "status", value: status))
            }
            return items
        default:
            return nil
        }
    }

    /// 请求体（Encodable）
    var body: AnyEncodable? {
        switch self {
        case .adminLogin(let req):
            return AnyEncodable(req)
        case .authRefresh(let refresh):
            return AnyEncodable(["refreshToken": refresh])
        case .masterBookingConfirm(_, let remark), .masterBookingComplete(_, let remark):
            return AnyEncodable(RemarkBody(remark: remark))
        case .blessingTaskComplete(_, let urls):
            return AnyEncodable(CertificateBody(certificateUrls: urls))
        case .masterScheduleUpdate(let date, let timeSlots, let status):
            return AnyEncodable(ScheduleUpdateBody(date: date, timeSlots: timeSlots, status: status))
        case .masterProfileUpdate(let req):
            return AnyEncodable(req)
        case .withdrawalApply(let req):
            return AnyEncodable(req)
        case .registerDeviceToken(let req):
            return AnyEncodable(req)
        case .masterCommunityPostCreate(let req), .masterCommunityPostUpdate(_, let req):
            return AnyEncodable(req)
        case .masterCommunityPostStatus(_, let status):
            return AnyEncodable(["status": status])
        case .mediaUploadCredential(let request):
            return AnyEncodable(request)
        case .mediaComplete(_, let coverMediaId):
            return AnyEncodable(MediaUploadCompleteRequest(coverMediaId: coverMediaId))
        case .liveRoomCreate(let request):
            return AnyEncodable(request)
        case .liveRoomBindOpenIM(_, let groupId):
            return AnyEncodable(["openimGroupId": groupId])
        case .liveRoomStart, .liveRoomClose:
            return AnyEncodable([String: String]())
        default:
            return nil
        }
    }

    var shouldAttemptTokenRefresh: Bool {
        switch self {
        case .adminLogin, .authRefresh:
            return false
        default:
            return true
        }
    }
}

// MARK: - 请求体模型

/// 管理台登录请求（account + password）
struct AdminLoginRequest: Encodable {
    let account: String
    let password: String
}

struct DeviceTokenRegisterRequest: Encodable {
    let userId: String
    let clientType: String
    let platform: String
    let deviceToken: String
    let bundleId: String
    let appVersion: String
}

struct DeviceTokenResponse: Decodable {
    let id: Int64
    let status: String
}

/// 法师内容发布请求（短视频/图文，提交后进入平台审核）
struct MasterContentCreateRequest: Encodable {
    let type: String
    let title: String
    let content: String?
    let coverUrl: String?
    let videoUrl: String?
    let tags: [String]?
}

struct MediaUploadCredentialRequest: Encodable {
    let fileName: String
    let mediaType: String
    let contentType: String
    let fileSize: Int64
}

struct MediaUploadCompleteRequest: Encodable {
    let coverMediaId: Int64?
}

struct MediaUploadCredential: Decodable {
    let mediaId: Int64
    let uploadUrl: String
    let objectName: String
    let expiresIn: Int64
    let uploadHeaders: [String: String]
}

struct MediaAsset: Decodable, Identifiable {
    let id: Int64
    let mediaNo: String
    let mediaType: String
    let status: String
    let auditStatus: String
    let playbackUrl: String
    let coverUrl: String
    let coverMediaId: Int64
    let duration: Double
    let fileSize: Int64
    let errorMessage: String
}

struct LiveCapabilities: Decodable {
    let enabled: Bool
    let provider: String
    let configured: Bool
    let canStart: Bool
}

struct LiveRoomCreateRequest: Encodable {
    let title: String
    let coverMediaId: Int64?
    let openimGroupId: String?
}

struct LiveRoom: Decodable, Identifiable {
    let id: Int64
    let roomNo: String
    let ownerId: String
    let masterId: String
    let title: String
    let status: String
    let openimGroupId: String
    let pushUrl: String
    let watchUrl: String
}

/// 法师资料更新请求
struct MasterProfileUpdateRequest: Encodable {
    var bio: String?
    var specialties: [String]?
    var avatar: String?
    var pricing: String?

    init(bio: String? = nil,
         specialties: [String]? = nil,
         avatar: String? = nil,
         pricing: String? = nil) {
        self.bio = bio
        self.specialties = specialties
        self.avatar = avatar
        self.pricing = pricing
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // 仅编码非 nil 字段，符合后端 optional 语义
        try container.encodeIfPresent(bio, forKey: .bio)
        try container.encodeIfPresent(specialties, forKey: .specialties)
        try container.encodeIfPresent(avatar, forKey: .avatar)
        try container.encodeIfPresent(pricing, forKey: .pricing)
    }

    enum CodingKeys: String, CodingKey {
        case bio, specialties, avatar, pricing
    }
}

/// 提现申请请求
struct WithdrawalApplyRequest: Encodable {
    let amount: Double
    let bankCard: String
}

/// 备注/批注请求体（confirm / complete）
struct RemarkBody: Encodable {
    let remark: String?

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(remark, forKey: .remark)
    }

    enum CodingKeys: String, CodingKey { case remark }
}

/// 加持完成请求体（certificateUrls）
struct CertificateBody: Encodable {
    let certificateUrls: [String]
}

/// 日程更新请求体（date / timeSlots / status）
struct ScheduleUpdateBody: Encodable {
    let date: String
    let timeSlots: [String]
    let status: String
}

/// 类型擦除的 Encodable 包装（用于把不同类型的 body 统一为 any Encodable）
struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init(_ wrapped: any Encodable) {
        self._encode = wrapped.encode
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
