import UIKit

enum SettingsTint {
    static func solid(_ color: UIColor) -> [UIColor] { [color, color] }
}

/// A vertical column of content that scrolls, is centred at a readable maximum width and keeps the screen margin on every size class.
final class SettingsColumnView: UIScrollView {
    let stack = UIStackView()

    private let maxWidth: CGFloat
    private var widthConstraint: NSLayoutConstraint?
    private var leadingConstraint: NSLayoutConstraint?
    private var trailingConstraint: NSLayoutConstraint?

    init(maxWidth: CGFloat = Theme.Width.form, spacing: CGFloat = 28) {
        self.maxWidth = maxWidth
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        alwaysBounceVertical = true
        keyboardDismissMode = .interactive
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = spacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func install(in host: UIView, top: CGFloat = Theme.Space.sm, bottom: CGFloat = Theme.Space.xxxl) {
        host.addSubview(self)
        let guide = host.safeAreaLayoutGuide
        let margin = Theme.screenMargin(for: host.traitCollection)
        let width = stack.widthAnchor.constraint(equalTo: guide.widthAnchor, constant: -2 * margin)
        width.priority = .defaultHigh
        let leading = stack.leadingAnchor.constraint(greaterThanOrEqualTo: guide.leadingAnchor, constant: margin)
        let trailing = stack.trailingAnchor.constraint(lessThanOrEqualTo: guide.trailingAnchor, constant: -margin)
        widthConstraint = width
        leadingConstraint = leading
        trailingConstraint = trailing
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: host.topAnchor),
            leadingAnchor.constraint(equalTo: host.leadingAnchor),
            trailingAnchor.constraint(equalTo: host.trailingAnchor),
            bottomAnchor.constraint(equalTo: host.bottomAnchor),
            contentLayoutGuide.widthAnchor.constraint(equalTo: frameLayoutGuide.widthAnchor),
            stack.topAnchor.constraint(equalTo: contentLayoutGuide.topAnchor, constant: top),
            stack.bottomAnchor.constraint(equalTo: contentLayoutGuide.bottomAnchor, constant: -bottom),
            stack.centerXAnchor.constraint(equalTo: guide.centerXAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: maxWidth),
            width, leading, trailing,
        ])
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        let margin = Theme.screenMargin(for: traitCollection)
        widthConstraint?.constant = -2 * margin
        leadingConstraint?.constant = margin
        trailingConstraint?.constant = -margin
    }

    func removeAllContent() {
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
    }
}

enum SettingsLayout {
    static let plainDividerInset = Theme.Space.lg

    static func card(rows: [UIView], dividerInset: CGFloat = Theme.Space.lg + 40 + Theme.Space.md, style: SurfaceView.Style = .card) -> SurfaceView {
        let surface = SurfaceView(style: style)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        for (index, row) in rows.enumerated() {
            if index > 0 { stack.addArrangedSubview(RowDivider(inset: dividerInset)) }
            stack.addArrangedSubview(row)
        }
        surface.contentView.addSubview(stack)
        stack.pinEdges(to: surface.contentView)
        return surface
    }

    static func section(title: String, content: [UIView], spacing: CGFloat = Theme.Space.md) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: [SectionLabelView(title: title)] + content)
        stack.axis = .vertical
        stack.spacing = spacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    static func footnote(_ text: String) -> UILabel {
        let label = UILabel()
        label.setStyledText(text, .footnote)
        return label
    }

    static func padded(_ content: UIView, insets: UIEdgeInsets) -> UIView {
        let host = UIView()
        host.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(content)
        content.pinEdges(to: host, insets: insets)
        return host
    }
}

final class SettingsRowView: UIControl {
    var onTap: (() -> Void)?

    private let badge: IconBadge?
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let valueLabel = UILabel()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
    private let accessoryHost = UIView()
    private let textStack = UIStackView()
    private let row = UIStackView()
    private var isBusy = false

