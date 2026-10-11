import UIKit

final class GlassButton: UIControl {
    private let glass = GlassSurface(interactive: true, tintAlpha: 0.4)
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let stack = UIStackView()
    private let badge = UIView()

    init(symbol: String, title: String? = nil, accessibilityLabel spoken: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        glass.isUserInteractionEnabled = false
        addSubview(glass)
        glass.pinEdges(to: self)

        iconView.image = UIImage(systemName: symbol)
        iconView.tintColor = Theme.Color.ink
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        iconView.setContentCompressionResistancePriority(.required, for: .horizontal)
        stack.addArrangedSubview(iconView)

        if let title {
            titleLabel.font = ChatTopBar.cappedFont(.subheadline, size: 15, weight: .semibold)
            titleLabel.adjustsFontForContentSizeCategory = true
            titleLabel.textColor = Theme.Color.ink
            titleLabel.text = title
            titleLabel.numberOfLines = 1
            stack.addArrangedSubview(titleLabel)
        }
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 6
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        badge.backgroundColor = Theme.Color.warning
        badge.layer.cornerRadius = 5
        badge.layer.borderWidth = 1.5
        badge.isHidden = true
        badge.isUserInteractionEnabled = false
        badge.translatesAutoresizingMaskIntoConstraints = false
        addSubview(badge)

        let inset: CGFloat = title == nil ? 0 : 14
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 44),
            widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: inset),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -inset),
            badge.widthAnchor.constraint(equalToConstant: 10),
            badge.heightAnchor.constraint(equalToConstant: 10),
            badge.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            badge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
        ])
        if title != nil {
            let width = widthAnchor.constraint(equalTo: stack.widthAnchor, constant: inset * 2)
            width.priority = .defaultHigh
            width.isActive = true
        } else {
            widthAnchor.constraint(equalToConstant: 44).isActive = true
        }
        isAccessibilityElement = true
        accessibilityLabel = spoken
        accessibilityTraits = .button
        applyBadgeAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    var showsBadge: Bool {
        get { !badge.isHidden }
        set { badge.isHidden = !newValue }
    }

    override var isHighlighted: Bool {
        didSet {
            guard oldValue != isHighlighted, !Motion.isReduced else { return }
            Motion.animate(0.15, options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.95, y: 0.95) : .identity
            }
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyBadgeAppearance()
    }

    private func applyBadgeAppearance() {
        badge.layer.borderColor = Theme.Color.canvas.resolvedColor(with: traitCollection).cgColor
    }
}

final class ChatTopBar: UIView {
    enum LeadingStyle {
        case wordmark
        case newChat
    }

    var onNewChat: (() -> Void)?
    var onCredits: (() -> Void)?
    var onGallery: (() -> Void)?
    var onSettings: (() -> Void)?

    private let wordmarkLabel = UILabel()
    private let newChatButton = GlassButton(symbol: "sparkles", title: String(localized: " New").trimmingCharacters(in: .whitespaces), accessibilityLabel: String(localized: "New Chat"))
    private let newChatIconButton = GlassButton(symbol: "sparkles", accessibilityLabel: String(localized: "New Chat"))
    private let creditPill = CreditPill()
    private let galleryButton = GlassButton(symbol: "photo.on.rectangle", accessibilityLabel: String(localized: "Gallery"))
    private let settingsButton = GlassButton(symbol: "gearshape", accessibilityLabel: String(localized: "Settings"))
    private let trailingStack = UIStackView()
    private(set) var leadingStyle = LeadingStyle.wordmark

