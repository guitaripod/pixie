import Foundation
import MidgarCommerce
import MidgarCore
import MidgarCredits
import MidgarPortal

/// The composition root of everything PixiePocket shares with the other Midgar apps: the Midgar ID, the gateway
/// client built on it, the anonymous signals client, the purchase store, the credit wallet on it and the gateway
/// address of mako. One instance lives for the whole process, so there is one identity and one ledger cache.
nonisolated final class PixieMidgar: Sendable {
    /// The registry slug: the `X-App-ID` of every gateway call, which mako resolves to its `pixie` tenant.
    static let appID = "pixiepocket"

    /// The tenant id AICredits sends as `X-App-ID` and names its keychain item with (`aicredits.pixie`). Changing it
    /// would orphan every anonymous account already on a device, so the credits client keeps the id it was born with;
    /// the gateway and mako accept both spellings of the tenant.
    static let creditsAppID = "pixie"

    /// The bundle id the registry holds for the App Store record.
    static let bundleID = "com.guitaripod.Pixie"

    /// The log file name, kept from the retired per-app logger so the `ios-device-logs` workflow still finds it.
    static let logFileName = "pixie.log"

    /// mako behind the gateway: `/v1/intelligence/` is stripped and the rest reaches mako's own routes, so
    /// `<this>/v1/credits/balance` is mako's `/v1/credits/balance`.
    static let intelligenceURL = MidgarHTTPConfiguration.defaultBaseURL.appendingPathComponent("v1/intelligence")

    /// The longest a call waits for the Midgar ID's access token before it goes without.
    static let tokenWait: Duration = .seconds(2)

    static let shared = PixieMidgar()

    /// The Midgar ID client. Minted on first launch, attached on every later one, shared through the keychain group.
    let identity: MidgarIdentity

    /// The gateway client that carries the Midgar ID's bearer token, for the ledger and the portal's "Your Midgar".
    let account: MidgarHTTPClient

    /// The purchase engine for the credit packs: StoreKit 2 with the Midgar ID as `appAccountToken`. Nil in a test host
    /// or a demo capture, which must not reach the ledger.
    let store: MidgarStore?

    /// The wallet behind the credit packs: the balance, the purchase and the credit on the Midgar ID, with the api key
    /// of the old per-app account as the legacy key so the balance from before the move stays linked. Nil where
    /// `store` is.
    let credits: MidgarCredits?

    private init() {
        let configuration = MidgarHTTPConfiguration(appID: Self.appID)
        let identity = MidgarIdentity(httpConfiguration: configuration, bundleID: Self.bundleID)
        let account = MidgarHTTPClient(configuration: identity.authorizing(configuration))
        self.identity = identity
        self.account = account
        let commerce = Self.makeCommerce(identity: identity, account: account, configuration: configuration)
        store = commerce?.store
        credits = commerce?.credits
    }

    /// Builds the store and the wallet on it, or nothing where the app reaches no Midgar service. The wallet takes the
    /// plain configuration, because it authorizes its own requests: the legacy key and the Midgar token travel in
    /// different headers. Creating the store starts its foreground refresh and its transaction listener, so create it
    /// once.
    private static func makeCommerce(
        identity: MidgarIdentity,
        account: MidgarHTTPClient,
        configuration: MidgarHTTPConfiguration
    ) -> (store: MidgarStore, credits: MidgarCredits)? {
        guard reachesMidgarServices else { return nil }
        let store = MidgarStore(configuration: PixiePacks.storeConfiguration(), identity: identity, http: account)
        let credits = MidgarCredits(
            configuration: PixiePacks.creditsConfiguration(),
            http: configuration,
            identity: identity,
            purchasing: store,
            legacyAPIKey: { await AICreditsService.shared.legacyAPIKey() }
        )
        return (store, credits)
    }

    /// The `X-Midgar-Token` header for a call to mako, which is how mako links the legacy api key to the Midgar ID,
    /// or nothing when the identity cannot answer within `tokenWait` or the host reaches no Midgar service. A call
    /// never waits on or fails for the token.
    func midgarTokenHeaders() async -> [String: String] {
        guard Self.reachesMidgarServices else { return [:] }
        return await identity.midgarTokenHeader(within: Self.tokenWait).map { [$0.name: $0.value] } ?? [:]
    }

    /// The portal configuration of Settings: the authorized client, so "Your Midgar" shows what the person owns in
    /// the other apps and a cross-sell skips an app they already use.
    var portalConfig: MidgarPortal.MidgarConfig {
        MidgarPortal.MidgarConfig(placement: "settings", account: Self.reachesMidgarServices ? account : nil)
    }

    /// Opens the log file. Call first thing at launch so nothing before the rest of the setup is lost.
    static func configureLogging() {
        MidgarLog.configure(fileName: logFileName)
    }

    /// Configures anonymous signals for the portal and starts the Midgar ID in the background, so the app holds one
    /// before mako is first asked to link it. Call once at launch. A test host or a demo capture talks to no Midgar
    /// service.
    func start() {
        guard Self.reachesMidgarServices else {
            MidgarLog.info("Midgar services not started: test host or demo world", category: .account)
            return
        }
        MidgarSignals.configure(configuration: MidgarHTTPConfiguration(appID: Self.appID))
        let identity = identity
        let store = store
        Task {
            do {
                _ = try await identity.midgarId
                MidgarLog.info("Midgar ID ready", category: .account)
            } catch {
                MidgarLog.info("Midgar ID not available yet: \(error)", category: .account)
            }
            await Self.logLedgerEntitlements(of: store)
        }
    }

    /// Removes the log files, for the account deletion that starts the app over.
    static func eraseLogFiles() {
        MidgarLog.flush()
        for url in MidgarLog.logFileURLs {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Writes the entitlement names the ledger holds for this Midgar ID, so a support log shows whether the ledger
    /// knows the person. Names only, never ids or receipts.
    private static func logLedgerEntitlements(of store: MidgarStore?) async {
        guard let store else { return }
        await store.refresh()
        let names = await store.entitlements.map(\.name).sorted().joined(separator: ", ")
        MidgarLog.info("Ledger entitlements: \(names.isEmpty ? "none" : names)", category: .commerce)
    }

    /// False inside an XCTest or Swift Testing host and in a DEBUG demo capture, which must not mint identities or
    /// send signals to the production services.
    static var reachesMidgarServices: Bool {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil { return false }
        #if DEBUG
        if DemoMode.isActive { return false }
        #endif
        return true
    }
}
