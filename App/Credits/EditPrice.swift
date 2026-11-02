import Foundation
import PixiepocketCore

/// Money in PixiePocket is edits. mako's balance says what one edit costs in credits and what pays for the next one
/// (mako migration 035); until its first answer the app counts the 21 credits an edit has cost since 1.6.
nonisolated enum EditPrice {
    static let fallbackCreditsPerEdit = 21

    static func creditsPerEdit(_ balance: CreditBalance?) -> Int {
        max(1, balance?.edits?.creditsPerEdit ?? fallbackCreditsPerEdit)
    }

    /// Whole edits the balance pays for, counted from the live credits so a balance a purchase just moved is right
    /// before the summary is read again.
    static func edits(of balance: CreditBalance) -> Int {
        max(0, balance.balance) / creditsPerEdit(balance)
    }

    /// Whole edits a pack of `credits` grants.
    static func edits(inCredits credits: Int, balance: CreditBalance?) -> Int {
        max(0, credits) / creditsPerEdit(balance)
    }

    /// What one image on `tier` costs in edits.
    static func edits(for tier: ImageModel, balance: CreditBalance?) -> Int {
        balance?.edits?.edits(forTier: tier.value) ?? tier.defaultEdits
    }

    /// How a request of `images` images on `tier` would be paid, or nil while the balance is unknown and the
    /// server decides.
    static func funding(tier: ImageModel, images: Int = 1, balance: CreditBalance?) -> EditFunding? {
        guard let balance else { return nil }
        let funding = balance.edits?.funding(forTier: tier.value, images: images)
            ?? .balance(edits: tier.defaultEdits * max(images, 1), affordable: false)
        guard case .balance(let edits, _) = funding else { return funding }
        return .balance(edits: edits, affordable: Self.edits(of: balance) >= edits)
    }

    /// A credit amount from the history or a gallery record as whole edits, rounded and never zero for a nonzero
    /// amount: records from before edits priced Nano Banana Pro at 41 credits, which reads as two edits.
    static func roundedEdits(ofCredits credits: Int) -> Int {
        guard credits != 0 else { return 0 }
        return max(1, Int((Double(abs(credits)) / Double(fallbackCreditsPerEdit)).rounded()))
    }

    /// "1 edit", "5 edits", in the person's language.
    static func label(edits: Int) -> String {
        String(localized: "\(edits) edits")
    }
}
