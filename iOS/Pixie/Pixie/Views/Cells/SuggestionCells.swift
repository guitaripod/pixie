import UIKit

extension UIColor {
    /// The same hue, darkened just enough that white text on it reaches `minimumContrast`.
    func darkenedForWhiteText(minimumContrast: CGFloat = 4.5) -> UIColor {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return self }
        for _ in 0..<24 {
            let contrast = 1.05 / (Self.relativeLuminance(red: red, green: green, blue: blue) + 0.05)
            if contrast >= minimumContrast { break }
            red *= 0.94
            green *= 0.94
            blue *= 0.94
        }
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    private static func relativeLuminance(red: CGFloat, green: CGFloat, blue: CGFloat) -> CGFloat {
        func linear(_ component: CGFloat) -> CGFloat {
            component <= 0.03928 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }
}


/// The shared look of a tile on the start screen: a surface with a hairline, a soft shadow in light
/// mode, and an accent-tinted state when marked. The shadow lives on the cell and the clipping on
/// its content view, so rounded corners never cut it off.
class CardCell: UICollectionViewCell {
    var cardRadius: CGFloat = Theme.Radius.lg {
        didSet { applyChrome() }
    }

    var showsHairline = true {
        didSet { applyChrome() }
    }

    var isMarked = false {
        didSet { applyChrome() }
    }

    private let markOverlay = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.clipsToBounds = true
        contentView.layer.cornerCurve = .continuous
        layer.cornerCurve = .continuous
        markOverlay.isUserInteractionEnabled = false
        markOverlay.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(markOverlay)
        markOverlay.pinEdges(to: contentView)
        applyChrome()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: cardRadius).cgPath
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyChrome()
    }

    private func applyChrome() {
        let isDark = traitCollection.userInterfaceStyle == .dark
        contentView.backgroundColor = Theme.Color.surface
        contentView.layer.cornerRadius = cardRadius
        layer.cornerRadius = cardRadius
        markOverlay.backgroundColor = Theme.Color.accentSoft
        markOverlay.isHidden = !isMarked
        let borderColor = isMarked ? Theme.Color.accent : Theme.Color.line
        contentView.layer.borderWidth = isMarked ? 2 : (showsHairline ? 1 : 0)
        contentView.layer.borderColor = borderColor.resolvedColor(with: traitCollection).cgColor
        layer.shadowColor = UIColor(hex: 0x1B0F4A).cgColor
        layer.shadowOpacity = isDark || isMarked ? 0 : 0.07
        layer.shadowRadius = 14
        layer.shadowOffset = CGSize(width: 0, height: 6)
    }
}


enum ChipSizing {
    /// How wide a `ChipView` with this title and symbol lays out at the current text size.
    static func width(title: String, symbol: String?) -> CGFloat {
        let chip = ChipView(title: title, symbol: symbol)
        return ceil(chip.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).width)
    }

}


class SuggestionsSectionHeaderView: UICollectionReusableView {
    enum Prominence {
        case hero
        case section
        case label
    }

    static let reuseIdentifier = "SuggestionsSectionHeaderView"
    let titleLabel = UILabel()
    let subtitleLabel = UILabel()
    let actionButton = PixieButton(style: .plain, size: .small)
    private let textStack = UIStackView()
    private var leadingConstraint: NSLayoutConstraint!
    private var trailingConstraint: NSLayoutConstraint!
    private var bottomConstraint: NSLayoutConstraint!

