import Foundation
import MidgarCore
import PixiepocketCore
import UIKit
import UserNotifications

/// The Pixie Week as the person sees it (D27): mako starts it at their first edit and makes five standard edits a
/// day free for seven days; the app announces it once, reminds them two days before it ends when they ask, and says
/// once that it has ended, with the way to Plus and the packs. Nothing here decides what is free.
@MainActor
final class PixieWeek {
    static let shared = PixieWeek()

    /// What onboarding promises before mako has answered: the `pixie` tenant's runway in mako.
    static let dailyEdits = 5
    static let days = 7

    private static let announcedKey = "pixieWeek.announced"
    private static let endNotedKey = "pixieWeek.endNoted"
    private static let reminderID = "pixieWeek.reminder"
    private static let reminderLead: TimeInterval = 2 * 86_400

    /// What there is to say about the week, each at most once.
    enum Moment: Equatable {
        case started(daily: Int, days: Int, endsAt: Date?)
        case ended
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The moment the app owes the person for this runway, or nil: the start once it is running, the end once it is
    /// over and only for someone who was told it started.
    func moment(for runway: Runway?) -> Moment? {
        guard let runway else { return nil }
        switch runway.state {
        case .active where !defaults.bool(forKey: Self.announcedKey):
            return .started(daily: runway.dailyLimit, days: runway.days, endsAt: runway.endDate)
        case .ended where defaults.bool(forKey: Self.announcedKey) && !defaults.bool(forKey: Self.endNotedKey):
            return .ended
        default:
            return nil
        }
    }

    /// Shows the moment over `presenter` and records it as said.
    func present(_ moment: Moment, from presenter: UIViewController) {
        switch moment {
        case .started(let daily, let days, let endsAt):
            defaults.set(true, forKey: Self.announcedKey)
            let alert = UIAlertController(
                title: String(localized: "Your Pixie Week has started"),
                message: String(localized: "\(EditPrice.label(edits: daily)) free every day for the next \(days) days. No sign-up, nothing to cancel."),
                preferredStyle: .alert
            )
            if let endsAt, endsAt.addingTimeInterval(-Self.reminderLead) > Date() {
                alert.addAction(UIAlertAction(title: String(localized: "Remind me before it ends"), style: .default) { _ in
                    Task { await Self.scheduleReminder(endsAt: endsAt) }
                })
            }
            alert.addAction(UIAlertAction(title: String(localized: "Great"), style: .cancel))
            presenter.present(alert, animated: true)
            MidgarLog.info("Pixie Week announced", category: .credits)
        case .ended:
            defaults.set(true, forKey: Self.endNotedKey)
            let alert = UIAlertController(
                title: String(localized: "Your Pixie Week has ended"),
                message: String(localized: "Keep editing with Plus, \(PixiePacks.plusWeeklyEdits) edits every week, or with a pack that never expires."),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: String(localized: "See options"), style: .default) { [weak presenter] _ in
                guard let presenter else { return }
                CreditStoreViewController.present(from: presenter)
            })
            alert.addAction(UIAlertAction(title: String(localized: "Not now"), style: .cancel))
            presenter.present(alert, animated: true)
            MidgarLog.info("Pixie Week end noted", category: .credits)
        }
    }

    /// Asks for permission to notify and schedules one reminder two days before the week ends.
    static func scheduleReminder(endsAt: Date) async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted, let fireDate = reminderDate(endsAt: endsAt) else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Two days left in your Pixie Week")
        content.body = String(localized: "Your free edits end on \(endsAt.formatted(.dateTime.weekday(.wide))). Make the most of them.")
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: fireDate.timeIntervalSinceNow, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: reminderID, content: content, trigger: trigger))
        MidgarLog.info("Pixie Week reminder scheduled", category: .credits)
    }

    /// When the reminder fires: two days before the end, or nil once that has passed.
    static func reminderDate(endsAt: Date, now: Date = Date()) -> Date? {
        let fire = endsAt.addingTimeInterval(-reminderLead)
        return fire > now.addingTimeInterval(60) ? fire : nil
    }

    /// Takes the reminder back, for a person who subscribed to Plus during the week.
    static func cancelReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderID])
    }
}
