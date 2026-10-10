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


class SectionHeaderView: UICollectionReusableView {
    static let reuseIdentifier = "SectionHeaderView"
    let titleLabel = UILabel()
    let subtitleLabel = UILabel()
    let actionButton = UIButton(type: .system)
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    private func setupUI() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.useScaledFont(.title2, size: 22, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0
        titleLabel.accessibilityTraits = .header
        addSubview(titleLabel)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.useScaledFont(.subheadline, size: 14)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0
        addSubview(subtitleLabel)
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.titleLabel?.font = .scaled(.subheadline, size: 15, weight: .medium)
        actionButton.titleLabel?.adjustsFontForContentSizeCategory = true
        addSubview(actionButton)

        let horizontalPadding: CGFloat = 8

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: horizontalPadding),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -horizontalPadding),
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: horizontalPadding),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -horizontalPadding),
            subtitleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            actionButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -horizontalPadding),
            actionButton.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    func configure(title: String, subtitle: String?, actionTitle: String? = nil) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        subtitleLabel.isHidden = subtitle == nil
        if let actionTitle = actionTitle {
            actionButton.setTitle(actionTitle, for: .normal)
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
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    private func setupUI() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.useScaledFont(.title2, size: 22, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0
        titleLabel.accessibilityTraits = .header
        addSubview(titleLabel)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.useScaledFont(.subheadline, size: 14)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0
        addSubview(subtitleLabel)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        addSubview(scrollView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.layoutMargins = .init(top: .zero, left: -16, bottom: .zero, right: .zero)
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.distribution = .fill
        scrollView.addSubview(stackView)

        let horizontalPadding: CGFloat = 8
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: horizontalPadding),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -horizontalPadding),
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: horizontalPadding),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -horizontalPadding),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 12),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            scrollView.frameLayoutGuide.heightAnchor.constraint(equalTo: scrollView.contentLayoutGuide.heightAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor)
        ])
    }
    func configure(categories: [CreativePrompt], selectedIndex: Int, onCategorySelected: @escaping (Int) -> Void) {
        self.categories = categories
        self.selectedIndex = selectedIndex
        self.onCategorySelected = onCategorySelected
        titleLabel.text = String(localized: "Creative Prompts")
        subtitleLabel.text = String(localized: "Tap a category, then select a prompt")
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let leadingPadding = UIView()
        leadingPadding.widthAnchor.constraint(equalToConstant: 16).isActive = true
        stackView.addArrangedSubview(leadingPadding)
        for (index, category) in categories.enumerated() {
            let button = UIButton(type: .custom)
            button.tag = index
            var config = UIButton.Configuration.plain()
            config.title = category.category
            config.image = UIImage(systemName: category.symbol)
            config.cornerStyle = .capsule
            config.background.strokeWidth = 1
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var attributes = attributes
                attributes.font = UIFont.scaled(.subheadline, size: 14, weight: .medium)
                return attributes
            }
            config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
            config.imagePadding = 6
            config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .footnote, scale: .medium)
            button.configuration = config
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 36).isActive = true
            updateButtonAppearance(button, isSelected: index == selectedIndex, color: category.color)
            button.addAction(UIAction { [weak self] _ in
                self?.selectCategory(at: index)
            }, for: .touchUpInside)
            stackView.addArrangedSubview(button)
        }
        let trailingPadding = UIView()
        trailingPadding.widthAnchor.constraint(equalToConstant: 16).isActive = true
        stackView.addArrangedSubview(trailingPadding)
    }
    private func selectCategory(at index: Int) {
        guard index != selectedIndex else { return }
        let previousButtonIndex = selectedIndex + 1
        let newButtonIndex = index + 1
        if previousButtonIndex < stackView.arrangedSubviews.count,
           let previousButton = stackView.arrangedSubviews[previousButtonIndex] as? UIButton {
            updateButtonAppearance(previousButton, isSelected: false, color: categories[selectedIndex].color)
        }
        if newButtonIndex < stackView.arrangedSubviews.count,
           let newButton = stackView.arrangedSubviews[newButtonIndex] as? UIButton {
            updateButtonAppearance(newButton, isSelected: true, color: categories[index].color)
        }
        selectedIndex = index
        onCategorySelected?(index)
    }
    private func updateButtonAppearance(_ button: UIButton, isSelected: Bool, color: UIColor) {
        let fill = color.darkenedForWhiteText()
        button.isSelected = isSelected
        Motion.animate(0.2) {
            var config = button.configuration
            config?.baseForegroundColor = isSelected ? .white : .label
            config?.imageColorTransformer = UIConfigurationColorTransformer { _ in isSelected ? .white : color }
            config?.background.backgroundColor = isSelected ? fill : .clear
            config?.background.strokeColor = isSelected ? fill : .separator
            button.configuration = config
            button.transform = isSelected && !Motion.isReduced ? CGAffineTransform(scaleX: 1.05, y: 1.05) : .identity
        }
    }
}


