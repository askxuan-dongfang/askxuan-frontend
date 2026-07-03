//
//  Endpoint.swift
//  DongFangApp
//
//  API 端点定义：路径、HTTP 方法、查询参数、请求体。
//  路径均为相对路径（不含 /api/v1 前缀，BaseURL 已包含）。
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
    // 寺院
    case temples                          // GET /temples
    case templeById(String)               // GET /temples/{id}
    // 师傅
    case masters                          // GET /masters
    case masterById(String)               // GET /masters/{id}
    // 服务
    case services                         // GET /services
    case serviceById(String)              // GET /services/{id}
    // 预约
    case bookings                         // GET /bookings
    case bookingById(String)              // GET /bookings/{id}
    case createBooking(CreateBookingRequest)  // POST /bookings
    // 认证
    case authLogin(phone: String, code: String)  // POST /auth/login

    /// 相对路径（不含 BaseURL 前缀）
    var path: String {
        switch self {
        case .temples:                  return "temples"
        case .templeById(let id):       return "temples/\(id)"
        case .masters:                  return "masters"
        case .masterById(let id):       return "masters/\(id)"
        case .services:                 return "services"
        case .serviceById(let id):      return "services/\(id)"
        case .bookings:                 return "bookings"
        case .bookingById(let id):      return "bookings/\(id)"
        case .createBooking:            return "bookings"
        case .authLogin:                return "auth/login"
        }
    }

    /// HTTP 方法
    var httpMethod: HTTPMethod {
        switch self {
        case .temples, .templeById,
             .masters, .masterById,
             .services, .serviceById,
             .bookings, .bookingById:
            return .GET
        case .createBooking, .authLogin:
            return .POST
        }
    }

    /// 查询参数
    var queryItems: [URLQueryItem]? {
        switch self {
        case .masters:
            // 教派筛选由调用方决定，此处返回 nil；如需筛选可扩展为 masters(sect: String?)
            return nil
        default:
            return nil
        }
    }

    /// 请求体（Encodable）
    var body: (any Encodable)? {
        switch self {
        case .createBooking(let request):
            return AnyEncodable(request)
        case .authLogin(let phone, let code):
            return AnyEncodable(["phone": phone, "code": code])
        default:
            return nil
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