    var horizontalInset: CGFloat = 0 {
        didSet {
            leadingConstraint.constant = horizontalInset
            trailingConstraint.constant = -horizontalInset
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    private func setupUI() {
        titleLabel.accessibilityTraits = .header
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)
        textStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textStack)
        actionButton.isHidden = true
        addSubview(actionButton)
        leadingConstraint = textStack.leadingAnchor.constraint(equalTo: leadingAnchor)
        trailingConstraint = textStack.trailingAnchor.constraint(equalTo: trailingAnchor)
        bottomConstraint = textStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Theme.Space.md)
        NSLayoutConstraint.activate([
            textStack.topAnchor.constraint(equalTo: topAnchor),
            leadingConstraint,
            trailingConstraint,
            bottomConstraint,
            actionButton.trailingAnchor.constraint(equalTo: textStack.trailingAnchor, constant: Theme.Space.md),
            actionButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor)
        ])
    }
    func configure(title: String, subtitle: String?, actionTitle: String? = nil, prominence: Prominence = .section) {
        switch prominence {
        case .hero:
            titleLabel.setStyledText(title, .title)
            bottomConstraint.constant = -Theme.Space.lg
        case .section:
            titleLabel.setStyledText(title, .title2)
            bottomConstraint.constant = -Theme.Space.md
        case .label:
            titleLabel.setStyledText(title, .caption)
            bottomConstraint.constant = -Theme.Space.sm
        }
        if let subtitle {
            subtitleLabel.setStyledText(subtitle, .footnote)
            subtitleLabel.isHidden = false
        } else {
            subtitleLabel.attributedText = nil
            subtitleLabel.isHidden = true
        }
        if let actionTitle {
            actionButton.title = actionTitle
            actionButton.isHidden = false
        } else {
            actionButton.isHidden = true
        }
    }
}


class CreativePromptsHeaderView: UICollectionReusableView {
    static let reuseIdentifier = "CreativePromptsHeaderView"
    let titleLabel = UILabel()
    let subtitleLabel = UILabel()
    let scrollView = UIScrollView()
    let stackView = UIStackView()
    var categories: [CreativePrompt] = []
    var selectedIndex = 0
    var onCategorySelected: ((Int) -> Void)?
    private var scrollLeading: NSLayoutConstraint!
    private var scrollTrailing: NSLayoutConstraint!

    var horizontalInset: CGFloat = 0 {
        didSet {
            scrollLeading.constant = -horizontalInset
            scrollTrailing.constant = horizontalInset
            stackView.layoutMargins = UIEdgeInsets(top: 0, left: horizontalInset, bottom: 0, right: horizontalInset)
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    private func setupUI() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.accessibilityTraits = .header
        addSubview(titleLabel)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subtitleLabel)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        addSubview(scrollView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = Theme.Space.sm
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.distribution = .fill
        stackView.alignment = .center
        scrollView.addSubview(stackView)

        scrollLeading = scrollView.leadingAnchor.constraint(equalTo: leadingAnchor)
        scrollTrailing = scrollView.trailingAnchor.constraint(equalTo: trailingAnchor)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            scrollLeading,
            scrollTrailing,
            scrollView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: Theme.Space.md),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Theme.Space.sm),
            scrollView.frameLayoutGuide.heightAnchor.constraint(equalTo: scrollView.contentLayoutGuide.heightAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor)
        ])
    }
    func configure(categories: [CreativePrompt], selectedIndex: Int, onCategorySelected: @escaping (Int) -> Void) {
        self.categories = categories
        self.selectedIndex = selectedIndex
        self.onCategorySelected = onCategorySelected
        titleLabel.setStyledText(String(localized: "Creative Prompts"), .title2)
        subtitleLabel.setStyledText(String(localized: "Tap a category, then select a prompt"), .footnote)
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, category) in categories.enumerated() {
            let chip = ChipView(title: category.category, symbol: category.symbol, isSelected: index == selectedIndex)
            chip.onTap = { [weak self] in
                self?.selectCategory(at: index)
            }
            stackView.addArrangedSubview(chip)
        }
    }
    private func selectCategory(at index: Int) {
        guard index != selectedIndex else { return }
        for (position, view) in stackView.arrangedSubviews.enumerated() {
            (view as? ChipView)?.isSelected = position == index
        }
        selectedIndex = index
        onCategorySelected?(index)
    }
}


