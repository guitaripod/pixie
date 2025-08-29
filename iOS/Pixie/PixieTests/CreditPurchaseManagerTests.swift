import XCTest
import Combine
@testable import Pixie
import RevenueCat

class CreditPurchaseManagerTests: XCTestCase {
    
    private var cancellables = Set<AnyCancellable>()
    
    override func setUp() async throws {
        try await super.setUp()
        cancellables.removeAll()
    }
    
    override func tearDown() async throws {
        try await super.tearDown()
        cancellables.removeAll()
    }
    
    func testSharedInstance() {
        let manager1 = CreditPurchaseManager.shared
        let manager2 = CreditPurchaseManager.shared
        XCTAssertTrue(manager1 === manager2, "CreditPurchaseManager should be a singleton")
    }
    
    func testGetCreditsForPackage() {
        let manager = CreditPurchaseManager.shared
        
        let starterCredits = manager.getCreditsForPackage("starter")
        XCTAssertEqual(starterCredits.total, 299)
        XCTAssertEqual(starterCredits.base, 299)
        XCTAssertEqual(starterCredits.bonus, 0)
        
        let basicCredits = manager.getCreditsForPackage("basic")
        XCTAssertEqual(basicCredits.total, 1250)
        XCTAssertEqual(basicCredits.base, 1000)
        XCTAssertEqual(basicCredits.bonus, 250)
        
        let popularCredits = manager.getCreditsForPackage("popular")
        XCTAssertEqual(popularCredits.total, 3250)
        XCTAssertEqual(popularCredits.base, 2500)
        XCTAssertEqual(popularCredits.bonus, 750)
        
        let businessCredits = manager.getCreditsForPackage("business")
        XCTAssertEqual(businessCredits.total, 6800)
        XCTAssertEqual(businessCredits.base, 5000)
        XCTAssertEqual(businessCredits.bonus, 1800)
        
        let enterpriseCredits = manager.getCreditsForPackage("enterprise")
        XCTAssertEqual(enterpriseCredits.total, 15000)
        XCTAssertEqual(enterpriseCredits.base, 10000)
        XCTAssertEqual(enterpriseCredits.bonus, 5000)
        
        let unknownCredits = manager.getCreditsForPackage("unknown")
        XCTAssertEqual(unknownCredits.total, 0)
        XCTAssertEqual(unknownCredits.base, 0)
        XCTAssertEqual(unknownCredits.bonus, 0)
    }
    
    func testCreditPacksWithPricingPublisher() {
        let manager = CreditPurchaseManager.shared
        let expectation = expectation(description: "Publisher should emit value")
        
        manager.getCreditPacksWithPricing()
            .sink { packs in
                XCTAssertNotNil(packs)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        waitForExpectations(timeout: 2.0)
    }
    
    func testResetPurchaseState() {
        let manager = CreditPurchaseManager.shared
        manager.resetPurchaseState()
        
        switch manager.purchaseState {
        case .idle:
            XCTAssertTrue(true, "State should be idle after reset")
        default:
            XCTFail("State should be idle after reset")
        }
    }
}