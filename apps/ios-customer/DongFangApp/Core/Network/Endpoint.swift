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

/// OpenIM token 续签响应
struct IMTokenResponse: Decodable {
    let imToken: String
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

struct MediaUploadCredential: Decodable {
	let mediaId: Int64
	let uploadUrl: String
	let uploadHeaders: [String: String]
}

struct MediaUploadCredentialRequest: Encodable {
	let fileName: String
	let mediaType: String
	let contentType: String
	let fileSize: Int64
}

struct MediaCompleteRequest: Encodable { let coverMediaId: Int64? }

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

struct LiveRoomListResponse: Decodable {
    let list: [LiveRoom]
}

struct CommunityAsset: Decodable, Identifiable {
    let id: Int64
    let mediaId: Int64
    let assetType: String
    let sort: Int
}

struct CommunityPost: Decodable, Identifiable, Hashable {
    let id: String
    let masterId: String
    let type: String
    let title: String
    let content: String
    let coverMediaId: Int64
    let beliefCode: String
    let status: String
    let likeCount: Int64
    let commentCount: Int64
    let liked: Bool
    let assets: [CommunityAsset]
    let createTime: String

    static func == (lhs: CommunityPost, rhs: CommunityPost) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct CommunityPostListResponse: Decodable {
    let total: Int64
    let list: [CommunityPost]
    let page: Int
    let size: Int
}

struct CommunityComment: Decodable, Identifiable {
    let id: String
    let postId: String
    let userId: String
    let content: String
    let status: String
    let createTime: String
}

struct CommunityCommentListResponse: Decodable {
    let total: Int64
    let list: [CommunityComment]
}

struct CommunityLikeResponse: Decodable {
    let liked: Bool
    let likeCount: Int64
}

struct CommunityFollowResponse: Decodable { let following: Bool }

/// 我关注的法师 ID 列表
struct FollowedMastersResponse: Decodable { let list: [String] }

/// 收藏/取消收藏响应
struct FavoriteResponse: Decodable { let favorited: Bool }

/// 大师直约请求（先付费咨询后预约服务）
struct DirectBookingRequest: Encodable {
    let serviceCode: String
    let bookingDate: String
    let requestId: String
    let note: String?
}

/// 大师直约响应
struct DirectBookingResponse: Decodable {
    let id: String
    let status: String
    let paymentStatus: String
    let serviceFee: Double
    let totalFee: Double
}

/// 收藏的寺院列表
struct TempleFavoritesResponse: Decodable { let list: [Temple] }

/// 收藏的商品列表
struct ProductFavoritesResponse: Decodable { let list: [ShopProduct] }

/// 我的设计条目（含最新订单信息）
struct MyDesignItem: Decodable, Identifiable, Hashable {
    let id: Int64
    let designNo: String?
    let name: String
    let designData: String?
    let totalPrice: Double
    let status: String
    let blessServiceCode: String?
    let createTime: String?
    let updateTime: String?
    let orderNo: String?
    let orderStatus: String?

    /// 是否已下单
    var hasOrder: Bool { !(orderNo?.isEmpty ?? true) }
}
struct CommunityCommentCreateRequest: Encodable { let content: String }

/// API 端点枚举
enum Endpoint {
    // MARK: - 寺院
    case temples(sect: String?, type: String?, serviceCode: String?, page: Int, size: Int)
    case templesByBelief(String, page: Int, size: Int)
    case templeById(String)
    case templeServices(String)         // GET /temples/{id}/services
    case beliefs
    case belief(String)
    case serviceTypes

    // MARK: - 法师
    case masters(type: String?, templeId: String?, manageBy: String?, serviceCode: String?, page: Int, size: Int)
    case masterBooking(String, DirectBookingRequest)
    case mastersByBelief(String, page: Int, size: Int)
    case masterById(String)

    // MARK: - 预约（后端复数 /bookings）
    case bookings(userId: String?, status: String?, page: Int, size: Int)
    case bookingById(String)
    case createBooking(CreateBookingRequest)
	case bookingAvailability(templeId: String, serviceId: String, date: String)
    case updateBookingStatus(id: String, status: String)
    case bookingReviewCreate(id: String, BookingReviewCreateRequest)
    case bookingReviewById(String)
    case bookingChats(page: Int, size: Int)
    case bookingChatMessages(id: String, page: Int, size: Int)
    case bookingChatSend(id: String, BookingChatMessageSendRequest)
    case chats(page: Int, size: Int)
    case chatMessages(id: String, page: Int, size: Int)
    case chatSend(id: String, BookingChatMessageSendRequest)
    case consultationQuote(masterId: String)
    case consultationCreate(ConsultationCreateRequest)
    case consultationPay(id: String)