    init(
        title: String,
        subtitle: String? = nil,
        symbol: String? = nil,
        colors: [UIColor] = Theme.Color.gradient,
        titleColor: UIColor = Theme.Color.ink,
        value: String? = nil,
        showsChevron: Bool = false
    ) {
        badge = symbol.map { IconBadge(symbol: $0, colors: colors, size: 40) }
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        titleLabel.apply(.headline, color: titleColor)
        titleLabel.text = title
        subtitleLabel.apply(.footnote)
        subtitleLabel.text = subtitle
        subtitleLabel.isHidden = subtitle == nil
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)

        valueLabel.apply(.numeral(17))
        valueLabel.textColor = Theme.Color.inkSecondary
        valueLabel.numberOfLines = 1
        valueLabel.text = value
        valueLabel.isHidden = value == nil
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        chevron.tintColor = Theme.Color.inkTertiary
        chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        chevron.isHidden = !showsChevron

        accessoryHost.isHidden = true
        accessoryHost.setContentHuggingPriority(.required, for: .horizontal)
        accessoryHost.setContentCompressionResistancePriority(.required, for: .horizontal)

        row.axis = .horizontal
        row.alignment = .center
        row.spacing = Theme.Space.md
        if let badge { row.addArrangedSubview(badge) }
        row.addArrangedSubview(textStack)
        row.addArrangedSubview(valueLabel)
        row.addArrangedSubview(accessoryHost)
        row.addArrangedSubview(chevron)
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
        accessibilityTraits = showsChevron ? .button : .staticText
        refreshAccessibility()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var isHighlighted: Bool {
        didSet {
            guard !Motion.isReduced else { return }
            Motion.animate(0.12, options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.backgroundColor = self.isHighlighted ? Theme.Color.fill : .clear
            }
        }
    }

    /// Keeps the row itself the touch target except for a control placed in the accessory slot, such as a switch.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hit = super.hitTest(point, with: event) else { return nil }
        if hit !== self, hit is UIControl, hit.isDescendant(of: accessoryHost) { return hit }
        return self
    }

    func setExpanded(_ expanded: Bool) {
        chevron.transform = expanded ? CGAffineTransform(rotationAngle: .pi / 2) : .identity
    }

    func setSubtitle(_ text: String?) {
        subtitleLabel.text = text
        subtitleLabel.isHidden = text == nil
        refreshAccessibility()
    }

    func setValue(_ text: String?) {
        valueLabel.text = text
        valueLabel.isHidden = text == nil
        refreshAccessibility()
    }

    func setAccessory(_ view: UIView?) {
        accessoryHost.subviews.forEach { $0.removeFromSuperview() }
        accessoryHost.isHidden = view == nil
        guard let view else { return }
        view.translatesAutoresizingMaskIntoConstraints = false
        accessoryHost.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: accessoryHost.topAnchor),
            view.bottomAnchor.constraint(equalTo: accessoryHost.bottomAnchor),
            view.leadingAnchor.constraint(equalTo: accessoryHost.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: accessoryHost.trailingAnchor),
        ])
    }

    func setBusy(_ busy: Bool) {
        isBusy = busy
        isEnabled = !busy
        row.alpha = busy ? 0.5 : 1
        if busy {
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.startAnimating()
            spinner.hideFromAccessibility()
            setAccessory(spinner)
        } else {
            setAccessory(nil)
        }
        refreshAccessibility()
    }

    private func refreshAccessibility() {
        accessibilityLabel = [titleLabel.text, subtitleLabel.isHidden ? nil : subtitleLabel.text].compactMap { $0 }.joined(separator: ", ")
        accessibilityValue = valueLabel.isHidden ? nil : valueLabel.text
        if isBusy {
            accessibilityTraits.insert(.notEnabled)
        } else {
            accessibilityTraits.remove(.notEnabled)
        }
    }
}

