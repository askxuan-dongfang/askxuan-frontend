import Foundation
import Testing
@testable import OnboardingRules

private let catalog = [
    OnboardingTradition(code: "chan", group: "tradition", beliefCode: "han_buddhism", name: "禅宗", status: "enabled"),
    OnboardingTradition(code: "gelug", group: "tradition", beliefCode: "tibetan_buddhism", name: "格鲁派", status: "enabled"),
    OnboardingTradition(code: "theravada", group: "tradition", beliefCode: "theravada_buddhism", name: "上座部传统", status: "enabled"),
    OnboardingTradition(code: "quanzhen", group: "tradition", beliefCode: "daoism", name: "全真派", status: "enabled"),
    OnboardingTradition(code: "mazu", group: "tradition", beliefCode: "folk", name: "妈祖 / 天后", status: "enabled"),
    OnboardingTradition(code: "guandi", group: "tradition", beliefCode: "folk", name: "关帝信俗", status: "enabled"),
    OnboardingTradition(code: "disabled", group: "tradition", beliefCode: "folk", name: "停用项", status: "disabled"),
    OnboardingTradition(code: "identity", group: "position", beliefCode: "folk", name: "资料身份", status: "enabled")
]

@Test func legacyProfileDecodingAndEncodingPreserveText() throws {
    let data = Data(#"{"belief":"taoism","sect":"历史原文：全真派"}"#.utf8)
    let profile = try JSONDecoder().decode(WorkProfile.self, from: data).normalized()
    #expect(profile.belief == "daoism")
    #expect(profile.sect == "历史原文：全真派")
    #expect(profile.traditionCodes == [])
    let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(profile)) as? [String: Any])
    #expect(json["traditionCodes"] as? [String] == [])
    #expect(json["sect"] as? String == "历史原文：全真派")
}

@Test(arguments: ["han_buddhism", "tibetan_buddhism", "theravada_buddhism", "daoism", "folk"])
func fiveBeliefChoicesAndSubmission(belief: String) throws {
    let choices = OnboardingAffiliation.choices(in: catalog, belief: belief)
    let selected = try #require(choices.first)
    #expect(choices.allSatisfy { $0.beliefCode == belief && $0.group == "tradition" && $0.status == "enabled" })
    var profile = WorkProfile()
    profile.belief = belief;profile.traditionCodes = [selected.code];profile.sect = ""
    #expect(OnboardingAffiliation.validationError(profile: profile, catalog: catalog, catalogReady: true, submit: true) == nil)
}

@Test func explicitMultipleAssociationsDoNotRewriteText() {
    var profile = WorkProfile()
    profile.belief = "folk";profile.traditionCodes = ["mazu", "guandi"];profile.sect = "保留补充说明"
    #expect(OnboardingAffiliation.validationError(profile: profile, catalog: catalog, catalogReady: true, submit: true) == nil)
    #expect(profile.sect == "保留补充说明")
    #expect(profile.traditionCodes == ["mazu", "guandi"])
}

@Test func changedBeliefRetainsDraftButRequiresResolution() {
    var profile = WorkProfile()
    profile.belief = "daoism";profile.traditionCodes = ["mazu", "guandi"]
    #expect(OnboardingAffiliation.validationError(profile: profile, catalog: catalog, catalogReady: true, submit: false) == nil)
    #expect(OnboardingAffiliation.validationError(profile: profile, catalog: catalog, catalogReady: true, submit: true) != nil)
    #expect(profile.traditionCodes == ["mazu", "guandi"])
}

@Test func emptyDraftAndCatalogFailureDoNotEraseData() {
    var profile = WorkProfile()
    profile.belief = "folk"
    #expect(OnboardingAffiliation.validationError(profile: profile, catalog: [], catalogReady: false, submit: false) == nil)
    #expect(OnboardingAffiliation.validationError(profile: profile, catalog: [], catalogReady: false, submit: true) == "请先加载宗派／信俗目录")
    #expect(OnboardingAffiliation.validationError(profile: profile, catalog: catalog, catalogReady: true, submit: true) == "请至少选择一项宗派／信俗")
}

@Test(arguments: ["missing", "disabled", "identity"])
func unavailableSelectionsRemainInDraft(code: String) {
    var profile = WorkProfile()
    profile.belief = "folk";profile.traditionCodes = [code]
    #expect(OnboardingAffiliation.issue(for: code, belief: "folk", catalog: catalog) != nil)
    #expect(OnboardingAffiliation.validationError(profile: profile, catalog: catalog, catalogReady: true, submit: false) == nil)
    #expect(OnboardingAffiliation.validationError(profile: profile, catalog: catalog, catalogReady: true, submit: true) != nil)
    #expect(profile.traditionCodes == [code])
}

@Test(arguments: [["mazu", "mazu"], [""], [" "], (0..<13).map(String.init)])
func malformedSelectionsAreRejected(codes: [String]) {
    var profile = WorkProfile()
    profile.belief = "folk";profile.traditionCodes = codes
    #expect(OnboardingAffiliation.validationError(profile: profile, catalog: catalog, catalogReady: true, submit: false) != nil)
    #expect(OnboardingAffiliation.validationError(profile: profile, catalog: catalog, catalogReady: true, submit: true) != nil)
}