    // MARK: - DIY
    case diyDesigns(page: Int, size: Int)
    case diyMyDesigns(page: Int, size: Int)
    case diyDesignSave(DiyDesignSaveRequest)
    case diyDesignById(Int64)
    case diyMaterials(category: String?, page: Int, size: Int)
    case diyBlessingServices(page: Int, size: Int)
    case diyOrderCreate(DiyOrderCreateRequest)
    case diyOrderAvailability(DiyOrderAvailabilityRequest)
    case diyOrderCreateFromDesign(Int64, DiyDesignOrderCreateRequest)
    case diyOrders(userId: String, status: String?, page: Int, size: Int)
    case diyOrderById(Int64)

    // MARK: - 支付
    case paymentCreate(PaymentCreateRequest)
    case paymentById(Int64)

    // MARK: - AI 问事
    case aiSkills
    case aiSessions(userId: String, page: Int, size: Int)
    case aiSessionCreate(AiSessionCreateRequest)
    case aiMessages(sessionId: String, userId: String, page: Int, size: Int)
    case aiSendMessage(AiMessageSendRequest)
    case aiRetryMessage(sessionId: String, messageId: Int64, userId: String)
	case mediaUploadCredential(MediaUploadCredentialRequest)
	case mediaComplete(id: Int64, MediaCompleteRequest)

    // MARK: - 社区内容 / 大师广场
    case communityFeed(type: String?, beliefCode: String?, page: Int, size: Int)
    case communityPostById(String)
    case communityPostLike(String)
    case communityPostUnlike(String)
    case communityComments(postId: String, page: Int, size: Int)
    case communityCommentCreate(postId: String, CommunityCommentCreateRequest)
    case communityMasterFollow(String)
    case communityMasterUnfollow(String)
    case communityMyFollowing
    case templeFavorite(String)
    case templeUnfavorite(String)
    case templeFavorites
    case productFavorite(Int64)
    case productUnfavorite(Int64)
    case productFavorites

    // MARK: - 媒体与直播
    case mediaDetail(Int64)
    case liveRooms(masterId: String?, limit: Int)
    case liveRoomById(Int64)

    // MARK: - 原型聚合入口
    case intentionHub(code: String?, page: Int, size: Int)
    case intentionTags

    // MARK: - 商城
    case products(categoryId: Int64?, keyword: String?, page: Int, size: Int)
    case productById(Int64)
    case productCategories
    case shopOrderCreate(ShopOrderCreateRequest)
    case shopOrders(status: String?, page: Int, size: Int)
    case shopOrderById(Int64)
    case shopOrderConfirm(Int64)

    // MARK: - 消息（站内消息）
    case messages(userId: String, isRead: Int, page: Int, size: Int)  // GET /message/list
    case messageRead(String)                                           // PUT /message/{id}/read
    case unreadCount(userId: String)                                   // GET /messages/unread-count
    case readAllMessages(userId: String)                               // PUT /messages/read-all
    case deleteMessage(String)                                         // DELETE /messages/{id}
    case registerDeviceToken(DeviceTokenRegisterRequest)               // POST /messages/device-token

    // MARK: - 公告
    case announcements(type: String?, page: Int, size: Int)

    // MARK: - 认证
    case authLogin(LoginRequest)
    case authRegister(RegisterRequest)
    case authRefresh(refreshToken: String)
    case authLogout(accessToken: String?)
    case authIMToken

    // MARK: - 用户
    case userProfile
    case updateProfile(UpdateProfileRequest)
    case addressList
    case addressCreate(AddressCreateRequest)
    case addressUpdate(id: Int64, AddressUpdateRequest)
    case addressDelete(Int64)
    case reviews(userId: String, page: Int, size: Int)
    case myCoupons(status: String?, page: Int, size: Int)

