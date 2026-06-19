import Foundation

enum BlockedUsers {
    private static let key = "pixie.blockedUserIDs"
    static let didChangeNotification = Notification.Name("BlockedUsersDidChange")

    static var all: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    static var count: Int { all.count }

    static func isBlocked(_ userId: String) -> Bool {
        all.contains(userId)
    }

    static func block(_ userId: String) {
        guard !userId.isEmpty else { return }
        var set = all
        set.insert(userId)
        persist(set)
    }

    static func unblock(_ userId: String) {
        var set = all
        set.remove(userId)
        persist(set)
    }

    private static func persist(_ set: Set<String>) {
        UserDefaults.standard.set(Array(set), forKey: key)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
}
