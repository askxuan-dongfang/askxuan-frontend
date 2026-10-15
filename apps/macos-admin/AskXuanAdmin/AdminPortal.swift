import Foundation

enum AdminPortal: String, CaseIterable, Identifiable {
    case platform, temple
    var id: String { rawValue }
    var title: String { self == .platform ? "运营后台" : "寺院后台" }
    var icon: String { self == .platform ? "square.grid.2x2" : "building.columns" }
    var path: String { self == .platform ? "/admin/" : "/temple/" }
    // Separate persistent stores prevent same-origin localStorage/cookie collisions.
    var storeID: UUID {
        UUID(uuidString: self == .platform ? "54A8361B-1547-43DA-A3AD-73D4117FDC21" : "8CC7387F-0D4C-48AA-9652-FCC9581A91CD")!
    }
    func owns(_ url: URL, origin: URL) -> Bool {
        guard Self.sameOrigin(url, origin) else { return false }
        let value = url.path.removingPercentEncoding ?? url.path
        return value == String(path.dropLast()) || value.hasPrefix(path) ||
            (self == .platform && (value == "/shop" || value.hasPrefix("/shop/")))
    }
    static func sameOrigin(_ a: URL, _ b: URL) -> Bool {
        a.scheme == b.scheme && a.host == b.host && (a.port ?? 443) == (b.port ?? 443) && a.user == nil && a.password == nil
    }
    static func matching(_ url: URL, origin: URL) -> Self? { allCases.first { $0.owns(url, origin: origin) } }
}

enum AdminEnvironment {
    static let origin: URL = {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["ASKXUAN_MAC_TEST_ORIGIN"],
           let url = URL(string: raw), ["127.0.0.1", "localhost"].contains(url.host ?? ""),
           ["http", "https"].contains(url.scheme ?? "") { return url }
        #endif
        let raw = Bundle.main.object(forInfoDictionaryKey: "ASKXUAN_WEB_BASE_URL") as? String ?? "https://101.96.228.71"
        guard let url = URL(string: raw), url.scheme == "https", url.host != nil,
              url.user == nil, url.password == nil else { preconditionFailure("A valid HTTPS administration origin is required") }
        return url
    }()
}
