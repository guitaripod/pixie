import UIKit

final class PresetCell: UICollectionViewCell {
    static let reuseIdentifier = "PresetCell"

    private let iconBackground = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let countBadge = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        contentView.backgroundColor = .secondarySystemBackground
        contentView.layer.cornerRadius = 16
        contentView.layer.cornerCurve = .continuous
        contentView.clipsToBounds = true

        iconBackground.translatesAutoresizingMaskIntoConstraints = false
        iconBackground.layer.cornerRadius = 18
        contentView.addSubview(iconBackground)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        iconBackground.addSubview(iconView)

        countBadge.translatesAutoresizingMaskIntoConstraints = false
        countBadge.font = .systemFont(ofSize: 12, weight: .bold)
        countBadge.textColor = .white
        countBadge.textAlignment = .center
        countBadge.layer.cornerRadius = 10
        countBadge.clipsToBounds = true
        contentView.addSubview(countBadge)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.8
        contentView.addSubview(titleLabel)

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 2
        contentView.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            iconBackground.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            iconBackground.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            iconBackground.widthAnchor.constraint(equalToConstant: 36),
            iconBackground.heightAnchor.constraint(equalToConstant: 36),
            iconView.centerXAnchor.constraint(equalTo: iconBackground.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor),

            countBadge.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor),
            countBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            countBadge.heightAnchor.constraint(equalToConstant: 20),
            countBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 32),

            titleLabel.topAnchor.constraint(equalTo: iconBackground.bottomAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -10)
        ])

        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    func configure(with preset: EditPreset) {
        iconBackground.backgroundColor = preset.tint.withAlphaComponent(0.18)
        iconView.image = UIImage(systemName: preset.symbol)
        iconView.tintColor = preset.tint
        titleLabel.text = preset.title
        subtitleLabel.text = preset.subtitle
        countBadge.isHidden = preset.imageCount <= 1
        countBadge.backgroundColor = preset.tint
        countBadge.text = "×\(preset.imageCount)"
        accessibilityLabel = preset.title
        accessibilityHint = preset.subtitle
    }
}
