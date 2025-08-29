import Foundation
import RevenueCat
import Combine

struct CreditPurchaseResult {
    let purchaseId: String
    let credits: Int
    let newBalance: Int
    let amountUsd: String
}

struct RestoredPurchase {
    let productId: String
    let purchaseDate: String
    let expirationDate: String?
}

struct CreditPackWithPrice {
    let creditPack: CreditPack
    let rcPackage: Package
    let localizedPrice: String
}

class PurchaseCancelledException: LocalizedError {
    var errorDescription: String? {
        return "Purchase cancelled by user"
    }
}

struct RevenueCatPurchaseValidationRequest: Codable {
    let packId: String
    let purchaseToken: String
    let productId: String
    let platform: String
    
    enum CodingKeys: String, CodingKey {
        case packId = "pack_id"
        case purchaseToken = "purchase_token"
        case productId = "product_id"
        case platform
    }
}


@MainActor
class CreditPurchaseManager {
    static let shared = CreditPurchaseManager()
    
    private let revenueCatManager = RevenueCatManager.shared
    private let apiService: APIServiceProtocol
    private let creditsViewModel: CreditsViewModel
    
    @Published private(set) var purchaseState: PurchaseState = .idle
    @Published private(set) var offerings: Offerings?
    @Published private(set) var creditPacks: [CreditPack] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    private let packageToPackId: [String: String] = [
        "starter": "starter",
        "basic": "basic",
        "popular": "popular",
        "business": "business",
        "enterprise": "enterprise"
    ]
    
    private init(apiService: APIServiceProtocol = APIService.shared) {
        self.apiService = apiService
        self.creditsViewModel = CreditsViewModel(apiService: apiService)
        setupBindings()
    }
    
    private func setupBindings() {
        revenueCatManager.observePurchaseState { [weak self] state in
            self?.purchaseState = state
        }
        
        revenueCatManager.$offerings
            .sink { [weak self] offerings in
                self?.offerings = offerings
            }
            .store(in: &cancellables)
        
        Task {
            await fetchCreditPacks()
        }
    }
    
    func fetchCreditPacks() async {
        do {
            let response = try await apiService.getCreditPacks()
            await MainActor.run {
                self.creditPacks = response.packs
            }
        } catch {
            print("Error fetching credit packs: \(error)")
        }
    }
    
    func purchaseCreditPack(package: Package) async -> Result<CreditPurchaseResult, Error> {
        do {
            try await revenueCatManager.purchaseCreditPack(package: package)
            
            switch purchaseState {
            case .success(let purchaseToken, let productId, let packageId):
                let packId = packageToPackId[packageId] ?? packageId
                return await validateAndRecordPurchase(
                    packId: packId,
                    purchaseToken: purchaseToken,
                    productId: productId
                )
                
            case .error(let message):
                return .failure(NSError(domain: "CreditPurchase", code: -1, userInfo: [NSLocalizedDescriptionKey: message]))
                
            case .cancelled:
                return .failure(PurchaseCancelledException())
                
            default:
                return .failure(NSError(domain: "CreditPurchase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unexpected purchase state"]))
            }
        } catch {
            return .failure(error)
        }
    }
    
    private func validateAndRecordPurchase(
        packId: String,
        purchaseToken: String,
        productId: String
    ) async -> Result<CreditPurchaseResult, Error> {
        do {
            let request = RevenueCatPurchaseValidationRequest(
                packId: packId,
                purchaseToken: purchaseToken,
                productId: productId,
                platform: "ios"
            )
            
            let response: RevenueCatPurchaseValidationResponse = try await apiService.validateRevenueCatPurchase(request)
            
            if response.success {
                await creditsViewModel.loadBalance()
                
                return .success(CreditPurchaseResult(
                    purchaseId: response.purchaseId,
                    credits: response.creditsAdded,
                    newBalance: response.newBalance,
                    amountUsd: ""
                ))
            } else {
                return .failure(NSError(domain: "CreditPurchase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Purchase validation failed"]))
            }
        } catch {
            print("Error recording purchase: \(error)")
            return .failure(error)
        }
    }
    
    func restorePurchases() async -> Result<[RestoredPurchase], Error> {
        do {
            let customerInfo = try await revenueCatManager.restorePurchases()
            var restoredPurchases: [RestoredPurchase] = []
            
            for (_, entitlement) in customerInfo.entitlements.all {
                if entitlement.isActive {
                    let productId = entitlement.productIdentifier
                    restoredPurchases.append(RestoredPurchase(
                        productId: productId,
                        purchaseDate: entitlement.latestPurchaseDate?.description ?? "",
                        expirationDate: entitlement.expirationDate?.description
                    ))
                }
            }
            
            return .success(restoredPurchases)
        } catch {
            print("Error restoring purchases: \(error)")
            return .failure(error)
        }
    }
    
    func getCreditPacksWithPricing() -> AnyPublisher<[CreditPackWithPrice], Never> {
        Publishers.CombineLatest($creditPacks, $offerings)
            .map { (backendPacks, revenueCatOfferings) -> [CreditPackWithPrice] in
                guard !backendPacks.isEmpty else { return [] }
                
                let defaultOffering = revenueCatOfferings?.current ?? revenueCatOfferings?.all.values.first
                
                guard let packages = defaultOffering?.availablePackages else { return [] }
                
                var creditPacksWithPrice: [CreditPackWithPrice] = []
                
                for pack in backendPacks {
                    if let rcPackage = packages.first(where: { $0.identifier == pack.id }) {
                        let creditPack = CreditPack(
                            id: pack.id,
                            name: pack.name,
                            credits: pack.credits,
                            priceUsdCents: pack.priceUsdCents,
                            bonusCredits: pack.bonusCredits,
                            description: pack.description
                        )
                        
                        creditPacksWithPrice.append(CreditPackWithPrice(
                            creditPack: creditPack,
                            rcPackage: rcPackage,
                            localizedPrice: rcPackage.storeProduct.localizedPriceString
                        ))
                    }
                }
                
                return creditPacksWithPrice.sorted { $0.creditPack.priceUsdCents < $1.creditPack.priceUsdCents }
            }
            .eraseToAnyPublisher()
    }
    
    func getCreditsForPackage(_ packId: String) -> (total: Int, base: Int, bonus: Int) {
        if let pack = creditPacks.first(where: { $0.id == packId }) {
            let total = pack.credits + pack.bonusCredits
            return (total, pack.credits, pack.bonusCredits)
        }
        
        return (0, 0, 0)
    }
    
    func resetPurchaseState() {
        revenueCatManager.resetPurchaseState()
    }
}