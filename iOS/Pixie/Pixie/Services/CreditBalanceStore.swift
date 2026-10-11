import Foundation
import Combine
import UIKit

/// The one place the user's credit balance lives, so the home pill, the store, the Credits tab
/// and the purchase flow all show the same number and move together.
@MainActor
final class CreditBalanceStore: ObservableObject {
    static let shared = CreditBalanceStore()

    @Published private(set) var balance: CreditBalance?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var updatedAt: Date?

    private static let retryDelays: [TimeInterval] = [1, 2, 4, 8, 16, 30]
    private static let foregroundRefreshInterval: TimeInterval = 3

    private let apiService: APIServiceProtocol
    private var inFlight: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?
    private var failureCount = 0
    private var revision = 0
    private var accountId: String?
    private var cancellables = Set<AnyCancellable>()

    init(apiService: APIServiceProtocol = APIService.shared) {
        self.apiService = apiService
        observeLifecycle()
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
        publish(CreditBalance(balance: newBalance, currency: balance?.currency ?? "credits"))
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
            publish(CreditBalance(balance: demo, currency: "credits"))
            return
        }
        #endif

        let startedAt = revision
        do {
            let fetched = try await apiService.getCreditBalance()
            guard startedAt == revision else { return }
            publish(fetched)
        } catch {
            guard startedAt == revision else { return }
            errorMessage = error.localizedDescription
            AppLogger.warning("Balance refresh failed: \(error.localizedDescription)", category: .general)
            scheduleRetry()
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
