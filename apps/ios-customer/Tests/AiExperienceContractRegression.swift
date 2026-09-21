import Foundation

@main struct AiExperienceContractRegression {
    struct Envelope<T: Decodable>: Decodable { let code: Int; let data: T }
    static func run(_ input: AiExperienceInput) async throws -> AiExperienceResult {
        // This local fixture proxy never authenticates against production.
        var request = URLRequest(url: URL(string: "http://127.0.0.1:18198/api/v1/ai/experiences/run")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer fixture-95101", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(input)
        let (data, response) = try await URLSession.shared.data(for: request)
        precondition((response as? HTTPURLResponse)?.statusCode == 200)
        let decoded = try JSONDecoder().decode(Envelope<AiExperienceResult>.self, from: data)
        precondition(decoded.code == 0)
        return decoded.data
    }
    static func main() async throws {
        let naming = AiExperienceInput(skill: "naming", naming: AiNamingInput(purpose: "name", style: "nature", surname: "林", avoid: ""), decision: nil)
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(naming)) as! [String: Any]
        precondition(Set(json.keys) == Set(["skill", "naming"]))
        var identity = AiNoteSaveIdentity()
        let first = identity.request(input: naming, favorites: ["b", "a"], note: "想法")
        precondition(first.requestKey == identity.request(input: naming, favorites: ["a", "b"], note: "想法").requestKey)
        precondition(first.requestKey != identity.request(input: naming, favorites: [], note: "编辑后").requestKey)
        let named = try await run(naming)
        precondition(named.candidates?.map(\.name) == ["林云舒", "林星禾", "林初晴"])
        precondition(named.candidates?.first?.characters.first?.source.hasPrefix("https://www.zdic.net/") == true)
        var decision = AiDecisionInput(a: "A", b: "B", constraintA: "超出预算", constraintB: "", factors: [AiDecisionFactor(label: "长期价值", weight: 3, a: 5, b: 2), AiDecisionFactor(label: "时间", weight: 1, a: 5, b: 3)])
        let constrained = try await run(AiExperienceInput(skill: "decision", naming: nil, decision: decision))
        precondition(constrained.comparison?.scoreA == 100 && constrained.comparison?.eligibleA == false)
        precondition(constrained.comparison?.scoreB == 45 && constrained.comparison?.eligibleB == true)
        decision.constraintA = ""
        let eligible = try await run(AiExperienceInput(skill: "decision", naming: nil, decision: decision))
        precondition(eligible.comparison?.eligibleA == true)
        print("PASS: native JSON contracts, idempotent retry identity, live naming provenance, weighted score and hard constraint")
    }
}
