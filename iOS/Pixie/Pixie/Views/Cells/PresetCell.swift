import UIKit

/// Title, subtitle and, for a pack, how many images one tap makes, as one spoken phrase.
private func spokenDescription(of preset: EditPreset) -> String {
    let base = "\(preset.title), \(preset.subtitle)"
    guard preset.imageCount > 1 else { return base }
    return "\(base), " + String(localized: "\(preset.imageCount) images")
}

/// A popular edit as a picture card: the real result image, a scrim along the bottom, the title and
/// one line about it in white, and a "×4" capsule when one tap makes a pack.
final class PresetCell: CardCell {
    static let reuseIdentifier = "PresetCell"

    private let fallbackGradient = GradientView()
    private let fallbackIcon = UIImageView()
    private let imageView = UIImageView()
    private let scrim = GradientView(start: CGPoint(x: 0.5, y: 0), end: CGPoint(x: 0.5, y: 1))
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let countCapsule = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let countLabel = UILabel()
    private static let subtitleMinimumHeight: CGFloat = 150

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        showsHairline = false

        fallbackGradient.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(fallbackGradient)
        fallbackGradient.pinEdges(to: contentView)

        fallbackIcon.translatesAutoresizingMaskIntoConstraints = false
        fallbackIcon.tintColor = UIColor.white.withAlphaComponent(0.85)
        fallbackIcon.contentMode = .scaleAspectFit
        fallbackIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 44, weight: .semibold)
        contentView.addSubview(fallbackIcon)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        contentView.addSubview(imageView)
        imageView.pinEdges(to: contentView)

        scrim.colors = [UIColor.black.withAlphaComponent(0), UIColor.black.withAlphaComponent(0.78)]
        scrim.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(scrim)

        titleLabel.apply(.headline, color: .white)
        titleLabel.numberOfLines = 2
        subtitleLabel.apply(.footnote, color: UIColor.white.withAlphaComponent(0.78))
        subtitleLabel.numberOfLines = 2
        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textStack)

        countCapsule.translatesAutoresizingMaskIntoConstraints = false
        countCapsule.clipsToBounds = true
        countCapsule.layer.cornerCurve = .continuous
        countCapsule.isUserInteractionEnabled = false
        countLabel.apply(.numeral(13), color: .white)
        countLabel.numberOfLines = 1
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countCapsule.contentView.addSubview(countLabel)
        contentView.addSubview(countCapsule)

        let scrimHeight = scrim.heightAnchor.constraint(equalTo: contentView.heightAnchor, multiplier: 0.62)
        scrimHeight.priority = .defaultHigh
        NSLayoutConstraint.activate([
            fallbackIcon.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            fallbackIcon.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -24),

            scrim.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrim.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrim.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            scrim.topAnchor.constraint(lessThanOrEqualTo: textStack.topAnchor, constant: -Theme.Space.xxl),
            scrim.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor),
            scrimHeight,

            textStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Space.md),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Space.md),
            textStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Theme.Space.md),
            textStack.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: Theme.Space.md),

            countCapsule.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Theme.Space.sm + 2),
            countCapsule.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -(Theme.Space.sm + 2)),
            countLabel.topAnchor.constraint(equalTo: countCapsule.contentView.topAnchor, constant: 4),
            countLabel.bottomAnchor.constraint(equalTo: countCapsule.contentView.bottomAnchor, constant: -4),
            countLabel.leadingAnchor.constraint(equalTo: countCapsule.contentView.leadingAnchor, constant: 10),
            countLabel.trailingAnchor.constraint(equalTo: countCapsule.contentView.trailingAnchor, constant: -10)
        ])

        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        countCapsule.layer.cornerRadius = countCapsule.bounds.height / 2
        subtitleLabel.isHidden = bounds.height < Self.subtitleMinimumHeight
    }

    func configure(with preset: EditPreset) {
        let art = preset.artName.flatMap { UIImage(named: $0) }
        imageView.image = art
        imageView.isHidden = art == nil
        fallbackGradient.colors = preset.gradientColors
        fallbackIcon.image = UIImage(systemName: preset.symbol)
        fallbackIcon.isHidden = art != nil
        titleLabel.text = preset.title
        subtitleLabel.text = preset.subtitle
        countCapsule.isHidden = preset.imageCount <= 1
        countLabel.text = "×\(preset.imageCount)"
        accessibilityLabel = spokenDescription(of: preset)
    }
}