/// A selectable card for a single choice among a few, used for the default model.
final class SettingsOptionCard: UIControl {
    var onTap: (() -> Void)?

    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let indicator = UIImageView()

    override var isSelected: Bool {
        didSet { applyState() }
    }

    init(title: String, detail: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = Theme.Radius.lg
        layer.cornerCurve = .continuous

        titleLabel.apply(.headline)
        titleLabel.text = title
        detailLabel.apply(.footnote)
        detailLabel.text = detail
        let textStack = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.isUserInteractionEnabled = false

        indicator.contentMode = .scaleAspectFit
        indicator.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        indicator.setContentHuggingPriority(.required, for: .horizontal)
        indicator.setContentCompressionResistancePriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [textStack, indicator])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = Theme.Space.md
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: Theme.Space.md),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Theme.Space.md),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Theme.Space.lg),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Theme.Space.lg),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 64),
        ])

        addAction(UIAction { [weak self] _ in
            HapticsManager.shared.selection()
            self?.onTap?()
        }, for: .touchUpInside)
        isAccessibilityElement = true
        accessibilityLabel = title
        accessibilityValue = detail
        applyState()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var isHighlighted: Bool {
        didSet {
            guard !Motion.isReduced else { return }
            Motion.animate(0.12, options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.alpha = self.isHighlighted ? 0.7 : 1
            }
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyState()
    }

    private func applyState() {
        backgroundColor = isSelected ? Theme.Color.accentSoft : Theme.Color.surface
        layer.borderWidth = isSelected ? 2 : 1
        layer.borderColor = (isSelected ? Theme.Color.accent : Theme.Color.line).resolvedColor(with: traitCollection).cgColor
        indicator.image = UIImage(systemName: isSelected ? "checkmark.circle.fill" : "circle")
        indicator.tintColor = isSelected ? Theme.Color.accentText : Theme.Color.inkTertiary
        accessibilityTraits = isSelected ? [.button, .selected] : .button
    }
}

private final class SettingsMiniScreen: UIView {
    private let card = UIView()

    init(style: UIUserInterfaceStyle) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        overrideUserInterfaceStyle = style
        backgroundColor = Theme.Color.canvas
        isUserInteractionEnabled = false

        card.backgroundColor = Theme.Color.surface
        card.layer.cornerRadius = 8
        card.layer.cornerCurve = .continuous
        card.layer.borderWidth = 1
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)

        let headline = bar(color: Theme.Color.ink, height: 5)
        let detail = bar(color: Theme.Color.inkTertiary, height: 4)
        let pill = bar(color: Theme.Color.accent, height: 14)
        pill.layer.cornerRadius = 7
        card.addSubview(headline)
        card.addSubview(detail)
        addSubview(pill)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            card.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            card.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            card.heightAnchor.constraint(equalToConstant: 32),

            headline.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            headline.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            headline.widthAnchor.constraint(equalTo: card.widthAnchor, multiplier: 0.5),

            detail.topAnchor.constraint(equalTo: headline.bottomAnchor, constant: 5),
            detail.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            detail.widthAnchor.constraint(equalTo: card.widthAnchor, multiplier: 0.72),

            pill.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            pill.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            pill.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.42),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        card.layer.borderColor = Theme.Color.line.resolvedColor(with: traitCollection).cgColor
    }

    private func bar(color: UIColor, height: CGFloat) -> UIView {
        let view = UIView()
        view.backgroundColor = color
        view.layer.cornerRadius = height / 2
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: height).isActive = true
        return view
    }
}

private final class SettingsPreviewFrame: UIView {
    private let diagonalMask = CAShapeLayer()

    var diagonalMaskedView: UIView? {
        didSet { diagonalMaskedView?.layer.mask = diagonalMask }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard diagonalMaskedView != nil else { return }
        let path = UIBezierPath()
        path.move(to: CGPoint(x: bounds.maxX, y: 0))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
        path.addLine(to: CGPoint(x: 0, y: bounds.maxY))
        path.close()
        diagonalMask.path = path.cgPath
        diagonalMask.frame = bounds
    }
}