/// A recent library photo: a rounded square thumbnail that fills the photo strip.
class ImageCell: UICollectionViewCell {
    static let reuseIdentifier = "ImageCell"
    let imageView = UIImageView()
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    private func setupUI() {
        contentView.layer.cornerRadius = Theme.Radius.md
        contentView.layer.cornerCurve = .continuous
        contentView.clipsToBounds = true
        contentView.backgroundColor = Theme.Color.fill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        contentView.addSubview(imageView)
        imageView.pinEdges(to: contentView)
        isAccessibilityElement = true
        accessibilityLabel = String(localized: "Recent photo")
        accessibilityTraits = .button
    }
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = Theme.Color.line.resolvedColor(with: traitCollection).cgColor
    }
    func configure(with image: UIImage?) {
        imageView.image = image
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = Theme.Color.line.resolvedColor(with: traitCollection).cgColor
    }
}


/// The picked photo as a 3:4 card with a Change capsule beside it, and a remove control when the
/// owner handles removal. When the row is too narrow for a readable column beside the photo the hint
/// and the capsule move under it; a compact row (short windows) uses a smaller photo.
final class SelectedPhotoCell: UICollectionViewCell {
    static let reuseIdentifier = "SelectedPhotoCell"
    static let cardWidth: CGFloat = 160
    static let compactCardWidth: CGFloat = 96
    private static let minimumColumnWidth: CGFloat = 168
    private static let minimumCompactColumnWidth: CGFloat = 148
    var onChange: (() -> Void)?
    var onRemove: (() -> Void)?
    var isCompact = false {
        didSet {
            guard oldValue != isCompact else { return }
            setNeedsLayout()
        }
    }
    private let cardView = UIView()
    private let photoView = UIImageView()
    private let removeButton = UIButton(type: .custom)
    private let removeDisc = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let hintLabel = UILabel()
    private let column = UIStackView()
    private var cardWidthConstraint: NSLayoutConstraint!
    private var besideConstraints: [NSLayoutConstraint] = []
    private var stackedConstraints: [NSLayoutConstraint] = []
    private var appliedWidth: CGFloat = -1
    private var appliedCompact: Bool?
    private lazy var changeButton = PixieButton(style: .secondary, size: .medium, title: String(localized: "Change"), symbol: "photo.on.rectangle") { [weak self] in
        self?.onChange?()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    private func setupUI() {
        isAccessibilityElement = false
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.layer.cornerRadius = Theme.Radius.xl - 4
        cardView.layer.cornerCurve = .continuous
        cardView.layer.shadowColor = UIColor(hex: 0x1B0F4A).cgColor
        cardView.layer.shadowRadius = 18
        cardView.layer.shadowOffset = CGSize(width: 0, height: 8)
        cardView.describe(String(localized: "Your photo"), traits: [.image, .selected])
        contentView.addSubview(cardView)

        photoView.translatesAutoresizingMaskIntoConstraints = false
        photoView.contentMode = .scaleAspectFill
        photoView.clipsToBounds = true
        photoView.backgroundColor = Theme.Color.fill
        photoView.layer.cornerRadius = Theme.Radius.xl - 4
        photoView.layer.cornerCurve = .continuous
        photoView.layer.borderWidth = 1
        cardView.addSubview(photoView)
        photoView.pinEdges(to: cardView)

        let tap = UITapGestureRecognizer(target: self, action: #selector(cardTapped))
        cardView.addGestureRecognizer(tap)

        removeButton.translatesAutoresizingMaskIntoConstraints = false
        removeButton.accessibilityLabel = String(localized: "Remove photo")
        removeButton.addAction(UIAction { [weak self] _ in
            HapticsManager.shared.selection()
            self?.onRemove?()
        }, for: .touchUpInside)
        removeDisc.translatesAutoresizingMaskIntoConstraints = false
        removeDisc.isUserInteractionEnabled = false
        removeDisc.layer.cornerRadius = 14
        removeDisc.clipsToBounds = true
        let glyph = UIImageView(image: UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)))
        glyph.tintColor = .white
        glyph.translatesAutoresizingMaskIntoConstraints = false
        removeDisc.contentView.addSubview(glyph)
        removeButton.addSubview(removeDisc)
        contentView.addSubview(removeButton)

        hintLabel.apply(.callout)
        hintLabel.text = String(localized: "Tap an edit below, or describe your own")
        hintLabel.lineBreakMode = .byTruncatingTail
        changeButton.translatesAutoresizingMaskIntoConstraints = false
        changeButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        changeButton.setContentHuggingPriority(.required, for: .horizontal)
        column.addArrangedSubview(hintLabel)
        column.addArrangedSubview(changeButton)
        column.axis = .vertical
        column.alignment = .leading
        column.spacing = Theme.Space.md
        column.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(column)

        let columnCentering = column.centerYAnchor.constraint(equalTo: cardView.centerYAnchor)
        columnCentering.priority = .defaultHigh
        cardWidthConstraint = cardView.widthAnchor.constraint(equalToConstant: Self.cardWidth)
        besideConstraints = [
            columnCentering,
            column.leadingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: Theme.Space.lg),
            column.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor),
            contentView.bottomAnchor.constraint(greaterThanOrEqualTo: column.bottomAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Theme.Space.sm)
        ]
        stackedConstraints = [
            column.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            column.topAnchor.constraint(equalTo: cardView.bottomAnchor, constant: Theme.Space.lg),
            column.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Theme.Space.sm)
        ]
        NSLayoutConstraint.activate([
            cardWidthConstraint,
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardView.heightAnchor.constraint(equalTo: cardView.widthAnchor, multiplier: 4.0 / 3.0),
            removeButton.widthAnchor.constraint(equalToConstant: 44),
            removeButton.heightAnchor.constraint(equalToConstant: 44),
            removeButton.centerXAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -22),
            removeButton.centerYAnchor.constraint(equalTo: cardView.topAnchor, constant: 22),
            removeDisc.widthAnchor.constraint(equalToConstant: 28),
            removeDisc.heightAnchor.constraint(equalToConstant: 28),
            removeDisc.centerXAnchor.constraint(equalTo: removeButton.centerXAnchor),
            removeDisc.centerYAnchor.constraint(equalTo: removeButton.centerYAnchor),
            glyph.centerXAnchor.constraint(equalTo: removeDisc.contentView.centerXAnchor),
            glyph.centerYAnchor.constraint(equalTo: removeDisc.contentView.centerYAnchor),
            column.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
        NSLayoutConstraint.activate(besideConstraints)
        applyAppearance()
    }

    /// The photo's width for a row, and whether the hint column goes under it, from the row's width alone.
    private static func arrangement(forWidth width: CGFloat, compact: Bool) -> (photoWidth: CGFloat, stacked: Bool) {
        let photoWidth = compact ? compactCardWidth : cardWidth
        let column = width - photoWidth - Theme.Space.lg
        let stacked = column < (compact ? minimumCompactColumnWidth : minimumColumnWidth) || UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory
        return (photoWidth, stacked)
    }

    /// Switches between the two arrangements for a row `width` points wide; a no-op while neither the
    /// width nor the compact flag changed.
    private func applyArrangement(forWidth width: CGFloat) {
        guard width > 0, width != appliedWidth || appliedCompact != isCompact else { return }
        appliedWidth = width
        appliedCompact = isCompact
        let arrangement = Self.arrangement(forWidth: width, compact: isCompact)
        cardWidthConstraint.constant = arrangement.photoWidth
        if arrangement.stacked {
            NSLayoutConstraint.deactivate(besideConstraints)
            NSLayoutConstraint.activate(stackedConstraints)
            hintLabel.numberOfLines = 2
        } else {
            NSLayoutConstraint.deactivate(stackedConstraints)
            NSLayoutConstraint.activate(besideConstraints)
            hintLabel.numberOfLines = 0
        }
    }

    /// The row's height at the current text size for a row `width` points wide, measured from a real cell.
    static func height(forWidth width: CGFloat, compact: Bool = false) -> CGFloat {
        let probe = SelectedPhotoCell(frame: CGRect(x: 0, y: 0, width: width, height: 400))
        probe.isCompact = compact
        probe.applyArrangement(forWidth: width)
        let size = probe.contentView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        return ceil(size.height)
    }
    @objc private func cardTapped() {
        HapticsManager.shared.selection()
        onChange?()
    }
    override func layoutSubviews() {
        applyArrangement(forWidth: contentView.bounds.width)
        super.layoutSubviews()
        cardView.layer.shadowPath = UIBezierPath(roundedRect: cardView.bounds, cornerRadius: cardView.layer.cornerRadius).cgPath
    }
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyAppearance()
        if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
            appliedWidth = -1
            setNeedsLayout()
        }
    }
    private func applyAppearance() {
        let isDark = traitCollection.userInterfaceStyle == .dark
        cardView.layer.shadowOpacity = isDark ? 0 : 0.14
        photoView.layer.borderColor = Theme.Color.line.resolvedColor(with: traitCollection).cgColor
    }
    func configure(with image: UIImage?, canRemove: Bool, compact: Bool = false) {
        photoView.image = image
        removeButton.isHidden = !canRemove
        isCompact = compact
    }
}


