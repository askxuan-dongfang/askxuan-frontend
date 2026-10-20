import Testing
import Foundation
@testable import DongFangApp

struct H5ParityTests {
    @Test(arguments: [("0.01", Int64(1)), ("12.34", Int64(1234)), ("100", Int64(10000))])
    func withdrawalUsesExactCents(_ pair: (String, Int64)) { #expect(CreatorWithdrawalInput.cents(pair.0) == pair.1) }
    @Test(arguments: ["-1", "0", "NaN", "1e2", "1.001", " 1", "92233720368547759", "9,99"])
    func rejectsInvalidWithdrawalAmounts(_ amount: String) { #expect(CreatorWithdrawalInput.cents(amount) == nil) }
    @Test @MainActor func regionAndTraditionIntersectWithBeliefAndService() throws {
        let payload = #"{"id":"1","name":"目录示例","regionCode":"southeast_asia","traditionCodes":["theravada"],"beliefCode":"han_buddhism","serviceCodes":["S001"]}"#
        let temple = try JSONDecoder().decode(Temple.self, from: Data(payload.utf8))
        let model = TempleListViewModel()
        model.temples = [temple]; model.selectedRegionCode = "southeast_asia"
        model.selectedTraditionCode = "theravada"; model.selectedServiceCode = "S001"
        #expect(model.filteredTemples.count == 1)
        model.selectedBeliefCode = "daoism"
        #expect(model.filteredTemples.isEmpty)
        model.selectedBeliefCode = ""; model.selectedRegionCode = "mainland"
        #expect(model.filteredTemples.isEmpty)
    }
    @Test @MainActor func priceFilterUsesEnabledStartingPriceAndH5Boundaries() throws {
        let payload = #"{"id":"1","serviceTags":[{"serviceCode":"S001","price":200,"status":"enabled"},{"serviceCode":"S002","price":10,"status":"disabled"}]}"#
        let master = try JSONDecoder().decode(Master.self, from: Data(payload.utf8))
        let model = MasterListViewModel(); model.masters = [master]
        model.selectedPrice = "200元以下"; #expect(model.filteredMasters.isEmpty)
        model.selectedPrice = "200–500元"; #expect(model.filteredMasters.count == 1)
        model.clearFilters()
        #expect(model.filteredMasters.count == 1)
        #expect(model.startingPrice(master) == 200)
    }
}
