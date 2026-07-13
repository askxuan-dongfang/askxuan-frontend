//
//  Endpoint.swift
//  DongFangApp
//
//  API 端点定义：路径、HTTP 方法、查询参数、请求体。
//  路径均为相对路径（不含 /api/v1 前缀，BaseURL 已包含）。
//  RESTful 复数：/temples, /masters, /bookings。
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

/// API 端点枚举
enum Endpoint {
    // MARK: - 寺院
    case temples(sect: String?, type: String?, serviceCode: String?, page: Int, size: Int)
    case templeById(String)
    case templeServices(String)         // GET /temples/{id}/services

    // MARK: - 法师
    case masters(type: String?, templeId: String?, page: Int, size: Int)
    case masterById(String)

    // MARK: - 预约（后端复数 /bookings）
    case bookings(userId: String?, status: String?, page: Int, size: Int)
    case bookingById(String)
    case createBooking(CreateBookingRequest)
    case updateBookingStatus(id: String, status: String)

    // MARK: - DIY
    case diyDesigns(page: Int, size: Int)
    case diyDesignSave(DiyDesignSaveRequest)
    case diyDesignById(Int64)
    case diyMaterials(category: String?, page: Int, size: Int)
    case diyOrderCreate(DiyOrderCreateRequest)
    case diyOrderCreateFromDesign(Int64, DiyDesignOrderCreateRequest)
    case diyOrders(userId: String, status: String?, page: Int, size: Int)
    case diyOrderById(Int64)

    // MARK: - AI 问事
    case aiSessions(userId: String, page: Int, size: Int)
    case aiSessionCreate(AiSessionCreateRequest)
    case aiMessages(sessionId: String, page: Int, size: Int)
    case aiSendMessage(AiMessageSendRequest)

    // MARK: - 社区内容 / 大师广场
    case communityFeed(type: String?, sect: String?, page: Int, size: Int)
    case communityPostById(String)
    case communityPostLike(String)
    case communityComments(postId: String, page: Int, size: Int)

    // MARK: - 原型聚合入口
    case intentionHub(code: String?, page: Int, size: Int)

    // MARK: - 商城
    case products(categoryId: Int64?, keyword: String?, page: Int, size: Int)
    case productById(Int64)
    case productCategories

    // MARK: - 消息（站内消息）
    case messages(userId: String, isRead: Int, page: Int, size: Int)  // GET /message/list
    case messageRead(String)                                           // PUT /message/{id}/read
    case unreadCount(userId: String)                                   // GET /messages/unread-count
    case readAllMessages(userId: String)                               // PUT /messages/read-all
    case deleteMessage(String)                                         // DELETE /messages/{id}
    case sendMessage(SendMessageRequest)                               // POST /messages/send（C 端发送咨询消息）
    case registerDeviceToken(DeviceTokenRegisterRequest)               // POST /messages/device-token

    // MARK: - 公告
    case announcements(type: String?, page: Int, size: Int)

    // MARK: - 认证
    case authLogin(LoginRequest)
    case authRegister(RegisterRequest)
    case authRefresh(refreshToken: String)
    case authLogout(accessToken: String?)

    // MARK: - 用户
    case userProfile
    case updateProfile(UpdateProfileRequest)
    case addressList
    case addressCreate(AddressCreateRequest)
    case addressUpdate(id: Int64, AddressUpdateRequest)
    case addressDelete(Int64)

    /// 相对路径（不含 BaseURL 前缀）
    var path: String {
        switch self {
        // 寺院
        case .temples:                  return "temples"
        case .templeById(let id):       return "temples/\(id)"
        case .templeServices(let id):   return "temples/\(id)/services"
        // 法师
        case .masters:                  return "masters"
        case .masterById(let id):       return "masters/\(id)"
        // 预约（后端复数 bookings）
        case .bookings:                 return "bookings"
        case .bookingById(let id):      return "bookings/\(id)"
        case .createBooking:            return "bookings"
        case .updateBookingStatus(let id, _): return "bookings/\(id)/status"
        // DIY
        case .diyDesigns:               return "diy/designs"
        case .diyDesignSave:            return "diy/designs"
        case .diyDesignById(let id):    return "diy/designs/\(id)"
        case .diyMaterials:             return "diy/materials"
        case .diyOrderCreate:           return "diy/orders"
        case .diyOrderCreateFromDesign(let id, _): return "diy/designs/\(id)/order"
        case .diyOrders:                return "diy/orders"
        case .diyOrderById(let id):     return "diy/orders/\(id)"
        // AI 问事
        case .aiSessions:               return "ai/sessions"
        case .aiSessionCreate:          return "ai/sessions"
        case .aiMessages(let sessionId, _, _): return "ai/sessions/\(sessionId)/messages"
        case .aiSendMessage(let req):   return "ai/sessions/\(req.sessionId)/messages"
        // 社区内容
        case .communityFeed:            return "community/feed"
        case .communityPostById(let id): return "community/posts/\(id)"
        case .communityPostLike(let id): return "community/posts/\(id)/like"
        case .communityComments(let postId, _, _): return "community/posts/\(postId)/comments"
        // 原型聚合入口
        case .intentionHub:             return "intentions"
        // 商城
        case .products:                 return "products"
        case .productById(let id):      return "products/\(id)"
        case .productCategories:        return "products/categories"
        // 消息（message-service 单数前缀）
        case .messages:                 return "messages/list"
        case .messageRead(let id):      return "messages/\(id)/read"
        case .unreadCount:              return "messages/unread-count"
        case .readAllMessages:          return "messages/read-all"
        case .deleteMessage(let id):    return "messages/\(id)"
        case .sendMessage:              return "messages/send"
        case .registerDeviceToken:      return "messages/device-token"
        // 公告
        case .announcements:            return "announcements/list"
        // 认证
        case .authLogin:                return "auth/login"
        case .authRegister:             return "users/register"
        case .authRefresh:              return "auth/refresh"
        case .authLogout:               return "auth/logout"
        // 用户
        case .userProfile:              return "users/profile"
        case .updateProfile:            return "users/profile"
        case .addressList:              return "users/addresses"
        case .addressCreate:            return "users/addresses"
        case .addressUpdate(let id, _): return "users/addresses/\(id)"
        case .addressDelete(let id):    return "users/addresses/\(id)"
        }
    }