class ImageCell: UICollectionViewCell {
    static let reuseIdentifier = "ImageCell"
    let imageView = UIImageView()
    let overlayView = UIView()
    let iconImageView = UIImageView()
    let label = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    private func setupUI() {
        contentView.layer.cornerRadius = 16
        contentView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        contentView.addSubview(imageView)
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.backgroundColor = .systemGray6
        contentView.addSubview(overlayView)
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.tintColor = .brandText
        iconImageView.contentMode = .scaleAspectFit
        overlayView.addSubview(iconImageView)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.useScaledFont(.footnote, size: 13, weight: .medium)
        label.textColor = .brandText
        label.textAlignment = .center
        label.numberOfLines = 0
        overlayView.addSubview(label)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            overlayView.topAnchor.constraint(equalTo: contentView.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            iconImageView.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: overlayView.centerYAnchor, constant: -12),
            iconImageView.widthAnchor.constraint(equalToConstant: 32),
            iconImageView.heightAnchor.constraint(equalToConstant: 32),
            label.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 8),
            label.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: overlayView.trailingAnchor, constant: -8)
        ])
        isAccessibilityElement = true
    }
    func configure(with image: UIImage?, isAddButton: Bool = false, isSelectedPhoto: Bool = false) {
        contentView.layer.borderWidth = isSelectedPhoto ? 3 : 0
        contentView.layer.borderColor = UIColor.systemPurple.cgColor
        if isAddButton {
            imageView.image = nil
            overlayView.isHidden = false
            overlayView.layer.borderWidth = 2
            overlayView.layer.borderColor = UIColor.brandText.withAlphaComponent(0.5).cgColor
            overlayView.layer.cornerRadius = 16
            iconImageView.image = UIImage(systemName: "photo.badge.plus")
            label.text = String(localized: "Choose Image")
            accessibilityLabel = String(localized: "Choose Image")
            accessibilityTraits = .button
        } else {
            imageView.image = image
            overlayView.isHidden = true
            accessibilityLabel = isSelectedPhoto ? String(localized: "Your photo") : String(localized: "Recent photo")
            accessibilityTraits = isSelectedPhoto ? [.button, .selected] : .button
        }
    }
}


/// The first-run shortcut next to "Choose Image": the old photo the onboarding restores,
/// offered as a ready-made input so a new person can see a result before using their own photo.
class SampleTileCell: UICollectionViewCell {
    static let reuseIdentifier = "SampleTileCell"
    private let thumbnailView = UIImageView()
    private let badgeView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let textStack = UIStackView()
    private static let title = String(localized: "Try a sample photo")
    private static let subtitle = String(localized: "Restores an old photo with one of your free images")

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    private func setupUI() {
        contentView.backgroundColor = .brandTint
        contentView.layer.cornerRadius = 16
        contentView.layer.cornerCurve = .continuous
        contentView.layer.borderWidth = 1.5
        contentView.layer.borderColor = UIColor.brandText.withAlphaComponent(0.5).cgColor
        contentView.clipsToBounds = true

        thumbnailView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailView.image = UIImage(named: "onboarding_before_1")
        thumbnailView.contentMode = .scaleAspectFill
        thumbnailView.layer.cornerRadius = 10
        thumbnailView.layer.cornerCurve = .continuous
        thumbnailView.clipsToBounds = true
        for axis in [NSLayoutConstraint.Axis.horizontal, .vertical] {
            thumbnailView.setContentHuggingPriority(.defaultLow, for: axis)
            thumbnailView.setContentCompressionResistancePriority(.defaultLow, for: axis)
        }
        contentView.addSubview(thumbnailView)

        badgeView.translatesAutoresizingMaskIntoConstraints = false
        badgeView.image = UIImage(systemName: "sparkles")
        badgeView.tintColor = .white
        badgeView.backgroundColor = .brand
        badgeView.contentMode = .center
        badgeView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)
        badgeView.layer.cornerRadius = 11
        contentView.addSubview(badgeView)

