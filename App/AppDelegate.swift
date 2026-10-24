import UIKit
import UserNotifications
import RevenueCat
import MidgarCore

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        PixieMidgar.configureLogging()
        MidgarLog.info("App launched", category: .launch)

        warmUpLaunchServicesReceiptPath()

        UNUserNotificationCenter.current().delegate = self
        
        let categories = createNotificationCategories()
        UNUserNotificationCenter.current().setNotificationCategories(categories)
        
        URLCache.shared.removeAllCachedResponses()
        
        _ = RevenueCatManager.shared
        PixieMidgar.shared.start()
        ReviewPrompt.beginSession()
        _ = GenerationActivity.shared
        
        let keychainManager = AppContainer.shared.keychainManager
        if let user = try? keychainManager.getCodable(forKey: KeychainKeys.userProfile, type: User.self) {
            Task {
                try? await RevenueCatManager.shared.setUserId(user.id)
            }
        }
        
        return true
    }
    
    /// RevenueCat ≤5.78.0 reads `Bundle.main.appStoreReceiptURL` from its background
    /// "RC Backend Queue" during configure, which crashes deterministically at launch on
    /// iOS 26.5 devices (purchases-ios#6886). A main-thread access first makes the later
    /// background read safe. Remove only after RevenueCat ships a real fix.
    private func warmUpLaunchServicesReceiptPath() {
        _ = Bundle.main.appStoreReceiptURL
    }

    private func createNotificationCategories() -> Set<UNNotificationCategory> {
        let viewAction = UNNotificationAction(
            identifier: "VIEW_ACTION",
            title: String(localized: "View"),
            options: [.foreground]
        )
        
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS_ACTION",
            title: String(localized: "Dismiss"),
            options: []
        )
        
        let generationCategory = UNNotificationCategory(
            identifier: "GENERATION_COMPLETE",
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )
        
        return [generationCategory]
    }
}

/// UserNotifications calls its delegate on queues of its own, so the methods are nonisolated and hop to the main
/// actor only for the one thing that touches UI state.
nonisolated extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        guard let chatId = userInfo["chatId"] as? String,
              userInfo["type"] as? String == "generation_complete" else { return }
        await MainActor.run {
            NotificationCenter.default.post(
                name: .openChatFromNotification,
                object: nil,
                userInfo: ["chatId": chatId]
            )
        }
    }
}

nonisolated extension Notification.Name {
    static let openChatFromNotification = Notification.Name("openChatFromNotification")
}
