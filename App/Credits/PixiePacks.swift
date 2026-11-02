import Foundation
import MidgarCommerce
import MidgarCredits

/// One credit pack Pixie sells: mako's catalog entry (`credit_packs.pack_id`, base credits plus bonus) and the App Store product that carries it.
nonisolated struct PixiePack: Sendable, Equatable {
    let id: String
    let name: String
    let baseCredits: Int
    let bonusCredits: Int
    let listPrice: String

    var productID: String {
        PixiePacks.productPrefix + id
    }

    var totalCredits: Int {
        baseCredits + bonusCredits
    }

    /// The pack as MidgarCredits sells it: what mako grants is base plus bonus.
    var creditsPack: MidgarCreditsPack {
        MidgarCreditsPack(id: id, productID: productID, credits: totalCredits)
    }
}

/// The credit packs Pixie sells, in one place: the store configuration, the credits configuration, the demo capture and the tests all read this table. The ids and amounts are mako's catalog for the `pixie` tenant (since mako 035 each grants whole edits of 21 credits), and mako requires each product id to be its `rc_product_prefix` plus the pack id. Prices are StoreKit's, from the App Store records and `Products.storekit`; `listPrice` is the US price, shown only where StoreKit is not asked.
nonisolated enum PixiePacks {
    static let productPrefix = "com.guitaripod.pixie.credits."

    static let starter = PixiePack(id: "starter", name: "Starter", baseCredits: 210, bonusCredits: 0, listPrice: "$2.99")
    static let basic = PixiePack(id: "basic", name: "Basic", baseCredits: 840, bonusCredits: 0, listPrice: "$9.99")
    static let popular = PixiePack(id: "popular", name: "Popular", baseCredits: 2520, bonusCredits: 0, listPrice: "$24.99")
    static let business = PixiePack(id: "business", name: "Business", baseCredits: 2174, bonusCredits: 1076, listPrice: "$49.99")
    static let enterprise = PixiePack(id: "enterprise", name: "Enterprise", baseCredits: 4167, bonusCredits: 2833, listPrice: "$99.99")

    /// Every pack a transaction can carry. Business and enterprise are no longer offered, and stay here so a purchase
    /// of one still in flight is credited and finished.
    static let all = [starter, basic, popular, business, enterprise]

    /// The packs the store shows.
    static let offered = [starter, basic, popular]

    static let productIDs = all.map(\.productID)

    /// PixiePocket Plus: a weekly subscription whose edits mako grants from the ledger's `plus` entitlement.
    static let plusProductID = "com.guitaripod.pixie.plus.weekly"
    static let plusEntitlement = "plus"
    static let plusWeeklyEdits = 60
    static let plusListPrice = "$6.99"

    /// The store sells the packs and Plus; Plus is the only product that grants an entitlement.
    static func storeConfiguration(directory: URL? = nil) -> MidgarStoreConfiguration {
        MidgarStoreConfiguration(
            appID: PixieMidgar.appID,
            productIDs: productIDs + [plusProductID],
            entitlementsByProduct: [plusProductID: plusEntitlement],
            mode: .purchases,
            directory: directory
        )
    }

    static func creditsConfiguration(directory: URL? = nil) -> MidgarCreditsConfiguration {
        MidgarCreditsConfiguration(packs: all.map(\.creditsPack), directory: directory)
    }
}
