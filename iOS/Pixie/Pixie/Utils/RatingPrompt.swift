import UIKit
import StoreKit

@MainActor
enum RatingPrompt {
    private static let countKey = "successfulGenerationCount"
    private static let lastPromptVersionKey = "lastRatingPromptVersion"

    private static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// Apple shows the rating sheet at most three times per year and silently
    /// ignores extra requests, so we only ask after a genuine success moment and
    /// never twice on the same app version.
    static func registerSuccessfulGeneration(in scene: UIWindowScene?) {
        let defaults = UserDefaults.standard
        let count = defaults.integer(forKey: countKey) + 1
        defaults.set(count, forKey: countKey)

        guard count >= 2 else { return }
        guard defaults.string(forKey: lastPromptVersionKey) != appVersion else { return }

        guard let scene else { return }
        defaults.set(appVersion, forKey: lastPromptVersionKey)
        AppStore.requestReview(in: scene)
    }
}
