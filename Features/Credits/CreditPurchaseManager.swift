import Combine
import Foundation
import MidgarCore
import MidgarCredits
import PixiepocketCore

nonisolated struct CreditPackWithPrice: Sendable {
    let creditPack: CreditPack
    let localizedPrice: String
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

/// Sells the credit packs through the Midgar wallet: mako's pack list for names, credits and bonus, StoreKit's products
/// (through MidgarCredits) for the price in the customer's storefront, and `MidgarCredits.buy` for the purchase.
@MainActor
final class CreditPurchaseManager {
    static let shared = CreditPurchaseManager()

    private let credits: MidgarCredits?
    private let apiService: APIServiceProtocol
    private let balanceStore: CreditBalanceStore
    private let welcomeCredits: WelcomeCredits
    private let notePurchaseFailure: @MainActor () -> Void

    @Published private(set) var offers: [MidgarCreditsOffer] = []
    @Published private(set) var creditPacks: [CreditPack] = []

    /// - Parameters:
    ///   - credits: The wallet, or nil where the app reaches no Midgar service (a test host): nothing is for sale then.
    ///   - notePurchaseFailure: Tells the review policy, which holds its prompt back for a week after a failed purchase.
    init(
        credits: MidgarCredits? = PixieMidgar.shared.credits,
        apiService: APIServiceProtocol = APIService.shared,
        balanceStore: CreditBalanceStore = .shared,
        welcomeCredits: WelcomeCredits = WelcomeCredits(),
        notePurchaseFailure: @escaping @MainActor () -> Void = { ReviewPrompt.notePurchaseFailure() }
    ) {
        self.credits = credits
        self.apiService = apiService
        self.balanceStore = balanceStore
        self.welcomeCredits = welcomeCredits
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
            welcomeCredits.markCreditsAdded()
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

    /// mako's packs that StoreKit sells, cheapest first, each with the price StoreKit shows this customer.
    func getCreditPacksWithPricing() -> AnyPublisher<[CreditPackWithPrice], Never> {
        Publishers.CombineLatest($creditPacks, $offers)
            .map(Self.priced)
            .eraseToAnyPublisher()
    }

    /// The join, nonisolated because Combine runs it on whichever thread the publisher emits on.
    private nonisolated static func priced(_ backendPacks: [CreditPack], _ offers: [MidgarCreditsOffer]) -> [CreditPackWithPrice] {
        let priceByPackID = Dictionary(offers.map { ($0.pack.id, $0.product.displayPrice) }, uniquingKeysWith: { first, _ in first })
        return backendPacks
            .compactMap { pack in
                priceByPackID[pack.id].map { CreditPackWithPrice(creditPack: pack, localizedPrice: $0) }
            }
            .sorted { $0.creditPack.priceUsdCents < $1.creditPack.priceUsdCents }
    }
}
