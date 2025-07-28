import Foundation

protocol APIServiceProtocol {
    func generateImages(_ request: ImageGenerationRequest) async throws -> ImageResponse
    func editImage(_ request: ImageEditRequest) async throws -> ImageResponse
    func listImages(page: Int, perPage: Int) async throws -> GalleryResponse
    func listUserImages(userId: String, page: Int, perPage: Int) async throws -> UserGalleryResponse
    func getImage(id: String) async throws -> ImageMetadata
    func getUsage(userId: String, start: String?, end: String?) async throws -> UsageResponse
    func getUsageDetails(userId: String, start: String?, end: String?) async throws -> UsageDetailsResponse
    func getCreditBalance() async throws -> CreditBalance
    func getCreditTransactions(limit: Int) async throws -> CreditTransactionsResponse
    func getCreditPacks() async throws -> CreditPacksResponse
    func estimateCreditCost(_ request: CreditEstimateRequest) async throws -> CreditEstimateResponse
    func checkDeviceAuthStatus(deviceCode: String) async throws -> DeviceAuthStatus
    func downloadImage(from url: String) async throws -> Data
    func authenticateGitHub(_ request: OAuthCallbackRequest) async throws -> AuthResponse
    func authenticateGoogle(_ request: OAuthCallbackRequest) async throws -> AuthResponse
    func authenticateGoogleToken(_ request: GoogleTokenRequest) async throws -> AuthResponse
    func authenticateApple(_ request: OAuthCallbackRequest) async throws -> AuthResponse
    func authenticateAppleToken(_ request: AppleTokenRequest) async throws -> AuthResponse
}

class APIService: APIServiceProtocol {
    private let networkService: NetworkServiceProtocol
    
    init(networkService: NetworkServiceProtocol) {
        self.networkService = networkService
    }
    
    func generateImages(_ request: ImageGenerationRequest) async throws -> ImageResponse {
        try await networkService.post("/v1/images/generations", body: request, type: ImageResponse.self)
    }
    
    func editImage(_ request: ImageEditRequest) async throws -> ImageResponse {
        try await networkService.post("/v1/images/edits", body: request, type: ImageResponse.self)
    }
    
    func listImages(page: Int, perPage: Int) async throws -> GalleryResponse {
        try await networkService.get("/v1/images?page=\(page)&per_page=\(perPage)", type: GalleryResponse.self)
    }
    
    func listUserImages(userId: String, page: Int, perPage: Int) async throws -> UserGalleryResponse {
        try await networkService.get("/v1/images/user/\(userId)?page=\(page)&per_page=\(perPage)", type: UserGalleryResponse.self)
    }
    
    func getImage(id: String) async throws -> ImageMetadata {
        try await networkService.get("/v1/images/\(id)", type: ImageMetadata.self)
    }
    
    func getUsage(userId: String, start: String? = nil, end: String? = nil) async throws -> UsageResponse {
        var endpoint = "/v1/usage/users/\(userId)"
        var params: [String] = []
        
        if let start = start {
            params.append("start=\(start)")
        }
        if let end = end {
            params.append("end=\(end)")
        }
        
        if !params.isEmpty {
            endpoint += "?\(params.joined(separator: "&"))"
        }
        
        return try await networkService.get(endpoint, type: UsageResponse.self)
    }
    
    func getUsageDetails(userId: String, start: String? = nil, end: String? = nil) async throws -> UsageDetailsResponse {
        var endpoint = "/v1/usage/users/\(userId)/details"
        var params: [String] = []
        
        if let start = start {
            params.append("start=\(start)")
        }
        if let end = end {
            params.append("end=\(end)")
        }
        
        if !params.isEmpty {
            endpoint += "?\(params.joined(separator: "&"))"
        }
        
        return try await networkService.get(endpoint, type: UsageDetailsResponse.self)
    }
    
    func getCreditBalance() async throws -> CreditBalance {
        try await networkService.get("/v1/credits/balance", type: CreditBalance.self)
    }
    
    func getCreditTransactions(limit: Int) async throws -> CreditTransactionsResponse {
        try await networkService.get("/v1/credits/transactions?per_page=\(limit)", type: CreditTransactionsResponse.self)
    }
    
    func getCreditPacks() async throws -> CreditPacksResponse {
        try await networkService.get("/v1/credits/packs", type: CreditPacksResponse.self)
    }
    
    func estimateCreditCost(_ request: CreditEstimateRequest) async throws -> CreditEstimateResponse {
        try await networkService.post("/v1/credits/estimate", body: request, type: CreditEstimateResponse.self)
    }
    
    func checkDeviceAuthStatus(deviceCode: String) async throws -> DeviceAuthStatus {
        try await networkService.get("/v1/auth/device/\(deviceCode)/status", type: DeviceAuthStatus.self)
    }
    
    func downloadImage(from url: String) async throws -> Data {
        guard let imageURL = URL(string: url) else {
            throw NetworkError.invalidURL
        }
        return try await networkService.downloadData(from: imageURL)
    }
    
    func authenticateGitHub(_ request: OAuthCallbackRequest) async throws -> AuthResponse {
        try await networkService.post("/v1/auth/github/callback", body: request, type: AuthResponse.self)
    }
    
    func authenticateGoogle(_ request: OAuthCallbackRequest) async throws -> AuthResponse {
        try await networkService.post("/v1/auth/google/callback", body: request, type: AuthResponse.self)
    }
    
    func authenticateGoogleToken(_ request: GoogleTokenRequest) async throws -> AuthResponse {
        try await networkService.post("/v1/auth/google/token", body: request, type: AuthResponse.self)
    }
    
    func authenticateApple(_ request: OAuthCallbackRequest) async throws -> AuthResponse {
        try await networkService.post("/v1/auth/apple/callback/json", body: request, type: AuthResponse.self)
    }
    
    func authenticateAppleToken(_ request: AppleTokenRequest) async throws -> AuthResponse {
        try await networkService.post("/v1/auth/apple/token", body: request, type: AuthResponse.self)
    }
}