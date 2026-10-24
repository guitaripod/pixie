import UIKit

final class BackdropTextButton: UIButton {
    var title: String? {
        didSet { setNeedsUpdateConfiguration() }
    }

    private let tint: UIColor

    init(title: String, color: UIColor = Theme.Color.onBackdropSecondary, handler: (() -> Void)? = nil) {
        self.title = title
        tint = color
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        configurationUpdateHandler = { [weak self] _ in self?.refresh() }
        if let handler {
            addAction(UIAction { _ in
                HapticsManager.shared.selection()
                handler()
            }, for: .touchUpInside)
        }
        refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var isHighlighted: Bool {
        didSet {
            guard oldValue != isHighlighted else { return }
            Motion.animate(0.12, options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.alpha = self.isHighlighted ? 0.6 : 1
            }
        }
    }

    private func refresh() {
        var config = UIButton.Configuration.plain()
        config.title = title
        config.baseForegroundColor = tint
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = Theme.TextStyle.subhead.font
            return outgoing
        }
        configuration = config
    }
}
