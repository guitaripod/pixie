import Foundation
import RevenueCat
import UIKit

enum PurchaseState {
    case idle
    case loading
    case success(purchaseToken: String, productId: String, packageId: String)
    case error(message: String)
    case cancelled
}

@MainActor
final class RevenueCatManager: NSObject {
    static let shared = RevenueCatManager()
    
    private static let revenueCatAPIKey = "appl_GYqkuGCJhGnqPanmoeSJhTvIgHA"
    
    @Published private(set) var purchaseState: PurchaseState = .idle
    @Published private(set) var offerings: Offerings?
    @Published private(set) var customerInfo: CustomerInfo?
    
    private var purchaseStateObservers: [(PurchaseState) -> Void] = []
    
    private override init() {
        super.init()
        setupRevenueCat()
    }
    
    private func setupRevenueCat() {
        Purchases.logLevel = .info
        Purchases.configure(withAPIKey: Self.revenueCatAPIKey)
        Purchases.shared.delegate = self
        fetchOfferings()
    }
    
    func setUserId(_ userId: String) async throws {
        let (customerInfo, created) = try await Purchases.shared.logIn(userId)
        self.customerInfo = customerInfo
        print("User logged in: \(userId), created: \(created)")
    }
    
    func fetchOfferings() {
        Task {
            do {
                let offerings = try await Purchases.shared.offerings()
                self.offerings = offerings
                print("Offerings fetched: \(offerings.all.count) offerings")
            } catch {
                print("Error fetching offerings: \(error.localizedDescription)")
                updatePurchaseState(.error(message: error.localizedDescription))
            }
        }
    }
    
    func purchaseCreditPack(package: Package) async throws {
        updatePurchaseState(.loading)
        
        do {
            let (transaction, customerInfo, userCancelled) = try await Purchases.shared.purchase(package: package)
            
            if userCancelled {
                updatePurchaseState(.cancelled)
                print("Purchase cancelled by user")
            } else {
                let purchaseToken = transaction?.transactionIdentifier ?? ""
                let productId = transaction?.productIdentifier ?? package.storeProduct.productIdentifier
                
                updatePurchaseState(.success(
                    purchaseToken: purchaseToken,
                    productId: productId,
                    packageId: package.identifier
                ))
                
                self.customerInfo = customerInfo
                print("Purchase successful: \(productId)")
            }
        } catch let error as ErrorCode {
            if error == .purchaseCancelledError {
                updatePurchaseState(.cancelled)
                print("Purchase cancelled by user")
            } else {
                updatePurchaseState(.error(message: error.localizedDescription))
                print("Purchase error: \(error.localizedDescription)")
            }
        } catch {
            updatePurchaseState(.error(message: error.localizedDescription))
            print("Purchase error: \(error.localizedDescription)")
        }
    }
    
    func restorePurchases() async throws -> CustomerInfo {
        let customerInfo = try await Purchases.shared.restorePurchases()
        self.customerInfo = customerInfo
        print("Restore successful")
        return customerInfo
    }
    
    func getCustomerInfo() async throws -> CustomerInfo {
        let customerInfo = try await Purchases.shared.customerInfo()
        self.customerInfo = customerInfo
        return customerInfo
    }
    
    func resetPurchaseState() {
        updatePurchaseState(.idle)
    }
    
    func observePurchaseState(_ observer: @escaping (PurchaseState) -> Void) {
        purchaseStateObservers.append(observer)
        observer(purchaseState)
    }
    
    private func updatePurchaseState(_ state: PurchaseState) {
        purchaseState = state
        purchaseStateObservers.forEach { $0(state) }
    }
}

extension RevenueCatManager: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.customerInfo = customerInfo
        }
    }
    
    nonisolated func purchases(_ purchases: Purchases, readyForPromotedProduct product: StoreProduct, purchase startPurchase: @escaping StartPurchaseBlock) {
        startPurchase { (transaction, customerInfo, error, userCancelled) in
            print("Promoted product purchase completed")
        }
    }
}