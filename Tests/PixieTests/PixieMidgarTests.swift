import MidgarCommerce
import Testing

@testable import Pixie

struct PixieMidgarTests {
    @Test func theStoreBuysThePacksAndPlusAndOnlyPlusGrantsAnEntitlement() {
        let configuration = PixiePacks.storeConfiguration()
        #expect(configuration.mode == .purchases)
        #expect(configuration.appID == "pixiepocket")
        #expect(configuration.productIDs == PixiePacks.productIDs + ["com.guitaripod.pixie.plus.weekly"])
        #expect(configuration.entitlementsByProduct == ["com.guitaripod.pixie.plus.weekly": "plus"])
        #expect(configuration.crossAppEntitlements.isEmpty)
    }

    @Test func thePackTableMatchesMakosCatalog() {
        #expect(PixiePacks.all.map(\.id) == ["starter", "basic", "popular", "business", "enterprise"])
        #expect(PixiePacks.all.map(\.totalCredits) == [210, 840, 2520, 3250, 7000])
        #expect(PixiePacks.all.allSatisfy { $0.productID == "com.guitaripod.pixie.credits." + $0.id })
        #expect(PixiePacks.all.map(\.listPrice) == ["$2.99", "$9.99", "$24.99", "$49.99", "$99.99"])
    }

    @Test func theStoreOffersThreePacksOfWholeEdits() {
        #expect(PixiePacks.offered.map(\.id) == ["starter", "basic", "popular"])
        #expect(PixiePacks.offered.map { $0.totalCredits / EditPrice.fallbackCreditsPerEdit } == [10, 40, 120])
        #expect(PixiePacks.offered.allSatisfy { $0.totalCredits % EditPrice.fallbackCreditsPerEdit == 0 })
    }

    @Test func theWalletSellsEveryPackForWhatMakoGrantsBonusIncluded() {
        let configuration = PixiePacks.creditsConfiguration()
        #expect(configuration.packs.map(\.id) == PixiePacks.all.map(\.id))
        #expect(configuration.packs.map(\.credits) == [210, 840, 2520, 3250, 7000])
        #expect(configuration.productIDs == PixiePacks.productIDs)
    }

    @Test func everyMakoCallGoesThroughTheGatewayTenant() {
        #expect(PixieMidgar.intelligenceURL.absoluteString == "https://api.midgarcorp.cc/v1/intelligence")
        #expect(PixieMidgar.appID == "pixiepocket")
    }

    @Test func theCreditsClientKeepsTheTenantItsKeychainItemIsNamedAfter() {
        #expect(PixieMidgar.creditsAppID == "pixie")
    }

    @Test func aTestHostReachesNoMidgarService() async {
        #expect(!PixieMidgar.reachesMidgarServices)
        #expect(PixieMidgar.shared.store == nil)
        #expect(PixieMidgar.shared.credits == nil)
        #expect(await PixieMidgar.shared.midgarTokenHeaders().isEmpty)
    }
}
