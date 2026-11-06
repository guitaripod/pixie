import Combine
import Foundation
import MidgarCommerce
import MidgarCore
import MidgarCredits
import PixiepocketCore
import StoreKit
import StoreKitTest
import Testing
import UIKit
@testable import Pixie

/// Buys Pixie's credit packs through MidgarCredits on a MidgarStore with the app's own configuration, against
/// `Products.storekit` (the file the scheme runs with), so the pack table, the StoreKit products and mako's validate
/// request are checked together on a real StoreKit. The gateway is a `URLProtocol` stub, so nothing reaches mako. StoreKit
/// is process-wide, so the suite runs serially. A test session signs its transactions with Xcode's local certificate, so
/// the store never reports them to the ledger. The first purchase on a fresh simulator can stall: rerun once. The
/// account deletion tests live here too, because they share the process-wide gateway stub and a suite that resets it
/// must not run beside another.
@MainActor
@Suite(.serialized, .timeLimit(.minutes(3)))
struct CreditsPurchaseStoreKitTests {
    private nonisolated static let legacyKey = "legacy-aicredits-key"
    private static let starterProductID = "com.guitaripod.pixie.credits.starter"

    private struct Harness {
        let store: MidgarStore
        let credits: MidgarCredits
        let balanceStore: CreditBalanceStore
        let manager: CreditPurchaseManager
        let session: SKTestSession
        let directory: URL
        let failures: FailureCounter

        func stop() async {
            await credits.stop()
            await store.stop()
            try? FileManager.default.removeItem(at: directory)
        }
    }

    @MainActor
    private final class FailureCounter {
        private(set) var count = 0

        func note() {
            count += 1
        }
    }

    private static let configurationURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Products.storekit")

    private func makeHarness(purchasing override: (any MidgarCreditsPurchasing)? = nil) throws -> Harness {
        let session = try SKTestSession(contentsOf: Self.configurationURL)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        session.askToBuyEnabled = false
        GatewayStub.reset()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pixie-credits-" + UUID().uuidString, isDirectory: true)
        let configuration = GatewayStub.httpConfiguration()
        let identity = StubIdentity()
        let store = MidgarStore(
            configuration: PixiePacks.storeConfiguration(directory: directory),
            identity: identity,
            http: MidgarHTTPClient(configuration: configuration)
        )
        let credits = MidgarCredits(
            configuration: PixiePacks.creditsConfiguration(directory: directory),
            http: configuration,
            identity: identity,
            purchasing: override ?? SceneAnchoredPurchasing(store: store),
            legacyAPIKey: { Self.legacyKey }
        )
        let balanceStore = CreditBalanceStore(credits: credits, store: nil, apiService: StubPacksAPI())
        let failures = FailureCounter()
        let manager = CreditPurchaseManager(
            credits: credits,
            store: store,
            apiService: StubPacksAPI(),
            balanceStore: balanceStore,
            notePurchaseFailure: { failures.note() }
        )
        return Harness(
            store: store, credits: credits, balanceStore: balanceStore, manager: manager,
            session: session, directory: directory, failures: failures
        )
    }

    @Test func theConfigurationFileSellsExactlyTheFivePacksAtTheirPrices() throws {
        let file = try JSONDecoder().decode(StoreKitFile.self, from: Data(contentsOf: Self.configurationURL))
        let sold = Dictionary(uniqueKeysWithValues: file.products.map { ($0.productID, $0) })

        #expect(Set(sold.keys) == Set(PixiePacks.productIDs))
        #expect(sold.values.allSatisfy { $0.type == "Consumable" })
        for pack in PixiePacks.all {
            let product = sold["com.guitaripod.pixie.credits." + pack.id]
            #expect("$" + (product?.displayPrice ?? "") == pack.listPrice)
            #expect(product?.referenceName == pack.name)
        }
    }

    @Test func theOffersAreTheFivePacksWithStoreKitsPrices() async throws {
        let harness = try makeHarness()

        let offers = try await harness.credits.offers()

        #expect(offers.map(\.pack.id) == ["starter", "basic", "popular", "business", "enterprise"])
        #expect(offers.map(\.product.displayPrice) == ["$2.99", "$9.99", "$24.99", "$49.99", "$99.99"])
        #expect(offers.map(\.product.displayName) == ["10 Edits", "40 Edits", "120 Edits", "Business", "Enterprise"])
        await harness.stop()
    }

