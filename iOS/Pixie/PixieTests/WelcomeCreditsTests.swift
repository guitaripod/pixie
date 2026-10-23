import Foundation
import Testing

@testable import Pixie

@MainActor
struct WelcomeCreditsTests {
    private func makeCredits() -> WelcomeCredits {
        WelcomeCredits(defaults: UserDefaults(suiteName: "WelcomeCreditsTests-\(UUID().uuidString)")!)
    }

    @Test func aFreshWalletWithTheGrantIsOnTheWelcomeGrant() {
        let credits = makeCredits()
        #expect(credits.isOnWelcomeGrant(balance: WelcomeCredits.grant))
        #expect(credits.isOnWelcomeGrant(balance: 0))
    }

    @Test func aBalanceAboveTheGrantLeavesTheWelcomeStateForGood() {
        let credits = makeCredits()
        #expect(!credits.isOnWelcomeGrant(balance: WelcomeCredits.grant + 1))
        #expect(!credits.isOnWelcomeGrant(balance: 10))
    }

    @Test func aRecordedPurchaseLeavesTheWelcomeState() {
        let credits = makeCredits()
        credits.markCreditsAdded()
        #expect(!credits.isOnWelcomeGrant(balance: 30))
    }

    @Test func freeImagesUseTheGivenModelCost() {
        #expect(WelcomeCredits.freeImages(balance: 65, imageCost: ImageModel.gemini.fixedCost ?? 0) == 3)
        #expect(WelcomeCredits.freeImages(balance: 65, imageCost: ImageModel.geminiPro.fixedCost ?? 0) == 1)
        #expect(WelcomeCredits.freeImages(balance: 20, imageCost: 21) == 0)
        #expect(WelcomeCredits.freeImages(balance: -5, imageCost: 21) == 0)
        #expect(WelcomeCredits.freeImages(balance: 65, imageCost: 0) == 0)
    }
}
