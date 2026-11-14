import UIKit

/// The ideas row under a picked photo: which chips it holds in each state and how they are laid out.
@MainActor
enum PhotoIdeasRow {

    /// The chips of the row for the state it is in, or none while it is hidden or no photo is picked.
    static func items(for state: PhotoIdeasState, hasPhoto: Bool) -> [PhotoIdeaItem] {
        guard hasPhoto else { return [] }
        switch state {
        case .hidden: return []
        case .offer: return [.offer]
        case .loading: return [.loading]
        case .ideas(let ideas): return ideas.map(PhotoIdeaItem.idea)
        case .withPlus: return [.plus]
        case .failed: return [.tryAgain]
        }
    }

    /// Chips side by side on one row that scrolls sideways, so the row costs the screen one line however many
    /// chips it holds and the edits below it stay in view.
    static func group(widths: [CGFloat], height: CGFloat) -> NSCollectionLayoutGroup {
        let spacing = Theme.Space.sm
        var frames: [CGRect] = []
        var x: CGFloat = 0
        for width in widths {
            frames.append(CGRect(x: x, y: 0, width: width, height: height))
            x += width + spacing
        }
        let size = NSCollectionLayoutSize(widthDimension: .absolute(max(1, x - spacing)), heightDimension: .absolute(height))
        return NSCollectionLayoutGroup.custom(layoutSize: size) { _ in
            frames.map { NSCollectionLayoutGroupCustomItem(frame: $0) }
        }
    }
}