    /// 相对路径（不含 BaseURL 前缀）
    var path: String {
        switch self {
        // 寺院
        case .temples:                  return "temples"
        case .templesByBelief:          return "temples"
        case .templeById(let id):       return "temples/\(id)"
        case .templeServices(let id):   return "temples/\(id)/services"
        case .beliefs:                  return "beliefs"
        case .belief(let code):         return "beliefs/\(code)"
        case .serviceTypes:             return "service-types"
        // 法师
        case .masters:                  return "masters"
        case .masterBooking(let id, _): return "master-bookings/\(id)"
        case .mastersByBelief:          return "masters"
        case .masterById(let id):       return "masters/\(id)"
        // 预约（后端复数 bookings）
        case .bookings:                 return "bookings"
        case .bookingById(let id):      return "bookings/\(id)"
        case .createBooking:            return "bookings"
		case .bookingAvailability:       return "bookings/availability"
        case .updateBookingStatus(let id, _): return "bookings/\(id)/status"
        case .bookingReviewCreate(let id, _): return "bookings/\(id)/review"
        case .bookingReviewById(let id):      return "bookings/\(id)/review"
        case .bookingChats:                   return "bookings/chats"
        case .bookingChatMessages(let id, _, _), .bookingChatSend(let id, _):
            return "bookings/\(id)/chat/messages"
        case .chats:                     return "chats"
        case .chatMessages(let id, _, _), .chatSend(let id, _): return "chats/\(id)/messages"
        case .consultationQuote:         return "consultations/quote"
        case .consultationCreate:        return "consultations"
        case .consultationPay(let id):   return "consultations/\(id)/pay"
        // DIY
        case .diyDesigns:               return "diy/designs"
        case .diyMyDesigns:             return "diy/my-designs"
        case .diyDesignSave:            return "diy/designs"
        case .diyDesignById(let id):    return "diy/designs/\(id)"
        case .diyMaterials:             return "diy/materials"
        case .diyBlessingServices:      return "diy/blessing-services"
        case .diyOrderCreate:           return "diy/orders"
        case .diyOrderAvailability:     return "diy/orders/availability"
        case .diyOrderCreateFromDesign(let id, _): return "diy/designs/\(id)/order"
        case .diyOrders:                return "diy/orders"
        case .diyOrderById(let id):     return "diy/orders/\(id)"
        case .paymentCreate:            return "payments"
        case .paymentById(let id):      return "payments/\(id)"
        // AI 问事
        case .aiSkills:                 return "ai/skills"
        case .aiSessions:               return "ai/sessions"
        case .aiSessionCreate:          return "ai/sessions"
        case .aiMessages(let sessionId, _, _, _): return "ai/sessions/\(sessionId)/messages"
        case .aiSendMessage(let req):   return "ai/sessions/\(req.sessionId)/messages"
        case .aiRetryMessage(let sessionId, let messageId, _): return "ai/sessions/\(sessionId)/messages/\(messageId)/retry"
		case .mediaUploadCredential: return "media/uploads/credentials"
		case .mediaComplete(let id, _): return "media/\(id)/complete"
        // 社区内容
        case .communityFeed:            return "community/feed"
        case .communityPostById(let id): return "community/posts/\(id)"
        case .communityPostLike(let id), .communityPostUnlike(let id): return "community/posts/\(id)/like"
        case .communityComments(let postId, _, _): return "community/posts/\(postId)/comments"
        case .communityCommentCreate(let postId, _): return "community/posts/\(postId)/comments"
        case .communityMasterFollow(let id), .communityMasterUnfollow(let id): return "community/masters/\(id)/follow"
        case .communityMyFollowing:       return "community/masters/following"
        case .templeFavorite(let id), .templeUnfavorite(let id): return "temples/\(id)/favorite"
        case .templeFavorites:             return "favorites/temples"
        case .productFavorite(let id), .productUnfavorite(let id): return "products/\(id)/favorite"
        case .productFavorites:            return "favorites/products"
        case .mediaDetail(let id):       return "media/\(id)"
        case .liveRooms:                 return "live/rooms"
        case .liveRoomById(let id):      return "live/rooms/\(id)"
        // 原型聚合入口
        case .intentionHub:             return "intentions"
        case .intentionTags:            return "intentions/tags"
        // 商城
        case .products:                 return "products"
        case .productById(let id):      return "products/\(id)"
        case .productCategories:        return "products/categories"
        case .shopOrderCreate, .shopOrders: return "orders"
        case .shopOrderById(let id):    return "orders/\(id)"
        case .shopOrderConfirm(let id): return "orders/\(id)/confirm"
        // 消息（message-service 单数前缀）
        case .messages:                 return "messages/list"
        case .messageRead(let id):      return "messages/\(id)/read"
        case .unreadCount:              return "messages/unread-count"
        case .readAllMessages:          return "messages/read-all"
        case .deleteMessage(let id):    return "messages/\(id)"
        case .registerDeviceToken:      return "messages/device-token"
        // 公告
        case .announcements:            return "announcements/list"
        // 认证
        case .authLogin:                return "auth/login"
        case .authRegister:             return "users/register"
        case .authRefresh:              return "auth/refresh"
        case .authLogout:               return "auth/logout"
        case .authIMToken:             return "auth/im-token"
        // 用户
        case .userProfile:              return "users/profile"
        case .updateProfile:            return "users/profile"
        case .addressList:              return "users/addresses"
        case .addressCreate:            return "users/addresses"
        case .addressUpdate(let id, _): return "users/addresses/\(id)"
        case .addressDelete(let id):    return "users/addresses/\(id)"
        case .reviews:                  return "reviews"
        case .myCoupons:                return "marketing/my-coupons"
        }
    }

