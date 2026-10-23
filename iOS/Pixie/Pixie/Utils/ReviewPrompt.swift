import MidgarCommerce
import MidgarCore
import StoreKit
import UIKit

/// Asks for an App Store rating after the user has gotten value from the app. A generation that returned images is
/// this app's core success. `MidgarReviewPolicy` decides whether the ask is due; this type only reports the success
/// and, when the policy says yes, shows Apple's prompt if nothing else is on screen.
///
/// The prompt never fires on a launch, a tap or a preview, never before the second image, and never while a sheet is
/// already presented.
@MainActor
enum ReviewPrompt {
    private nonisolated static let successCountKey = "pixie.review.successfulGenerations"
    private static let askDelay: Duration = .milliseconds(1500)

    /// The success count at which the rating prompt may first fire.
    nonisolated static let firstAskThreshold = 2

    nonisolated static var successfulGenerationCount: Int {
        UserDefaults.standard.integer(forKey: successCountKey)
    }

    nonisolated static let policy: MidgarReviewPolicy = {
        let storage = MidgarReviewFileStorage(appID: PixieMidgar.appID)
        LegacyReviewState.migrate(from: .standard, into: storage)
        return MidgarReviewPolicy(storage: storage)
    }()

    /// Counts one session. Call it once per launch.
    static func beginSession() {
        policy.beginSession()
    }

    /// Reports a purchase that failed, which holds the prompt back for a week.
    nonisolated static func notePurchaseFailure() {
        policy.notePurchaseFailure()
    }

    /// Call when a generation returns at least one image.
    static func recordSuccess() {
        let successCount = successfulGenerationCount + 1
        UserDefaults.standard.set(successCount, forKey: successCountKey)

        let due = policy.noteSuccess()
        guard due, successCount >= firstAskThreshold else {
            MidgarLog.info("Review prompt skipped | due: \(due), successCount: \(successCount)", category: .review)
            return
        }
        guard canPresentNow else {
            MidgarLog.info("Review prompt skipped | reason: no eligible scene, successCount: \(successCount)", category: .review)
            return
        }
        Task {
            try? await Task.sleep(for: askDelay)
            requestReviewIfStillSafe(successCount: successCount)
        }
    }

    private static func requestReviewIfStillSafe(successCount: Int) {
        guard canPresentNow, let scene = activeForegroundScene else {
            MidgarLog.info("Review prompt dropped | reason: scene no longer eligible, successCount: \(successCount)", category: .review)
            return
        }
        policy.notePrompted()
        MidgarLog.info("Review prompt asked | successCount: \(successCount)", category: .review)
        AppStore.requestReview(in: scene)
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
}

/// The ask history the app kept before `MidgarReviewPolicy`: a list of ask dates, and before that a flag with the app
/// version that had asked. A person who was asked recently must not be asked again the day the policy changes, so
/// the newest ask becomes the policy's last prompt the first time it runs.
nonisolated enum LegacyReviewState {
    static let askDatesKey = "pixie.review.askDates"
    static let legacyPromptedVersionKey = "pixie.review.promptedVersion"
    static let migratedKey = "pixie.review.migratedToMidgar"

    static func migrate(from defaults: UserDefaults, into storage: any MidgarReviewStorage, now: Date = Date()) {
        guard !defaults.bool(forKey: migratedKey) else { return }
        defaults.set(true, forKey: migratedKey)
        guard let lastAsk = lastAsk(in: defaults, now: now) else { return }
        var state = storage.load()
        guard state.lastPrompt == nil else { return }
        state.lastPrompt = lastAsk
        state.lastPromptedVersion = defaults.string(forKey: legacyPromptedVersionKey)
        storage.save(state)
    }

    /// The newest recorded ask, or `now` when only the old per-version flag survives, since its date was never kept.
    private static func lastAsk(in defaults: UserDefaults, now: Date) -> Date? {
        let seconds = defaults.array(forKey: askDatesKey) as? [Double] ?? []
        if let newest = seconds.max() { return Date(timeIntervalSince1970: newest) }
        return defaults.object(forKey: legacyPromptedVersionKey) == nil ? nil : now
    }
}
