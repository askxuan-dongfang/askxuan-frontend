import XCTest
@testable import DongFangApp

func liveRewardFixture(kind: String = "wheel", participants: Int = 0, prizes: Int = 20, awarded: Int = 0, capacity: Int = 200) -> RewardCampaign {
    RewardCampaign(id: 2, title: "秋日好礼 · 积分幸运转盘", kind: kind, prizeName: "平安香囊礼袋", image: "", description: "一份草木香，送给幸运的你。", rules: "每人每期一次", prizeValue: 3900, budget: 100000, pointsCost: 10, prizeQuantity: prizes, capacity: capacity, participantCount: participants, awardedCount: awarded, startsAt: 1788973900, endsAt: 1790183560, drawnAt: 0, status: "published", phase: "open", poolDigest: "", announcement: "", algorithm: "crypto-rand")
}
final class RewardExperienceTests: XCTestCase {
    func testPoolProbabilityUsesValidParticipants() {
        XCTAssertEqual(liveRewardFixture(kind: "pool", participants: 100, prizes: 1).oddsText, "1.00%")
        XCTAssertEqual(liveRewardFixture(kind: "pool", participants: 2, prizes: 3).oddsText, "100.00%")
        XCTAssertEqual(liveRewardFixture(kind: "pool", participants: 0, prizes: 1).oddsText, "—")
    }
    func testWheelProbabilityUsesRemainingInventory() {
        XCTAssertEqual(liveRewardFixture().oddsText, "10.00%")
        XCTAssertEqual(liveRewardFixture(participants: 100, awarded: 15).oddsText, "5.00%")
        XCTAssertEqual(liveRewardFixture(participants: 100, awarded: 20).oddsText, "0.00%")
        XCTAssertEqual(liveRewardFixture(participants: 200, awarded: 20).oddsText, "—")
    }
    func testServerDetailPreservesBalanceAndResult() throws {
        let campaignData = try JSONEncoder().encode(liveRewardFixture())
        let campaign = try JSONSerialization.jsonObject(with: campaignData)
        let raw: [String: Any] = ["campaign": campaign, "pointsBalance": 5, "mine": ["id": 8, "campaignId": 2, "createdAt": 1789006900, "pointsSpent": 10, "code": "WX-2-8", "outcome": "lost", "title": "本期转盘"], "winners": []]
        let decoded = try JSONDecoder().decode(RewardDetail.self, from: JSONSerialization.data(withJSONObject: raw))
        XCTAssertEqual(decoded.pointsBalance, 5); XCTAssertEqual(decoded.mine?.code, "WX-2-8"); XCTAssertEqual(decoded.mine?.outcome, "lost")
    }
}

// Render actual SwiftUI components in the test host, without operating another
// project's Simulator window or making any production activity API request.
import SwiftUI
@MainActor final class RewardNativeRenderTests: XCTestCase {
    func testNativeActivityLayouts() async throws {
        let detail = RewardDetail(campaign: liveRewardFixture(), mine: nil, winners: [], pointsBalance: 15)
        for width in [320.0, 390.0, 768.0] {
            let wheel = NavigationStack {
                ScrollView {
                    RewardWheelExperience(detail: detail, busy: false, spinning: false, rotation: 0, hasError: false, onJoin: {}, onResult: {}).padding(16)
                }.background(Color.bgPrimary).navigationTitle("幸运转盘").navigationBarTitleDisplayMode(.inline)
            }
            try await render(wheel, name: "ios-wheel-focused-\(Int(width))", width: width)
            let view = NavigationStack {
                ScrollView {
                    VStack(spacing: 18) {
                        Text("积分，让期待发生").font(.title2).foregroundStyle(Color.accentDefault)
                        HStack(spacing: 12) { RewardCategoryEntry(kind: "wheel"); RewardCategoryEntry(kind: "pool") }
                        PointsWalletCard(balance: 15, onRules: {})
                        RewardWheelArt(rotation: 0, spinning: false, cost: 10).frame(height: 280)
                        RewardCountdown(endsAt: Int64(Date().timeIntervalSince1970) + 72 * 3600)
                        RewardDeliverySteps(status: "completed")
                    }.padding(16)
                }.background(Color.bgPrimary).navigationTitle("原生活动体验")
            }
            try await render(view, name: "ios-reward-components-\(Int(width))", width: width)
        }
        try await render(RewardWheelMotionFixture(), name: "ios-reward-wheel-motion", width: 390, height: 420, expectsMotion: true)
        let entry = RewardEntry(id: 8, campaignId: 2, createdAt: 1000, pointsSpent: 20, code: "WX-2-8", outcome: "won", title: "天然香珠 · 一期一礼")
        try await render(RewardResultSheet(entry: entry), name: "ios-reward-result", width: 390, height: 460)
    }
    private func render<V: View>(_ view: V, name: String, width: Double, height: Double = 844, expectsMotion: Bool = false) async throws {
        let root = view.environmentObject(AuthStore.shared).preferredColorScheme(.dark)
        let controller = UIHostingController(rootView: root)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: width, height: height)
        window.rootViewController = controller; window.makeKeyAndVisible()
        controller.view.frame = window.bounds
        controller.view.setNeedsLayout(); controller.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(350))
        let renderer = UIGraphicsImageRenderer(bounds: controller.view.bounds)
        let image = renderer.image { _ in controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true) }
        XCTAssertEqual(image.size.width, width, accuracy: 1)
        let attachment = XCTAttachment(image: image); attachment.name = name; attachment.lifetime = XCTAttachment.Lifetime.keepAlways; add(attachment)
        if expectsMotion && !UIAccessibility.isReduceMotionEnabled {
            try await Task.sleep(for: .milliseconds(300))
            let next = renderer.image { _ in controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true) }
            XCTAssertNotEqual(image.pngData(), next.pngData(), "The native wheel must move between animation frames")
            let second = XCTAttachment(image: next); second.name = name + "-next-frame"; second.lifetime = XCTAttachment.Lifetime.keepAlways; add(second)
        }
        window.isHidden = true
    }
}

