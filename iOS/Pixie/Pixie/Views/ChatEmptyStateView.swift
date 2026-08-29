import UIKit

struct StarterPrompt: Hashable {
    let icon: String
    let text: String
}

enum StarterPrompts {
    static let all: [StarterPrompt] = [
        StarterPrompt(icon: "bolt.fill", text: String(localized: "Cyberpunk anime portrait, neon rain")),
        StarterPrompt(icon: "snowflake", text: String(localized: "Cozy cabin in the snow, watercolor")),
        StarterPrompt(icon: "cup.and.saucer.fill", text: String(localized: "Minimal logo for a coffee brand")),
        StarterPrompt(icon: "shoe.fill", text: String(localized: "Product photo of sneakers on white")),
        StarterPrompt(icon: "sun.horizon.fill", text: String(localized: "Retro 80s synthwave sunset")),
        StarterPrompt(icon: "cat.fill", text: String(localized: "Cute cat astronaut sticker, transparent background"))
    ]
}

final class StarterChipView: UIVisualEffectView {
    private static let horizontalPadding: CGFloat = 16
    private static let verticalPadding: CGFloat = 11
    private static let iconSpacing: CGFloat = 9

    private let label = UILabel()
    private let icon: UIImageView
    private let text: String

    init(prompt: StarterPrompt, accent: UIColor, action: @escaping () -> Void) {
        self.text = prompt.text
        self.icon = UIImageView(image: UIImage(systemName: prompt.icon))
        super.init(effect: GlassMaterial.effect(interactive: true))
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 21
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = UIColor.separator.withAlphaComponent(0.35).cgColor
        clipsToBounds = true

        icon.tintColor = accent
        icon.contentMode = .scaleAspectFit
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .subheadline, scale: .medium)
        icon.setContentHuggingPriority(.required, for: .horizontal)
        icon.setContentCompressionResistancePriority(.required, for: .horizontal)