/// The empty-state hero: a wide drop-zone with a dashed gradient hairline that asks for a photo.
final class PhotoDropZoneCell: UICollectionViewCell {
    static let reuseIdentifier = "PhotoDropZoneCell"
    private let card = UIView()
    private let dashBorder = DashedGradientBorderView()
    private let badge = IconBadge(symbol: "plus", size: 56, symbolScale: 0.5)
    private let titleLabel = UILabel()
    private static let cornerRadius = Theme.Radius.xl - 4
    static let compactHeight: CGFloat = 136
    static let compactRowHeight: CGFloat = 96
    private let stack = UIStackView()
    private var ratioConstraint: NSLayoutConstraint!
    private var compactHeightConstraint: NSLayoutConstraint!

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    private func setupUI() {
        card.translatesAutoresizingMaskIntoConstraints = false
        card.layer.cornerRadius = Self.cornerRadius
        card.layer.cornerCurve = .continuous
        contentView.addSubview(card)
        card.pinEdges(to: contentView)

        dashBorder.cornerRadius = Self.cornerRadius
        card.addSubview(dashBorder)
        dashBorder.pinEdges(to: card)

        titleLabel.apply(.headline)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.text = String(localized: "Choose a photo")

        stack.addArrangedSubview(badge)
        stack.addArrangedSubview(titleLabel)
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = Theme.Space.md
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        ratioConstraint = contentView.heightAnchor.constraint(greaterThanOrEqualTo: contentView.widthAnchor, multiplier: 9.0 / 16.0)
        ratioConstraint.priority = UILayoutPriority(999)
        compactHeightConstraint = contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: Self.compactHeight)
        compactHeightConstraint.priority = UILayoutPriority(999)
        NSLayoutConstraint.activate([
            ratioConstraint,
            stack.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: card.leadingAnchor, constant: Theme.Space.xl),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -Theme.Space.xl),
            stack.topAnchor.constraint(greaterThanOrEqualTo: card.topAnchor, constant: Theme.Space.xl),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -Theme.Space.xl)
        ])

        describe(String(localized: "Choose a photo"), hint: String(localized: "Pick one, then tap an edit"), traits: .button)
        applyAppearance()
    }
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyAppearance()
    }
    private func applyAppearance() {
        card.backgroundColor = Theme.Color.accentSoft
    }
    /// A compact card keeps a fixed minimum height instead of the 16:9 ratio, so a short window still
    /// shows what comes after it; unless `stacksVertically` it lays the glyph and the title side by side to stay shorter.
    func configure(compact: Bool, stacksVertically: Bool = true) {
        let horizontal = compact && !stacksVertically
        ratioConstraint.isActive = !compact
        compactHeightConstraint.constant = horizontal ? Self.compactRowHeight : Self.compactHeight
        compactHeightConstraint.isActive = compact
        stack.axis = horizontal ? .horizontal : .vertical
        stack.alignment = .center
    }
}