private struct RewardWheelMotionFixture: View {
    @State private var rotation = 0.0
    var body: some View {
        RewardWheelArt(rotation: rotation, spinning: true, cost: 10).frame(width: 280, height: 280)
            .frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.bgPrimary)
            .onAppear { withAnimation(.timingCurve(0.12, 0.64, 0.1, 1, duration: 3.7)) { rotation = 2835 } }
    }
}

@MainActor final class AiSessionDeletionTests: XCTestCase {
    private func session(_ id: Int64) -> AiConversation {
        AiConversation(id: id, sessionNo: "test-\(id)", userId: "fixture", skillCode: "general", selectionMode: "explicit", skillVersion: "1", title: "验收会话", status: "active", createdAt: "", updatedAt: "")
    }
    func testDeleteRequestHasNoJSONBodyAndPurchaseKeepsPayload() throws {
        let deletion = try APIClient.shared.buildRequest(.aiSessionDelete(42))
        XCTAssertEqual(deletion.httpMethod, "DELETE"); XCTAssertTrue(deletion.url?.path.hasSuffix("ai/sessions/42") == true)
        XCTAssertNil(deletion.httpBody); XCTAssertNil(deletion.value(forHTTPHeaderField: "Content-Type"))
        let purchase = try APIClient.shared.buildRequest(.aiReportUnlock(.init(reportId: 42, expectedPoints: 10)))
        XCTAssertEqual(purchase.value(forHTTPHeaderField: "Content-Type"), "application/json"); XCTAssertNotNil(purchase.httpBody)
    }
    func testDeletingCurrentClearsConversationAndDraft() async {
        var requested: [Int64] = []
        let model = AiDivinationViewModel(deleteSessionRequest: { requested.append($0) })
        model.sessions = [session(1), session(2)]; model.selectedSessionId = 1; model.input = "草稿"; model.selectedImages = [Data([1])]
        let success = await model.deleteSession(session(1))
        XCTAssertTrue(success); XCTAssertEqual(requested, [1]); XCTAssertNil(model.selectedSessionId); XCTAssertEqual(model.input, ""); XCTAssertTrue(model.selectedImages.isEmpty); XCTAssertEqual(model.sessions.map(\.id), [2])
    }
    func testDeletingOtherPreservesCurrentDraft() async {
        let model = AiDivinationViewModel(deleteSessionRequest: { _ in })
        model.sessions = [session(1), session(2)]; model.selectedSessionId = 1; model.input = "保留的草稿"
        let success = await model.deleteSession(session(2))
        XCTAssertTrue(success); XCTAssertEqual(model.selectedSessionId, 1); XCTAssertEqual(model.input, "保留的草稿"); XCTAssertEqual(model.sessions.map(\.id), [1])
    }
    func testFailedDeletionKeepsSessionAndCanRetry() async {
        var fail = true
        let model = AiDivinationViewModel(deleteSessionRequest: { _ in if fail { throw URLError(.notConnectedToInternet) } })
        model.sessions = [session(1)]; model.selectedSessionId = 1
        let failed = await model.deleteSession(session(1)); XCTAssertFalse(failed); XCTAssertEqual(model.sessions.count, 1); XCTAssertEqual(model.selectedSessionId, 1); XCTAssertNotNil(model.deletionError); XCTAssertFalse(model.deletingSession)
        fail = false
        let success = await model.deleteSession(session(1)); XCTAssertTrue(success); XCTAssertTrue(model.sessions.isEmpty); XCTAssertNil(model.deletionError)
    }
}