    static func cappedFont(_ style: UIFont.TextStyle, size: CGFloat, weight: UIFont.Weight, rounded: Bool = false, maximum: CGFloat = 26) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        return UIFontMetrics(forTextStyle: style).scaledFont(for: rounded ? base.rounded() : base, maximumPointSize: maximum)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        setupWordmark()
        setupTrailing()
        setupActions()
        setupAccessibility()
        applyLeadingStyle()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
            applyLeadingStyle()
        }
    }

    func setLeadingStyle(_ style: LeadingStyle, animated: Bool) {
        guard style != leadingStyle else { return }
        leadingStyle = style
        guard animated else {
            applyLeadingStyle()
            return
        }
        Motion.animate(0.2, animations: {
            self.wordmarkLabel.alpha = 0
            self.newChatButton.alpha = 0
            self.newChatIconButton.alpha = 0
        }, completion: { _ in
            self.applyLeadingStyle()
            Motion.animate(0.2) { self.applyLeadingAlpha() }
        })
    }

    func setCredits(text: String, isLow: Bool, value: String?) {
        creditPill.configure(text: text, isLow: isLow, accessibilityLabel: String(localized: "Credits"), hint: String(localized: "Opens the credit store"))
        creditPill.accessibilityValue = value
    }

    func setCredits(amount: Int?, kind: String, format: @escaping (Int) -> String, isLow: Bool, value: String?) {
        creditPill.configure(amount: amount, kind: kind, format: format, isLow: isLow, accessibilityLabel: String(localized: "Credits"), hint: String(localized: "Opens the credit store"))
        creditPill.accessibilityValue = value
    }

    func setShowsAdminBadge(_ isAdmin: Bool) {
        settingsButton.showsBadge = isAdmin
        settingsButton.accessibilityValue = isAdmin ? String(localized: "Admin") : nil
    }

    private var usesCompactLeading: Bool {
        traitCollection.preferredContentSizeCategory.isAccessibilityCategory
    }

    private func setupWordmark() {
        wordmarkLabel.translatesAutoresizingMaskIntoConstraints = false
        wordmarkLabel.text = "Pixie"
        wordmarkLabel.font = Self.cappedFont(.title2, size: 22, weight: .heavy, rounded: true, maximum: 30)
        wordmarkLabel.adjustsFontForContentSizeCategory = true
        wordmarkLabel.textColor = Theme.Color.ink
        wordmarkLabel.numberOfLines = 1
        wordmarkLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addSubview(wordmarkLabel)
        addSubview(newChatButton)
        addSubview(newChatIconButton)
        NSLayoutConstraint.activate([
            wordmarkLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Theme.Space.sm),
            wordmarkLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            newChatButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            newChatButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            newChatIconButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            newChatIconButton.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    private func setupTrailing() {
        trailingStack.axis = .horizontal
        trailingStack.alignment = .center
        trailingStack.spacing = Theme.Space.sm
        trailingStack.translatesAutoresizingMaskIntoConstraints = false
        [creditPill, galleryButton, settingsButton].forEach(trailingStack.addArrangedSubview)
        creditPill.setContentCompressionResistancePriority(.required, for: .horizontal)
        addSubview(trailingStack)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            trailingStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            trailingStack.topAnchor.constraint(equalTo: topAnchor),
            trailingStack.bottomAnchor.constraint(equalTo: bottomAnchor),
            wordmarkLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingStack.leadingAnchor, constant: -Theme.Space.sm),
            newChatButton.trailingAnchor.constraint(lessThanOrEqualTo: trailingStack.leadingAnchor, constant: -Theme.Space.sm),
        ])
    }

    private func setupActions() {
        newChatButton.addAction(UIAction { [weak self] _ in self?.onNewChat?() }, for: .touchUpInside)
        newChatIconButton.addAction(UIAction { [weak self] _ in self?.onNewChat?() }, for: .touchUpInside)
        creditPill.onTap = { [weak self] in self?.onCredits?() }
        galleryButton.addAction(UIAction { [weak self] _ in self?.onGallery?() }, for: .touchUpInside)
        settingsButton.addAction(UIAction { [weak self] _ in self?.onSettings?() }, for: .touchUpInside)
    }

    private func setupAccessibility() {
        wordmarkLabel.isAccessibilityElement = true
        wordmarkLabel.accessibilityTraits = .header
        accessibilityElements = [wordmarkLabel, newChatButton, newChatIconButton, creditPill, galleryButton, settingsButton]
    }

    private func applyLeadingStyle() {
        let compact = usesCompactLeading
        wordmarkLabel.isHidden = leadingStyle != .wordmark || compact
        newChatButton.isHidden = leadingStyle != .newChat || compact
        newChatIconButton.isHidden = leadingStyle != .newChat || !compact
        applyLeadingAlpha()
        wordmarkLabel.isAccessibilityElement = !wordmarkLabel.isHidden
        accessibilityElements = [wordmarkLabel, newChatButton, newChatIconButton, creditPill, galleryButton, settingsButton].filter { !$0.isHidden }
    }

    private func applyLeadingAlpha() {
        wordmarkLabel.alpha = 1
        newChatButton.alpha = 1
        newChatIconButton.alpha = 1
    }
}
