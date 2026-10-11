import UIKit

final class SurfaceView: UIView {
    enum Style {
        case card
        case raised
        case sunken
        case tinted(UIColor)
        case outlined
    }

    var style: Style {
        didSet { applyStyle() }
    }

    let contentView = UIView()

    init(style: Style = .card, cornerRadius: CGFloat = Theme.Radius.lg) {
        self.style = style
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = cornerRadius
        layer.cornerCurve = .continuous
        addSubview(contentView)
        contentView.pinEdges(to: self)
        contentView.layer.cornerRadius = cornerRadius
        contentView.layer.cornerCurve = .continuous
        contentView.clipsToBounds = true
        applyStyle()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    var cornerRadius: CGFloat {
        get { layer.cornerRadius }
        set {
            layer.cornerRadius = newValue
            contentView.layer.cornerRadius = newValue
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyStyle()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if case .card = style { layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: layer.cornerRadius).cgPath }
        if case .raised = style { layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: layer.cornerRadius).cgPath }
    }

    private func applyStyle() {
        let isDark = traitCollection.userInterfaceStyle == .dark
        layer.shadowOpacity = 0
        layer.borderWidth = 0
        switch style {
        case .card:
            backgroundColor = Theme.Color.surface
            layer.borderWidth = 1
            layer.borderColor = Theme.Color.line.resolvedColor(with: traitCollection).cgColor
            applyShadow(isDark ? 0 : 0.08, radius: 24, offset: 8)
        case .raised:
            backgroundColor = Theme.Color.surfaceRaised
            layer.borderWidth = 1
            layer.borderColor = Theme.Color.line.resolvedColor(with: traitCollection).cgColor
            applyShadow(isDark ? 0 : 0.12, radius: 30, offset: 12)
        case .sunken:
            backgroundColor = Theme.Color.fill
        case .tinted(let color):
            backgroundColor = color
        case .outlined:
            backgroundColor = .clear
            layer.borderWidth = 1
            layer.borderColor = Theme.Color.line.resolvedColor(with: traitCollection).cgColor
        }
    }

    private func applyShadow(_ opacity: Float, radius: CGFloat, offset: CGFloat) {
        layer.shadowColor = UIColor(hex: 0x1B0F4A).cgColor
        layer.shadowOpacity = opacity
        layer.shadowRadius = radius
        layer.shadowOffset = CGSize(width: 0, height: offset)
    }
}

final class IconBadge: UIView {
    private let imageView = UIImageView()
    private let gradient = GradientView()

    init(symbol: String, colors: [UIColor] = Theme.Color.gradient, size: CGFloat = 44, symbolScale: CGFloat = 0.46) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        gradient.colors = colors
        gradient.cornerRadius = size * 0.3
        addSubview(gradient)
        gradient.pinEdges(to: self)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: size * symbolScale, weight: .semibold)
        imageView.image = UIImage(systemName: symbol)
        addSubview(imageView)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: size),
            heightAnchor.constraint(equalToConstant: size),
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        layer.cornerRadius = size * 0.3
        layer.cornerCurve = .continuous
        isAccessibilityElement = false
        accessibilityElementsHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func setSymbol(_ name: String) {
        imageView.image = UIImage(systemName: name)
    }
}

final class SectionLabelView: UIView {
    private let titleLabel = UILabel()
    private let actionButton = PixieButton(style: .plain, size: .small)

    init(title: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        titleLabel.setStyledText(title, .caption)
        titleLabel.accessibilityTraits = .header
        titleLabel.numberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        var constraints = [
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
        ]
        if let actionTitle, let action {
            actionButton.title = actionTitle
            actionButton.addAction(UIAction { _ in action() }, for: .touchUpInside)
            addSubview(actionButton)
            constraints += [
                actionButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 14),
                actionButton.centerYAnchor.constraint(equalTo: centerYAnchor),
                titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: actionButton.leadingAnchor, constant: -Theme.Space.sm),
            ]
        } else {
            constraints.append(titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor))
        }
        NSLayoutConstraint.activate(constraints)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}

final class ChipView: UIControl {
    private let label = UILabel()
    private let iconView = UIImageView()
    private let stack = UIStackView()

    var onTap: (() -> Void)?

    override var isSelected: Bool {
        didSet { applyState() }
    }