    @Test func theStoreListsTheOfferedPacksWithTheirStoreKitPrice() async throws {
        let harness = try makeHarness()
        await harness.manager.fetchCreditPacks()
        await harness.manager.fetchOffers()

        let listed = try #require(await firstValue(of: harness.manager.getCreditPacksWithPricing()))

        #expect(listed.map(\.creditPack.id) == ["starter", "basic", "popular"])
        #expect(listed.map(\.localizedPrice) == ["$2.99", "$9.99", "$24.99"])
        await harness.stop()
    }

    @Test func aPackStoreKitDoesNotReturnIsHidden() async throws {
        let harness = try makeHarness(purchasing: PartialCatalogPurchasing(hiding: "basic"))
        await harness.manager.fetchCreditPacks()
        await harness.manager.fetchOffers()

        let listed = try #require(await firstValue(of: harness.manager.getCreditPacksWithPricing()))

        #expect(listed.map(\.creditPack.id) == ["starter", "popular"])
        await harness.stop()
    }

    @Test func buyingStarterCarriesTheMidgarIDAndPostsMakosValidateRoute() async throws {
        let harness = try makeHarness()
        GatewayStub.setBalance(65)
        await harness.balanceStore.refresh()
        #expect(harness.balanceStore.balance?.balance == 65)
        GatewayStub.setBalance(215)
        GatewayStub.setValidate([.credited(added: 150, newBalance: 215)])

        let outcome = try await harness.manager.purchaseCreditPack(id: "starter")

        #expect(outcome == .credited(credits: 150, newBalance: 215))
        let recorded = try #require(harness.session.allTransactions().first { $0.productIdentifier == Self.starterProductID })
        let posted = GatewayStub.requests(method: "POST", pathSuffix: "/v1/credits/purchase/validate")
        let request = try #require(posted.first)
        #expect(posted.count == 1)
        let body = try request.json()
        #expect(body["pack_id"] == "starter")
        #expect(body["product_id"] == Self.starterProductID)
        #expect(body["purchase_token"] == String(recorded.identifier))
        #expect(body["platform"] == "ios")
        let signed = try SignedTransactionPayload(jws: try #require(body["signed_transaction"]))
        #expect(signed.transactionId == String(recorded.identifier))
        #expect(signed.productId == Self.starterProductID)
        #expect(signed.appAccountToken?.uppercased() == StubIdentity.midgarID)
        #expect(request.header("X-App-ID") == "pixiepocket")
        #expect(request.header("Authorization") == "Bearer " + Self.legacyKey)
        #expect(request.header("X-Midgar-Token") == StubIdentity.accessToken)
        #expect(harness.balanceStore.balance?.balance == 215)
        #expect(await harness.credits.unconfirmedPurchases == 0)
        #expect(harness.failures.count == 0)
        await harness.stop()
    }

    @Test func aCreditPendingAnswerKeepsTheReceiptAndTheBalanceFollowsTheLaterCredit() async throws {
        let harness = try makeHarness()
        GatewayStub.setBalance(65)
        await harness.balanceStore.refresh()
        GatewayStub.setValidate([.error(status: 409, code: "credit_pending", message: "The credit is on its way.")])

        let outcome = try await harness.manager.purchaseCreditPack(id: "starter")

        #expect(outcome == .creditPending(credits: PixiePacks.starter.totalCredits))
        #expect(await harness.credits.unconfirmedPurchases == 1)
        #expect(harness.balanceStore.balance?.balance == 65)
        let validations = GatewayStub.requests(method: "POST", pathSuffix: "/v1/credits/purchase/validate")
        let transactionIDs = try Set(validations.map { try $0.json()["purchase_token"] })
        #expect(validations.count == 4)
        #expect(transactionIDs.count == 1)
        let kept = try Data(contentsOf: harness.directory.appendingPathComponent("credits-pixiepocket.json"))
        #expect(String(decoding: kept, as: UTF8.self).contains(Self.starterProductID))

        GatewayStub.setBalance(215)
        GatewayStub.setValidate([.credited(added: 150, newBalance: 215)])
        await harness.balanceStore.refresh()

        #expect(harness.balanceStore.balance?.balance == 215)
        #expect(await harness.credits.unconfirmedPurchases == 0)
        let retried = GatewayStub.requests(method: "POST", pathSuffix: "/v1/credits/purchase/validate")
        #expect(retried.count == 5)
        #expect(try Set(retried.map { try $0.json()["purchase_token"] }) == transactionIDs)
        await harness.stop()
    }

    @Test func aPurchaseWaitingForApprovalCreditsNothingAndPostsNothing() async throws {
        let harness = try makeHarness(purchasing: ScriptedPurchasing(outcome: .pending))

        let outcome = try await harness.manager.purchaseCreditPack(id: "starter")

        #expect(outcome == .awaitingApproval)
        #expect(GatewayStub.requests(method: "POST", pathSuffix: "/v1/credits/purchase/validate").isEmpty)
        #expect(harness.failures.count == 0)
        await harness.stop()
    }

    @Test func aCancelledPurchaseIsSilentAndPostsNothing() async throws {
        let harness = try makeHarness(purchasing: ScriptedPurchasing(outcome: .cancelled))

        let outcome = try await harness.manager.purchaseCreditPack(id: "starter")

        #expect(outcome == .cancelled)
        #expect(GatewayStub.requests(method: "POST", pathSuffix: "/v1/credits/purchase/validate").isEmpty)
        #expect(await harness.credits.unconfirmedPurchases == 0)
        #expect(harness.failures.count == 0)
        await harness.stop()
    }

    @Test func aStoreKitFailureThrowsASentenceNotesTheFailureAndPostsNothing() async throws {
        let harness = try makeHarness()
        try await harness.session.setSimulatedError(.generic(.unknown), forAPI: .purchase)

        let error = await #expect(throws: MidgarCreditsError.self) {
            _ = try await harness.manager.purchaseCreditPack(id: "starter")
        }

        #expect(error?.errorDescription?.isEmpty == false)
        #expect(harness.failures.count == 1)
        #expect(GatewayStub.requests(method: "POST", pathSuffix: "/v1/credits/purchase/validate").isEmpty)
        #expect(await harness.credits.unconfirmedPurchases == 0)
        #expect(harness.session.allTransactions().isEmpty)
        await harness.stop()
    }

