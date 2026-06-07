import Foundation
import AICreditsCore

final class AICreditsService {
    static let shared = AICreditsService()

    let client: AICreditsClient

    private init() {
        let base = URL(string: ConfigurationManager.shared.baseURL)
            ?? URL(string: "https://openai-image-proxy.guitaripod.workers.dev")!
        let config = AICreditsConfig(baseURL: base, appID: "pixie")
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
