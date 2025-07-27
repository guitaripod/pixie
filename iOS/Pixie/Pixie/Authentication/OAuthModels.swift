import Foundation

enum AuthProvider: String, CaseIterable {
    case github = "github"
    case google = "google" 
    case apple = "apple"
    
    var displayName: String {
        switch self {
        case .github:
            return "GitHub"
        case .google:
            return "Google"
        case .apple:
            return "Apple"
        }
    }
}

struct OAuthState {
    let state: String
    let provider: AuthProvider
    let timestamp: Date
    
    init(provider: AuthProvider) {
        self.state = UUID().uuidString
        self.provider = provider
        self.timestamp = Date()
    }
    
    func isValid() -> Bool {
        Date().timeIntervalSince(timestamp) < 600
    }
}

enum AuthResult {
    case success(apiKey: String, userId: String, provider: AuthProvider)
    case error(String)
    case cancelled
    case pending
}

struct OAuthCallbackRequest: Codable {
    let code: String
    let state: String?
    let redirectUri: String
    
    enum CodingKeys: String, CodingKey {
        case code
        case state
        case redirectUri = "redirect_uri"
    }
}

struct AuthResponse: Codable {
    let apiKey: String
    let userId: String
    
    enum CodingKeys: String, CodingKey {
        case apiKey = "api_key"
        case userId = "user_id"
    }
}

struct GoogleTokenRequest: Codable {
    let idToken: String
    
    enum CodingKeys: String, CodingKey {
        case idToken = "id_token"
    }
}

struct AppleIDCredential {
    let userID: String
    let authorizationCode: Data
    let identityToken: Data
    let email: String?
    let fullName: PersonNameComponents?
}