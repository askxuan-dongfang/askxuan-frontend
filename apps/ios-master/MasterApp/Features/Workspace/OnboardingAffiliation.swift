import Foundation

struct WorkProfile: Codable {
    var name: String?
    var legalName: String?
    var contact: String?
    var region: String?
    var belief: String?
    var traditionCodes: [String]?
    var sect: String?
    var position: String?
    var description: String?
    var evidenceIds: [String]?

    /// Legacy text and saved associations are preserved until the applicant resolves them.
    func normalized() -> Self {
        var profile = self
        profile.belief = OnboardingAffiliation.canonical(belief ?? "")
        profile.traditionCodes = traditionCodes ?? []
        profile.evidenceIds = evidenceIds ?? []
        return profile
    }
}

struct OnboardingTradition: Decodable, Identifiable {
    let code: String
    let group: String
    let beliefCode: String?
    let name: String
    let status: String
    var id: String { code }
}

enum OnboardingAffiliation {
    struct Belief: Identifiable {
        let code: String
        let name: String
        var id: String { code }
    }

    static let beliefs: [Belief] = [
        Belief(code: "han_buddhism", name: "汉传佛教"),
        Belief(code: "tibetan_buddhism", name: "藏传佛教"),
        Belief(code: "theravada_buddhism", name: "南传佛教"),
        Belief(code: "daoism", name: "道教"),
        Belief(code: "folk", name: "民间信仰")
    ]

    static func canonical(_ code: String) -> String {
        code == "taoism" ? "daoism" : code
    }

    static func choices(in catalog: [OnboardingTradition], belief: String) -> [OnboardingTradition] {
        catalog.filter {
            $0.group == "tradition" && $0.status == "enabled"
                && canonical($0.beliefCode ?? "") == canonical(belief)
        }
    }

    static func issue(for code: String, belief: String, catalog: [OnboardingTradition]) -> String? {
        guard let tag = catalog.first(where: { $0.code == code && $0.group == "tradition" }) else {
            return "目录中未找到"
        }
        guard tag.status == "enabled" else { return "已停用" }
        guard canonical(tag.beliefCode ?? "") == canonical(belief) else {
            return "不属于当前信仰流派"
        }
        return nil
    }

    static func validationError(
        profile: WorkProfile,
        catalog: [OnboardingTradition],
        catalogReady: Bool,
        submit: Bool
    ) -> String? {
        let codes = profile.traditionCodes ?? []
        guard codes.count <= 12 else { return "宗派／信俗最多选择 12 项" }
        guard Set(codes).count == codes.count,
              !codes.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            return "宗派／信俗选择无效，请移除重复或空白项"
        }
        // A draft can retain old or temporarily unavailable choices without silently rewriting them.
        guard submit else { return nil }
        let belief = canonical(profile.belief ?? "")
        guard beliefs.contains(where: { $0.code == belief }) else { return "请选择信仰流派" }
        guard catalogReady else { return "请先加载宗派／信俗目录" }
        guard !codes.isEmpty else { return "请至少选择一项宗派／信俗" }
        guard !codes.contains(where: { issue(for: $0, belief: belief, catalog: catalog) != nil }) else {
            return "请先移除不属于当前流派、已停用或无效的宗派／信俗"
        }
        return nil
    }
}
