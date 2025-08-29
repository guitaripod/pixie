import XCTest
@testable import Pixie
import RevenueCat

class RevenueCatManagerTests: XCTestCase {
    
    override func setUp() async throws {
        try await super.setUp()
    }
    
    override func tearDown() async throws {
        try await super.tearDown()
    }
    
    func testSharedInstance() {
        let manager1 = RevenueCatManager.shared
        let manager2 = RevenueCatManager.shared
        XCTAssertTrue(manager1 === manager2, "RevenueCatManager should be a singleton")
    }
    
    func testInitialPurchaseState() {
        let manager = RevenueCatManager.shared
        
        switch manager.purchaseState {
        case .idle:
            XCTAssertTrue(true, "Initial state should be idle")
        default:
            XCTFail("Initial state should be idle")
        }
    }
    
    func testResetPurchaseState() {
        let manager = RevenueCatManager.shared
        manager.resetPurchaseState()
        
        switch manager.purchaseState {
        case .idle:
            XCTAssertTrue(true, "State should be idle after reset")
        default:
            XCTFail("State should be idle after reset")
        }
    }
    
    func testPurchaseStateObserver() {
        let manager = RevenueCatManager.shared
        let expectation = expectation(description: "Observer should be called")
        
        manager.observePurchaseState { state in
            switch state {
            case .idle:
                expectation.fulfill()
            default:
                break
            }
        }
        
        waitForExpectations(timeout: 1.0)
    }
}