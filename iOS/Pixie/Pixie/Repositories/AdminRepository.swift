import Foundation

class AdminRepository: AdminRepositoryProtocol {
    private let networkService: NetworkServiceProtocol
    
    init(networkService: NetworkServiceProtocol) {
        self.networkService = networkService
    }
    
    func checkAdminStatus() async -> Bool {
        do {
            _ = try await networkService.get(
                "/v1/admin/credits/stats",
                type: SystemStatsResponse.self
            )
            return true
        } catch {
            return false
        }
    }
    
    func getSystemStats() async throws -> SystemStatsResponse {
        return try await networkService.get(
            "/v1/admin/credits/stats",
            type: SystemStatsResponse.self
        )
    }
    
    func searchUsers(query: String) async throws -> [UserSearchResult] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await networkService.get(
            "/v1/admin/users?q=\(encodedQuery)",
            type: [UserSearchResult].self
        )
    }
    
    func adjustCredits(request: AdminCreditAdjustmentRequest) async throws -> AdminCreditAdjustmentResponse {
        return try await networkService.post(
            "/v1/admin/credits/adjust",
            body: request,
            type: AdminCreditAdjustmentResponse.self
        )
    }
    
    func getAdjustmentHistory(userId: String?) async throws -> AdjustmentHistoryResponse {
        let path: String
        if let userId = userId {
            path = "/v1/admin/credits/adjustments/\(userId)"
        } else {
            // Get all adjustments - might need to check if this endpoint exists
            path = "/v1/admin/credits/adjustments"
        }
        
        return try await networkService.get(
            path,
            type: AdjustmentHistoryResponse.self
        )
    }
}