    /// HTTP 方法
    var httpMethod: HTTPMethod {
        switch self {
        case .temples, .templeById, .templeServices,
             .masters, .masterById,
             .bookings, .bookingById,
             .diyDesigns, .diyDesignById, .diyMaterials, .diyOrders, .diyOrderById,
             .aiSessions, .aiMessages,
             .communityFeed, .communityPostById, .communityComments,
             .intentionHub,
             .products, .productById, .productCategories,
             .messages, .unreadCount, .announcements,
             .userProfile, .addressList:
            return .GET
        case .createBooking, .diyDesignSave, .diyOrderCreate, .diyOrderCreateFromDesign,
             .aiSessionCreate, .aiSendMessage, .communityPostLike,
             .authLogin, .authRegister, .authRefresh, .authLogout,
             .addressCreate, .sendMessage, .registerDeviceToken:
            return .POST
        case .updateBookingStatus, .messageRead, .readAllMessages,
             .updateProfile, .addressUpdate:
            return .PUT
        case .deleteMessage, .addressDelete:
            return .DELETE
        }
    }

    /// 查询参数
    var queryItems: [URLQueryItem]? {
        switch self {
        case .temples(let sect, let type, let serviceCode, let page, let size):
            var items = [URLQueryItem(name: "page", value: "\(page)"),
                         URLQueryItem(name: "size", value: "\(size)")]
            if let sect, !sect.isEmpty { items.append(URLQueryItem(name: "sect", value: sect)) }
            if let type, !type.isEmpty { items.append(URLQueryItem(name: "type", value: type)) }
            if let serviceCode, !serviceCode.isEmpty { items.append(URLQueryItem(name: "serviceCode", value: serviceCode)) }
            return items
        case .masters(let type, let templeId, let page, let size):
            var items = [URLQueryItem(name: "page", value: "\(page)"),
                         URLQueryItem(name: "size", value: "\(size)")]
            if let type, !type.isEmpty { items.append(URLQueryItem(name: "type", value: type)) }
            if let templeId, !templeId.isEmpty { items.append(URLQueryItem(name: "templeId", value: templeId)) }
            return items
        case .bookings(let userId, let status, let page, let size):
            var items = [URLQueryItem(name: "page", value: "\(page)"),
                         URLQueryItem(name: "size", value: "\(size)")]
            if let userId, !userId.isEmpty { items.append(URLQueryItem(name: "userId", value: userId)) }
            if let status, !status.isEmpty { items.append(URLQueryItem(name: "status", value: status)) }
            return items
        case .diyDesigns(let page, let size):
            return [URLQueryItem(name: "page", value: "\(page)"),
                    URLQueryItem(name: "size", value: "\(size)")]
        case .diyMaterials(let category, let page, let size):
            var items = [URLQueryItem(name: "page", value: "\(page)"),
                         URLQueryItem(name: "size", value: "\(size)")]
            if let category, !category.isEmpty { items.append(URLQueryItem(name: "category", value: category)) }
            return items
        case .diyOrders(let userId, let status, let page, let size):
            var items = [URLQueryItem(name: "userId", value: userId),
                         URLQueryItem(name: "page", value: "\(page)"),
                         URLQueryItem(name: "size", value: "\(size)")]
            if let status, !status.isEmpty { items.append(URLQueryItem(name: "status", value: status)) }
            return items
        case .aiSessions(let userId, let page, let size):
            return [URLQueryItem(name: "userId", value: userId),
                    URLQueryItem(name: "page", value: "\(page)"),
                    URLQueryItem(name: "size", value: "\(size)")]
        case .aiMessages(_, let page, let size):
            return [URLQueryItem(name: "page", value: "\(page)"),
                    URLQueryItem(name: "size", value: "\(size)")]
        case .communityFeed(let type, let sect, let page, let size):
            var items = [URLQueryItem(name: "page", value: "\(page)"),
                         URLQueryItem(name: "size", value: "\(size)")]
            if let type, !type.isEmpty { items.append(URLQueryItem(name: "type", value: type)) }
            if let sect, !sect.isEmpty { items.append(URLQueryItem(name: "sect", value: sect)) }
            return items
        case .communityComments(_, let page, let size):
            return [URLQueryItem(name: "page", value: "\(page)"),
                    URLQueryItem(name: "size", value: "\(size)")]
        case .intentionHub(let code, let page, let size):
            var items = [URLQueryItem(name: "page", value: "\(page)"),
                         URLQueryItem(name: "size", value: "\(size)")]
            if let code, !code.isEmpty { items.append(URLQueryItem(name: "code", value: code)) }
            return items
        case .products(let categoryId, let keyword, let page, let size):
            var items = [URLQueryItem(name: "page", value: "\(page)"),
                         URLQueryItem(name: "size", value: "\(size)")]
            if let categoryId { items.append(URLQueryItem(name: "categoryId", value: "\(categoryId)")) }
            if let keyword, !keyword.isEmpty { items.append(URLQueryItem(name: "keyword", value: keyword)) }
            return items
        case .messages(let userId, let isRead, let page, let size):
            return [URLQueryItem(name: "userId", value: userId),
                    URLQueryItem(name: "isRead", value: "\(isRead)"),
                    URLQueryItem(name: "page", value: "\(page)"),
                    URLQueryItem(name: "size", value: "\(size)")]
        case .unreadCount(let userId):
            return [URLQueryItem(name: "userId", value: userId)]
        case .announcements(let type, let page, let size):
            var items = [URLQueryItem(name: "page", value: "\(page)"),
                         URLQueryItem(name: "size", value: "\(size)")]
            if let type, !type.isEmpty { items.append(URLQueryItem(name: "type", value: type)) }
            return items
        default:
            return nil
        }
    }

