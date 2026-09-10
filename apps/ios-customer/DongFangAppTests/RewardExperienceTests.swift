import XCTest
@testable import DongFangApp

@MainActor final class RewardExperienceTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!
    override func setUp() {
        super.setUp(); suite = "RewardExperienceTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
    }
    override func tearDown() { defaults.removePersistentDomain(forName: suite); defaults = nil; super.tearDown() }
    private func store(_ account: String = "alice", time: Int64 = 1000) -> RewardDemoStore {
        RewardDemoStore(accountID: account, defaults: defaults, clock: { time })
    }
    func testEmptyCatalogHasTwoIsolatedExamples() throws {
        let s = store(); XCTAssertEqual(s.campaigns().count, 2); XCTAssertEqual(s.state.balance, 100)
        XCTAssertEqual(s.campaigns(kind: "wheel").first?.pointsCost, 10)
        XCTAssertEqual(s.campaigns(kind: "pool").first?.pointsCost, 20)
        XCTAssertTrue(s.campaigns().allSatisfy { $0.isDemo && $0.participantCount == 0 && $0.endsAt == 1000 + 72 * 3600 })
        XCTAssertThrowsError(try s.detail(1))
    }
    func testJoinPersistsWithoutRepeatChargeOrAccountLeak() throws {
        let first = try store().join(RewardDemoStore.wheelID, expectedPoints: 10, randomWin: { false })
        let duplicate = try store().join(RewardDemoStore.wheelID, expectedPoints: 10, randomWin: { true })
        XCTAssertEqual(first.code, duplicate.code); XCTAssertEqual(duplicate.outcome, "lost")
        XCTAssertEqual(store().state.balance, 90); XCTAssertEqual(store().state.entries.count, 1)
        XCTAssertEqual(store("bob").state.balance, 100); XCTAssertTrue(store("bob").state.entries.isEmpty)
    }
    func testPriceMismatchAndExpiredExamplesDoNotCharge() throws {
        let s = store(); _ = s.state
        XCTAssertThrowsError(try s.join(RewardDemoStore.poolID, expectedPoints: 1))
        XCTAssertThrowsError(try s.join(88, expectedPoints: 20))
        XCTAssertThrowsError(try store(time: 1000 + 72 * 3600).join(RewardDemoStore.poolID, expectedPoints: 20))
        XCTAssertEqual(s.state.balance, 100); XCTAssertTrue(s.state.entries.isEmpty)
    }
    func testPoolDrawAndFulfillmentAreIdempotentAndLocal() throws {
        let s = store(); XCTAssertThrowsError(try s.draw())
        let e = try s.join(RewardDemoStore.poolID, expectedPoints: 20)
        XCTAssertEqual(e.outcome, "pending"); XCTAssertEqual(s.state.balance, 80)
        XCTAssertEqual(try s.draw().outcome, "won"); _ = try s.draw()
        XCTAssertEqual(s.state.orders.count, 1); XCTAssertEqual(try s.detail(RewardDemoStore.poolID).campaign.oddsText, "100.00%")
        try s.advanceOrder(e.id); XCTAssertEqual(s.state.orders[0].status, "pending"); XCTAssertEqual(s.state.orders[0].address, "演示地址 · 无需填写真实信息")
        try s.advanceOrder(e.id); XCTAssertEqual(s.state.orders[0].status, "shipped")
        try s.advanceOrder(e.id); try s.advanceOrder(e.id); XCTAssertEqual(s.state.orders[0].status, "completed")
        XCTAssertEqual(s.state.balance, 80)
    }
    func testWinLossAndResetPreserveFormalIDBoundary() throws {
        let s = store(); let e = try s.join(RewardDemoStore.wheelID, expectedPoints: 10, randomWin: { true })
        XCTAssertEqual(e.outcome, "won"); XCTAssertEqual(s.state.orders.count, 1)
        XCTAssertEqual(try s.detail(RewardDemoStore.wheelID).campaign.oddsText, "50.00%")
        let oldRound = e.code; s.reset(); XCTAssertTrue(s.state.orders.isEmpty); XCTAssertEqual(s.state.balance, 100)
        let next = try s.join(RewardDemoStore.wheelID, expectedPoints: 10, randomWin: { false })
        XCTAssertNotEqual(next.code, oldRound); XCTAssertTrue(s.state.orders.isEmpty)
        XCTAssertFalse(RewardDemoStore.isDemo(1)); XCTAssertFalse(RewardDemoStore.isDemo(-9))
    }
    func testExpiredPendingPoolCanStillReveal() throws {
        _ = try store().join(RewardDemoStore.poolID, expectedPoints: 20)
        let later = store(time: 1000 + 72 * 3600)
        XCTAssertEqual(try later.detail(RewardDemoStore.poolID).campaign.phase, "awaiting_draw")
        XCTAssertEqual(try later.draw().outcome, "won")
        XCTAssertEqual(try later.detail(RewardDemoStore.poolID).campaign.drawnAt, 1000 + 72 * 3600)
        XCTAssertEqual(later.state.balance, 80)
    }
}

// Render actual SwiftUI components in the test host, without operating another
// project's Simulator window or making any production activity API request.
import SwiftUI
@MainActor final class RewardNativeRenderTests: XCTestCase {
    func testNativeActivityLayouts() async throws {
        for width in [320.0, 390.0, 768.0] {
            let view = NavigationStack {
                ScrollView {
                    VStack(spacing: 18) {
                        Text("积分，让期待发生").font(.title2).foregroundStyle(Color.accentDefault)
                        HStack(spacing: 12) { RewardCategoryEntry(kind: "wheel"); RewardCategoryEntry(kind: "pool") }
                        RewardDemoBanner(balance: 100, busy: false, reset: {})
                        RewardWheelArt(rotation: 0, spinning: false, cost: 10).frame(height: 280)
                        RewardCountdown(endsAt: Int64(Date().timeIntervalSince1970) + 72 * 3600)
                        RewardDeliverySteps(status: "completed")
                    }.padding(16)
                }.background(Color.bgPrimary).navigationTitle("原生活动体验")
            }
            try await render(view, name: "ios-reward-components-\(Int(width))", width: width)
        }
        try await render(RewardWheelMotionFixture(), name: "ios-reward-wheel-motion", width: 390, height: 420, expectsMotion: true)
        let entry = RewardEntry(id: -91002, campaignId: -91002, createdAt: 1000, pointsSpent: 20, code: "DEMO-P-RENDER", outcome: "won", title: "天然香珠 · 一期一礼")
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
