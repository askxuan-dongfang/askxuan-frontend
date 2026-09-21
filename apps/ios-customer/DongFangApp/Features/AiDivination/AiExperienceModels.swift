import Foundation

// Same versioned payload contract as H5; results are calculated and saved by the server.
struct AiNamingInput: Codable, Equatable {
    var purpose = "name"
    var style = "nature"
    var surname = ""
    var avoid = ""
}
struct AiDecisionFactor: Codable, Equatable {
    var label: String
    var weight: Int
    var a: Int
    var b: Int
}
struct AiDecisionInput: Codable, Equatable {
    var a = "方案 A"
    var b = "方案 B"
    var constraintA = ""
    var constraintB = ""
    var factors = [AiDecisionFactor(label: "长期价值", weight: 3, a: 3, b: 3),
                   AiDecisionFactor(label: "时间精力", weight: 3, a: 3, b: 3),
                   AiDecisionFactor(label: "当前感受", weight: 3, a: 3, b: 3)]
}
struct AiExperienceInput: Codable, Equatable {
    var skill: String
    var naming: AiNamingInput?
    var decision: AiDecisionInput?
}
struct AiNameCharacter: Codable {
    let text: String
    let reading: String
    let meaning: String
    let source: String
}
struct AiNameCandidate: Codable, Identifiable {
    let id: String
    let name: String
    let idea: String
    let characters: [AiNameCharacter]
}
struct AiDecisionContribution: Codable {
    let label: String
    let weight: Int
    let a: Int
    let b: Int
    let contributionA: Double
    let contributionB: Double
}
struct AiDecisionComparison: Codable {
    let scoreA: Double
    let scoreB: Double
    let eligibleA: Bool
    let eligibleB: Bool
    let factors: [AiDecisionContribution]
}
struct AiExperienceResult: Codable {
    let skill: String
    let version: String
    let basis: String
    let summary: String
    let nextSteps: [String]
    let candidates: [AiNameCandidate]?
    let comparison: AiDecisionComparison?
}
struct AiExperienceData: Codable {
    let input: AiExperienceInput
    let result: AiExperienceResult
    let favorites: [String]
    let note: String
}
struct AiExperienceNote: Codable, Identifiable {
    let id: Int64
    let createdAt: String
    let data: AiExperienceData
    var title: String { data.input.skill == "naming" ? "姓名灵感" : "两难梳理" }
}
struct AiNoteSaveRequest: Encodable, Equatable {
    let input: AiExperienceInput
    let favorites: [String]
    let note: String
    let requestKey: String
}

// A stable key is retained across uncertain network retries; any payload edit gets a new key.
struct AiNoteSaveIdentity {
    private var previous: AiNoteSaveRequest?
    mutating func request(input: AiExperienceInput, favorites: [String], note: String) -> AiNoteSaveRequest {
        let ordered = favorites.sorted()
        if let previous, previous.input == input, previous.favorites == ordered, previous.note == note { return previous }
        let next = AiNoteSaveRequest(input: input, favorites: ordered, note: note, requestKey: UUID().uuidString)
        previous = next
        return next
    }
}
