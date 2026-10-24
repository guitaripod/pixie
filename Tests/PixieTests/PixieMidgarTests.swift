import MidgarCommerce
import Testing

@testable import Pixie

struct PixieMidgarTests {
    @Test func theStoreBuysThePacksThroughStoreKitAndGrantsNothingFromThem() {
        let configuration = PixiePacks.storeConfiguration()
        #expect(configuration.mode == .purchases)
        #expect(configuration.appID == "pixiepocket")
        #expect(configuration.productIDs == PixiePacks.productIDs)
        #expect(configuration.entitlementsByProduct.isEmpty)
        #expect(configuration.crossAppEntitlements.isEmpty)
    }

    @Test func thePackTableMatchesMakosCatalog() {
        #expect(PixiePacks.all.map(\.id) == ["starter", "basic", "popular", "business", "enterprise"])
        #expect(PixiePacks.all.map(\.baseCredits) == [150, 475, 1136, 2174, 4167])
        #expect(PixiePacks.all.map(\.bonusCredits) == [0, 75, 364, 1076, 2833])
        #expect(PixiePacks.all.map(\.totalCredits) == [150, 550, 1500, 3250, 7000])
        #expect(PixiePacks.all.allSatisfy { $0.productID == "com.guitaripod.pixie.credits." + $0.id })
        #expect(PixiePacks.all.map(\.listPrice) == ["$2.99", "$9.99", "$24.99", "$49.99", "$99.99"])
    }

    @Test func theWalletSellsEveryPackForWhatMakoGrantsBonusIncluded() {
        let configuration = PixiePacks.creditsConfiguration()
        #expect(configuration.packs.map(\.id) == PixiePacks.all.map(\.id))
        #expect(configuration.packs.map(\.credits) == [150, 550, 1500, 3250, 7000])
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