/// A dashed rounded outline drawn in the brand gradient: the gradient layer is masked by the dashed stroke.
private final class DashedGradientBorderView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }
    private var gradientLayer: CAGradientLayer { layer as! CAGradientLayer }
    private let dashShape = CAShapeLayer()
    var cornerRadius: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        translatesAutoresizingMaskIntoConstraints = false
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        dashShape.fillColor = nil
        dashShape.strokeColor = UIColor.black.cgColor
        dashShape.lineWidth = 1.5
        dashShape.lineDashPattern = [7, 6]
        dashShape.lineCap = .round
        gradientLayer.mask = dashShape
        applyColors()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        dashShape.frame = bounds
        dashShape.path = UIBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), cornerRadius: cornerRadius).cgPath
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyColors()
    }

    private func applyColors() {
        gradientLayer.colors = Theme.Color.gradient.map { $0.resolvedColor(with: traitCollection).cgColor }
    }
}


/// The first-run shortcut next to "Choose a photo": the old photo the onboarding restores,
/// offered as a ready-made input so a new person can see a result before using their own photo.
class SampleTileCell: CardCell {
    static let reuseIdentifier = "SampleTileCell"
    private let thumbnailView = UIImageView()
    private let badgeView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let textStack = UIStackView()
    private static let title = String(localized: "Try a sample photo")
    private static let subtitle = String(localized: "Restores an old photo with one of your free images")
    private static let thumbnailWidth: CGFloat = 54
    private static let padding: CGFloat = 12

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    private func setupUI() {
        thumbnailView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailView.image = UIImage(named: "onboarding_before_1")
        thumbnailView.contentMode = .scaleAspectFill
        thumbnailView.layer.cornerRadius = Theme.Radius.sm
        thumbnailView.layer.cornerCurve = .continuous
        thumbnailView.clipsToBounds = true
        contentView.addSubview(thumbnailView)

        badgeView.translatesAutoresizingMaskIntoConstraints = false
        badgeView.image = UIImage(systemName: "sparkles")
        badgeView.tintColor = .white
        badgeView.backgroundColor = Theme.Color.accent
        badgeView.contentMode = .center
        badgeView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)
        badgeView.layer.cornerRadius = 11
        contentView.addSubview(badgeView)

