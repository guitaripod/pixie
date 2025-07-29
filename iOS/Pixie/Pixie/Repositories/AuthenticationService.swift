import Foundation

class AuthenticationService: AuthenticationServiceProtocol {
    private let keychainManager: KeychainManagerProtocol
    private let configurationManager: ConfigurationManagerProtocol
    private let networkService: NetworkServiceProtocol
    
    private(set) var currentUser: User?
    
    var isAuthenticated: Bool {
        do {
            let token = try keychainManager.getString(forKey: KeychainKeys.authToken)
            return !token.isEmpty
        } catch {
            return false
        }
    }
    
    init(keychainManager: KeychainManagerProtocol,
         configurationManager: ConfigurationManagerProtocol,
         networkService: NetworkServiceProtocol) {
        self.keychainManager = keychainManager
        self.configurationManager = configurationManager
        self.networkService = networkService
        
        loadCurrentUser()
    }
    
    func authenticate(with token: String) async throws -> User {
        try keychainManager.setString(token, forKey: KeychainKeys.authToken)
        
        ConfigurationManager.shared.apiKey = token
        if let networkService = networkService as? NetworkService {
            networkService.setAPIKey(token)
        }
        AppContainer.shared.updateNetworkServiceAPIKey()
        
        let user = User(
            id: UUID().uuidString,
            email: nil,
            name: nil,
            isAdmin: false,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
        
        try keychainManager.setCodable(user, forKey: KeychainKeys.userProfile)
        currentUser = user
        
        NotificationCenter.default.post(
            name: Notification.Name("UserDidAuthenticate"),
            object: user
        )
        
        return user
    }
    
    func setCurrentUser(_ user: User) async throws {
        try keychainManager.setCodable(user, forKey: KeychainKeys.userProfile)
        currentUser = user
        
        NotificationCenter.default.post(
            name: Notification.Name("UserDidAuthenticate"),
            object: user
        )
    }
    
    func logout() async throws {
        try keychainManager.delete(forKey: KeychainKeys.authToken)
        try keychainManager.delete(forKey: KeychainKeys.refreshToken)
        try keychainManager.delete(forKey: KeychainKeys.userProfile)
        try keychainManager.delete(forKey: KeychainKeys.deviceCode)
        
        ConfigurationManager.shared.apiKey = nil
        if let networkService = networkService as? NetworkService {
            networkService.setAPIKey(nil)
        }
        
        currentUser = nil
        
        NotificationCenter.default.post(
            name: Notification.Name("UserDidLogout"),
            object: nil
        )
    }
    
    func refreshToken() async throws {
        guard let refreshToken = try? keychainManager.getString(forKey: KeychainKeys.refreshToken),
              !refreshToken.isEmpty else {
            throw NetworkError.unauthorized
        }
        
        let tokenExpirationKey = "pixie.token.expiration"
        if let expirationDate = UserDefaults.standard.object(forKey: tokenExpirationKey) as? Date {
            if expirationDate > Date() {
                return
            }
        }
        
        do {
            let request = RefreshTokenRequest(refreshToken: refreshToken)
            let response: AuthResponse = try await networkService.post("/v1/auth/refresh", body: request, type: AuthResponse.self)
            
            try keychainManager.setString(response.apiKey, forKey: KeychainKeys.authToken)
            
            ConfigurationManager.shared.apiKey = response.apiKey
            if let networkService = networkService as? NetworkService {
                networkService.setAPIKey(response.apiKey)
            }
            AppContainer.shared.updateNetworkServiceAPIKey()
            
            let expirationDate = Date().addingTimeInterval(3600)
            UserDefaults.standard.set(expirationDate, forKey: tokenExpirationKey)
            
            NotificationCenter.default.post(
                name: Notification.Name("TokenDidRefresh"),
                object: nil
            )
        } catch {
            NotificationCenter.default.post(
                name: Notification.Name("TokenRefreshDidFail"),
                object: error
            )
            throw error
        }
    }
    
    func checkDeviceAuthStatus(deviceCode: String) async throws -> DeviceAuthStatus {
        let apiService = APIService(networkService: networkService)
        return try await apiService.checkDeviceAuthStatus(deviceCode: deviceCode)
    }
    
    private func loadCurrentUser() {
        do {
            currentUser = try keychainManager.getCodable(
                forKey: KeychainKeys.userProfile,
                type: User.self
            )
            
            if let token = try? keychainManager.getString(forKey: KeychainKeys.authToken) {
                ConfigurationManager.shared.apiKey = token
                if let networkService = networkService as? NetworkService {
                    networkService.setAPIKey(token)
                }
                AppContainer.shared.updateNetworkServiceAPIKey()
            }
        } catch {
            currentUser = nil
        }
    }
}

extension Notification.Name {
    static let userDidAuthenticate = Notification.Name("UserDidAuthenticate")
    static let userDidLogout = Notification.Name("UserDidLogout")
    static let tokenDidRefresh = Notification.Name("TokenDidRefresh")
    static let tokenRefreshDidFail = Notification.Name("TokenRefreshDidFail")
}