/// A theme choice drawn as a miniature of the app: a light screen, a dark screen, or the two split on the diagonal for System.
final class SettingsAppearanceTile: UIControl {
    var onTap: (() -> Void)?

    private let previewFrame = SettingsPreviewFrame()
    private let checkView = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
    private let titleLabel = UILabel()
    override var isSelected: Bool {
        didSet { applyState() }
    }

    init(title: String, style: UIUserInterfaceStyle?) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        previewFrame.layer.cornerRadius = Theme.Radius.md
        previewFrame.layer.cornerCurve = .continuous
        previewFrame.clipsToBounds = true
        previewFrame.isUserInteractionEnabled = false
        previewFrame.translatesAutoresizingMaskIntoConstraints = false

        if let style {
            let screen = SettingsMiniScreen(style: style)
            previewFrame.addSubview(screen)
            screen.pinEdges(to: previewFrame)
        } else {
            let light = SettingsMiniScreen(style: .light)
            let dark = SettingsMiniScreen(style: .dark)
            previewFrame.addSubview(light)
            previewFrame.addSubview(dark)
            light.pinEdges(to: previewFrame)
            dark.pinEdges(to: previewFrame)
            previewFrame.diagonalMaskedView = dark
        }

        checkView.tintColor = Theme.Color.accentText
        checkView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .subheadline, scale: .medium)
        checkView.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.apply(.subhead, color: Theme.Color.ink)
        titleLabel.text = title
        titleLabel.textAlignment = .center

        let labelRow = UIStackView(arrangedSubviews: [checkView, titleLabel])
        labelRow.axis = .horizontal
        labelRow.alignment = .center
        labelRow.spacing = 4
        labelRow.isUserInteractionEnabled = false

        let column = UIStackView(arrangedSubviews: [previewFrame, labelRow])
        column.axis = .vertical
        column.alignment = .center
        column.spacing = Theme.Space.sm
        column.isUserInteractionEnabled = false
        column.translatesAutoresizingMaskIntoConstraints = false
        addSubview(column)
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: topAnchor),
            column.bottomAnchor.constraint(equalTo: bottomAnchor),
            column.leadingAnchor.constraint(equalTo: leadingAnchor),
            column.trailingAnchor.constraint(equalTo: trailingAnchor),
            previewFrame.heightAnchor.constraint(equalToConstant: 88),
            previewFrame.widthAnchor.constraint(equalTo: column.widthAnchor),
        ])

        addAction(UIAction { [weak self] _ in
            HapticsManager.shared.selection()
            self?.onTap?()
        }, for: .touchUpInside)
        isAccessibilityElement = true
        accessibilityLabel = title
        applyState()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var isHighlighted: Bool {
        didSet {
            guard !Motion.isReduced else { return }
            Motion.animate(0.12, options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.alpha = self.isHighlighted ? 0.7 : 1
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyBorder()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyBorder()
    }

    private func applyBorder() {
        previewFrame.layer.borderWidth = isSelected ? 2.5 : 1
        previewFrame.layer.borderColor = (isSelected ? Theme.Color.accent : Theme.Color.line).resolvedColor(with: traitCollection).cgColor
    }

    private func applyState() {
        checkView.isHidden = !isSelected
        titleLabel.textColor = isSelected ? Theme.Color.accentText : Theme.Color.ink
        accessibilityTraits = isSelected ? [.button, .selected] : .button
        applyBorder()
    }
}

/// A set of single-choice pills that wraps onto as many lines as the width needs.
final class SettingsChipGroup: UIView {
    struct Option {
        let id: String
        let title: String
        let symbol: String?
    }

    var onSelect: ((String) -> Void)?

    private let options: [Option]
    private var chips: [ChipView] = []
    private var leadingConstraints: [NSLayoutConstraint] = []
    private var topConstraints: [NSLayoutConstraint] = []
    private var heightRef: NSLayoutConstraint!
    private var laidOutWidth: CGFloat = 0
    private let spacing = Theme.Space.sm

    init(options: [Option], selected: String?, label: String) {
        self.options = options
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        heightRef = heightAnchor.constraint(equalToConstant: 38)
        heightRef.isActive = true

        for option in options {
            let chip = ChipView(title: option.title, symbol: option.symbol, isSelected: option.id == selected)
            chip.onTap = { [weak self] in
                self?.select(option.id)
                self?.onSelect?(option.id)
            }
            addSubview(chip)
            let leading = chip.leadingAnchor.constraint(equalTo: leadingAnchor)
            let top = chip.topAnchor.constraint(equalTo: topAnchor)
            leadingConstraints.append(leading)
            topConstraints.append(top)
            NSLayoutConstraint.activate([
                leading,
                top,
                chip.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            ])
            chips.append(chip)
        }
        accessibilityContainerType = .semanticGroup
        accessibilityLabel = label
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    var isEnabled = true {
        didSet {
            isUserInteractionEnabled = isEnabled
            alpha = isEnabled ? 1 : 0.5
            chips.forEach { $0.accessibilityTraits = isEnabled ? ($0.isSelected ? [.button, .selected] : .button) : [.button, .notEnabled] }
        }
    }

    func select(_ id: String?) {
        for (option, chip) in zip(options, chips) {
            chip.isSelected = option.id == id
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, abs(bounds.width - laidOutWidth) > 0.5 else { return }
        laidOutWidth = bounds.width
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for (index, chip) in chips.enumerated() {
            var size = chip.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
            size.width = min(size.width, bounds.width)
            if x > 0, x + size.width > bounds.width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            leadingConstraints[index].constant = x
            topConstraints[index].constant = y
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        heightRef.constant = y + rowHeight
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        laidOutWidth = 0
        setNeedsLayout()
    }
}

/// A tappable field showing an identifier that copies itself to the pasteboard.
final class SettingsCopyableIDView: UIControl {
    private let valueLabel = UILabel()
    private let iconView = UIImageView(image: UIImage(systemName: "doc.on.doc"))
    private let value: String
    private var resetTask: Task<Void, Never>?

    init(title: String, value: String) {
        self.value = value
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = Theme.Radius.md
        layer.cornerCurve = .continuous
        backgroundColor = Theme.Color.fill

        let caption = UILabel()
        caption.setStyledText(title, .caption)
        valueLabel.apply(.footnote, color: Theme.Color.ink)
        valueLabel.text = value
        valueLabel.lineBreakMode = .byCharWrapping
        let textStack = UIStackView(arrangedSubviews: [caption, valueLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.isUserInteractionEnabled = false

        iconView.tintColor = Theme.Color.accentText
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .subheadline, scale: .medium)
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        iconView.setContentCompressionResistancePriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [textStack, iconView])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = Theme.Space.md
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: Theme.Space.md),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Theme.Space.md),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Theme.Space.lg),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Theme.Space.lg),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 52),
        ])

        addAction(UIAction { [weak self] _ in self?.copy() }, for: .touchUpInside)
        describe(title, hint: String(localized: "Copies your user ID"), value: value, traits: .button)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var isHighlighted: Bool {
        didSet {
            guard !Motion.isReduced else { return }
            Motion.animate(0.12, options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.alpha = self.isHighlighted ? 0.7 : 1
            }
        }
    }

    private func copy() {
        UIPasteboard.general.string = value
        HapticManager.shared.notification(.success)
        Announce.say(String(localized: "Copied!"))
        iconView.image = UIImage(systemName: "checkmark")
        iconView.tintColor = Theme.Color.success
        resetTask?.cancel()
        resetTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled, let self else { return }
            self.iconView.image = UIImage(systemName: "doc.on.doc")
            self.iconView.tintColor = Theme.Color.accentText
        }
    }
}