        titleLabel.apply(.subhead, color: Theme.Color.ink)
        titleLabel.text = Self.title
        subtitleLabel.apply(.footnote)
        subtitleLabel.text = Self.subtitle
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)
        textStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textStack)

        let padding = Self.padding
        let textCentering = textStack.centerYAnchor.constraint(equalTo: thumbnailView.centerYAnchor)
        textCentering.priority = .defaultHigh
        NSLayoutConstraint.activate([
            textCentering,
            thumbnailView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            thumbnailView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: padding),
            thumbnailView.widthAnchor.constraint(equalToConstant: Self.thumbnailWidth),
            thumbnailView.heightAnchor.constraint(equalTo: thumbnailView.widthAnchor, multiplier: 4.0 / 3.0),
            thumbnailView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -padding),

            badgeView.widthAnchor.constraint(equalToConstant: 22),
            badgeView.heightAnchor.constraint(equalToConstant: 22),
            badgeView.leadingAnchor.constraint(equalTo: thumbnailView.leadingAnchor, constant: -6),
            badgeView.topAnchor.constraint(equalTo: thumbnailView.topAnchor, constant: -6),

            textStack.leadingAnchor.constraint(equalTo: thumbnailView.trailingAnchor, constant: padding),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            textStack.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: padding),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -padding)
        ])

        describe("\(Self.title). \(Self.subtitle).", traits: .button)
    }

    /// The card's height at the current text size for a card `width` points wide, measured from a real cell.
    static func height(forWidth width: CGFloat) -> CGFloat {
        let probe = SampleTileCell(frame: CGRect(x: 0, y: 0, width: width, height: 400))
        probe.updateLabelWidths(forCellWidth: width)
        let size = probe.contentView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        return ceil(size.height)
    }

    private func updateLabelWidths(forCellWidth width: CGFloat) {
        let textWidth = max(0, width - Self.padding - Self.thumbnailWidth - Self.padding - Self.padding)
        titleLabel.preferredMaxLayoutWidth = textWidth
        subtitleLabel.preferredMaxLayoutWidth = textWidth
    }

    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        updateLabelWidths(forCellWidth: layoutAttributes.size.width)
        return super.preferredLayoutAttributesFitting(layoutAttributes)
    }

    /// The text column is whatever the thumbnail and the margins leave, so both labels are told that
    /// width before the cell lays out; a label measured without one reports a single line and truncates.
    override func layoutSubviews() {
        updateLabelWidths(forCellWidth: contentView.bounds.width)
        super.layoutSubviews()
    }
}


