import Foundation

protocol ImageRepositoryProtocol {
    func generateImages(request: ImageGenerationRequest) async throws -> ImageResponse
    func editImage(request: ImageEditRequest) async throws -> ImageResponse
    func getPublicGallery(page: Int, perPage: Int) async throws -> GalleryResponse
    func getUserGallery(userId: String, page: Int, perPage: Int) async throws -> UserGalleryResponse
    func getImage(id: String) async throws -> ImageMetadata
    func downloadImage(from url: String) async throws -> Data
}

protocol CreditRepositoryProtocol {
    func getBalance() async throws -> CreditBalance
    func getTransactions(limit: Int) async throws -> CreditTransactionsResponse
    func getPacks() async throws -> CreditPacksResponse
    func estimateCost(request: CreditEstimateRequest) async throws -> CreditEstimateResponse
}

protocol UserRepositoryProtocol {
    func getCurrentUser() async throws -> User?
    func saveUser(_ user: User) async throws
    func deleteUser() async throws
    func getUsage(start: String?, end: String?) async throws -> UsageResponse
    func getUsageDetails(start: String?, end: String?) async throws -> UsageDetailsResponse
}

protocol AuthenticationServiceProtocol {
    var isAuthenticated: Bool { get }
    var currentUser: User? { get }
    
    func authenticate(with token: String) async throws -> User
    func setCurrentUser(_ user: User) async throws
    func logout() async throws
    func refreshToken() async throws
    func checkDeviceAuthStatus(deviceCode: String) async throws -> DeviceAuthStatus
}

protocol AdminRepositoryProtocol {
    func checkAdminStatus() async -> Bool
    func getSystemStats() async throws -> SystemStatsResponse
    func searchUsers(query: String) async throws -> [UserSearchResult]
    func adjustCredits(request: AdminCreditAdjustmentRequest) async throws -> AdminCreditAdjustmentResponse
    func getAdjustmentHistory(userId: String?) async throws -> AdjustmentHistoryResponse
}

struct User: Codable {
    let id: String
    let email: String?
    let name: String?
    let isAdmin: Bool
    let createdAt: String?
}