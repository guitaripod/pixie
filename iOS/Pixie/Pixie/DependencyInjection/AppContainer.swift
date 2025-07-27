import Foundation

protocol AppContainerProtocol {
    var networkService: NetworkServiceProtocol { get }
    var apiService: APIServiceProtocol { get }
    var keychainManager: KeychainManagerProtocol { get }
    var configurationManager: ConfigurationManagerProtocol { get }
    var authenticationService: AuthenticationServiceProtocol { get }
    var imageRepository: ImageRepositoryProtocol { get }
    var creditRepository: CreditRepositoryProtocol { get }
    var userRepository: UserRepositoryProtocol { get }
    var imageCache: ImageCacheProtocol { get }
    var networkMonitor: NetworkMonitorProtocol { get }
}

class AppContainer: AppContainerProtocol {
    static let shared = AppContainer()
    
    lazy var networkService: NetworkServiceProtocol = {
        let service = NetworkService(baseURL: configurationManager.baseURL)
        if let apiKey = configurationManager.apiKey {
            service.setAPIKey(apiKey)
        }
        return service
    }()
    
    lazy var apiService: APIServiceProtocol = {
        APIService(networkService: networkService)
    }()
    
    lazy var keychainManager: KeychainManagerProtocol = {
        KeychainManager()
    }()
    
    lazy var configurationManager: ConfigurationManagerProtocol = {
        ConfigurationManager.shared
    }()
    
    lazy var authenticationService: AuthenticationServiceProtocol = {
        AuthenticationService(
            keychainManager: keychainManager,
            configurationManager: configurationManager,
            networkService: networkService
        )
    }()
    
    lazy var imageRepository: ImageRepositoryProtocol = {
        ImageRepository(apiService: apiService)
    }()
    
    lazy var creditRepository: CreditRepositoryProtocol = {
        CreditRepository(apiService: apiService)
    }()
    
    lazy var userRepository: UserRepositoryProtocol = {
        UserRepository(
            keychainManager: keychainManager,
            apiService: apiService
        )
    }()
    
    lazy var imageCache: ImageCacheProtocol = {
        ImageCache.shared
    }()
    
    lazy var networkMonitor: NetworkMonitorProtocol = {
        NetworkMonitor.shared
    }()
    
    private init() {}
    
    func updateNetworkServiceAPIKey() {
        if let apiKey = configurationManager.apiKey,
           let networkService = networkService as? NetworkService {
            networkService.setAPIKey(apiKey)
        }
    }
}