    @Test func anUnknownPackIsRefusedBeforeStoreKitIsAsked() async throws {
        let harness = try makeHarness()

        await #expect(throws: MidgarCreditsError.self) {
            _ = try await harness.manager.purchaseCreditPack(id: "huge")
        }

        #expect(harness.failures.count == 1)
        #expect(GatewayStub.requests(method: "POST", pathSuffix: "/v1/credits/purchase/validate").isEmpty)
        #expect(harness.session.allTransactions().isEmpty)
        await harness.stop()
    }

    @Test func refreshingTheBalanceCreditsAPaidReceiptAnEarlierLaunchLeftQueued() async throws {
        let harness = try makeHarness()
        GatewayStub.setValidate([.error(status: 409, code: "credit_pending", message: "The credit is on its way.")])
        _ = try await harness.manager.purchaseCreditPack(id: "starter")
        await harness.credits.stop()
        await harness.store.stop()

        GatewayStub.setBalance(215)
        GatewayStub.setValidate([.credited(added: 150, newBalance: 215)])
        let relaunched = MidgarCredits(
            configuration: PixiePacks.creditsConfiguration(directory: harness.directory),
            http: GatewayStub.httpConfiguration(),
            identity: StubIdentity(),
            purchasing: ScriptedPurchasing(outcome: .cancelled),
            legacyAPIKey: { Self.legacyKey }
        )
        let balanceStore = CreditBalanceStore(credits: relaunched, store: nil, apiService: StubPacksAPI())
        #expect(await relaunched.unconfirmedPurchases == 1)

        await balanceStore.refresh()

        #expect(balanceStore.balance?.balance == 215)
        #expect(await relaunched.unconfirmedPurchases == 0)
        await relaunched.stop()
        try? FileManager.default.removeItem(at: harness.directory)
    }

    @Test func theBalanceStoreFollowsTheWalletsEventsAndMarksACreditedPurchase() async throws {
        let harness = try makeHarness()
        GatewayStub.setBalance(65)
        await harness.balanceStore.refresh()
        #expect(harness.balanceStore.balance?.balance == 65)

        GatewayStub.setBalance(215)
        GatewayStub.setValidate([.credited(added: 150, newBalance: 215)])
        _ = try await harness.credits.buy("starter")

        #expect(await eventually { harness.balanceStore.balance?.balance == 215 })
        await harness.stop()
    }

    @Test func notEnoughEditsOpensTheStoreWithTheShortfall() throws {
        let store = CreditStoreViewController(shortfall: 12)
        store.loadViewIfNeeded()
        let expected = String(localized: "You need \(EditPrice.label(edits: 12)) more for this.")
        let banner = labels(in: store.view).map { $0.text ?? "" }.first { $0 == expected }
        #expect(banner == expected)
    }

    @Test func deletingTheAccountSendsTheLegacyKeyAloneThroughTheWallet() async throws {
        GatewayStub.reset()
        let credits = makeCredits(legacyKey: "legacy-key")
        let deletion = ServerAccountDeletion(credits: credits, networkService: UnusedNetwork())

        try await deletion.run()

        let deletes = GatewayStub.requests(method: "DELETE", pathSuffix: "/v1/identity")
        let request = try #require(deletes.first)
        #expect(deletes.count == 1)
        #expect(request.header("Authorization") == "Bearer legacy-key")
        #expect(request.header("X-Midgar-Token") == nil)
        #expect(request.header("X-App-ID") == "pixiepocket")
        await credits.stop()
    }

    @Test func aFailedServerDeletionThrowsSoNothingLocalIsErased() async throws {
        GatewayStub.reset()
        GatewayStub.setLegacyDelete(.error(status: 500, code: "internal", message: "Something went wrong."))
        let credits = makeCredits(legacyKey: "legacy-key")
        let deletion = ServerAccountDeletion(credits: credits, networkService: UnusedNetwork())

        await #expect(throws: AccountDeletionError.self) {
            try await deletion.run()
        }

        #expect(GatewayStub.requests(method: "DELETE", pathSuffix: "/v1/identity").count == 1)
        await credits.stop()
    }

    @Test func aRejectedKeyCountsAsDeleted() async throws {
        GatewayStub.reset()
        GatewayStub.setLegacyDelete(.error(status: 401, code: "unauthorized", message: "Invalid key."))
        let credits = makeCredits(legacyKey: "stale-key")

        try await ServerAccountDeletion(credits: credits, networkService: UnusedNetwork()).run()

        await credits.stop()
    }

    private func makeCredits(legacyKey: String) -> MidgarCredits {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pixie-credits-" + UUID().uuidString, isDirectory: true)
        return MidgarCredits(
            configuration: PixiePacks.creditsConfiguration(directory: directory),
            http: GatewayStub.httpConfiguration(),
            identity: StubIdentity(),
            purchasing: ScriptedPurchasing(outcome: .cancelled),
            legacyAPIKey: { legacyKey }
        )
    }

    private func labels(in view: UIView) -> [UILabel] {
        (view as? UILabel).map { [$0] } ?? view.subviews.flatMap { labels(in: $0) }
    }

    private func firstValue<T: Sendable>(of publisher: some Publisher<T, Never>) async -> T? {
        for await value in publisher.values {
            return value
        }
        return nil
    }

    private func eventually(timeout: Duration = .seconds(10), _ condition: () async -> Bool) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
            if await condition() { return true }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return await condition()
    }
}

