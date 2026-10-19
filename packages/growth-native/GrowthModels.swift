import Foundation

struct GrowthLevel: Decodable, Identifiable {
    let code: Int; var id: Int { code }; let name: String; let threshold: Int64
    let goodsRateBps: Int64; let serviceRateBps: Int64; let couponMinimumCents: Int64; let couponValueCents: Int64; let benefit: String
}
struct GrowthCoupon: Decodable, Identifiable { let id: Int64; let level: Int; let minimumCents: Int64; let valueCents: Int64; let status: String; let expiresAt: Int64 }
struct GrowthTask: Decodable, Identifiable { let kind: String; var id: String { kind }; let award: Int; let used: Int; let limit: Int; let available: Bool; let period: String }
struct GrowthOverview: Decodable { let total: Int64; let level: GrowthLevel; let levels: [GrowthLevel]; let nextThreshold: Int64; let remaining: Int64; let pending: Int64; let monthlyEarned: Int64; let monthlyLimit: Int64; let badgeVisible: Bool; let discountsEnabled: Bool; let coupons: [GrowthCoupon]; let tasks: [GrowthTask]; let ruleVersion: String?; let rule: GrowthRuleRelease?; let revision: Int64? }
struct GrowthContent: Decodable, Identifiable { let id: Int64; let title: String; let kind: String; let body: String; let mediaUrl: String; let durationSeconds: Int64 }
struct GrowthLearning: Decodable { let sessionId: String; let elapsedSeconds: Int64; let completed: Bool }
struct GrowthNote: Decodable, Identifiable { let day: String; var id: String { day }; let action: String; let body: String }
struct GrowthActivity: Decodable, Identifiable { let id: Int64; let title: String; let description: String; let startsAt: Int64; let endsAt: Int64; let registeredAt: Int64; let verifiedAt: Int64 }
struct GrowthEntry: Decodable, Identifiable { let id: Int64; let kind: String; let referenceNo: String; let delta: Int64; let totalAfter: Int64; let createdAt: Int64 }
struct GrowthPending: Decodable, Identifiable { let id: Int64; let referenceNo: String; let amount: Int64; let reason: String; let eligibleAt: Int64 }
struct GrowthRecords: Decodable { var entries: [GrowthEntry]; let pending: [GrowthPending]; let hasMore: Bool }
struct GrowthSummary: Decodable {
    struct Source: Decodable, Identifiable { let kind: String; var id: String { kind }; let amount: Int64; let count: Int64 }
    let period: String; let added: Int64; let reversed: Int64; let entries: Int64; let bySource: [Source]
}
struct GrowthSupport: Decodable, Identifiable { let id: Int64; let body: String; let reply: String; let status: String }
struct GrowthPriceLine: Decodable, Identifiable { let id: String; let name: String; let amountCents: Int64; let discountCents: Int64; let netCents: Int64; let eligible: Bool; let growthEligible: Bool }
struct GrowthOffer: Decodable, Identifiable {
    let kind: String; let couponId: Int64; var id: String { "\(kind):\(couponId)" }; let discountCents: Int64; let payableCents: Int64; let estimatedGrowth: Int64; let lines: [GrowthPriceLine]
}
struct GrowthPriceQuote: Decodable {
    struct Snapshot: Decodable { let level: GrowthLevel; let offers: [GrowthOffer]; let selected: GrowthOffer }
    let quoteId: String; let expiresAt: Int64; let grossCents: Int64; let discountCents: Int64; let payableCents: Int64; let status: String; let snapshot: Snapshot
}
struct GrowthPolicy: Decodable, Identifiable { let itemType: String; let itemId: String; var id: String {itemType+":"+itemId}; let title: String; let enabled: Bool; let consent: Bool; let revision: Int64 }
struct GrowthBill: Decodable, Identifiable { let orderNo: String; var id: String { orderNo }; let orderType: String; let status: String; let contractGrossCents: Int64; let customerPaidCents: Int64; let platformSubsidyCents: Int64 }
struct GrowthAck: Decodable {}
@MainActor enum GrowthAPI {
    static func request<T: Decodable>(_ path: String, body: [String: Any]? = nil) async throws -> T {
        guard let url = URL(string: APIClient.shared.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/payments/growth/" + path) else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        if let body { request.httpMethod = "POST"; request.httpBody = try JSONSerialization.data(withJSONObject: body); request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        let (data, _) = try await APIClient.shared.sessionData(for: request)
        let response = try JSONDecoder().decode(APIResponse<T>.self, from: data)
        guard response.code == 0, let value = response.data else { throw APIError.serverError(response.code, response.message) }
        return value
    }
    static func label(_ key: String) -> String {
        L10n.lookup(["profile":"完善资料","learning":"每日学习","note":"记录行动","activity":"参与活动","review":"真实评价","purchase":"有效消费","reversal":"退款或纠正","adjustment":"人工补偿","unused":"可使用","pending_budget":"待发放","used":"已使用","reserved":"订单占用中","expired":"已过期","revoked":"已撤回","normal":"原价","level":"等级优惠","coupon":"升级礼券","waiting_completion":"等待订单完成","observation_period":"观察期内","after_sale":"售后处理中"][key] ?? key)
    }
    static func money(_ cents: Int64) -> String { String(format: "%.2f", Double(cents)/100) }
    static func rate(_ basisPoints: Int64) -> String { basisPoints == 10000 ? L10n.text("原价") : String(format:"%.1f",Double(basisPoints)/1000)+L10n.text("折") }
    static func date(_ seconds: Int64) -> String { Date(timeIntervalSince1970: Double(seconds)).formatted(date: .abbreviated, time: .omitted) }
}

struct GrowthRuleConfig: Decodable { let levels: [GrowthLevel]; let tasks: [GrowthTask]; let monthlyGrowthLimit: Int64; let monthlyDiscountLimitCents: Int64; let goodsDiscountCapCents: Int64; let serviceDiscountCapCents: Int64; let observationDays: Int64; let couponDays: Int64 }
struct GrowthRuleRelease: Decodable, Identifiable { let version: String; var id: String { version }; let summary: String; let effectiveAt: Int64; let createdAt: Int64; let status: String; let config: GrowthRuleConfig }
struct GrowthRuleHistory: Decodable { let items: [GrowthRuleRelease]; let hasMore: Bool; let currentVersion: String }
struct GrowthLevelNotice: Decodable { let level: GrowthLevel; let previousLevel: Int; let revision: Int64 }
struct GrowthNoticeResponse: Decodable { let notice: GrowthLevelNotice? }
struct GrowthCatalogItem: Encodable, Equatable { let itemType: String; let itemId: String; var quantity: Int = 1; var spec: String? = nil }
struct GrowthCatalogPreview: Decodable { struct Snapshot: Decodable { let ruleVersion: String; let level: GrowthLevel; let offers: [GrowthOffer]; let selected: GrowthOffer }; let grossCents: Int64; let levelPrice: GrowthOffer?; let reason: String; let expiresAt: Int64; let serverTime: Int64; let snapshot: Snapshot
 var valid: Bool {
  guard (0...100_000_000).contains(grossCents), serverTime > 0, expiresAt > serverTime, expiresAt - serverTime <= 30, (1...5).contains(snapshot.level.code), !snapshot.ruleVersion.isEmpty, !snapshot.offers.isEmpty else { return false }
  func validOffer(_ offer: GrowthOffer) -> Bool {
   guard ["normal", "level", "coupon", "activity_price"].contains(offer.kind), (0...grossCents).contains(offer.payableCents), offer.discountCents == grossCents - offer.payableCents, (0...100_000_000).contains(offer.estimatedGrowth), !offer.lines.isEmpty, offer.lines.count <= 100 else { return false }
   guard offer.lines.allSatisfy({ (0...grossCents).contains($0.amountCents) && (0...$0.amountCents).contains($0.netCents) && $0.discountCents == $0.amountCents - $0.netCents }) else { return false }
   return offer.lines.reduce(0) { $0 + $1.netCents } == offer.payableCents && offer.lines.reduce(0) { $0 + $1.amountCents } == grossCents
  }
  func included(_ offer: GrowthOffer) -> Bool { snapshot.offers.contains { $0.id == offer.id && $0.payableCents == offer.payableCents && $0.discountCents == offer.discountCents } }
  guard snapshot.offers.allSatisfy(validOffer), validOffer(snapshot.selected), included(snapshot.selected) else { return false }
  if let levelPrice { return levelPrice.kind == "level" && validOffer(levelPrice) && included(levelPrice) }
  return true
 }
}
