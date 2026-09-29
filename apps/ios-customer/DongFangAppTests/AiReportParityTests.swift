import XCTest
import SwiftUI
import PDFKit
@testable import DongFangApp

final class AiReportContractTests: XCTestCase {
    func testBothCalendarsAndServerNumericConstraints() throws {
        let decoder = JSONDecoder()
        let date = try decoder.decode(AiSkillField.self, from: Data(#"{"key":"partnerBirthDate","label":"对方生日","type":"date","required":true}"#.utf8))
        XCTAssertTrue(date.valid(in: ["partnerCalendarType":"lunar", "partnerBirthDate":"1990-02-30"]))
        XCTAssertFalse(date.valid(in: ["partnerCalendarType":"solar", "partnerBirthDate":"1990-02-30"]))
        XCTAssertFalse(date.valid(in: ["partnerBirthDate":"1800-01-01"]))
        let number = try decoder.decode(AiSkillField.self, from: Data(#"{"key":"year","label":"年份","type":"number","required":true,"min":1900,"max":2100,"validation":"integer"}"#.utf8))
        XCTAssertTrue(number.valid(in: ["year":"2026"]))
        for value in ["1899", "2101", "2026.5", "nan", ""] { XCTAssertFalse(number.valid(in: ["year":value])) }
        let pillar = try decoder.decode(AiSkillField.self, from: Data(#"{"key":"pillar","label":"四柱","type":"text","required":true,"validation":"pillar"}"#.utf8))
        XCTAssertTrue(pillar.valid(in: ["pillar":"甲子"]))
        XCTAssertFalse(pillar.valid(in: ["pillar":"甲丑"]))
        let numbers = try decoder.decode(AiSkillField.self, from: Data(#"{"key":"numbers","label":"起卦数字","type":"text","required":true,"validation":"triple-numbers"}"#.utf8))
        XCTAssertTrue(numbers.valid(in: ["numbers":"1 2 3"]))
        XCTAssertFalse(numbers.valid(in: ["numbers":"1 2"]))
        let hidden = try decoder.decode(AiSkillField.self, from: Data(#"{"key":"leap","label":"闰月","type":"select","required":true,"visibleWhen":{"key":"calendar","value":"lunar"}}"#.utf8))
        XCTAssertTrue(hidden.valid(in: ["calendar":"solar"]))
    }
    func testHarnessClarificationDecodesConfirmedScalarValues() throws {
        let data = Data(#"{"runtime":"harness","modelCalls":2,"toolCalls":1,"clarification":{"skillCode":"bazi_dayun","question":"请确认资料","fields":[],"values":{"year":2026,"longitude":120.5,"name":"合成测试","missing":null}},"context":{"window":1048576,"outputBudget":16384,"estimatedInputTokens":12000,"droppedMessages":0,"summaryIncluded":false}}"#.utf8)
        let agent = try JSONDecoder().decode(AiAgentState.self, from: data)
        XCTAssertEqual(agent.clarification?.values["year"], "2026")
        XCTAssertEqual(agent.clarification?.values["longitude"], "120.5")
        XCTAssertNil(agent.clarification?.values["missing"])
        XCTAssertEqual(agent.context?.window, 1048576)
    }
    func testOldAndLockedReportsDoNotRequireGraphs() throws {
        let json = #"{"id":1,"reportNo":"TEST","skillCode":"bazi","title":"测试","version":"1","question":"测试","chapters":[],"priceCents":100,"pointsPrice":10,"status":"ready","summary":"摘要","content":"","errorMessage":"","unlocked":false,"createdAt":"2026-09-29"}"#
        let old = try JSONDecoder().decode(AiReport.self, from: Data(json.utf8))
        XCTAssertNil(old.document)
        let locked = try JSONDecoder().decode(AiReport.self, from: Data(json.dropLast().appending(",\"document\":{\"version\":0,\"runtime\":\"\",\"modelCalls\":0,\"toolCalls\":0,\"blocks\":null}}").utf8))
        XCTAssertNil(locked.document?.blocks)
    }
    func testTraceAndCancelContractsRemainAuthenticated() {
        XCTAssertEqual(Endpoint.aiTrace(12, 34).path, "ai/sessions/12/messages/34/trace")
        XCTAssertEqual(Endpoint.aiCancelMessage(12, 34).path, "ai/sessions/12/messages/34/cancel")
        XCTAssertTrue(Endpoint.aiTrace(12, 34).usesSessionAuthorization)
        XCTAssertTrue(Endpoint.aiCancelMessage(12, 34).usesSessionAuthorization)
    }
}

@MainActor final class AiReportRenderTests: XCTestCase {
    func testAllTwelveH5ExamplesDecodeAndEveryGraphKindRenders() throws {
        XCTAssertEqual(AiReportCatalog.examples.map(\.code), AiReportCatalog.order)
        let blocks = AiReportCatalog.examples.flatMap { $0.document?.blocks ?? [] }
        XCTAssertTrue(Set(["pillars", "elements", "timeline", "palaces", "hexagram", "cards", "pairs", "table"]).isSubset(of: Set(blocks.map(\.kind))))
        for kind in Set(blocks.map(\.kind)).sorted() {
            let block = try XCTUnwrap(blocks.first { $0.kind == kind })
            for (width, scheme) in [(320.0, ColorScheme.dark), (390.0, ColorScheme.light)] {
                let view = AiReportBlockView(block: block, expanded: true).padding(16).frame(width: width).fixedSize(horizontal: false, vertical: true).background(Color.bgPrimary).environment(\.colorScheme, scheme)
                let image = try XCTUnwrap(ImageRenderer(content: view).uiImage, kind)
                XCTAssertEqual(image.size.width, width)
                XCTAssertGreaterThan(try XCTUnwrap(image.pngData()).count, 1000)
                let attachment = XCTAttachment(image: image); attachment.name = "report-\(kind)-\(Int(width))"; attachment.lifetime = .keepAlways; add(attachment)
            }
        }
        let block = try XCTUnwrap(blocks.first)
        XCTAssertNotNil(ImageRenderer(content: AiReportBlockView(block: block).frame(width: 320).environment(\.dynamicTypeSize, .accessibility3)).uiImage)
    }
    func testPDFExportsUnlockedFullReportAndRejectsLockedContent() throws {
        let sample = try XCTUnwrap(AiReportCatalog.examples.first { $0.code == "bazi" })
        let report = AiReport(id: 900001, reportNo: "LOCAL-SYNTHETIC", skillCode: sample.code, title: sample.title, version: "1", question: "合成测试", chapters: [], priceCents: 0, pointsPrice: 0, status: "ready", summary: sample.summary, content: sample.content, errorMessage: "", unlocked: true, createdAt: "2026-09-29", document: sample.document)
        let url = try AiReportPDF.export(report)
        defer { try? FileManager.default.removeItem(at: url) }
        let pdf = try XCTUnwrap(PDFDocument(url: url))
        XCTAssertGreaterThan(pdf.pageCount, 2)
        XCTAssertTrue(pdf.string?.contains("LOCAL-SYNTHETIC") == true)
        XCTAssertGreaterThan(try Data(contentsOf: url).count, 10000)
        let attachment = XCTAttachment(contentsOfFile: url); attachment.name = "report-full-chart-export.pdf"; attachment.lifetime = .keepAlways; add(attachment)
        let locked = AiReport(id: 900002, reportNo: "LOCKED", skillCode: "bazi", title: "锁定", version: "1", question: "", chapters: [], priceCents: 1, pointsPrice: 1, status: "ready", summary: "摘要", content: "", errorMessage: "", unlocked: false, createdAt: "")
        XCTAssertThrowsError(try AiReportPDF.export(locked))
    }
}
