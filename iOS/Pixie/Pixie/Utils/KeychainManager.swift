import Foundation
import Security

enum KeychainError: LocalizedError {
    case unhandledError(OSStatus)
    case unexpectedData
    case noData
    
    var errorDescription: String? {
        switch self {
        case .unhandledError(let status):
            return "Keychain error: \(status)"
        case .unexpectedData:
            return "Unexpected data format in keychain"
        case .noData:
            return "No data found in keychain"
        }
    }
}

protocol KeychainManagerProtocol {
    func set(_ data: Data, forKey key: String) throws
    func get(forKey key: String) throws -> Data
    func delete(forKey key: String) throws
    func setString(_ string: String, forKey key: String) throws
    func getString(forKey key: String) throws -> String
    func setCodable<T: Codable>(_ object: T, forKey key: String) throws
    func getCodable<T: Codable>(forKey key: String, type: T.Type) throws -> T
}

class KeychainManager: KeychainManagerProtocol {
    private let service: String
    private let accessGroup: String?
    
    init(service: String = Bundle.main.bundleIdentifier ?? "com.guitaripod.pixie",
         accessGroup: String? = nil) {
        self.service = service
        self.accessGroup = accessGroup
    }
    
    func set(_ data: Data, forKey key: String) throws {
        var query = baseQuery(forKey: key)
        query[kSecValueData as String] = data
        
        var status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecDuplicateItem {
            status = SecItemUpdate(
                baseQuery(forKey: key) as CFDictionary,
                [kSecValueData as String: data] as CFDictionary
            )
        }
        
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status)
        }
    }
    
    func get(forKey key: String) throws -> Data {
        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.noData
            }
            throw KeychainError.unhandledError(status)
        }
        
        guard let data = result as? Data else {
            throw KeychainError.unexpectedData
        }
        
        return data
    }
    
    func delete(forKey key: String) throws {
        let query = baseQuery(forKey: key)
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status)
        }
    }
    
    func setString(_ string: String, forKey key: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.unexpectedData
        }
        try set(data, forKey: key)
    }
    
    func getString(forKey key: String) throws -> String {
        let data = try get(forKey: key)
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedData
        }
        return string
    }
    
    func setCodable<T: Codable>(_ object: T, forKey key: String) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(object)
        try set(data, forKey: key)
    }
    
    func getCodable<T: Codable>(forKey key: String, type: T.Type) throws -> T {
        let data = try get(forKey: key)
        let decoder = JSONDecoder()
        return try decoder.decode(type, from: data)
    }
    
    private func baseQuery(forKey key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        return query
    }
}

enum KeychainKeys {
    static let apiKey = "pixie.api.key"
    static let authToken = "pixie.auth.token"
    static let refreshToken = "pixie.refresh.token"
    static let userProfile = "pixie.user.profile"
    static let deviceCode = "pixie.device.code"
}