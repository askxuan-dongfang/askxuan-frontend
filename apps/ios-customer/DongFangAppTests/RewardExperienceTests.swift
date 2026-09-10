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
