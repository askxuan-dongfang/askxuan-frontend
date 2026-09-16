import Foundation

struct JourneyMedia: Decodable, Identifiable {
  let id: String
  let name: String
  let contentType: String
  let size: Int
  let sha256: String
}
struct JourneyRecord: Decodable, Identifiable {
  let id: String
  let kind: String
  let content: String
  let operatorType: String
  let createdAt: String
  let files: [JourneyMedia]
}
struct JourneyReceipt: Decodable, Identifiable {
  let id: String
  let summary: String
  let operatorType: String
  let createdAt: String
  let digest: String
  let files: [JourneyMedia]
}
struct JourneyLog: Decodable, Identifiable {
  let id: Int
  let toStatus: String
  let operatorType: String
  let remark: String
  let createTime: String
}
struct JourneyProgress: Decodable {
  let status: String
  let logs: [JourneyLog]?
  let records: [JourneyRecord]
  let receipts: [JourneyReceipt]
}
struct JourneyItem: Decodable, Identifiable {
  let id: String
  let templeName: String
  let masterName: String
  let masterId: String
  let serviceName: String
  let bookingDate: String
  let timeSlot: String
  let status: String
  let latest: String
  let updatedAt: String
  let receiptCount: Int
  let needsRevision: Int
  let preview: [JourneyMedia]
  var providerName: String { templeName.isEmpty ? masterName : templeName }
}
struct JourneyCounts: Decodable {
  let active: Int
  let pending: Int
  let confirmed: Int
  let executing: Int
  let receipt: Int
  let complete: Int
  let revision: Int
}
struct JourneyIndex: Decodable {
  let list: [JourneyItem]
  let total: Int
  let page: Int
  let counts: JourneyCounts
}
struct JourneyEnvelope<T: Decodable>: Decodable { let data: T }
struct JourneyActionResponse: Decodable {
  let status: String?
  let id: String?
}
struct JourneyFailure: LocalizedError {
  let message: String
  var errorDescription: String? { message }
}
enum JourneyText {
  static func status(_ value: String) -> String {
    [
      "pending_payment": "待支付", "pending": "待接单", "confirmed": "待执行", "in_progress": "执行中",
      "pending_receipt": "待确认回执", "completed": "已完成", "reviewed": "已评价", "cancelled": "已取消",
    ][value] ?? "状态更新中"
  }
  static func actor(_ value: String) -> String {
    ["user": "信众", "master": "大师", "temple_admin": "寺院管理员", "system": "系统"][value] ?? "执行方"
  }
}

/// Both native apps use the same session recovery and tenant enforcement as their existing API client.
@MainActor
enum JourneyAPI {
  static func request<T: Decodable>(
    _ path: String, query: [URLQueryItem] = [], body: [String: Any]? = nil, method: String = "POST"
  ) async throws -> T {
    var components = URLComponents(
      url: APIClient.shared.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
    if !query.isEmpty { components.queryItems = query }
    guard let url = components.url else { throw JourneyFailure(message: "请求地址无效") }
    var request = URLRequest(url: url)
    if let body {
      request.httpMethod = method
      request.httpBody = try JSONSerialization.data(withJSONObject: body)
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    let (data, _) = try await APIClient.shared.sessionData(for: request)
    try Task.checkCancellation()
    return try JSONDecoder().decode(JourneyEnvelope<T>.self, from: data).data
  }
  static func index(
    filter: String = "all", page: Int = 1, query: String = "", from: String = "", to: String = ""
  ) async throws -> JourneyIndex {
    try await request(
      "bookings/journeys",
      query: [
        URLQueryItem(name: "filter", value: filter),
        URLQueryItem(name: "page", value: String(page)), URLQueryItem(name: "q", value: query),
        URLQueryItem(name: "from", value: from), URLQueryItem(name: "to", value: to),
      ])
  }
  static func progress(_ id: String) async throws -> JourneyProgress {
    try await request("bookings/\(id)/fulfillment")
  }
  static func action(_ id: String, _ action: String, body: [String: Any] = [:]) async throws {
    let _: JourneyActionResponse = try await request("bookings/\(id)/\(action)", body: body)
  }
  static func advance(_ id: String, status: String) async throws {
    let _: JourneyActionResponse = try await request(
      "admin/masters/bookings/\(id)/\(status == "pending" ? "confirm" : "start")", body: [:],
      method: "PUT")
  }
  static func upload(_ id: String, data: Data, name: String, mime: String) async throws
    -> JourneyMedia
  {
    guard data.count <= 20 * 1024 * 1024 else { throw JourneyFailure(message: "每个文件最多 20 MB") }
    guard ["image/jpeg", "image/png", "image/webp", "video/mp4", "video/webm"].contains(mime) else {
      throw JourneyFailure(message: "请选择 JPG、PNG、WebP 图片或 MP4、WebM 视频")
    }
    let boundary = "Journey-\(UUID().uuidString)"
    var body = Data(
      "--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(name.replacingOccurrences(of: "\"", with: "_").replacingOccurrences(of: "\r", with: "").replacingOccurrences(of: "\n", with: ""))\"\r\nContent-Type: \(mime)\r\n\r\n"
        .utf8)
    body.append(data)
    body.append(Data("\r\n--\(boundary)--\r\n".utf8))
    var request = URLRequest(
      url: APIClient.shared.baseURL.appendingPathComponent("bookings/\(id)/receipt-files"))
    request.httpMethod = "POST"
    request.httpBody = body
    request.timeoutInterval = 90
    request.setValue(
      "multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    let (response, _) = try await APIClient.shared.sessionData(for: request)
    return try JSONDecoder().decode(JourneyEnvelope<JourneyMedia>.self, from: response).data
  }
  static func media(_ id: String, file: JourneyMedia) async throws -> Data {
    let (data, response) = try await APIClient.shared.sessionData(
      for: URLRequest(
        url: APIClient.shared.baseURL.appendingPathComponent(
          "bookings/\(id)/receipt-files/\(file.id)")))
    guard response.mimeType == file.contentType else { throw JourneyFailure(message: "文件类型不符，请重试") }
    return data
  }
}
