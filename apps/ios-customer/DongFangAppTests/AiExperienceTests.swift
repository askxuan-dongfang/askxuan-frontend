import XCTest
@testable import DongFangApp

final class AiExperienceTests: XCTestCase {
    func testNamingPayloadOmitsInactiveDecisionAndEncodesOnlyContractFields() throws {
        let input = AiExperienceInput(skill: "naming", naming: AiNamingInput(), decision: nil)
        let data = try JSONEncoder().encode(input)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(object.keys), Set(["skill", "naming"]))
        XCTAssertEqual(try JSONDecoder().decode(AiExperienceInput.self, from: data), input)
    }
    func testIdempotencySurvivesRetriesButChangesWithEditedPayload() {
        var identity = AiNoteSaveIdentity()
        let input = AiExperienceInput(skill: "decision", naming: nil, decision: AiDecisionInput())
        let first = identity.request(input: input, favorites: ["b", "a"], note: "考虑长期价值")
        let retry = identity.request(input: input, favorites: ["a", "b"], note: "考虑长期价值")
        XCTAssertEqual(first.requestKey, retry.requestKey)
        let edited = identity.request(input: input, favorites: [], note: "重新考虑")
        XCTAssertNotEqual(first.requestKey, edited.requestKey)
    }
    func testServerDecisionSnapshotPreservesHardConstraintsAndVersion() throws {
        let json = #"{"id":5,"createdAt":"2026-09-21 12:00:00","data":{"input":{"skill":"decision","decision":{"a":"A","b":"B","constraintA":"超出预算","constraintB":"","factors":[{"label":"感受","weight":3,"a":5,"b":2},{"label":"时间","weight":1,"a":5,"b":3}]}},"result":{"skill":"decision","version":"2026-09-21.1","basis":"按权重计算","summary":"A 不满足底线","nextSteps":["补充资料"],"comparison":{"scoreA":100,"scoreB":45,"eligibleA":false,"eligibleB":true,"factors":[{"label":"感受","weight":3,"a":5,"b":2,"contributionA":75,"contributionB":30}]}},"favorites":[],"note":"保留当时的输入"}}"#
        let note = try JSONDecoder().decode(AiExperienceNote.self, from: Data(json.utf8))
        XCTAssertEqual(note.data.result.comparison?.eligibleA, false)
        XCTAssertEqual(note.data.result.comparison?.scoreA, 100)
        XCTAssertEqual(note.data.input.decision?.constraintA, "超出预算")
        XCTAssertEqual(note.data.result.version, "2026-09-21.1")
        XCTAssertEqual(note.data.note, "保留当时的输入")
    }
    func testNewEndpointsUseAuthenticatedRoutesAndExpectedMethods() throws {
        XCTAssertEqual(Endpoint.aiNotes(2).path, "ai/notes")
        XCTAssertEqual(Endpoint.aiNotes(2).queryItems?.first?.value, "2")
        XCTAssertEqual(Endpoint.aiNoteDelete(5).path, "ai/notes/5")
        XCTAssertTrue(Endpoint.aiNoteDelete(5).usesSessionAuthorization)
    }
}

import SwiftUI
@MainActor final class AiExperienceRenderTests: XCTestCase {
    func testNativeNamingAndDecisionLayouts() throws {
        let naming = AiExperienceInput(skill: "naming", naming: AiNamingInput(), decision: nil)
        let result = AiExperienceResult(skill: "naming", version: "2026-09-21.1", basis: "字义来自汉典，组合联想为编辑内容。", summary: "从喜欢的字义开始", nextSteps: ["结合姓氏读一读"], candidates: [AiNameCandidate(id: "a", name: "云舒", idea: "开阔从容", characters: [AiNameCharacter(text: "云", reading: "yún", meaning: "天空中悬浮的水滴或冰晶形成的集合体。", source: "https://www.zdic.net/hans/云")])], comparison: nil)
        for (width, scheme) in [(320.0, ColorScheme.dark), (390.0, ColorScheme.light)] {
            let root = ScrollView { AiExperienceResultView(input: naming, result: result, favorites: .constant(["a"]), editable: false).padding(18) }
                .background(Color.bgPrimary).preferredColorScheme(scheme)
            let renderer = ImageRenderer(content: root.frame(width: width, height: 844))
            let image = try XCTUnwrap(renderer.uiImage)
            XCTAssertEqual(image.size.width, width)
            let attachment = XCTAttachment(image: image)
            attachment.name = "ai-native-naming-\(Int(width))"; attachment.lifetime = .keepAlways; add(attachment)
        }
        let form = AiExperienceView(skill: "decision", naming: .constant(AiNamingInput()), decision: .constant(AiDecisionInput()))
        let renderer = ImageRenderer(content: form.frame(width: 390, height: 844).preferredColorScheme(.light))
        let attachment = XCTAttachment(image: try XCTUnwrap(renderer.uiImage))
        attachment.name = "ai-native-decision"; attachment.lifetime = .keepAlways; add(attachment)
    }
}
