import UIKit

extension AppTheme {
    var displayName: String {
        switch self {
        case .system: return String(localized: "System")
        case .light: return String(localized: "Light")
        case .dark: return String(localized: "Dark")
        }
    }
}

final class AccountDeletionProgressView: UIView {
    private let card = SurfaceView(style: .raised, cornerRadius: Theme.Radius.xl)
    private let spinner = UIActivityIndicatorView(style: .large)
    private let messageLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func install(in host: UIView) {
        translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(self)
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: host.topAnchor),
            leadingAnchor.constraint(equalTo: host.leadingAnchor),
            trailingAnchor.constraint(equalTo: host.trailingAnchor),
            bottomAnchor.constraint(equalTo: host.bottomAnchor)
        ])
        alpha = 0
        spinner.startAnimating()
        Motion.animate(0.2) { self.alpha = 1 }
        Announce.screenChanged(messageLabel)
    }

    func remove() {
        spinner.stopAnimating()
        Motion.animate(0.2, animations: { self.alpha = 0 }, completion: { _ in
            self.removeFromSuperview()
        })
    }

    private func configureViews() {
        backgroundColor = UIColor.black.withAlphaComponent(0.4)
        accessibilityViewIsModal = true

        spinner.color = Theme.Color.accentText
        spinner.hideFromAccessibility()

        messageLabel.apply(.headline)
        messageLabel.text = String(localized: "Deleting your account…")
        messageLabel.textAlignment = .center
        messageLabel.isAccessibilityElement = true
        messageLabel.accessibilityTraits = [.staticText, .updatesFrequently]

        let stack = UIStackView(arrangedSubviews: [spinner, messageLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = Theme.Space.lg
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.contentView.addSubview(stack)
        addSubview(card)

        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: centerXAnchor),
            card.centerYAnchor.constraint(equalTo: centerYAnchor),
            card.widthAnchor.constraint(lessThanOrEqualToConstant: 320),
            card.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: Theme.Space.xxl),
            card.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -Theme.Space.xxl),

            stack.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: Theme.Space.xxl),
            stack.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: Theme.Space.xxl),
            stack.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -Theme.Space.xxl),
            stack.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -Theme.Space.xxl)
        ])
    }
}
