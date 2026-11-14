import Foundation

/// Every word of the ideas row under a picked photo.
enum PhotoIdeasCopy {

    static var header: String { String(localized: "Ideas for this photo") }

    /// The line under "Start with a photo" for someone whose picked photo is looked at without a further tap.
    static var pickerLine: String { String(localized: "Pick one and Pixie looks at it to suggest edits") }

    static func title(of item: PhotoIdeaItem) -> String {
        switch item {
        case .idea(let idea): return idea
        case .offer: return String(localized: "Suggest 3 Edits")
        case .plus: return String(localized: "See Plus")
        case .loading: return String(localized: "Looking at your photo…")
        case .tryAgain: return String(localized: "Try Again")
        }
    }

    static func subtitle(for state: PhotoIdeasState) -> String? {
        switch state {
        case .hidden, .loading: return nil
        case .offer: return sharing
        case .withPlus: return String(localized: "With Plus, Pixie looks at your photo and suggests three edits")
        case .ideas: return String(localized: "Pixie looked at your photo. Tap one to use it")
        case .failed: return String(localized: "Couldn't get ideas just now")
        }
    }

    /// What agreeing to ideas sends and where, said before anything is sent and again in Settings and Help.
    static var sharing: String {
        String(localized: "A small copy of the photo you pick goes to Anthropic's Claude, which suggests the edits. Pixie's servers keep no copy.")
    }

    static var settingsTitle: String { String(localized: "Photo Ideas") }
}
