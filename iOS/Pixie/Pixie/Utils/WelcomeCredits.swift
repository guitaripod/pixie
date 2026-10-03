import Foundation

struct WelcomeCredits {
    static let grant = 65

    private static let purchasedKey = "creditsEverExceededWelcomeGrant_v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// True while the wallet can only hold the welcome grant: nothing was ever bought or
    /// added and the balance is not above what a new account starts with.
    func isOnWelcomeGrant(balance: Int) -> Bool {
        recordObserved(balance: balance)
        return !defaults.bool(forKey: Self.purchasedKey) && balance <= Self.grant
    }

    func markCreditsAdded() {
        defaults.set(true, forKey: Self.purchasedKey)
    }

    /// Whole images the balance covers at `imageCost` credits each.
    static func freeImages(balance: Int, imageCost: Int) -> Int {
        guard imageCost > 0 else { return 0 }
        return max(0, balance) / imageCost
    }

    private func recordObserved(balance: Int) {
        if balance > Self.grant { markCreditsAdded() }
    }
}
