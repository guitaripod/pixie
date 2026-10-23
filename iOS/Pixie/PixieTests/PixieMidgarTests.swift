import MidgarCommerce
import Testing

@testable import Pixie

struct PixieMidgarTests {
    @Test func theLedgerStoreOnlyReadsBecauseRevenueCatKeepsPurchasing() {
        #expect(PixieMidgar.storeConfiguration.mode == .readOnly)
        #expect(PixieMidgar.storeConfiguration.appID == "pixiepocket")
    }

    @Test func theStoreKnowsTheFiveCreditPacksAndGrantsNothingFromThem() {
        let configuration = PixieMidgar.storeConfiguration
        #expect(configuration.productIDs.count == 5)
        #expect(configuration.productIDs.allSatisfy { $0.hasPrefix("com.guitaripod.pixie.credits.") })
        #expect(configuration.entitlementsByProduct.isEmpty)
        #expect(configuration.crossAppEntitlements.isEmpty)
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
        #expect(PixieMidgar.shared.ledger == nil)
        #expect(await PixieMidgar.shared.midgarTokenHeaders().isEmpty)
    }
}