    /// 请求体（Encodable）
    var body: (any Encodable)? {
        switch self {
        case .createBooking(let req):          return AnyEncodable(req)
        case .updateBookingStatus(_, let status): return AnyEncodable(["status": status])
        case .diyDesignSave(let req):          return AnyEncodable(req)
        case .diyOrderCreate(let req):         return AnyEncodable(req)
        case .diyOrderCreateFromDesign(_, let req): return AnyEncodable(req)
        case .aiSessionCreate(let req):        return AnyEncodable(req)
        case .aiSendMessage(let req):          return AnyEncodable(req)
        case .authLogin(let req):              return AnyEncodable(req)
        case .authRegister(let req):           return AnyEncodable(req)
        case .authRefresh(let refresh):        return AnyEncodable(["refreshToken": refresh])
        case .authLogout(let token):
            var dict: [String: String] = [:]
            if let token { dict["accessToken"] = token }
            return AnyEncodable(dict)
        case .updateProfile(let req):          return AnyEncodable(req)
        case .addressCreate(let req):          return AnyEncodable(req)
        case .addressUpdate(_, let req):       return AnyEncodable(req)
        case .readAllMessages(let userId):     return AnyEncodable(["userId": userId])
        case .sendMessage(let req):            return AnyEncodable(req)
        case .registerDeviceToken(let req):    return AnyEncodable(req)
        default:
            return nil
        }
    }

    var shouldAttemptTokenRefresh: Bool {
        switch self {
        case .authLogin, .authRegister, .authRefresh, .authLogout:
            return false
        default:
            return true
        }
    }
}

/// 类型擦除的 Encodable 包装（用于把不同类型的 body 统一为 Encodable）
struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init(_ wrapped: any Encodable) {
        self._encode = wrapped.encode
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}

// MARK: - AI / 社区请求体

struct AiSessionCreateRequest: Encodable {
    let userId: String
    let skillCode: String
    let question: String?
}

struct AiMessageSendRequest: Encodable {
    let sessionId: String
    let userId: String
    let content: String
}

struct DiyDesignOrderCreateRequest: Codable {
    let userId: String
    let blessServiceCode: String?
    let addressId: Int64
}

// MARK: - 消息发送请求/响应

/// C 端发送消息请求（向法师发送咨询消息）
struct SendMessageRequest: Encodable {
    let conversationId: String
    let userId: String
    let content: String
}

/// 发送消息响应
struct SendMessageResponse: Decodable {
    let id: Int64
}

/// APNs mock 设备 token 注册请求
struct DeviceTokenRegisterRequest: Encodable {
    let userId: String
    let clientType: String
    let platform: String
    let deviceToken: String
    let bundleId: String
    let appVersion: String
}

/// APNs mock 设备 token 注册响应
struct DeviceTokenResponse: Decodable {
    let id: Int64
    let status: String
}
