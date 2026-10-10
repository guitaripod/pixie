import Foundation
import RevenueCat
import AICreditsCore

enum AccountDeletionError: LocalizedError {
    case notSignedIn
    case offline
    case server(String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return String(localized: "There is no account on this device to delete.")
        case .offline:
            return String(localized: "You're offline. Connect to the internet and try again; nothing was deleted.")
        case .server(let message):
            return String(localized: "Pixie couldn't delete your account: \(message). Nothing was deleted.")
        }
    }
}

@MainActor
final class AccountDeletionService {
    static let shared = AccountDeletionService()

    private let networkService: NetworkServiceProtocol
    private let keychain: KeychainManagerProtocol
    private let authenticationService: AuthenticationServiceProtocol

    private init(container: AppContainer = .shared) {
        networkService = container.networkService
        keychain = container.keychainManager
        authenticationService = container.authenticationService
    }

    func deleteAccount() async throws {
        guard authenticationService.isAuthenticated else { throw AccountDeletionError.notSignedIn }
        guard NetworkMonitor.shared.isConnected else { throw AccountDeletionError.offline }

        do {
            try await networkService.delete("/v1/identity")
        } catch let error as NetworkError {
            if case .unauthorized = error {
                AppLogger.warning("Account deletion: key already invalid, wiping locally", category: .auth)
            } else {
                throw AccountDeletionError.server(error.localizedDescription)
            }
        } catch {
            throw AccountDeletionError.server(error.localizedDescription)
        }

        await wipeLocalState()
        AppLogger.info("Account deleted", category: .auth)
    }

    /// Returns the device to a first-launch state: no keys, no identity, no cached or shared
    /// images, no stored preferences, so the next launch bootstraps a brand-new account.
    private func wipeLocalState() async {
        for key in [KeychainKeys.authToken, KeychainKeys.refreshToken, KeychainKeys.userProfile, KeychainKeys.deviceCode, KeychainKeys.apiKey, KeychainKeys.authProvider] {
            try? keychain.delete(forKey: key)
        }
        ConfigurationManager.shared.apiKey = nil
        AppContainer.shared.updateNetworkServiceAPIKey()
        await AICreditsService.shared.signOut()
        try? await authenticationService.logout()
        _ = try? await Purchases.shared.logOut()

        await CacheManager.shared.clearCache()
        CacheManager.shared.clearImageCache()
        GalleryCache.shared.clearCache()
        removeSharedContainerFiles()

        if let domain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: domain)
        }
        UserDefaults.standard.synchronize()
    }

    private func removeSharedContainerFiles() {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: GenerationActivityFiles.appGroup),
              let entries = try? FileManager.default.contentsOfDirectory(at: container, includingPropertiesForKeys: nil) else { return }
        for entry in entries where entry.lastPathComponent != "Library" {
            try? FileManager.default.removeItem(at: entry)
        }
    }
}