@MainActor final class AiTopicNativeRenderTests: XCTestCase {
    func testGuidedFieldConditionalValidation() throws {
        let data = Data(#"{"key":"numbers","label":"起卦数字","type":"text","required":false,"helpText":"2–3 个整数","visibleWhen":{"key":"method","value":"number"},"requiredWhen":{"key":"method","value":"number"},"validation":"divination-numbers"}"#.utf8)
        let field = try JSONDecoder().decode(AiSkillField.self, from: data)
        XCTAssertFalse(field.visible(in: ["method":"auto"]))
        XCTAssertTrue(field.valid(in: ["method":"auto"]))
        XCTAssertFalse(field.valid(in: ["method":"number"]))
        XCTAssertFalse(field.valid(in: ["method":"number","numbers":"1 2 3 4"]))
        XCTAssertFalse(field.valid(in: ["method":"number","numbers":"-1 2"]))
        XCTAssertTrue(field.valid(in: ["method":"number","numbers":"12，34 56"]))
        XCTAssertEqual(field.helpText, "2–3 个整数")
    }

    func testProductTypographyRendersChineseAndNumericContent() async throws {
        XCTAssertEqual(AppTypography.serifName, "AskXuanSerif-Semibold")
        XCTAssertNotNil(UIFont(name: "HelveticaNeue", size: 14))
        for width in [320.0, 390.0, 768.0] {
            let content = VStack(alignment: .leading, spacing: 18) {
                Text("专题解读 · 问玄东方").font(AppTypography.navigation)
                Text("让每一次探索，有迹可循").font(AppTypography.hero)
                Text("我的积分与活动").font(AppTypography.section)
                Text("日常的每一份积累，都有清晰的记录。标题、正文与数字使用各自的文字层级。").font(AppTypography.body)
                Text("¥12,345.67 · 1,024 积分").font(AppTypography.numeric(28))
                Text("继续查看完整内容 →").font(AppTypography.control)
                Text("辅助说明 · 2026/9/10 16:30").font(AppTypography.caption)
            }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(Color.textPrimary).background(Color.bgPrimary)
            try await render(content, name: "ios-product-typography-\(Int(width))", width: width, height: 700)
        }
    }

    func testSevenTopicLayoutsAndMotion() async throws {
        let codes = ["bazi", "ziwei", "marriage", "fengshui", "liuyao", "qimen", "tarot"]
        let names = ["八字命理", "紫微斗数", "姻缘合盘", "风水布局", "六爻占卜", "奇门遁甲", "塔罗指引"]
        for width in [320.0,390.0,768.0] {
            let view = ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("一事一解，自有章法").font(.system(.title2, design: .serif))
                    LazyVGrid(columns: [GridItem(.flexible()),GridItem(.flexible())], spacing: 12) {
                        ForEach(Array(codes.enumerated()), id: \.offset) { index, code in AiTopicTile(topic: AiTopic(code:code,title:names[index],subtitle:"专题解读",priceCents:990,pointsPrice:10,chapters:[],version:"1")) }
                    }
                }.padding(18)
            }.background(Color(red:0.97,green:0.96,blue:0.93)).preferredColorScheme(.light)
            try await render(view, name:"ios-ai-seven-topics-\(Int(width))", width:width, height:900)
        }
        try await render(AiTopicArtwork(code:"ziwei").padding(35).background(.white),name:"ios-ai-topic-motion",width:390,height:360, motion:true)
    }
    private func render<V:View>(_ view:V,name:String,width:Double,height:Double,motion:Bool=false) async throws {
        let controller = UIHostingController(rootView:view)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene:scene);window.frame=CGRect(x:0,y:0,width:width,height:height);window.rootViewController=controller;window.makeKeyAndVisible();controller.view.frame=window.bounds;controller.view.layoutIfNeeded()
        try await Task.sleep(for:.milliseconds(350))
        let renderer=UIGraphicsImageRenderer(bounds:controller.view.bounds)
        let image=renderer.image { _ in controller.view.drawHierarchy(in:controller.view.bounds,afterScreenUpdates:true) }
        XCTAssertEqual(image.size.width,width,accuracy:1)
        let attachment=XCTAttachment(image:image);attachment.name=name;attachment.lifetime = .keepAlways;add(attachment)
        if motion && !UIAccessibility.isReduceMotionEnabled {
            try await Task.sleep(for:.milliseconds(550))
            let next=renderer.image { _ in controller.view.drawHierarchy(in:controller.view.bounds,afterScreenUpdates:true) }
            XCTAssertNotEqual(image.pngData(),next.pngData(),"Topic art should animate between frames")
        }
        window.isHidden=true
    }
}
