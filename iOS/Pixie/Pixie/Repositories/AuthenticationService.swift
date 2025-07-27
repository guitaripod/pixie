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
        guard let refreshToken = try? keychainManager.getString(forKey: KeychainKeys.refreshToken) else {
            throw NetworkError.unauthorized
        }
        
        if refreshToken.isEmpty {
            throw NetworkError.unauthorized
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
            }
        } catch {
            currentUser = nil
        }
    }
}

extension Notification.Name {
    static let userDidAuthenticate = Notification.Name("UserDidAuthenticate")
    static let userDidLogout = Notification.Name("UserDidLogout")
}