/// A smaller edit as a tile: a gradient icon badge in the preset colour, the title and up to two
/// lines about it, and a "Seasonal" capsule while the season runs.
final class MoreEditCell: CardCell {
    static let reuseIdentifier = "MoreEditCell"

    private let badgeSlot = UIView()
    private var badge: IconBadge?
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let seasonalLabel = UILabel()
    private let seasonalCapsule = UIView()
    private let textStack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        badgeSlot.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(badgeSlot)

        seasonalCapsule.translatesAutoresizingMaskIntoConstraints = false
        seasonalCapsule.layer.cornerCurve = .continuous
        seasonalCapsule.layer.cornerRadius = 11
        seasonalLabel.translatesAutoresizingMaskIntoConstraints = false
        seasonalLabel.setStyledText(String(localized: "Seasonal"), .caption, color: .white)
        seasonalLabel.numberOfLines = 1
        seasonalCapsule.addSubview(seasonalLabel)
        contentView.addSubview(seasonalCapsule)

        titleLabel.apply(.subhead, color: Theme.Color.ink)
        subtitleLabel.apply(.footnote)
        subtitleLabel.numberOfLines = 2
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textStack)

        NSLayoutConstraint.activate([
            badgeSlot.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Space.md + 2),
            badgeSlot.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Theme.Space.md + 2),
            badgeSlot.widthAnchor.constraint(equalToConstant: 36),
            badgeSlot.heightAnchor.constraint(equalToConstant: 36),

            seasonalCapsule.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -(Theme.Space.md + 2)),
            seasonalCapsule.centerYAnchor.constraint(equalTo: badgeSlot.centerYAnchor),
            seasonalLabel.topAnchor.constraint(equalTo: seasonalCapsule.topAnchor, constant: 3),
            seasonalLabel.bottomAnchor.constraint(equalTo: seasonalCapsule.bottomAnchor, constant: -3),
            seasonalLabel.leadingAnchor.constraint(equalTo: seasonalCapsule.leadingAnchor, constant: 8),
            seasonalLabel.trailingAnchor.constraint(equalTo: seasonalCapsule.trailingAnchor, constant: -8),
            seasonalCapsule.leadingAnchor.constraint(greaterThanOrEqualTo: badgeSlot.trailingAnchor, constant: Theme.Space.sm),

            textStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Space.md + 2),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -(Theme.Space.md + 2)),
            textStack.topAnchor.constraint(equalTo: badgeSlot.bottomAnchor, constant: Theme.Space.md),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -(Theme.Space.md + 2))
        ])

        isAccessibilityElement = true
        accessibilityTraits = .button
        updateTitleLineLimit()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
            updateTitleLineLimit()
        }
    }

    /// One line at the default text size; every line once the text is larger, where the tile grows to fit.
    private func updateTitleLineLimit() {
        titleLabel.numberOfLines = traitCollection.preferredContentSizeCategory > .large ? 0 : 1
    }

    /// The tile's height at the current text size, measured from a real cell holding a title and a
    /// two-line subtitle so the figure follows the fonts instead of guessing at them.
    static func height(titleLines: Int) -> CGFloat {
        let probe = MoreEditCell(frame: CGRect(x: 0, y: 0, width: 160, height: 400))
        probe.titleLabel.numberOfLines = titleLines
        probe.titleLabel.text = Array(repeating: "Title", count: titleLines).joined(separator: "\n")
        probe.subtitleLabel.text = "Line\nLine"
        let text = probe.textStack.systemLayoutSizeFitting(CGSize(width: 160 - 2 * (Theme.Space.md + 2), height: UIView.layoutFittingCompressedSize.height), withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel).height
        let padding = Theme.Space.md + 2
        return ceil(padding + 36 + Theme.Space.md + text + padding)
    }

    func configure(with preset: EditPreset) {
        badge?.removeFromSuperview()
        let badge = IconBadge(symbol: preset.symbol, colors: preset.gradientColors, size: 36)
        badgeSlot.addSubview(badge)
        badge.pinEdges(to: badgeSlot)
        self.badge = badge
        titleLabel.text = preset.title
        subtitleLabel.text = preset.subtitle
        seasonalCapsule.isHidden = !preset.isSeasonal
        seasonalCapsule.backgroundColor = preset.gradientColors.last
        let spoken = spokenDescription(of: preset)
        accessibilityLabel = preset.isSeasonal ? "\(spoken), " + String(localized: "Seasonal") : spoken
    }
}
