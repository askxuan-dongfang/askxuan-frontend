import Testing
import Foundation
@testable import AskXuanAdmin

struct AdminPortalTests {
    let origin = URL(string: "https://101.96.228.71")!
    @Test func rolesAndStorageAreSeparated() {
        #expect(AdminPortal.platform.storeID != AdminPortal.temple.storeID)
        #expect(AdminPortal.matching(URL(string: "https://101.96.228.71/temple/orders?status=pending")!, origin: origin) == .temple)
        #expect(!AdminPortal.platform.owns(URL(string: "https://101.96.228.71/temple/")!, origin: origin))
    }
    @Test(arguments: ["https://101.96.228.71.evil.test/admin/", "http://101.96.228.71/admin/", "https://101.96.228.71:444/admin/", "https://user:secret@101.96.228.71/admin/", "https://101.96.228.71/administrator"])
    func rejectsOriginAndPrefixConfusion(_ value: String) {
        #expect(!AdminPortal.platform.owns(URL(string: value)!, origin: origin))
    }
    @Test func recognizesLegacyCommerceAndDeepLinks() {
        #expect(AdminPortal.platform.owns(URL(string: "https://101.96.228.71/shop/orders/17?tab=refund#detail")!, origin: origin))
        #expect(AdminPortal.platform.owns(URL(string: "https://101.96.228.71/admin")!, origin: origin))
    }
}