        titleLabel.text = Self.title
        titleLabel.useScaledFont(.subheadline, size: 15, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0
        subtitleLabel.text = Self.subtitle
        subtitleLabel.useScaledFont(.caption1, size: 12)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)
        textStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textStack)

        let thumbnailHeight = thumbnailView.heightAnchor.constraint(equalTo: contentView.heightAnchor, constant: -24)
        thumbnailHeight.priority = .defaultHigh
        NSLayoutConstraint.activate([
            thumbnailView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            thumbnailView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            thumbnailView.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 12),
            thumbnailHeight,
            thumbnailView.widthAnchor.constraint(equalTo: thumbnailView.heightAnchor, multiplier: 0.75),

            badgeView.widthAnchor.constraint(equalToConstant: 22),
            badgeView.heightAnchor.constraint(equalToConstant: 22),
            badgeView.leadingAnchor.constraint(equalTo: thumbnailView.leadingAnchor, constant: -6),
            badgeView.topAnchor.constraint(equalTo: thumbnailView.topAnchor, constant: -6),

            textStack.leadingAnchor.constraint(equalTo: thumbnailView.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            textStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            textStack.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 10),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -10)
        ])

        describe("\(Self.title). \(Self.subtitle).", traits: .button)
    }

    /// The text column is whatever the thumbnail and the margins leave, so both labels are told that
    /// width before the cell lays out; a label measured without one reports a single line and truncates.
    override func layoutSubviews() {
        let thumbnailWidth = max(0, contentView.bounds.height - 24) * 0.75
        let textWidth = max(0, contentView.bounds.width - 12 - thumbnailWidth - 12 - 12)
        titleLabel.preferredMaxLayoutWidth = textWidth
        subtitleLabel.preferredMaxLayoutWidth = textWidth
        super.layoutSubviews()
    }
}


class QuickActionCell: UICollectionViewCell {
    static let reuseIdentifier = "QuickActionCell"
    let iconImageView = UIImageView()
    let titleLabel = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    private func setupUI() {
        contentView.layer.cornerRadius = 20
        contentView.clipsToBounds = true
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.tintColor = .white
        iconImageView.contentMode = .scaleAspectFit
        contentView.addSubview(iconImageView)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.useScaledFont(.footnote, size: 13, weight: .medium)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.minimumScaleFactor = 0.8
        titleLabel.adjustsFontSizeToFitWidth = true
        contentView.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 18),
            iconImageView.heightAnchor.constraint(equalToConstant: 18),
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            titleLabel.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 10),
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -10),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14)
        ])
        isAccessibilityElement = true
    }
    func configure(with action: QuickAction, isSelected: Bool = false, category: String) {
        contentView.backgroundColor = action.color.darkenedForWhiteText()
        iconImageView.image = UIImage(systemName: action.icon)
        titleLabel.text = action.title
        accessibilityLabel = String(localized: "\(category): \(action.title)")
        accessibilityTraits = isSelected ? [.button, .selected] : .button
        if isSelected {
            contentView.layer.borderWidth = 3
            contentView.layer.borderColor = UIColor.systemBlue.cgColor
            contentView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        } else {
            contentView.layer.borderWidth = 0
            contentView.transform = .identity
        }
        contentView.layer.masksToBounds = true
    }
}


class PromptCardCell: UICollectionViewCell {
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
        contentView.layer.cornerRadius = 16
        contentView.layer.borderWidth = 1
        contentView.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        label.useScaledFont(.footnote, size: 13)
        label.textAlignment = .center
        label.lineBreakMode = .byTruncatingTail
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
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
        label.textColor = .label
        accessibilityLabel = String(localized: "\(category): \(prompt)")
        accessibilityTraits = isSelected ? [.button, .selected] : .button
        if isSelected {
            contentView.backgroundColor = color.withAlphaComponent(0.3)
            contentView.layer.borderColor = color.cgColor
            contentView.layer.borderWidth = 2
        } else {
            contentView.backgroundColor = color.withAlphaComponent(0.1)
            contentView.layer.borderColor = color.withAlphaComponent(0.3).cgColor
            contentView.layer.borderWidth = 1
        }
    }
}


