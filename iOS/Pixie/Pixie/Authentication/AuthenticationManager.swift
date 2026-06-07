import UIKit
import AICreditsCore

protocol AuthenticationManagerDelegate: AnyObject {
    func authenticationManager(_ manager: AuthenticationManager, didAuthenticate user: User)
    func authenticationManager(_ manager: AuthenticationManager, didFailWithError error: String)
}

class AuthenticationManager: NSObject {
    
    static let shared = AuthenticationManager()
    
    private let oauthCoordinator: OAuthCoordinator
    private let authenticationService: AuthenticationServiceProtocol
    private let keychainManager: KeychainManagerProtocol
    private let configurationManager: ConfigurationManagerProtocol
    
    weak var delegate: AuthenticationManagerDelegate?
    
    private override init() {
        let container = AppContainer.shared
        self.oauthCoordinator = OAuthCoordinator(
            apiService: container.apiService,
            configurationManager: container.configurationManager
        )
        self.authenticationService = container.authenticationService
        self.keychainManager = container.keychainManager
        self.configurationManager = container.configurationManager
        
        super.init()
        
        self.oauthCoordinator.delegate = self
    }
    
    var isAuthenticated: Bool {
        authenticationService.isAuthenticated
    }
    
    var currentUser: User? {
        authenticationService.currentUser
    }

    var isAnonymous: Bool {
        (try? keychainManager.getString(forKey: KeychainKeys.authProvider)) == "anonymous"
    }

    func authenticate(with provider: AuthProvider, from viewController: UIViewController) {
        oauthCoordinator.authenticate(provider: provider, from: viewController)
    }
    
    func authenticateDebug(from viewController: UIViewController) {
        Task { @MainActor in
            do {
                let debugApiKey = "debug-api-key"
                let debugUserId = "debug-user"
                let debugEmail = "debug@simulator.local"
                let debugUserName = "Debug User"
                
                try keychainManager.setString(debugApiKey, forKey: KeychainKeys.authToken)
                try keychainManager.setString("debug", forKey: KeychainKeys.authProvider)
                
                ConfigurationManager.shared.apiKey = debugApiKey
                AppContainer.shared.updateNetworkServiceAPIKey()
                
                let user = User(
                    id: debugUserId,
                    email: debugEmail,
                    name: debugUserName,
                    isAdmin: true,
                    createdAt: Date().ISO8601Format()
                )
                
                try await authenticationService.setCurrentUser(user)
                
                Task {
                    try? await RevenueCatManager.shared.setUserId(debugUserId)
                }
                
                NotificationCenter.default.post(name: .userDidAuthenticate, object: user)
                
                delegate?.authenticationManager(self, didAuthenticate: user)
            } catch {
                delegate?.authenticationManager(self, didFailWithError: "Debug authentication failed: \(error.localizedDescription)")
            }
        }
    }
    
    func logout() async throws {
        try await authenticationService.logout()
    }
    
    func handleUniversalLink(_ url: URL) -> Bool {
        guard url.scheme == "pixie",
              url.host == "auth" else {
            return false
        }
        
        Task {
            await oauthCoordinator.handleOAuthCallback(url: url)
        }
        
        return true
    }
    
    func restoreSession() async throws -> User? {
        if let user = authenticationService.currentUser {
            return user
        }
        
        if let token = try? keychainManager.getString(forKey: KeychainKeys.authToken),
           let savedUser = try? keychainManager.getCodable(forKey: KeychainKeys.userProfile, type: User.self) {
            ConfigurationManager.shared.apiKey = token
            AppContainer.shared.updateNetworkServiceAPIKey()
            try await authenticationService.setCurrentUser(savedUser)
            
            Task {
                try? await RevenueCatManager.shared.setUserId(savedUser.id)
            }
            
            return savedUser
        }

        return nil
    }

    @discardableResult
    func bootstrapAnonymous() async throws -> User {
        let identity = try await AICreditsService.shared.bootstrap()

        try keychainManager.setString(identity.apiKey, forKey: KeychainKeys.authToken)
        try keychainManager.setString("anonymous", forKey: KeychainKeys.authProvider)

        let user = User(
            id: identity.userID,
            email: nil,
            name: nil,
            isAdmin: false,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
        try keychainManager.setCodable(user, forKey: KeychainKeys.userProfile)

        ConfigurationManager.shared.apiKey = identity.apiKey
        AppContainer.shared.updateNetworkServiceAPIKey()
        try await authenticationService.setCurrentUser(user)

        Task {
            try? await RevenueCatManager.shared.setUserId(identity.userID)
        }

        return user
    }

    @discardableResult
    func linkApple(identityToken: String) async throws -> User {
        let identity = try await AICreditsService.shared.link(appleIdentityToken: identityToken)

        try keychainManager.setString(identity.apiKey, forKey: KeychainKeys.authToken)
        try keychainManager.setString("apple", forKey: KeychainKeys.authProvider)

        let user = User(
            id: identity.userID,
            email: nil,
            name: nil,
            isAdmin: false,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
        try keychainManager.setCodable(user, forKey: KeychainKeys.userProfile)

        ConfigurationManager.shared.apiKey = identity.apiKey
        AppContainer.shared.updateNetworkServiceAPIKey()
        try await authenticationService.setCurrentUser(user)

        Task {
            try? await RevenueCatManager.shared.setUserId(identity.userID)
        }

        return user
    }

    #if DEBUG
    func signOutForTesting() async {
        for key in [KeychainKeys.authToken, KeychainKeys.userProfile, KeychainKeys.authProvider, KeychainKeys.apiKey] {
            try? keychainManager.delete(forKey: key)
        }
        ConfigurationManager.shared.apiKey = nil
        await AICreditsService.shared.signOut()
        try? await authenticationService.logout()
    }
    #endif
}

extension AuthenticationManager: OAuthCoordinatorDelegate {
    func oauthCoordinator(_ coordinator: OAuthCoordinator, didCompleteWith result: AuthResult) {
        Task { @MainActor in
            switch result {
            case .success(let apiKey, let userId, let provider, let isAdmin):
                do {
                    try keychainManager.setString(apiKey, forKey: KeychainKeys.authToken)
                    try keychainManager.setString(provider.rawValue, forKey: KeychainKeys.authProvider)
                    
                    ConfigurationManager.shared.apiKey = apiKey
                    AppContainer.shared.updateNetworkServiceAPIKey()
                    
                    let user = User(
                        id: userId,
                        email: nil,
                        name: nil,
                        isAdmin: isAdmin,
                        createdAt: ISO8601DateFormatter().string(from: Date())
                    )
                    
                    try await authenticationService.setCurrentUser(user)
                    
                    Task {
                        try? await RevenueCatManager.shared.setUserId(userId)
                    }
                    
                    delegate?.authenticationManager(self, didAuthenticate: user)
                } catch {
                    delegate?.authenticationManager(self, didFailWithError: error.localizedDescription)
                }
                
            case .error(let message):
                delegate?.authenticationManager(self, didFailWithError: message)
                
            case .cancelled:
                delegate?.authenticationManager(self, didFailWithError: "Authentication cancelled")
                
            case .pending:
                break
            }
        }
    }
    
}

extension KeychainKeys {
    static let authProvider = "pixie.auth.provider"
}