/// The store with every purchase confirmed in the host app's window scene, as StoreKit needs inside a test host: a
/// scene-less purchase there never completes, because StoreKit finds no window to confirm in. Everything else is the
/// store itself, and MidgarCredits sells through this exactly as it sells through the store.
private nonisolated struct SceneAnchoredPurchasing: MidgarCreditsPurchasing {
    let store: MidgarStore

    func products() async throws -> [StoreProduct] {
        try await store.products()
    }

    func purchaseReceipt(_ productID: String) async throws -> MidgarReceiptResult {
        try await purchase(productID, in: store)
    }

    func events() async -> AsyncStream<MidgarStoreEvent> {
        await store.events()
    }

    @MainActor
    private func purchase(_ productID: String, in store: MidgarStore) async throws -> MidgarReceiptResult {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
            throw MidgarStoreError.unsupportedPlatform
        }
        return try await store.purchaseReceipt(productID, confirmIn: scene)
    }
}

/// A store whose purchase sheet ends the way the test scripts it: StoreKitTest cannot script a dismissed sheet or an Ask
/// to Buy hand-off on a real StoreKit (a simulated `userCancelled` error surfaces as a StoreKit failure), so the store
/// answers `.cancelled` or `.pending` itself, which is what MidgarStore returns for the real results. Nothing is bought.
private nonisolated struct ScriptedPurchasing: MidgarCreditsPurchasing {
    let outcome: MidgarReceiptResult

    func products() async throws -> [StoreProduct] { [] }

    func purchaseReceipt(_ productID: String) async throws -> MidgarReceiptResult { outcome }

    func events() async -> AsyncStream<MidgarStoreEvent> { AsyncStream { _ in } }
}

/// A store that lists every pack but one, as a storefront in which an App Store product is not approved yet.
private nonisolated struct PartialCatalogPurchasing: MidgarCreditsPurchasing {
    let hiding: String

    func products() async throws -> [StoreProduct] {
        PixiePacks.all.filter { $0.id != hiding }.map {
            StoreProduct(id: $0.productID, displayName: $0.name, description: "", displayPrice: $0.listPrice)
        }
    }

    func purchaseReceipt(_ productID: String) async throws -> MidgarReceiptResult { .cancelled }

    func events() async -> AsyncStream<MidgarStoreEvent> { AsyncStream { _ in } }
}

