import UIKit

final class ListRowView: UIControl {
    private let badge: IconBadge?
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let valueLabel = UILabel()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
    private let textStack = UIStackView()
    private let row = UIStackView()

    var onTap: (() -> Void)?

    init(
        title: String,
        subtitle: String? = nil,
        value: String? = nil,
        symbol: String? = nil,
        colors: [UIColor] = Theme.Color.gradient,
        showsChevron: Bool = false,
        valueColor: UIColor = Theme.Color.inkSecondary
    ) {
        badge = symbol.map { IconBadge(symbol: $0, colors: colors, size: 40) }
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        titleLabel.apply(.headline)
        titleLabel.text = title
        subtitleLabel.apply(.footnote)
        subtitleLabel.text = subtitle
        subtitleLabel.isHidden = subtitle == nil
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)
        textStack.isUserInteractionEnabled = false

        valueLabel.apply(.numeral(17), color: valueColor)
        valueLabel.numberOfLines = 1
        valueLabel.text = value
        valueLabel.isHidden = value == nil
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        chevron.tintColor = Theme.Color.inkTertiary
        chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        chevron.isHidden = !showsChevron

        row.axis = .horizontal
        row.alignment = .center
        row.spacing = Theme.Space.md
        if let badge { row.addArrangedSubview(badge) }
        row.addArrangedSubview(textStack)
        row.addArrangedSubview(valueLabel)
        row.addArrangedSubview(chevron)
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: Theme.Space.md),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Theme.Space.md),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Theme.Space.lg),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Theme.Space.lg),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 60),
        ])

        addAction(UIAction { [weak self] _ in
            HapticsManager.shared.selection()
            self?.onTap?()
        }, for: .touchUpInside)
        isAccessibilityElement = true
        accessibilityTraits = (showsChevron || onTap != nil) ? .button : .staticText
        accessibilityLabel = [title, subtitle].compactMap { $0 }.joined(separator: ", ")
        accessibilityValue = value
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyLayout()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        applyLayout()
    }

    /// At accessibility text sizes the icon, text and value stack vertically so titles are never squeezed.
    private func applyLayout() {
        let stacked = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        row.axis = stacked ? .vertical : .horizontal
        row.alignment = stacked ? .leading : .center
        row.spacing = stacked ? Theme.Space.sm : Theme.Space.md
    }

    override var isHighlighted: Bool {
        didSet {
            guard !Motion.isReduced else { return }
            Motion.animate(0.12, options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.backgroundColor = self.isHighlighted ? Theme.Color.fill : .clear
            }
        }
    }

    func update(title: String? = nil, subtitle: String? = nil, value: String? = nil) {
        if let title { titleLabel.text = title }
        if let subtitle {
            subtitleLabel.text = subtitle
            subtitleLabel.isHidden = false
        }
        if let value {
            valueLabel.text = value
            valueLabel.isHidden = false
        }
        accessibilityLabel = [titleLabel.text, subtitleLabel.isHidden ? nil : subtitleLabel.text].compactMap { $0 }.joined(separator: ", ")
        accessibilityValue = valueLabel.isHidden ? nil : valueLabel.text
    }
}

final class RowDivider: UIView {
    init(inset: CGFloat = Theme.Space.lg + 40 + Theme.Space.md) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        let line = UIView()
        line.backgroundColor = Theme.Color.line
        line.translatesAutoresizingMaskIntoConstraints = false
        addSubview(line)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),
            line.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            line.trailingAnchor.constraint(equalTo: trailingAnchor),
            line.topAnchor.constraint(equalTo: topAnchor),
            line.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        isAccessibilityElement = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}