    /// HTTP 方法
    var httpMethod: HTTPMethod {
        switch self {
        case .temples, .templesByBelief, .templeById, .templeServices, .beliefs, .belief, .serviceTypes,
             .masters, .mastersByBelief, .masterById,
			 .bookings, .bookingById, .bookingAvailability, .bookingReviewById, .bookingChats, .bookingChatMessages,
             .chats, .chatMessages, .consultationQuote,
             .diyDesigns, .diyMyDesigns, .diyDesignById, .diyMaterials, .diyBlessingServices, .diyOrders, .diyOrderById, .paymentById,
             .aiSkills, .aiSessions, .aiMessages,
             .communityFeed, .communityPostById, .communityComments, .communityMyFollowing,
             .templeFavorites, .productFavorites,
             .mediaDetail, .liveRooms, .liveRoomById,
             .intentionHub, .intentionTags,
             .products, .productById, .productCategories,
             .shopOrders, .shopOrderById,
             .messages, .unreadCount, .announcements,
             .userProfile, .addressList, .reviews, .myCoupons:
            return .GET
        case .createBooking, .bookingReviewCreate, .bookingChatSend, .chatSend, .consultationCreate, .consultationPay,
             .diyDesignSave, .diyOrderCreate, .diyOrderAvailability, .diyOrderCreateFromDesign, .paymentCreate,
             .shopOrderCreate,
			 .aiSessionCreate, .aiSendMessage, .aiRetryMessage, .mediaUploadCredential, .mediaComplete, .communityPostLike,
             .communityCommentCreate, .communityMasterFollow,
             .authLogin, .authRegister, .authRefresh, .authLogout, .authIMToken,
             .templeFavorite, .productFavorite, .masterBooking,
             .addressCreate, .registerDeviceToken:
            return .POST
        case .updateBookingStatus, .shopOrderConfirm, .messageRead, .readAllMessages,
             .updateProfile, .addressUpdate:
            return .PUT
        case .deleteMessage, .addressDelete, .communityPostUnlike, .communityMasterUnfollow,
             .templeUnfavorite, .productUnfavorite:
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
        case .templesByBelief(let code, let page, let size), .mastersByBelief(let code, let page, let size):
            return [URLQueryItem(name: "beliefCode", value: code),
                    URLQueryItem(name: "page", value: "\(page)"),
                    URLQueryItem(name: "size", value: "\(size)")]
        case .masters(let type, let templeId, let manageBy, let serviceCode, let page, let size):
            var items = [URLQueryItem(name: "page", value: "\(page)"),
                         URLQueryItem(name: "size", value: "\(size)")]
            if let type, !type.isEmpty { items.append(URLQueryItem(name: "type", value: type)) }
            if let templeId, !templeId.isEmpty { items.append(URLQueryItem(name: "templeId", value: templeId)) }
            if let manageBy, !manageBy.isEmpty { items.append(URLQueryItem(name: "manageBy", value: manageBy)) }
            if let serviceCode, !serviceCode.isEmpty { items.append(URLQueryItem(name: "serviceCode", value: serviceCode)) }
            return items
        case .bookings(let userId, let status, let page, let size):
            var items = [URLQueryItem(name: "page", value: "\(page)"),
                         URLQueryItem(name: "size", value: "\(size)")]
            if let userId, !userId.isEmpty { items.append(URLQueryItem(name: "userId", value: userId)) }
            if let status, !status.isEmpty { items.append(URLQueryItem(name: "status", value: status)) }
            return items
		case .bookingChats(let page, let size), .bookingChatMessages(_, let page, let size),
             .chats(let page, let size), .chatMessages(_, let page, let size):
			return [URLQueryItem(name: "page", value: "\(page)"),
					URLQueryItem(name: "size", value: "\(size)")]
		case .consultationQuote(let masterId):
			return [URLQueryItem(name: "masterId", value: masterId)]
		case .bookingAvailability(let templeId, let serviceId, let date):
			return [URLQueryItem(name: "templeId", value: templeId),
					URLQueryItem(name: "serviceId", value: serviceId),
					URLQueryItem(name: "date", value: date)]
        case .diyDesigns(let page, let size):
            return [URLQueryItem(name: "page", value: "\(page)"),
                    URLQueryItem(name: "size", value: "\(size)")]
        case .diyMaterials(let category, let page, let size):
            var items = [URLQueryItem(name: "page", value: "\(page)"),
                         URLQueryItem(name: "size", value: "\(size)")]
            if let category, !category.isEmpty { items.append(URLQueryItem(name: "category", value: category)) }
            return items
        case .diyBlessingServices(let page, let size):
            return [URLQueryItem(name: "page", value: "\(page)"),
                    URLQueryItem(name: "size", value: "\(size)")]
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
        case .aiSkills:
            return [URLQueryItem(name: "status", value: "enabled")]
        case .aiMessages(_, let userId, let page, let size):
            return [URLQueryItem(name: "userId", value: userId),
                    URLQueryItem(name: "page", value: "\(page)"),
                    URLQueryItem(name: "size", value: "\(size)")]
        case .communityFeed(let type, let beliefCode, let page, let size):
            var items = [URLQueryItem(name: "page", value: "\(page)"),
                         URLQueryItem(name: "size", value: "\(size)")]
            if let type, !type.isEmpty { items.append(URLQueryItem(name: "type", value: type)) }
            if let beliefCode, !beliefCode.isEmpty { items.append(URLQueryItem(name: "beliefCode", value: beliefCode)) }
            return items
        case .communityComments(_, let page, let size):
            return [URLQueryItem(name: "page", value: "\(page)"),
                    URLQueryItem(name: "size", value: "\(size)")]
        case .liveRooms(let masterId, let limit):
            var items = [URLQueryItem(name: "limit", value: "\(limit)")]
            if let masterId, !masterId.isEmpty {
                items.append(URLQueryItem(name: "masterId", value: masterId))
            }
            return items
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
        case .shopOrders(let status, let page, let size):
            var items = [URLQueryItem(name: "page", value: "\(page)"),
                         URLQueryItem(name: "size", value: "\(size)")]
            if let status, !status.isEmpty { items.append(URLQueryItem(name: "status", value: status)) }
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
        case .reviews(let userId, let page, let size):
            return [URLQueryItem(name: "userId", value: userId),
                    URLQueryItem(name: "page", value: "\(page)"),
                    URLQueryItem(name: "size", value: "\(size)")]
        case .myCoupons(let status, let page, let size):
            var items = [URLQueryItem(name: "page", value: "\(page)"),
                         URLQueryItem(name: "size", value: "\(size)")]
            if let status, !status.isEmpty {
                items.append(URLQueryItem(name: "status", value: status))
            }
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
        case .bookingReviewCreate(_, let request): return AnyEncodable(request)
        case .bookingChatSend(_, let request), .chatSend(_, let request): return AnyEncodable(request)
        case .consultationCreate(let request): return AnyEncodable(request)
        case .consultationPay:             return AnyEncodable([String: String]())
        case .diyDesignSave(let req):          return AnyEncodable(req)
        case .diyOrderCreate(let req):         return AnyEncodable(req)
        case .diyOrderAvailability(let req):   return AnyEncodable(req)
        case .diyOrderCreateFromDesign(_, let req): return AnyEncodable(req)
        case .paymentCreate(let req):          return AnyEncodable(req)
        case .shopOrderCreate(let req):        return AnyEncodable(req)
        case .aiSessionCreate(let req):        return AnyEncodable(req)
        case .aiSendMessage(let req):          return AnyEncodable(req)
        case .aiRetryMessage(_, _, let userId): return AnyEncodable(["userId": userId])
		case .mediaUploadCredential(let request): return AnyEncodable(request)
		case .mediaComplete(_, let request): return AnyEncodable(request)
        case .communityPostLike, .communityPostUnlike, .communityMasterFollow, .communityMasterUnfollow,
             .templeFavorite, .productFavorite:
            return AnyEncodable([String: String]())
        case .masterBooking(_, let req):
            return AnyEncodable(req)
        case .communityCommentCreate(_, let req): return AnyEncodable(req)
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
    let skillCode: String?
    let question: String?
    let inputs: [String: String]
	let attachments: [AiImageAttachment]
}

struct AiMessageSendRequest: Encodable {
    let sessionId: String
    let userId: String
    let content: String
    let inputs: [String: String]
	let attachments: [AiImageAttachment]
}

struct AiImageAttachment: Codable, Identifiable {
	let mediaId: Int64
	let url: String
	let contentType: String
	let width: Int?
	let height: Int?
	var id: Int64 { mediaId }
}

struct DiyDesignOrderCreateRequest: Codable {
    let userId: String
    let blessServiceCode: String?
    let addressId: Int64
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