/// mako's pack list as the store screen reads it: the five packs with their prices in cents.
private struct StubPacksAPI: APIServiceProtocol {
    func getCreditPacks() async throws -> CreditPacksResponse {
        CreditPacksResponse(packs: PixiePacks.all.map {
            CreditPack(
                id: $0.id, name: $0.name, credits: $0.baseCredits,
                priceUsdCents: Int($0.listPrice.dropFirst().replacingOccurrences(of: ".", with: "")) ?? 0,
                bonusCredits: $0.bonusCredits, description: ""
            )
        })
    }

    func generateImages(_ request: ImageGenerationRequest) async throws -> ImageResponse { throw Unused() }
    func editImage(_ request: ImageEditRequest) async throws -> ImageResponse { throw Unused() }
    func listImages(page: Int, perPage: Int) async throws -> GalleryResponse { throw Unused() }
    func listUserImages(userId: String, page: Int, perPage: Int) async throws -> UserGalleryResponse { throw Unused() }
    func getImage(id: String) async throws -> ImageMetadata { throw Unused() }
    func getUsage(userId: String, start: String?, end: String?) async throws -> UsageResponse { throw Unused() }
    func getUsageDetails(userId: String, start: String?, end: String?) async throws -> UsageDetailsResponse { throw Unused() }
    func getCreditBalance() async throws -> CreditBalance { throw Unused() }
    func getCreditTransactions(limit: Int, page: Int) async throws -> CreditTransactionsResponse { throw Unused() }
    func estimateCreditCost(_ request: CreditEstimateRequest) async throws -> CreditEstimateResponse { throw Unused() }
    func checkDeviceAuthStatus(deviceCode: String) async throws -> DeviceAuthStatus { throw Unused() }
    func downloadImage(from url: String) async throws -> Data { throw Unused() }
    func authenticateGitHub(_ request: OAuthCallbackRequest) async throws -> AuthResponse { throw Unused() }
    func authenticateGoogle(_ request: OAuthCallbackRequest) async throws -> AuthResponse { throw Unused() }
    func authenticateGoogleToken(_ request: GoogleTokenRequest) async throws -> AuthResponse { throw Unused() }
    func authenticateApple(_ request: OAuthCallbackRequest) async throws -> AuthResponse { throw Unused() }
    func authenticateAppleToken(_ request: AppleTokenRequest) async throws -> AuthResponse { throw Unused() }
    func deleteImage(id: String) async throws { throw Unused() }

    struct Unused: Error {}
}

/// A network service that must not be reached: the wallet deletes the account in these tests.
private struct UnusedNetwork: NetworkServiceProtocol {
    struct Reached: Error {}

    func get<T: Decodable>(_ endpoint: String, type: T.Type) async throws -> T { throw Reached() }
    func post<T: Decodable, U: Encodable>(_ endpoint: String, body: U, type: T.Type) async throws -> T { throw Reached() }
    func put<T: Decodable, U: Encodable>(_ endpoint: String, body: U, type: T.Type) async throws -> T { throw Reached() }
    func delete(_ endpoint: String) async throws { throw Reached() }
    func downloadData(from url: URL) async throws -> Data { throw Reached() }
}

/// The claims of a signed transaction the validate request carries, read from the JWS payload.
private nonisolated struct SignedTransactionPayload: Decodable {
    let transactionId: String
    let productId: String
    let appAccountToken: String?

    init(jws: String) throws {
        let parts = jws.split(separator: ".")
        guard parts.count == 3 else {
            throw URLError(.cannotParseResponse)
        }
        var base64 = parts[1].replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64) else {
            throw URLError(.cannotDecodeContentData)
        }
        self = try JSONDecoder().decode(SignedTransactionPayload.self, from: data)
    }

    private enum CodingKeys: String, CodingKey {
        case transactionId
        case productId
        case appAccountToken
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        transactionId = try container.decode(String.self, forKey: .transactionId)
        productId = try container.decode(String.self, forKey: .productId)
        appAccountToken = try container.decodeIfPresent(String.self, forKey: .appAccountToken)
    }
}

/// The parts of a StoreKit configuration file the product check reads.
private nonisolated struct StoreKitFile: Decodable {
    struct Item: Decodable {
        let productID: String
        let displayPrice: String
        let referenceName: String
        let type: String
    }

    let products: [Item]
}
