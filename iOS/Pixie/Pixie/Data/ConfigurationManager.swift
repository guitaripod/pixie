import Foundation

protocol ConfigurationManagerProtocol {
    var baseURL: String { get set }
    var apiKey: String? { get set }
    var defaultQuality: String { get set }
    var defaultSize: String { get set }
    var defaultOutputFormat: String { get set }
    var defaultCompression: Int { get set }
    var enableHaptics: Bool { get set }
    var theme: AppTheme { get set }
    func load()
    func save()
    func reset()
}

enum AppTheme: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"
}

class ConfigurationManager: ConfigurationManagerProtocol {
    static let shared = ConfigurationManager()
    static let configurationDidChangeNotification = Notification.Name("ConfigurationDidChange")
    private let defaults = UserDefaults.standard
    private let keychain = KeychainManager()
    @UserDefaultsWrapper(key: "pixie.baseURL", defaultValue: "https://openai-image-proxy.guitaripod.workers.dev")
    var baseURL: String {
        didSet { notifyConfigurationChanged() }
    }
    var apiKey: String? {
        get {
            try? keychain.getString(forKey: KeychainKeys.apiKey)
        }
        set {
            if let value = newValue {
                try? keychain.setString(value, forKey: KeychainKeys.apiKey)
            } else {
                try? keychain.delete(forKey: KeychainKeys.apiKey)
            }
            notifyConfigurationChanged()
        }
    }
    @UserDefaultsWrapper(key: "pixie.defaultQuality", defaultValue: "low")
    var defaultQuality: String {
        didSet { notifyConfigurationChanged() }
    }
    @UserDefaultsWrapper(key: "pixie.defaultSize", defaultValue: "auto")
    var defaultSize: String {
        didSet { notifyConfigurationChanged() }
    }
    @UserDefaultsWrapper(key: "pixie.defaultOutputFormat", defaultValue: "webp")
    var defaultOutputFormat: String {
        didSet { notifyConfigurationChanged() }
    }
    @UserDefaultsWrapper(key: "pixie.defaultCompression", defaultValue: 90)
    var defaultCompression: Int {
        didSet { notifyConfigurationChanged() }
    }
    @UserDefaultsWrapper(key: "pixie.enableHaptics", defaultValue: true)
    var enableHaptics: Bool {
        didSet { notifyConfigurationChanged() }
    }
    @UserDefaultsWrapper(key: "pixie.theme", defaultValue: .system)
    var theme: AppTheme {
        didSet { notifyConfigurationChanged() }
    }
    private init() {
        load()
    }
    func load() {
    }
    func save() {
        notifyConfigurationChanged()
    }
    func reset() {
        baseURL = "https://openai-image-proxy.guitaripod.workers.dev"
        apiKey = nil
        defaultQuality = "low"
        defaultSize = "auto"
        defaultOutputFormat = "webp"
        defaultCompression = 90
        enableHaptics = true
        theme = .system
    }
    private func notifyConfigurationChanged() {
        NotificationCenter.default.post(
            name: Self.configurationDidChangeNotification,
            object: self
        )
    }
}

@propertyWrapper
struct UserDefaultsWrapper<T> {
    let key: String
    let defaultValue: T
    let userDefaults: UserDefaults = .standard
    var wrappedValue: T {
        get {
            userDefaults.object(forKey: key) as? T ?? defaultValue
        }
        set {
            userDefaults.set(newValue, forKey: key)
        }
    }
}

extension UserDefaultsWrapper where T == AppTheme {
    var wrappedValue: T {
        get {
            if let rawValue = userDefaults.string(forKey: key),
               let theme = AppTheme(rawValue: rawValue) {
                return theme
            }
            return defaultValue
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: key)
        }
    }
}