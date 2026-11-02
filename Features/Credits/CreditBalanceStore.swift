import Foundation
import Combine
import MidgarCommerce
import MidgarCore
import MidgarCredits
import PixiepocketCore
import UIKit

/// The one place the user's balance lives, so the home pill, the store, the Credits tab and the
/// purchase flow all show the same number and move together. It is fed from the Midgar wallet:
/// every refresh reads the balance there (which also settles a paid purchase mako has not credited
/// yet), then mako's balance for what pays for edits (Plus, the Pixie Week, the tiers), and the
/// wallet's and the store's events move it when a credit or a subscription lands later.
///
/// Without a wallet (a test host) it reads nothing and the balance stays unknown.
@MainActor
final class CreditBalanceStore: ObservableObject {
    static let shared = CreditBalanceStore()

    @Published private(set) var balance: CreditBalance?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var updatedAt: Date?

    private static let currency = "credits"
    private static let retryDelays: [TimeInterval] = [1, 2, 4, 8, 16, 30]
    private static let foregroundRefreshInterval: TimeInterval = 3

    private let credits: MidgarCredits?
    private let store: MidgarStore?
    private let apiService: APIServiceProtocol
    private var inFlight: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?
    private var failureCount = 0
    private var revision = 0
    private var accountId: String?
    private var cancellables = Set<AnyCancellable>()

    init(
        credits: MidgarCredits? = PixieMidgar.shared.credits,
        store: MidgarStore? = PixieMidgar.shared.store,
        apiService: APIServiceProtocol = APIService.shared
    ) {
        self.credits = credits
        self.store = store
        self.apiService = apiService
        observeLifecycle()
        followWallet()
        followStore()
    }

    /// Fetches the balance from the server. Calls made while a fetch is running share it, and a
    /// failed fetch is retried with a growing delay so a launch that races sign-in still lands.
    func refresh() async {
        if let inFlight {
            await inFlight.value
            return
        }
        let task = Task { await fetch() }
        inFlight = task
        await task.value
        inFlight = nil
    }

    /// Shows a balance the server just reported, such as the one in a purchase confirmation,
    /// and discards any older fetch still on its way.
    func apply(newBalance: Int) {
        revision += 1
        publish(CreditBalance(balance: newBalance, currency: balance?.currency ?? Self.currency, edits: balance?.edits))
    }

    /// Forgets the balance when the account goes away so the next one never briefly shows it.
    func reset() {
        revision += 1
        retryTask?.cancel()
        retryTask = nil
        failureCount = 0
        balance = nil
        updatedAt = nil
        errorMessage = nil
    }

    private func fetch() async {
        isLoading = true
        defer { isLoading = false }

        #if DEBUG
        if let demo = Self.debugBalance {
            publish(CreditBalance(balance: demo, currency: Self.currency))
            return
        }
        #endif

        guard let credits else { return }
        let startedAt = revision
        do {
            let read = try await credits.refresh()
            let summary = await editsSummary()
            guard startedAt == revision else { return }
            publish(CreditBalance(balance: read.credits, currency: Self.currency, edits: summary ?? balance?.edits))
        } catch {
            guard startedAt == revision else { return }
            errorMessage = error.localizedDescription
            MidgarLog.notice("Balance refresh failed: \(error.localizedDescription)", category: .general)
            scheduleRetry()
        }
    }

    /// What pays for edits, from mako's balance; nil when it cannot be read, so the last summary stays.
    private func editsSummary() async -> EditsSummary? {
        do {
            return try await apiService.getCreditBalance().edits
        } catch {
            MidgarLog.notice("Edits summary unavailable: \(error.localizedDescription)", category: .credits)
            return nil
        }
    }

    private func publish(_ fetched: CreditBalance) {
        balance = fetched
        updatedAt = Date()
        errorMessage = nil
        failureCount = 0
        retryTask?.cancel()
        retryTask = nil
    }

    /// Tries again after a pause that doubles each time, giving up once the delays run out.
    private func scheduleRetry() {
        guard retryTask == nil, failureCount < Self.retryDelays.count else { return }
        let delay = Self.retryDelays[failureCount]
        failureCount += 1
        retryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            self.retryTask = nil
            await self.refresh()
        }
    }

    /// Follows what the wallet reports until its stream ends: a balance that changed is shown, and a credited
    /// purchase leaves the welcome state for good, also when the credit arrived after the store closed.
    private func followWallet() {
        guard let credits else { return }
        Task { [weak self] in
            for await event in await credits.events() {
                guard let self else { return }
                await self.handle(event)
            }
        }
    }

    func handle(_ event: MidgarCreditsEvent) async {
        switch event {
        case .balanceChanged(let changed):
            apply(newBalance: changed.credits)
        case .purchaseCredited:
            if let known = await credits?.balance {
                apply(newBalance: known.credits)
            }
        }
    }

    /// A Plus purchase, renewal or lapse changes what pays for edits, so mako is asked again.
    private func followStore() {
        guard let store else { return }
        Task { [weak self] in
            for await event in await store.events() {
                guard let self, event == .entitlementsChanged || Self.isPlus(event) else { continue }
                await self.refresh()
            }
        }
    }

    private nonisolated static func isPlus(_ event: MidgarStoreEvent) -> Bool {
        if case .purchaseApproved(let productID) = event { return productID == PixiePacks.plusProductID }
        return false
    }

    private func observeLifecycle() {
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in self?.refreshIfStale() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .userDidAuthenticate)
            .sink { [weak self] note in self?.accountSignedIn(note.object as? User) }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .userDidLogout)
            .sink { [weak self] _ in
                self?.accountId = nil
                self?.reset()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .networkStatusChanged)
            .sink { [weak self] note in
                guard note.userInfo?["isConnected"] as? Bool == true else { return }
                self?.refreshAfterReconnect()
            }
            .store(in: &cancellables)
    }

    /// A different account must not inherit the previous one's number while its own loads.
    private func accountSignedIn(_ user: User?) {
        if let user, user.id != accountId {
            if accountId != nil { reset() }
            accountId = user.id
        }
        Task { await refresh() }
    }

    private func refreshIfStale() {
        guard hasCredentials else { return }
        if let updatedAt, Date().timeIntervalSince(updatedAt) < Self.foregroundRefreshInterval { return }
        Task { await refresh() }
    }

    private func refreshAfterReconnect() {
        guard hasCredentials, errorMessage != nil || balance == nil else { return }
        failureCount = 0
        Task { await refresh() }
    }

    private var hasCredentials: Bool {
        ConfigurationManager.shared.apiKey?.isEmpty == false
    }

    #if DEBUG
    private static var debugBalance: Int? {
        if DemoMode.isActive { return DemoContent.balance }
        return ProcessInfo.processInfo.environment["PX_FAKE_BALANCE"].flatMap(Int.init)
    }
    #endif
}
