import UIKit

/// The item identifier of the suggestions grid, whose sections mix presets, photos, text rows and marker tiles. It
/// erases the wrapped value the way `AnyHashable` does, and unlike `AnyHashable` it can cross to a diffable data
/// source under Swift 6.
nonisolated struct SuggestionItem: Hashable, @unchecked Sendable {
    /// Always an immutable value: an `EditPreset`, a `String` or a `UIImage` that nothing mutates once listed.
    let base: AnyHashable

    init(_ base: some Hashable) {
        self.base = AnyHashable(base)
    }

    var marker: String? { base as? String }

    var image: UIImage? { base as? UIImage }

    var preset: EditPreset? { base as? EditPreset }
}