    init(title: String, symbol: String? = nil, isSelected: Bool = false) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerCurve = .continuous
        label.apply(.subhead, color: Theme.Color.ink)
        label.text = title
        label.numberOfLines = 0
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .subheadline, scale: .medium)
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        iconView.setContentCompressionResistancePriority(.required, for: .horizontal)
        if let symbol {
            iconView.image = UIImage(systemName: symbol)
            stack.addArrangedSubview(iconView)
        }
        stack.addArrangedSubview(label)
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 6
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 9),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -9),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 38),
        ])
        addAction(UIAction { [weak self] _ in
            HapticsManager.shared.selection()
            self?.onTap?()
        }, for: .touchUpInside)
        self.isSelected = isSelected
        accessibilityLabel = title
        applyState()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }

    override var isHighlighted: Bool {
        didSet {
            guard !Motion.isReduced else { return }
            Motion.animate(0.12, options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.alpha = self.isHighlighted ? 0.7 : 1
            }
        }
    }

    private func applyState() {
        backgroundColor = isSelected ? Theme.Color.accent : Theme.Color.fill
        label.textColor = isSelected ? .white : Theme.Color.ink
        iconView.tintColor = isSelected ? .white : Theme.Color.accentText
        accessibilityTraits = isSelected ? [.button, .selected] : .button
    }
}

final class CreditPill: UIControl {
    private let iconView = UIImageView(image: UIImage(systemName: "sparkles"))
    private let label = CountingLabel()
    private var amountKind: String?
    private let stack = UIStackView()
    private let background = UIVisualEffectView(effect: GlassMaterial.effect(interactive: true))

    var onTap: (() -> Void)?

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        background.translatesAutoresizingMaskIntoConstraints = false
        background.isUserInteractionEnabled = false
        background.layer.cornerCurve = .continuous
        background.clipsToBounds = true
        addSubview(background)
        background.pinEdges(to: self)

        iconView.tintColor = Theme.Color.accentText
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .subheadline, scale: .medium)
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        label.apply(.numeral(16), color: Theme.Color.ink)
        label.monospaceDigits()
        label.numberOfLines = 1
        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(label)
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 6
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
        ])
        addAction(UIAction { [weak self] _ in
            HapticsManager.shared.selection()
            self?.onTap?()
        }, for: .touchUpInside)
        accessibilityTraits = .button
        isAccessibilityElement = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        background.layer.cornerRadius = bounds.height / 2
    }

    func configure(text: String, isLow: Bool, accessibilityLabel spoken: String, hint: String?) {
        label.setValue(nil, placeholder: text, format: { _ in text }, animated: false)
        applyAppearance(isLow: isLow, accessibilityLabel: spoken, hint: hint)
    }

    /// Shows a number that rolls to its new value, with a small pulse when it grows. `kind`
    /// names what the number counts; when it changes the text is replaced instead of rolled.
    func configure(amount: Int?, kind: String, format: @escaping (Int) -> String, isLow: Bool, accessibilityLabel spoken: String, hint: String?) {
        let previous = label.value
        let isVisible = window != nil
        let sameKind = kind == amountKind
        amountKind = kind
        let update = { self.label.setValue(amount, format: format, animated: isVisible && sameKind) }
        if isVisible, !sameKind, previous != nil {
            Motion.transition(with: label, duration: 0.25, options: .transitionCrossDissolve, animations: update)
        } else {
            update()
        }
        applyAppearance(isLow: isLow, accessibilityLabel: spoken, hint: hint)
        if isVisible, sameKind, let previous, let amount, amount > previous { pulse() }
    }

    private func applyAppearance(isLow: Bool, accessibilityLabel spoken: String, hint: String?) {
        iconView.image = UIImage(systemName: isLow ? "exclamationmark.circle.fill" : "sparkles")
        iconView.tintColor = isLow ? Theme.Color.warning : Theme.Color.accentText
        accessibilityLabel = spoken
        accessibilityHint = hint
    }

    private func pulse() {
        guard !Motion.isReduced else { return }
        Motion.spring(0.5, damping: 0.5, animations: { self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1) }, completion: { _ in
            Motion.spring(0.4, damping: 0.7, animations: { self.transform = .identity })
        })
    }
}
