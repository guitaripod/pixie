import UIKit

final class StateView: UIView {
    private let badge: IconBadge
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let stack = UIStackView()
    private var actionButton: PixieButton?

    init(
        symbol: String,
        title: String,
        message: String? = nil,
        actionTitle: String? = nil,
        onBackdrop: Bool = false,
        colors: [UIColor] = Theme.Color.gradient,
        action: (() -> Void)? = nil
    ) {
        badge = IconBadge(symbol: symbol, colors: colors, size: 80, symbolScale: 0.42)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        titleLabel.setStyledText(title, .title2, color: onBackdrop ? Theme.Color.onBackdrop : nil, alignment: .center)
        titleLabel.accessibilityTraits = .header
        messageLabel.setStyledText(message ?? "", .callout, color: onBackdrop ? Theme.Color.onBackdropSecondary : nil, alignment: .center)
        messageLabel.isHidden = message == nil

        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = Theme.Space.md
        stack.addArrangedSubview(badge)
        stack.setCustomSpacing(Theme.Space.xl, after: badge)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(messageLabel)

        if let actionTitle, let action {
            let button = PixieButton(style: onBackdrop ? .onBackdrop : .primary, size: .medium, title: actionTitle, handler: action)
            stack.setCustomSpacing(Theme.Space.xl, after: messageLabel)
            stack.addArrangedSubview(button)
            actionButton = button
        }

        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: 360),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func setLoading(_ loading: Bool) {
        actionButton?.isLoading = loading
    }
}
