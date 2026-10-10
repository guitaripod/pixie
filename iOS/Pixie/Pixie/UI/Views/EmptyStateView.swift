import UIKit

enum EmptyStateType {
    case personal
    case transactions
}

final class EmptyStateView: UIView {

    var onCreateTapped: (() -> Void)?

    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let createButton = UIButton(type: .system)
    private var iconWidthConstraint: NSLayoutConstraint!
    private var iconHeightConstraint: NSLayoutConstraint!

    private static let baseIconSize: CGFloat = 80
    private static let maxIconSize: CGFloat = 128

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = UIColor.brandText.withAlphaComponent(0.7)
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.hideFromAccessibility()

        titleLabel.useScaledFont(.title3, size: 20, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.accessibilityTraits = .header

        subtitleLabel.useScaledFont(.body, size: 16)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        setupCreateButton()

        stackView.addArrangedSubview(iconImageView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)
        stackView.addArrangedSubview(createButton)
        stackView.setCustomSpacing(24, after: subtitleLabel)

        iconWidthConstraint = iconImageView.widthAnchor.constraint(equalToConstant: Self.baseIconSize)
        iconHeightConstraint = iconImageView.heightAnchor.constraint(equalToConstant: Self.baseIconSize)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),

            iconWidthConstraint,
            iconHeightConstraint
        ])

        updateIconSize()
    }

    private func setupCreateButton() {
        var config = UIButton.Configuration.filled()
        config.title = String(localized: "Create an image")
        config.image = UIImage(systemName: "wand.and.stars")
        config.imagePlacement = .leading
        config.imagePadding = 8
        config.cornerStyle = .capsule
        config.baseBackgroundColor = .brand
        config.baseForegroundColor = .white
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 24, bottom: 12, trailing: 24)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .scaled(.body, size: 17, weight: .semibold)
            return outgoing
        }
        createButton.configuration = config
        createButton.translatesAutoresizingMaskIntoConstraints = false
        createButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        createButton.accessibilityLabel = String(localized: "Create an image")
        createButton.addAction(UIAction { [weak self] _ in
            HapticsManager.shared.impact(.light)
            self?.onCreateTapped?()
        }, for: .touchUpInside)
        createButton.setupPointerInteraction()
    }

    /// Sizes the icon with the user's text size, capped so it never crowds out the text.
    private func updateIconSize() {
        let scaled = UIFontMetrics(forTextStyle: .title1).scaledValue(for: Self.baseIconSize, compatibleWith: traitCollection)
        let size = min(scaled, Self.maxIconSize)
        iconWidthConstraint.constant = size
        iconHeightConstraint.constant = size
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
            updateIconSize()
        }
    }

    func configure(for emptyType: EmptyStateType) {
        switch emptyType {
        case .personal:
            iconImageView.image = UIImage(systemName: "photo.on.rectangle.angled")
            titleLabel.text = String(localized: "No images yet")
            subtitleLabel.text = String(localized: "Your generated images will appear here")
            createButton.isHidden = false

        case .transactions:
            iconImageView.image = UIImage(systemName: "clock.arrow.circlepath")
            titleLabel.text = String(localized: "No transactions yet")
            subtitleLabel.text = String(localized: "Your credit usage history will appear here")
            createButton.isHidden = true
        }
    }
}
