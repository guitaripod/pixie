import XCTest
@testable import Pixie

final class WelcomeCreditsTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "WelcomeCreditsTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testFreshWalletWithGrantIsOnWelcomeGrant() {
        let credits = WelcomeCredits(defaults: defaults)
        XCTAssertTrue(credits.isOnWelcomeGrant(balance: WelcomeCredits.grant))
        XCTAssertTrue(credits.isOnWelcomeGrant(balance: 0))
    }

    func testBalanceAboveGrantLeavesWelcomeStateForGood() {
        let credits = WelcomeCredits(defaults: defaults)
        XCTAssertFalse(credits.isOnWelcomeGrant(balance: WelcomeCredits.grant + 1))
        XCTAssertFalse(credits.isOnWelcomeGrant(balance: 10))
    }

    func testRecordedPurchaseLeavesWelcomeState() {
        let credits = WelcomeCredits(defaults: defaults)
        credits.markCreditsAdded()
        XCTAssertFalse(credits.isOnWelcomeGrant(balance: 30))
    }

    func testFreeImagesUsesTheGivenModelCost() {
        XCTAssertEqual(WelcomeCredits.freeImages(balance: 65, imageCost: ImageModel.gemini.fixedCost ?? 0), 3)
        XCTAssertEqual(WelcomeCredits.freeImages(balance: 65, imageCost: ImageModel.geminiPro.fixedCost ?? 0), 1)
        XCTAssertEqual(WelcomeCredits.freeImages(balance: 20, imageCost: 21), 0)
        XCTAssertEqual(WelcomeCredits.freeImages(balance: -5, imageCost: 21), 0)
        XCTAssertEqual(WelcomeCredits.freeImages(balance: 65, imageCost: 0), 0)
    }
}
