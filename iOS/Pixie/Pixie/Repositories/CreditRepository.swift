import Foundation

class CreditRepository: CreditRepositoryProtocol {
    private let apiService: APIServiceProtocol
    
    init(apiService: APIServiceProtocol) {
        self.apiService = apiService
    }
    
    func getBalance() async throws -> CreditBalance {
        try await apiService.getCreditBalance()
    }
    
    func getTransactions(limit: Int) async throws -> CreditTransactionsResponse {
        try await apiService.getCreditTransactions(limit: limit)
    }
    
    func getPacks() async throws -> CreditPacksResponse {
        try await apiService.getCreditPacks()
    }
    
    func estimateCost(request: CreditEstimateRequest) async throws -> CreditEstimateResponse {
        try await apiService.estimateCreditCost(request)
    }
}