import StoreKit
import UIKit

/// Asks for an App Store rating early in real use, and again later if the first ask never turned
/// into anything, without spending more of Apple's three-per-year budget than it has to.
///
/// A generation that actually returned images is the app's core success. The eligibility check
/// itself is a pure function of the recorded state so it can be tested without StoreKit or a
/// live scene.
@MainActor
enum ReviewPrompt {

    private enum Keys {
        static let successCount = "pixie.review.successfulGenerations"
        static let askDates = "pixie.review.askDates"
        static let successCountAtLastAsk = "pixie.review.successCountAtLastAsk"
        static let legacyPromptedVersion = "pixie.review.promptedVersion"
    }

    private static let firstAskThreshold = 2
    private static let minDaysBetweenAsks = 14
    private static let minNewSuccessesBetweenAsks = 3
    private static let maxAsksPerRollingYear = 3
    private static let rollingYear: TimeInterval = 365 * 24 * 60 * 60
    private static let askDelay: Duration = .milliseconds(1500)

    static var successfulGenerationCount: Int {
        UserDefaults.standard.integer(forKey: Keys.successCount)
    }

    /// Call when a generation returns at least one image.
    static func recordSuccess() {
        migrateLegacyStateIfNeeded()

        let defaults = UserDefaults.standard
        let successCount = defaults.integer(forKey: Keys.successCount) + 1
        defaults.set(successCount, forKey: Keys.successCount)

        let now = Date()
        let askDates = storedAskDates(defaults)
        guard isEligible(
            successCount: successCount,
            askDates: askDates,
            successCountAtLastAsk: defaults.integer(forKey: Keys.successCountAtLastAsk),
            now: now
        ) else {
            AppLogger.info("Review prompt skipped: not eligible at success #\(successCount)", category: .review)
            return
        }

        guard canPresentNow else {
            AppLogger.info("Review prompt skipped: no eligible scene at success #\(successCount)", category: .review)
            return
        }

        let askNumber = askDates.count + 1
        recordAsk(at: now, successCount: successCount, defaults: defaults)
        AppLogger.info("Review prompt asked (#\(askNumber))", category: .review)

        Task {
            try? await Task.sleep(for: askDelay)
            guard canPresentNow, let scene = activeForegroundScene else {
                AppLogger.info("Review prompt canceled (#\(askNumber)): scene no longer eligible", category: .review)
                return
            }
            AppStore.requestReview(in: scene)
        }
    }

    /// A pure function of the recorded state: whether an ask is due right now.
    static func isEligible(successCount: Int, askDates: [Date], successCountAtLastAsk: Int, now: Date) -> Bool {
        let recentAskCount = askDates.filter { now.timeIntervalSince($0) < rollingYear }.count
        guard recentAskCount < maxAsksPerRollingYear else { return false }

        guard let lastAskDate = askDates.max() else {
            return successCount >= firstAskThreshold
        }

        let daysSinceLastAsk = now.timeIntervalSince(lastAskDate) / (24 * 60 * 60)
        let newSuccessesSinceLastAsk = successCount - successCountAtLastAsk
        return daysSinceLastAsk >= Double(minDaysBetweenAsks)
            && newSuccessesSinceLastAsk >= minNewSuccessesBetweenAsks
    }

    private static var canPresentNow: Bool {
        guard let scene = activeForegroundScene,
              let window = scene.windows.first(where: \.isKeyWindow)
        else { return false }
        return window.rootViewController?.presentedViewController == nil
    }

    private static var activeForegroundScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
    }

    private static func storedAskDates(_ defaults: UserDefaults) -> [Date] {
        (defaults.array(forKey: Keys.askDates) as? [Double] ?? []).map(Date.init(timeIntervalSince1970:))
    }

    private static func recordAsk(at date: Date, successCount: Int, defaults: UserDefaults) {
        let dates = storedAskDates(defaults).map(\.timeIntervalSince1970) + [date.timeIntervalSince1970]
        defaults.set(dates, forKey: Keys.askDates)
        defaults.set(successCount, forKey: Keys.successCountAtLastAsk)
    }

    /// The previous mechanism only ever asked once (gated by app version, not by date), so it
    /// left no timestamp behind. Migration treats "a prompt was shown at some point" as an ask
    /// that happened just now, which is the conservative reading: it starts the 14-day cooldown
    /// and spends one of the three yearly asks from today rather than guessing a stale date.
    private static func migrateLegacyStateIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: Keys.legacyPromptedVersion) != nil else { return }
        defer { defaults.removeObject(forKey: Keys.legacyPromptedVersion) }
        guard defaults.array(forKey: Keys.askDates) == nil else { return }

        let successCount = defaults.integer(forKey: Keys.successCount)
        defaults.set([Date().timeIntervalSince1970], forKey: Keys.askDates)
        defaults.set(successCount, forKey: Keys.successCountAtLastAsk)
        AppLogger.info("Migrated legacy review-prompt state to the dated ask history", category: .review)
    }
}
