import Foundation

/// `pixie://preset/<id>` opens the app on a one-tap edit; in-app events and custom
/// product pages link there. A link can arrive before the main screen exists, so it is
/// held until that screen takes it.
enum PresetLink {
    static let didArrive = Notification.Name("PresetLinkDidArrive")
    private static var pending: EditPreset?

    static func handle(_ url: URL) -> Bool {
        guard url.scheme == "pixie", url.host == "preset",
              let id = url.pathComponents.first(where: { $0 != "/" }),
              let preset = EditPreset.preset(id: id) else { return false }
        pending = preset
        NotificationCenter.default.post(name: didArrive, object: nil)
        return true
    }

    static func take() -> EditPreset? {
        defer { pending = nil }
        return pending
    }
}
