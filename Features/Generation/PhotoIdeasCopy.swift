import Foundation

/// Every word of the ideas row under a picked photo.
enum PhotoIdeasCopy {

    static var header: String { String(localized: "Ideas for this photo") }

    /// The line under "Start with a photo" for someone whose picked photo is looked at without a further tap.
    static var pickerLine: String { String(localized: "Pick one and Pixie looks at it to suggest edits") }

    static func title(of item: PhotoIdeaItem) -> String {
        switch item {
        case .idea(let idea): return idea
        case .offer: return String(localized: "Suggest 3 Edits · 1 credit")
        case .loading: return String(localized: "Looking at your photo…")
        case .tryAgain: return String(localized: "Try Again")
        case .getCredits: return String(localized: "Get Credits")
        }
    }

    static func subtitle(for state: PhotoIdeasState) -> String? {
        switch state {
        case .hidden, .loading: return nil
        case .offer: return String(localized: "Pixie can look at your photo and suggest three edits")
        case .ideas: return String(localized: "Pixie looked at your photo. Tap one to use it")
        case .failed: return String(localized: "Couldn't get ideas just now")
        case .needsCredits: return String(localized: "Ideas cost one credit, and you have none left")
        }
    }
}
