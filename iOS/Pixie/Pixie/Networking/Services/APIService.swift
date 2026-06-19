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
    func validateRevenueCatPurchase<T: Codable>(_ request: T) async throws -> RevenueCatPurchaseValidationResponse
    func reportImage(id: String) async throws -> ReportImageResponse
    func deleteImage(id: String) async throws
    func setImageVisibility(id: String, isPublic: Bool) async throws
    func setAllVisibility(isPublic: Bool) async throws -> Int
}

struct ReportImageRequest: Codable {
    let reason: String?
}

struct ReportImageResponse: Codable {
    let reported: Bool
    let imageId: String

    enum CodingKeys: String, CodingKey {
        case reported
        case imageId = "image_id"
    }
}

struct VisibilityRequest: Codable {
    let isPublic: Bool

    enum CodingKeys: String, CodingKey {
        case isPublic = "is_public"
    }
}

struct ImageVisibilityResponse: Codable {
    let imageId: String
    let isPublic: Bool

    enum CodingKeys: String, CodingKey {
        case imageId = "image_id"
        case isPublic = "is_public"
    }
}

struct AllVisibilityResponse: Codable {
    let updated: Int
    let isPublic: Bool

    enum CodingKeys: String, CodingKey {
        case updated
        case isPublic = "is_public"
    }
}

class APIService: APIServiceProtocol {
    static let shared: APIService = {
        // Use the network service from AppContainer to ensure API key is set
        return APIService(networkService: AppContainer.shared.networkService)
    }()
    
    private let networkService: NetworkServiceProtocol
    
    var baseURL: String {
        return ConfigurationManager.shared.baseURL
    }
    
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

    func reportImage(id: String) async throws -> ReportImageResponse {
        try await networkService.post("/v1/images/\(id)/report", body: ReportImageRequest(reason: nil), type: ReportImageResponse.self)
    }

    func deleteImage(id: String) async throws {
        try await networkService.delete("/v1/images/\(id)")
    }

    func setImageVisibility(id: String, isPublic: Bool) async throws {
        _ = try await networkService.put("/v1/images/\(id)/visibility", body: VisibilityRequest(isPublic: isPublic), type: ImageVisibilityResponse.self)
    }

    func setAllVisibility(isPublic: Bool) async throws -> Int {
        let response = try await networkService.put("/v1/images/visibility", body: VisibilityRequest(isPublic: isPublic), type: AllVisibilityResponse.self)
        return response.updated
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
    
    func validateRevenueCatPurchase<T: Codable>(_ request: T) async throws -> RevenueCatPurchaseValidationResponse {
        try await networkService.post("/v1/credits/purchase/revenuecat/validate", body: request, type: RevenueCatPurchaseValidationResponse.self)
    }
}