import Foundation

class UserRepository: UserRepositoryProtocol {
    private let keychainManager: KeychainManagerProtocol
    private let apiService: APIServiceProtocol
    
    init(keychainManager: KeychainManagerProtocol, apiService: APIServiceProtocol) {
        self.keychainManager = keychainManager
        self.apiService = apiService
    }
    
    func getCurrentUser() async throws -> User? {
        do {
            return try keychainManager.getCodable(forKey: KeychainKeys.userProfile, type: User.self)
        } catch {
            return nil
        }
    }
    
    func saveUser(_ user: User) async throws {
        try keychainManager.setCodable(user, forKey: KeychainKeys.userProfile)
    }
    
    func deleteUser() async throws {
        try keychainManager.delete(forKey: KeychainKeys.userProfile)
    }
    
    func getUsage(start: String? = nil, end: String? = nil) async throws -> UsageResponse {
        guard let user = try await getCurrentUser() else {
            throw NetworkError.unauthorized
        }
        return try await apiService.getUsage(userId: user.id, start: start, end: end)
    }
    
    func getUsageDetails(start: String? = nil, end: String? = nil) async throws -> UsageDetailsResponse {
        guard let user = try await getCurrentUser() else {
            throw NetworkError.unauthorized
        }
        return try await apiService.getUsageDetails(userId: user.id, start: start, end: end)
    }
}