class StylePresetCell: UICollectionViewCell {
    static let reuseIdentifier = "StylePresetCell"
    private let gradientLayer = CAGradientLayer()
    let iconImageView = UIImageView()
    let nameLabel = UILabel()
    let descriptionLabel = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = contentView.bounds
    }
    private func setupUI() {
        contentView.layer.cornerRadius = 12
        contentView.clipsToBounds = true
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        contentView.layer.insertSublayer(gradientLayer, at: 0)
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.tintColor = .white
        iconImageView.contentMode = .scaleAspectFit
        contentView.addSubview(iconImageView)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.useScaledFont(.caption1, size: 12, weight: .semibold)
        nameLabel.textColor = .white
        contentView.addSubview(nameLabel)
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.useScaledFont(.caption2, size: 10)
        descriptionLabel.textColor = .white
        contentView.addSubview(descriptionLabel)
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 20),
            iconImageView.heightAnchor.constraint(equalToConstant: 20),
            nameLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -8),
            descriptionLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            descriptionLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            descriptionLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -8),
            descriptionLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -10)
        ])
        isAccessibilityElement = true
    }
    func configure(with style: StylePreset, isSelected: Bool = false) {
        gradientLayer.colors = style.gradientColors.map { $0.darkenedForWhiteText().cgColor }
        iconImageView.image = UIImage(systemName: style.icon)
        nameLabel.text = style.name
        descriptionLabel.text = style.description
        accessibilityLabel = String(localized: "Style: \(style.name)")
        accessibilityHint = style.description
        accessibilityTraits = isSelected ? [.button, .selected] : .button
        if isSelected {
            contentView.layer.borderWidth = 3
            contentView.layer.borderColor = UIColor.systemBlue.cgColor
            contentView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        } else {
            contentView.layer.borderWidth = 0
            contentView.transform = .identity
        }
    }
}


class ModifierChipCell: UICollectionViewCell {
    static let reuseIdentifier = "ModifierChipCell"
    let label = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    private func setupUI() {
        contentView.backgroundColor = UIColor.secondarySystemFill
        contentView.layer.cornerRadius = 16
        contentView.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        label.useScaledFont(.subheadline, size: 14, weight: .medium)
        label.textColor = .label
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            label.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 6),
            label.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -6)
        ])
        isAccessibilityElement = true
    }
    func configure(with text: String, isSelected: Bool = false, category: String) {
        label.text = text
        accessibilityLabel = String(localized: "\(category): \(text)")
        accessibilityTraits = isSelected ? [.button, .selected] : .button
        if isSelected {
            contentView.backgroundColor = UIColor.brand
            label.textColor = .white
        } else {
            contentView.backgroundColor = UIColor.secondarySystemFill
            label.textColor = .label
        }
    }
}


class CategoryChipCell: UICollectionViewCell {
    static let reuseIdentifier = "CategoryChipCell"
    let label = UILabel()
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
        contentView.layer.cornerRadius = 16
        contentView.layer.borderWidth = 1
        contentView.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        label.useScaledFont(.subheadline, size: 14, weight: .medium)
        label.textAlignment = .center
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            label.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 6),
            label.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -6)
        ])
        isAccessibilityElement = true
        updateAppearance()
    }
    func configure(with text: String) {
        label.text = text
        accessibilityLabel = text
    }
    private func updateAppearance() {
        accessibilityTraits = isSelected ? [.button, .selected] : .button
        Motion.animate(0.2) {
            if self.isSelected {
                self.contentView.backgroundColor = .label
                self.contentView.layer.borderColor = UIColor.label.cgColor
                self.label.textColor = .systemBackground
            } else {
                self.contentView.backgroundColor = .clear
                self.contentView.layer.borderColor = UIColor.separator.cgColor
                self.label.textColor = .label
            }
        }
    }
}
