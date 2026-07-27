import StoreKit
import UIKit

/// Asks for an App Store rating once the user has successfully generated a few images, and at most
/// once per app version.
///
/// Rating count is both an App Store ranking input and the strongest conversion signal on a
/// product page, and PixiePocket shipped with no way to request one. The gate is a generation that
/// actually returned images — a failed request or an out-of-credits bounce never advances it.
@MainActor
enum ReviewPrompt {
    private static let generationsBeforeAsking = 3
    private static let countKey = "pixie.review.successfulGenerations"
    private static let versionKey = "pixie.review.promptedVersion"

    /// Call when a generation returns at least one image.
    static func recordSuccessfulGeneration() {
        let defaults = UserDefaults.standard
        let generations = defaults.integer(forKey: countKey) + 1
        defaults.set(generations, forKey: countKey)

        guard generations >= generationsBeforeAsking else { return }
        guard defaults.string(forKey: versionKey) != currentVersion, let scene = activeScene else {
            return
        }
        defaults.set(currentVersion, forKey: versionKey)
        AppStore.requestReview(in: scene)
    }

    private static var activeScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
    }

    private static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }
}