/// A template or edit idea as a `ChipView`; the cell is the touch target, the chip only draws.
class QuickActionCell: UICollectionViewCell {
    static let reuseIdentifier = "QuickActionCell"
    private var chip: ChipView?
    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = true
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func prepareForReuse() {
        super.prepareForReuse()
        chip?.removeFromSuperview()
        chip = nil
    }
    func configure(with action: QuickAction, isSelected: Bool = false, category: String) {
        chip?.removeFromSuperview()
        let chip = ChipView(title: action.title, symbol: action.icon, isSelected: isSelected)
        chip.isUserInteractionEnabled = false
        chip.isAccessibilityElement = false
        contentView.addSubview(chip)
        NSLayoutConstraint.activate([
            chip.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            chip.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            chip.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
        self.chip = chip
        accessibilityLabel = String(localized: "\(category): \(action.title)")
        accessibilityTraits = isSelected ? [.button, .selected] : .button
    }
}


class PromptCardCell: CardCell {
    static let reuseIdentifier = "PromptCardCell"
    let label = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    private func setupUI() {
        cardRadius = Theme.Radius.md
        label.translatesAutoresizingMaskIntoConstraints = false
        label.apply(.footnote, color: Theme.Color.ink)
        label.lineBreakMode = .byTruncatingTail
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])
        isAccessibilityElement = true
        updateLineLimit()
    }
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
            updateLineLimit()
        }
    }
    /// Three lines with an ellipsis at the default text size; every line once the text is
    /// larger, where the card grows to fit instead of cutting the idea off.
    private func updateLineLimit() {
        label.numberOfLines = traitCollection.preferredContentSizeCategory > .large ? 0 : 3
    }
    func configure(with prompt: String, color: UIColor, isSelected: Bool = false, category: String) {
        label.text = prompt
        isMarked = isSelected
        accessibilityLabel = String(localized: "\(category): \(prompt)")
        accessibilityTraits = isSelected ? [.button, .selected] : .button
    }
}


