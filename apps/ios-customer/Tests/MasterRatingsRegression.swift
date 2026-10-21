import Foundation

// Runs the production directory view model and rating models on macOS without a simulator.
// The fake transport supplies the public API contract; it does not exercise URLSession or UI.
enum Endpoint {
    case masters(type: String?, templeId: String?, manageBy: String?, serviceCode: String?, page: Int, size: Int)
    case beliefs, serviceTypes, directoryTags, directoryRegions, reviewRatings
}

struct PageResponse<T: Decodable>: Decodable { let list: [T]; let total: Int }
struct BeliefListResponse: Decodable { let list: [Belief] }
struct Belief: Decodable { let code: String; let name: String }
struct ServiceCatalogResponse: Decodable { let list: [ServiceFilterOption] }
struct DirectoryItems<T: Decodable>: Decodable { let list: [T] }
struct DirectoryTag: Decodable {}
struct DirectoryRegion: Decodable {}
struct ServiceFilterOption: Decodable, Identifiable { let code: String; let name: String; var id: String { code } }
struct BeliefFilterOption { let code: String; let name: String }
struct DirectorySearchCatalog {
    init(beliefs: [BeliefFilterOption] = [], tags: [DirectoryTag] = [], services: [ServiceFilterOption] = [], regions: [DirectoryRegion] = []) {}
}
enum DirectorySearch {
    static func matches(_ query: String, fields: [String]) -> Bool { query.isEmpty || fields.contains { $0.contains(query) } }
    static func fields(master: Master, catalog: DirectorySearchCatalog) -> [String] { [master.dharmaName] }
}
enum DirectoryLoadError: Error { case incomplete }
enum ServiceType {
    static func from(serviceCode: String) -> ServiceType? { nil }
    var rawValue: String { "" }
}

final class APIClient {
    static let shared = APIClient()
    enum Scenario { case ratings, empty, unavailable, invalid }
    var scenario: Scenario = .ratings
    private(set) var ratingsRequests = 0
    private(set) var masterRequests = 0

    @MainActor func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        try Task.checkCancellation()
        let payload: String
        switch endpoint {
        case .masters(_, _, _, _, let page, _):
            masterRequests += 1
            // Two directory pages, both with a seed rating that must never be shown.
            payload = #"{"list":[{"id":"\#(page == 1 ? "rated" : "unrated")","dharmaName":"师傅","rating":5.0}],"total":2}"#
        case .reviewRatings:
            ratingsRequests += 1
            switch scenario {
            case .ratings:
                payload = #"[{"kind":"master","code":"rated","count":1234,"average":4.6},{"kind":"temple","code":"rated","count":99,"average":1.0},{"kind":"temple","code":"unrated","count":99,"average":5.0}]"#
            case .empty: payload = "[]"
            case .unavailable: throw URLError(.cannotConnectToHost)
            case .invalid: payload = #"[{"kind":"master","code":"rated","count":4,"average":7}]"#
            }
        case .beliefs, .serviceTypes, .directoryTags, .directoryRegions:
            payload = #"{"list":[]}"#
        }
        return try JSONDecoder().decode(T.self, from: Data(payload.utf8))
    }
}

@main
struct MasterRatingsRegression {
    @MainActor
    static func main() async throws {
        var passed: [String] = []
        let api = APIClient()
        let model = MasterListViewModel(apiClient: api)
        let placeholder = try JSONDecoder().decode(Master.self, from: Data(#"{"id":"rated","rating":5}"#.utf8))
        try require(model.ratingState(for: placeholder) == .loading, "Initial rating must be loading")
        passed.append("initial_loading")

        await model.load()
        try require(model.errorMessage == nil && model.masters.count == 2, "Directory must load both pages")
        try require(api.masterRequests == 2 && api.ratingsRequests == 1, "One batch must cover all directory pages")
        let rated = model.masters[0], unrated = model.masters[1]
        try require(model.ratingState(for: rated) == .rated(average: 4.6, count: 1234), "Only master kind and matching code may provide the real aggregate")
        try require(model.ratingState(for: unrated) == .unrated, "Missing master aggregate must ignore seed rating and temple aggregate")
        passed.append("batch_contract_master_code_and_no_seed_fallback")

        model.selectedServiceCode = "S001"
        model.selectedPrice = "200–500元"
        model.clearFilters()
        try require(api.ratingsRequests == 1, "Local filters must not trigger rating fetches")
        passed.append("filters_do_not_refetch")

        api.scenario = .unavailable
        await model.load()
        try require(model.errorMessage == nil && model.masters.count == 2, "Rating failure must preserve the directory")
        try require(model.ratingState(for: rated) == .unavailable && model.ratingState(for: unrated) == .unavailable, "Fetch failure must replace stale ratings with unavailable")
        passed.append("rating_failure_isolated_from_directory")

        api.scenario = .empty
        await model.load()
        try require(model.ratingState(for: rated) == .unrated && model.ratingState(for: unrated) == .unrated, "Successful empty batch means no ratings")
        passed.append("successful_empty_batch_is_unrated")

        api.scenario = .invalid
        await model.load()
        try require(model.ratingState(for: rated) == .unavailable, "Invalid aggregate must not appear as a genuine score")
        try require(api.ratingsRequests == 4, "Every explicit refresh makes exactly one rating request")
        passed.append("invalid_aggregate_rejected_and_refresh_refetches")

        let output: [String: Any] = ["passed": passed.count, "checks": passed, "scope": "production view model and models with fake transport; no native UI or URLSession execution"]
        print(String(decoding: try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys]), as: UTF8.self))
    }

    private static func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw RegressionFailure(message: message) }
    }
}

private struct RegressionFailure: Error { let message: String }
