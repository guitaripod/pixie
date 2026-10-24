import UIKit

final class HairlineView: UIView {
    private lazy var heightConstraint = heightAnchor.constraint(equalToConstant: 1)

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = Theme.Color.line
        heightConstraint.isActive = true
        applyDisplayScale()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyDisplayScale()
    }

    /// One pixel of the display the view is on, which changes when the app moves between the
    /// displays of a foldable, so it is read from the trait collection and never from the main screen.
    private func applyDisplayScale() {
        heightConstraint.constant = 1 / max(traitCollection.displayScale, 1)
    }
}