class StylePresetCell: CardCell {
    static let reuseIdentifier = "StylePresetCell"
    private var badge: IconBadge?
    let nameLabel = UILabel()
    let descriptionLabel = UILabel()
    private let badgeSlot = UIView()
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    private func setupUI() {
        cardRadius = Theme.Radius.md
        badgeSlot.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(badgeSlot)
        nameLabel.apply(.subhead, color: Theme.Color.ink)
        nameLabel.numberOfLines = 1
        descriptionLabel.apply(.footnote)
        descriptionLabel.numberOfLines = 1
        let stack = UIStackView(arrangedSubviews: [nameLabel, descriptionLabel])
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            badgeSlot.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            badgeSlot.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            badgeSlot.widthAnchor.constraint(equalToConstant: 32),
            badgeSlot.heightAnchor.constraint(equalToConstant: 32),
            stack.leadingAnchor.constraint(equalTo: badgeSlot.trailingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stack.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -8)
        ])
        isAccessibilityElement = true
    }
    func configure(with style: StylePreset, isSelected: Bool = false) {
        badge?.removeFromSuperview()
        let badge = IconBadge(symbol: style.icon, colors: style.gradientColors.map { $0.darkenedForWhiteText(minimumContrast: 3) }, size: 32)
        badgeSlot.addSubview(badge)
        badge.pinEdges(to: badgeSlot)
        self.badge = badge
        nameLabel.text = style.name
        descriptionLabel.text = style.description
        isMarked = isSelected
        accessibilityLabel = String(localized: "Style: \(style.name)")
        accessibilityHint = style.description
        accessibilityTraits = isSelected ? [.button, .selected] : .button
    }
}


class ModifierChipCell: UICollectionViewCell {
    static let reuseIdentifier = "ModifierChipCell"
    private var chip: ChipView?
    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = true
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func prepareForReuse() {
        super.prepareForReuse()
        chip?.removeFromSuperview()
        chip = nil
    }
    func configure(with text: String, isSelected: Bool = false, category: String) {
        chip?.removeFromSuperview()
        let chip = ChipView(title: text, isSelected: isSelected)
        chip.isUserInteractionEnabled = false
        chip.isAccessibilityElement = false
        contentView.addSubview(chip)
        NSLayoutConstraint.activate([
            chip.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            chip.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            chip.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
        self.chip = chip
        accessibilityLabel = String(localized: "\(category): \(text)")
        accessibilityTraits = isSelected ? [.button, .selected] : .button
    }
}


/// A modifier category tab: single-select, drawn as an accent-outlined pill so it reads as a tab
/// beside the filled toggle chips.
class CategoryChipCell: UICollectionViewCell {
    static let reuseIdentifier = "CategoryChipCell"
    let label = UILabel()
    private let pill = PillView()
    override var isSelected: Bool {
        didSet {
            updateAppearance()
        }
    }
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    private func setupUI() {
        pill.translatesAutoresizingMaskIntoConstraints = false
        pill.layer.borderWidth = 1.5
        pill.layer.cornerCurve = .continuous
        contentView.addSubview(pill)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.apply(.subhead)
        label.numberOfLines = 1
        label.textAlignment = .center
        pill.addSubview(label)
        NSLayoutConstraint.activate([
            pill.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            pill.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            pill.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            pill.heightAnchor.constraint(greaterThanOrEqualToConstant: 38),
            label.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -14),
            label.topAnchor.constraint(equalTo: pill.topAnchor, constant: 9),
            label.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -9)
        ])
        isAccessibilityElement = true
        updateAppearance()
    }
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateAppearance()
    }
    func configure(with text: String) {
        label.text = text
        accessibilityLabel = text
    }
    private func updateAppearance() {
        accessibilityTraits = isSelected ? [.button, .selected] : .button
        Motion.animate(0.2) {
            self.pill.backgroundColor = self.isSelected ? Theme.Color.accentSoft : .clear
            self.pill.layer.borderColor = (self.isSelected ? Theme.Color.accent : Theme.Color.line).resolvedColor(with: self.traitCollection).cgColor
            self.label.textColor = self.isSelected ? Theme.Color.accentText : Theme.Color.ink
        }
    }
}


private final class PillView: UIView {
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }
}
