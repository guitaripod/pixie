import UserNotifications

/// Asks for notification permission once the user has seen a result and starts another
/// image: the first moment a "your image is ready" alert means anything to them, instead
/// of a cold system prompt on first launch.
@MainActor
enum NotificationPermission {
    static func requestIfUseful() {
        #if DEBUG
        if DemoMode.isActive { return }
        #endif
        guard ReviewPrompt.successfulGenerationCount >= 1 else { return }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                AppLogger.info("Notification permission answered: \(granted)", category: .general)
            }
        }
    }
}
