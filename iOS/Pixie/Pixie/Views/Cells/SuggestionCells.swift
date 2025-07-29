import UIKit


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
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .label
        addSubview(titleLabel)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = .secondaryLabel
        addSubview(subtitleLabel)
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        addSubview(actionButton)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            actionButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
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
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .label
        addSubview(titleLabel)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = .secondaryLabel
        addSubview(subtitleLabel)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        addSubview(scrollView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.distribution = .fill
        scrollView.addSubview(stackView)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 12),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            scrollView.heightAnchor.constraint(equalToConstant: 36),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
    }
    func configure(categories: [CreativePrompt], selectedIndex: Int, onCategorySelected: @escaping (Int) -> Void) {
        self.categories = categories
        self.selectedIndex = selectedIndex
        self.onCategorySelected = onCategorySelected
        titleLabel.text = "Creative Prompts"
        subtitleLabel.text = "Tap a category, then select a prompt"
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let leadingPadding = UIView()
        leadingPadding.widthAnchor.constraint(equalToConstant: 8).isActive = true
        stackView.addArrangedSubview(leadingPadding)
        for (index, category) in categories.enumerated() {
            let button = UIButton(type: .custom)
            button.setTitle("\(category.emoji) \(category.category)", for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
            button.tag = index
            button.layer.cornerRadius = 18
            button.layer.borderWidth = 1
            button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
            updateButtonAppearance(button, isSelected: index == selectedIndex, color: category.color)
            button.addAction(UIAction { [weak self] _ in
                self?.selectCategory(at: index)
            }, for: .touchUpInside)
            stackView.addArrangedSubview(button)
        }
        let trailingPadding = UIView()
        trailingPadding.widthAnchor.constraint(equalToConstant: 8).isActive = true
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
        UIView.animate(withDuration: 0.2) {
            if isSelected {
                button.backgroundColor = color
                button.setTitleColor(.white, for: .normal)
                button.layer.borderColor = color.cgColor
                button.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
            } else {
                button.backgroundColor = .clear
                button.setTitleColor(.label, for: .normal)
                button.layer.borderColor = UIColor.separator.cgColor
                button.transform = .identity
            }
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
        iconImageView.tintColor = .systemBlue
        iconImageView.contentMode = .scaleAspectFit
        overlayView.addSubview(iconImageView)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .systemBlue
        label.textAlignment = .center
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
    }
    func configure(with image: UIImage?, isAddButton: Bool = false) {
        if isAddButton {
            imageView.image = nil
            overlayView.isHidden = false
            overlayView.layer.borderWidth = 2
            overlayView.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.5).cgColor
            overlayView.layer.cornerRadius = 16
            iconImageView.image = UIImage(systemName: "photo.badge.plus")
            label.text = "Choose Image"
        } else {
            imageView.image = image
            overlayView.isHidden = true
        }
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
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
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
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14)
        ])
    }
    func configure(with action: QuickAction, isSelected: Bool = false) {
        contentView.backgroundColor = action.color
        iconImageView.image = UIImage(systemName: action.icon)
        titleLabel.text = action.title
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
        label.font = .systemFont(ofSize: 13)
        label.numberOfLines = 3
        label.textAlignment = .center
        label.lineBreakMode = .byTruncatingTail
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }
    func configure(with prompt: String, color: UIColor, isSelected: Bool = false) {
        label.text = prompt
        label.textColor = .label
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
        nameLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        nameLabel.textColor = .white
        contentView.addSubview(nameLabel)
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.font = .systemFont(ofSize: 10)
        descriptionLabel.textColor = UIColor.white.withAlphaComponent(0.8)
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
            descriptionLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -8)
        ])
    }
    func configure(with style: StylePreset, isSelected: Bool = false) {
        gradientLayer.colors = style.gradientColors.map { $0.cgColor }
        iconImageView.image = UIImage(systemName: style.icon)
        nameLabel.text = style.name
        descriptionLabel.text = style.description
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
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .label
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    func configure(with text: String, isSelected: Bool = false) {
        label.text = text
        if isSelected {
            contentView.backgroundColor = UIColor.systemBlue
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
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
        updateAppearance()
    }
    func configure(with text: String) {
        label.text = text
    }
    private func updateAppearance() {
        UIView.animate(withDuration: 0.2) {
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