        label.text = prompt.text
        label.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: .systemFont(ofSize: 15, weight: .medium))
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .label
        label.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = Self.iconSpacing
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        let button = UIButton(type: .custom, primaryAction: UIAction { _ in action() })
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityLabel = prompt.text
        PointerInteractionHelper.addPointerInteraction(to: button)
        contentView.addSubview(button)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Self.verticalPadding),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Self.verticalPadding),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Self.horizontalPadding),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Self.horizontalPadding),
            button.topAnchor.constraint(equalTo: contentView.topAnchor),
            button.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        let setHighlighted: (Bool) -> Void = { [weak self] highlighted in
            UIView.animate(withDuration: highlighted ? 0.1 : 0.2) {
                self?.alpha = highlighted ? 0.55 : 1
                self?.transform = highlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
            }
        }
        button.addAction(UIAction { _ in setHighlighted(true) }, for: .touchDown)
        button.addAction(UIAction { _ in setHighlighted(false) }, for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func measure(maxWidth: CGFloat) -> CGSize {
        let font = label.font ?? .preferredFont(forTextStyle: .subheadline)
        let iconSize = icon.intrinsicContentSize
        let chrome = Self.horizontalPadding * 2 + iconSize.width + Self.iconSpacing
        let available = max(1, maxWidth - chrome)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let singleLine = (text as NSString).size(withAttributes: attributes)
        if ceil(singleLine.width) <= available {
            setPreferredMaxLayoutWidth(ceil(singleLine.width))
            return CGSize(
                width: ceil(chrome + singleLine.width),
                height: ceil(max(singleLine.height, iconSize.height)) + Self.verticalPadding * 2
            )
        }
        let bounding = (text as NSString).boundingRect(
            with: CGSize(width: available, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        setPreferredMaxLayoutWidth(available)
        return CGSize(
            width: maxWidth,
            height: ceil(max(bounding.height, iconSize.height)) + Self.verticalPadding * 2
        )
    }

    private func setPreferredMaxLayoutWidth(_ width: CGFloat) {
        guard abs(label.preferredMaxLayoutWidth - width) > 0.5 else { return }
        label.preferredMaxLayoutWidth = width
    }
}

final class WrappingChipsView: UIView {
    var horizontalSpacing: CGFloat = 8
    var verticalSpacing: CGFloat = 8

    private var chips: [StarterChipView] = []
    private lazy var heightConstraint: NSLayoutConstraint = {
        let constraint = heightAnchor.constraint(equalToConstant: 0)
        constraint.priority = UILayoutPriority(999)
        constraint.isActive = true
        return constraint
    }()

    func setChips(_ views: [StarterChipView]) {
        chips.forEach { $0.removeFromSuperview() }
        chips = views
        views.forEach { addSubview($0) }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let height = layout(for: bounds.width, applying: true)
        if abs(heightConstraint.constant - height) > 0.5 {
            heightConstraint.constant = height
        }
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width, height: layout(for: size.width, applying: false))
    }

    private func chipSize(_ chip: StarterChipView, maxWidth: CGFloat) -> CGSize {
        chip.measure(maxWidth: maxWidth)
    }

    private func layout(for width: CGFloat, applying: Bool) -> CGFloat {
        guard width > 0, !chips.isEmpty else { return 0 }
        var rows: [[StarterChipView]] = [[]]
        var rowWidths: [CGFloat] = [0]
        for chip in chips {
            let chipWidth = chipSize(chip, maxWidth: width).width
            let isFirstInRow = rows[rows.count - 1].isEmpty
            let needed = isFirstInRow ? chipWidth : rowWidths[rowWidths.count - 1] + horizontalSpacing + chipWidth
            if needed > width && !isFirstInRow {
                rows.append([chip])
                rowWidths.append(chipWidth)
            } else {
                rows[rows.count - 1].append(chip)
                rowWidths[rowWidths.count - 1] = needed
            }
        }
        var y: CGFloat = 0
        let isRTL = effectiveUserInterfaceLayoutDirection == .rightToLeft
        for (index, row) in rows.enumerated() {
            var rowHeight: CGFloat = 0
            var x = ((width - rowWidths[index]) / 2).rounded()
            for chip in row {
                let size = chipSize(chip, maxWidth: width)
                if applying {
                    chip.frame = CGRect(
                        x: isRTL ? width - x - size.width : x,
                        y: y,
                        width: size.width,
                        height: size.height
                    )
                }
                x += size.width + horizontalSpacing
                rowHeight = max(rowHeight, size.height)
            }
            y += rowHeight + (index == rows.count - 1 ? 0 : verticalSpacing)
        }
        return y
    }
}

final class ChatEmptyStateView: UIView {
    var onPromptSelected: ((String) -> Void)?

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let chipsContainer = WrappingChipsView()
    private let haptics = HapticManager.shared

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .clear

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.keyboardDismissMode = .interactive
        addSubview(scrollView)

        let glyphContainer = UIView()
        glyphContainer.translatesAutoresizingMaskIntoConstraints = false
        let glyph = UIImageView(image: UIImage(systemName: "sparkles"))
        glyph.tintColor = tintColor
        glyph.contentMode = .scaleAspectFit
        glyph.translatesAutoresizingMaskIntoConstraints = false
        glyph.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
            font: UIFont.preferredFont(forTextStyle: .largeTitle),
            scale: .large
        )
        glyphContainer.addSubview(glyph)
        NSLayoutConstraint.activate([
            glyph.topAnchor.constraint(equalTo: glyphContainer.topAnchor),
            glyph.bottomAnchor.constraint(equalTo: glyphContainer.bottomAnchor),
            glyph.centerXAnchor.constraint(equalTo: glyphContainer.centerXAnchor)
        ])

        let titleLabel = UILabel()
        titleLabel.text = String(localized: "What will you make today?")
        titleLabel.font = UIFontMetrics(forTextStyle: .title2).scaledFont(for: .systemFont(ofSize: 24, weight: .bold))
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        let subtitleLabel = UILabel()
        subtitleLabel.text = String(localized: "Describe an image below, or start from one of these.")
        subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        chipsContainer.translatesAutoresizingMaskIntoConstraints = false
        chipsContainer.setChips(StarterPrompts.all.map(makeChip))

        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = 12
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(glyphContainer)
        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(subtitleLabel)
        contentStack.addArrangedSubview(chipsContainer)
        contentStack.setCustomSpacing(18, after: glyphContainer)
        contentStack.setCustomSpacing(6, after: titleLabel)
        contentStack.setCustomSpacing(28, after: subtitleLabel)
        scrollView.addSubview(contentStack)

        let centering = contentStack.centerYAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerYAnchor)
        centering.priority = .defaultHigh

        let columnWidth = contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -48)
        columnWidth.priority = .defaultHigh

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            contentStack.topAnchor.constraint(greaterThanOrEqualTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            contentStack.centerXAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerXAnchor),
            contentStack.leadingAnchor.constraint(greaterThanOrEqualTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(lessThanOrEqualTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -24),
            contentStack.widthAnchor.constraint(lessThanOrEqualToConstant: 520),
            columnWidth,
            centering,
            scrollView.contentLayoutGuide.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            scrollView.contentLayoutGuide.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor)
        ])
    }

    private func makeChip(_ prompt: StarterPrompt) -> StarterChipView {
        StarterChipView(prompt: prompt, accent: tintColor) { [weak self] in
            self?.haptics.impact(.click)
            self?.onPromptSelected?(prompt.text)
        }
    }

}

