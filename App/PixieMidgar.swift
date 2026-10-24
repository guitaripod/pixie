import Foundation
import MidgarCommerce
import MidgarCore
import MidgarPortal

/// The composition root of everything PixiePocket shares with the other Midgar apps: the Midgar ID, the gateway
/// client built on it, the anonymous signals client, the read-only purchase store and the gateway address of mako.
/// One instance lives for the whole process, so there is one identity and one ledger cache.
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

    /// The read-only ledger store, or nil in a test host or a demo capture.
    let ledger: MidgarStore?

    private init() {
        let configuration = MidgarHTTPConfiguration(appID: Self.appID)
        let identity = MidgarIdentity(httpConfiguration: configuration, bundleID: Self.bundleID)
        let account = MidgarHTTPClient(configuration: identity.authorizing(configuration))
        self.identity = identity
        self.account = account
        ledger = Self.reachesMidgarServices ? Self.makeStore(identity: identity, account: account) : nil
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
        let ledger = ledger
        Task {
            do {
                _ = try await identity.midgarId
                MidgarLog.info("Midgar ID ready", category: .account)
            } catch {
                MidgarLog.info("Midgar ID not available yet: \(error)", category: .account)
            }
            await Self.logLedgerEntitlements(of: ledger)
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
    private static func logLedgerEntitlements(of ledger: MidgarStore?) async {
        guard let ledger else { return }
        await ledger.refresh()
        let names = await ledger.entitlements.map(\.name).sorted().joined(separator: ", ")
        MidgarLog.info("Ledger entitlements: \(names.isEmpty ? "none" : names)", category: .commerce)
    }

    /// The ledger reader. RevenueCat keeps buying, restoring and finishing every purchase (registry engine
    /// `rc-full`), so the store runs in `Mode.readOnly`: it asks the ledger what the Midgar ID owns and touches no
    /// transaction. Creating the store starts its foreground refresh, so create it once.
    private static func makeStore(identity: MidgarIdentity, account: MidgarHTTPClient) -> MidgarStore {
        MidgarStore(configuration: storeConfiguration, identity: identity, http: account)
    }

    /// The credit packs are consumables, which the ledger never turns into an entitlement, so no product maps to one.
    static var storeConfiguration: MidgarStoreConfiguration {
        MidgarStoreConfiguration(
            appID: appID,
            productIDs: creditPackProductIDs,
            entitlementsByProduct: [:],
            mode: .readOnly
        )
    }

    /// The five credit packs mako sells, named as its `apps.rc_product_prefix` and `credit_packs.pack_id` build them.
    static var creditPackProductIDs: [String] {
        ["starter", "basic", "popular", "business", "enterprise"].map { "com.guitaripod.pixie.credits.\($0)" }
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
