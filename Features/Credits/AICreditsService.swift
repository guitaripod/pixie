import Foundation
import AICreditsCore

final class AICreditsService {
    static let shared = AICreditsService()

    let client: AICreditsClient

    private init() {
        let config = AICreditsConfig(
            baseURL: PixieMidgar.intelligenceURL,
            appID: PixieMidgar.creditsAppID,
            additionalHeaders: { await PixieMidgar.shared.midgarTokenHeaders() }
        )
        client = AICreditsClient(config: config, purchaseProvider: HostManagedPurchaseProvider())
    }

    @discardableResult
    func bootstrap() async throws -> Identity {
        try await client.bootstrap()
    }

    @discardableResult
    func link(appleIdentityToken: String) async throws -> Identity {
        _ = try await client.bootstrap()
        return try await client.link(appleIdentityToken: appleIdentityToken)
    }

    /// The api key of the account the app uses today, which MidgarCredits sends as its legacy key so mako links the
    /// balance from before the move to the Midgar ID's wallet. It is the key every mako call already carries: the one
    /// in the keychain after a sign-in, which for an anonymous or Apple-linked account is the AICredits identity's
    /// own. A device that has none yet gets its account registered here, the same one the first launch would register.
    /// Nil when that fails.
    func legacyAPIKey() async -> String? {
        if let key = ConfigurationManager.shared.apiKey, !key.isEmpty {
            return key
        }
        return try? await client.bootstrap().apiKey
    }

    func signOut() async {
        await client.signOut()
    }
}

private struct HostManagedPurchaseProvider: PurchaseProvider {
    func configure(appUserID: String) async {}
    func availablePackages() async throws -> [StorePackage] { [] }
    func purchase(packageID: String) async throws -> PurchaseReceipt {
        throw AICreditsError.purchaseFailed("Purchases are handled by the host app.")
    }
    func restore() async throws -> [RestoredEntitlement] { [] }
    func alias(to newAppUserID: String) async {}
}
