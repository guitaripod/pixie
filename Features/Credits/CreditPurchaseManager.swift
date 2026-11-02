import Combine
import Foundation
import MidgarCommerce
import MidgarCore
import MidgarCredits
import PixiepocketCore
import UIKit

nonisolated struct CreditPackWithPrice: Sendable {
    let creditPack: CreditPack
    let localizedPrice: String
    /// StoreKit's product, for the numeric price and the storefront's currency.
    let product: StoreProduct
}

/// How a purchase ended, in the cases the store screen shows differently. A purchase that failed is thrown instead.
enum CreditPurchaseOutcome: Equatable {
    /// mako credited the pack: `credits` arrived and the wallet now holds `newBalance`.
    case credited(credits: Int, newBalance: Int)
    /// The customer paid and mako has not credited yet. The receipt stays queued and the balance follows the credit.
    case creditPending(credits: Int)
    /// The purchase waits for someone else's approval (Ask to Buy).
    case awaitingApproval
    /// The customer dismissed the purchase sheet.
    case cancelled
}

/// Sells the edit packs through the Midgar wallet (mako's pack list for names and credits, StoreKit's products through
/// MidgarCredits for the price in the customer's storefront, `MidgarCredits.buy` for the purchase) and PixiePocket
/// Plus through the store, whose ledger entitlement mako turns into the weekly edits.
@MainActor
final class CreditPurchaseManager {
    static let shared = CreditPurchaseManager()

    private let credits: MidgarCredits?
    private let store: MidgarStore?
    private let apiService: APIServiceProtocol
    private let balanceStore: CreditBalanceStore
    private let notePurchaseFailure: @MainActor () -> Void

    @Published private(set) var offers: [MidgarCreditsOffer] = []
    @Published private(set) var creditPacks: [CreditPack] = []
    /// PixiePocket Plus as StoreKit sells it to this customer, or nil before it loads or where it is not for sale.
    @Published private(set) var plusProduct: StoreProduct?

    /// - Parameters:
    ///   - credits: The wallet, or nil where the app reaches no Midgar service (a test host): nothing is for sale then.
    ///   - notePurchaseFailure: Tells the review policy, which holds its prompt back for a week after a failed purchase.
    init(
        credits: MidgarCredits? = PixieMidgar.shared.credits,
        store: MidgarStore? = PixieMidgar.shared.store,
        apiService: APIServiceProtocol = APIService.shared,
        balanceStore: CreditBalanceStore = .shared,
        notePurchaseFailure: @escaping @MainActor () -> Void = { ReviewPrompt.notePurchaseFailure() }
    ) {
        self.credits = credits
        self.store = store
        self.apiService = apiService
        self.balanceStore = balanceStore
        self.notePurchaseFailure = notePurchaseFailure
        prefetch()
    }

    /// Loads the pack list and the prices ahead of the store screen. A host that reaches no Midgar service (a test host
    /// or a demo capture) makes no network call; its tests ask for each load themselves.
    private func prefetch() {
        guard PixieMidgar.reachesMidgarServices else { return }
        Task {
            await fetchCreditPacks()
            await fetchOffers()
            await fetchPlus()
        }
    }

    func fetchCreditPacks() async {
        do {
            let response = try await apiService.getCreditPacks()
            creditPacks = response.packs
        } catch {
            MidgarLog.notice("Credit pack list unavailable: \(error.localizedDescription)", category: .credits)
        }
    }

    /// Reads the packs StoreKit sells to this customer, with their localized prices. A pack StoreKit does not return is
    /// left out, so the store screen hides it.
    func fetchOffers() async {
        guard let credits else { return }
        do {
            offers = try await credits.offers()
        } catch {
            MidgarLog.notice("Credit pack prices unavailable: \(error.localizedDescription)", category: .credits)
        }
    }

    /// Reads Plus from StoreKit. A storefront where it is not for sale leaves it nil, and the store shows packs only.
    func fetchPlus() async {
        guard let store else { return }
        do {
            plusProduct = try await store.products().first { $0.id == PixiePacks.plusProductID }
        } catch {
            MidgarLog.notice("Plus unavailable: \(error.localizedDescription)", category: .credits)
        }
    }

    /// Whether this Midgar ID holds Plus, from the ledger's entitlements.
    func hasPlus() async -> Bool {
        await store?.isEntitled(to: PixiePacks.plusEntitlement) ?? false
    }

    /// Subscribes to Plus with the purchase sheet over `scene`; a cancelled sheet is an outcome, any failure is noted
    /// for the review policy and thrown. The balance is read again, so the weekly edits show once mako sees them.
    func purchasePlus(confirmIn scene: UIScene) async throws -> MidgarPurchaseResult {
        do {
            guard let store else { throw MidgarCreditsError.notConfigured(.purchasesDisabled) }
            let result: MidgarPurchaseResult
            if #available(iOS 17.0, *) {
                result = try await store.purchase(PixiePacks.plusProductID, confirmIn: scene)
            } else {
                result = try await store.purchase(PixiePacks.plusProductID)
            }
            if result == .purchased {
                await balanceStore.refresh()
            }
            return result
        } catch is CancellationError {
            return .cancelled
        } catch {
            notePurchaseFailure()
            MidgarLog.error("Plus purchase failed: \(error.localizedDescription)", category: .credits)
            throw error
        }
    }

    /// Buys one pack and credits it. A cancelled purchase is an outcome, not an error; any failure is noted for the
    /// review policy and thrown for the screen to show.
    func purchaseCreditPack(id packID: String) async throws -> CreditPurchaseOutcome {
        do {
            guard let credits else {
                throw MidgarCreditsError.notConfigured(.purchasesDisabled)
            }
            return outcome(of: try await credits.buy(packID))
        } catch is CancellationError {
            return .cancelled
        } catch {
            notePurchaseFailure()
            MidgarLog.error("Purchase failed: \(error.localizedDescription)", category: .credits)
            throw error
        }
    }

    private func outcome(of result: MidgarCreditsPurchaseResult) -> CreditPurchaseOutcome {
        switch result {
        case .credited(_, let creditsAdded, let balance):
            balanceStore.apply(newBalance: balance)
            Task { await balanceStore.refresh() }
            return .credited(credits: creditsAdded, newBalance: balance)
        case .creditPending(_, let expectedCredits):
            return .creditPending(credits: expectedCredits)
        case .awaitingApproval:
            return .awaitingApproval
        case .cancelled:
            return .cancelled
        }
    }

    /// The packs the store offers that StoreKit sells, cheapest first, each with the price StoreKit shows this customer.
    func getCreditPacksWithPricing() -> AnyPublisher<[CreditPackWithPrice], Never> {
        Publishers.CombineLatest($creditPacks, $offers)
            .map(Self.priced)
            .eraseToAnyPublisher()
    }

    /// The join, nonisolated because Combine runs it on whichever thread the publisher emits on.
    private nonisolated static func priced(_ backendPacks: [CreditPack], _ offers: [MidgarCreditsOffer]) -> [CreditPackWithPrice] {
        let productByPackID = Dictionary(offers.map { ($0.pack.id, $0.product) }, uniquingKeysWith: { first, _ in first })
        let offered = Set(PixiePacks.offered.map(\.id))
        return backendPacks
            .filter { offered.contains($0.id) }
            .compactMap { pack in
                productByPackID[pack.id].map { CreditPackWithPrice(creditPack: pack, localizedPrice: $0.displayPrice, product: $0) }
            }
            .sorted { $0.creditPack.priceUsdCents < $1.creditPack.priceUsdCents }
    }
}
