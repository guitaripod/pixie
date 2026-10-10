import UIKit

final class GalleryImageCell: UICollectionViewCell {
    
    static let identifier = "GalleryImageCell"
    
    
    private let imageView = UIImageView()
    private let gradientView = UIView()
    private let promptLabel = UILabel()
    private let timeLabel = UILabel()
    private let creditsStackView = UIStackView()
    private let creditsIcon = UIImageView()
    private let creditsLabel = UILabel()
    private let gradientLayer = CAGradientLayer()
    private let selectionDimView = UIView()
    private let selectionBadge = UIImageView()
    private let failureIcon = UIImageView()
    
    private var currentImageMetadata: ImageMetadata?
    private var isSelectionMode = false
    private var isMarked = false
    
    var onAction: ((ImageAction) -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        promptLabel.text = nil
        timeLabel.text = nil
        creditsLabel.text = nil
        currentImageMetadata = nil
        failureIcon.isHidden = true
        onAction = nil
        isSelectionMode = false
        isMarked = false
        updateSelectionAppearance()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = gradientView.bounds
    }
    
    private func setupUI() {
        contentView.backgroundColor = .black
        contentView.clipsToBounds = true
        
        setupPointerInteraction()
        
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .systemGray6
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)
        
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(gradientView)
        
        gradientLayer.colors = [
            UIColor.black.withAlphaComponent(0.4).cgColor,
            UIColor.black.withAlphaComponent(0.8).cgColor
        ]
        gradientLayer.locations = [0.0, 1.0]
        gradientView.layer.addSublayer(gradientLayer)
        

        promptLabel.useScaledFont(.caption2, size: 10, weight: .medium)
        promptLabel.maximumContentSizeCategory = .extraExtraExtraLarge
        promptLabel.textColor = .white
        promptLabel.numberOfLines = 2
        promptLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(promptLabel)
        
        timeLabel.useScaledFont(.caption2, size: 9)
        timeLabel.maximumContentSizeCategory = .extraExtraExtraLarge
        timeLabel.textColor = .white.withAlphaComponent(0.85)
        timeLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(timeLabel)
        
        creditsStackView.axis = .horizontal
        creditsStackView.spacing = 4
        creditsStackView.alignment = .center
        creditsStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(creditsStackView)
        
        creditsIcon.image = UIImage(systemName: "star.fill")
        creditsIcon.tintColor = .white.withAlphaComponent(0.85)
        creditsIcon.contentMode = .scaleAspectFit
        creditsIcon.translatesAutoresizingMaskIntoConstraints = false
        
        creditsLabel.useScaledFont(.caption2, size: 9)
        creditsLabel.maximumContentSizeCategory = .extraExtraExtraLarge
        creditsLabel.textColor = .white.withAlphaComponent(0.85)
        creditsLabel.setContentHuggingPriority(.required, for: .horizontal)
        creditsLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        creditsStackView.addArrangedSubview(creditsIcon)
        creditsStackView.addArrangedSubview(creditsLabel)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            gradientView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            gradientView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            gradientView.topAnchor.constraint(lessThanOrEqualTo: promptLabel.topAnchor, constant: -12),
            gradientView.heightAnchor.constraint(greaterThanOrEqualToConstant: 60),
            
            promptLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            promptLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            promptLabel.bottomAnchor.constraint(equalTo: timeLabel.topAnchor, constant: -2),
            
            timeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            timeLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            timeLabel.trailingAnchor.constraint(lessThanOrEqualTo: creditsStackView.leadingAnchor, constant: -4),
            
            creditsStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            creditsStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            creditsIcon.widthAnchor.constraint(equalToConstant: 10),
            creditsIcon.heightAnchor.constraint(equalToConstant: 10)

        ])
        
        setupSelectionOverlay()
        setupFailureIcon()
        isAccessibilityElement = true
        accessibilityTraits = .button
    }
    
    private func setupSelectionOverlay() {
        selectionDimView.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        selectionDimView.isHidden = true
        selectionDimView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(selectionDimView)
        
        selectionBadge.contentMode = .scaleAspectFit
        selectionBadge.isHidden = true
        selectionBadge.layer.shadowColor = UIColor.black.cgColor
        selectionBadge.layer.shadowOpacity = 0.4
        selectionBadge.layer.shadowRadius = 2
        selectionBadge.layer.shadowOffset = .zero
        selectionBadge.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(selectionBadge)
        
        NSLayoutConstraint.activate([
            selectionDimView.topAnchor.constraint(equalTo: contentView.topAnchor),
            selectionDimView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            selectionDimView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            selectionDimView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            selectionBadge.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            selectionBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),
            selectionBadge.widthAnchor.constraint(equalToConstant: 26),
            selectionBadge.heightAnchor.constraint(equalToConstant: 26)
        ])
    }
    
    private func setupFailureIcon() {
        failureIcon.image = UIImage(systemName: "exclamationmark.triangle")
        failureIcon.tintColor = .secondaryLabel
        failureIcon.contentMode = .scaleAspectFit
        failureIcon.isHidden = true
        failureIcon.translatesAutoresizingMaskIntoConstraints = false
        contentView.insertSubview(failureIcon, aboveSubview: imageView)
        
        NSLayoutConstraint.activate([
            failureIcon.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            failureIcon.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            failureIcon.widthAnchor.constraint(equalToConstant: 24),
            failureIcon.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    /// Switches the cell between browsing and picking. While picking, a circle in the corner
    /// shows whether the image is chosen, and VoiceOver hears the chosen state instead of
    /// the per-image actions.
    func setSelection(mode: Bool, marked: Bool) {
        isSelectionMode = mode
        isMarked = marked
        updateSelectionAppearance()
        updateAccessibility()
    }
    
    private func updateSelectionAppearance() {
        selectionBadge.isHidden = !isSelectionMode
        selectionDimView.isHidden = !(isSelectionMode && isMarked)
        if isMarked {
            selectionBadge.image = UIImage(systemName: "checkmark.circle.fill")
            selectionBadge.tintColor = .white
            selectionBadge.backgroundColor = .brand
            selectionBadge.layer.cornerRadius = 13
        } else {
            selectionBadge.image = UIImage(systemName: "circle")
            selectionBadge.tintColor = .white
            selectionBadge.backgroundColor = .clear
            selectionBadge.layer.cornerRadius = 0
        }
    }
    
    
    func configure(with metadata: ImageMetadata) {
        currentImageMetadata = metadata
        promptLabel.text = metadata.prompt
        timeLabel.text = formatTimeAgo(metadata.createdAt)
        
        if let creditsUsed = metadata.metadata?.creditsUsed {
            creditsLabel.text = "\(creditsUsed)"
            creditsStackView.isHidden = false
        } else {
            creditsStackView.isHidden = true
        }
        
        failureIcon.isHidden = true
        loadImage(from: metadata.thumbnailUrl ?? metadata.url)
        updateAccessibility()
    }
    
    private func loadImage(from urlString: String) {
        Task { @MainActor in
            let image = await ImageCache.shared.loadImage(from: urlString)
            guard self.currentImageMetadata?.url == urlString || self.currentImageMetadata?.thumbnailUrl == urlString else { return }
            if let image {
                self.imageView.image = image
                self.failureIcon.isHidden = true
            } else {
                self.failureIcon.isHidden = false
            }
        }
    }
    
    private func updateAccessibility() {
        guard let metadata = currentImageMetadata else { return }
        accessibilityLabel = accessibilityDescription(for: metadata)
        accessibilityTraits = isSelectionMode && isMarked ? [.button, .selected] : .button
        accessibilityCustomActions = isSelectionMode ? [] : makeCustomActions()
    }
    
    /// The cell as one spoken phrase: the prompt, when it was made and what it cost.
    private func accessibilityDescription(for metadata: ImageMetadata) -> String {
        var parts = [metadata.prompt]
        if let date = Self.parseDate(metadata.createdAt) {
            let relative = Self.spokenFormatter.localizedString(for: date, relativeTo: Date())
            parts.append(String(localized: "created \(relative)"))
        }
        if let credits = metadata.metadata?.creditsUsed {
            parts.append(String(localized: "\(credits) credits"))
        }
        return parts.joined(separator: ", ")
    }
    
    private func makeCustomActions() -> [UIAccessibilityCustomAction] {
        let entries: [(String, ImageAction)] = [
            (String(localized: "Save"), .download),
            (String(localized: "Share"), .share),
            (String(localized: "Delete"), .delete),
            (String(localized: "Copy Prompt"), .copyPrompt),
            (String(localized: "Edit"), .useForEdit)
        ]
        return entries.map { name, action in
            UIAccessibilityCustomAction(name: name) { [weak self] _ in
                self?.onAction?(action)
                return self?.onAction != nil
            }
        }
    }
    
    private static let spokenFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()
    
    private static func parseDate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: dateString)
    }
    
    
    private func formatTimeAgo(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = formatter.date(from: dateString) else { return dateString }
        
        let now = Date()
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date, to: now)
        
        if let years = components.year, years > 0 {
            return String(localized: "\(years)y ago")
        } else if let months = components.month, months > 0 {
            return String(localized: "\(months)mo ago")
        } else if let days = components.day, days > 0 {
            return String(localized: "\(days)d ago")
        } else if let hours = components.hour, hours > 0 {
            return String(localized: "\(hours)h ago")
        } else if let minutes = components.minute, minutes > 0 {
            return String(localized: "\(minutes)m ago")
        } else {
            return String(localized: "Just now")
        }
    }
    
    private func calculateCredits(for quality: String, size: String) -> Int {
        let isHighQuality = quality.lowercased() == "high"
        let isLargeSize = size.contains("1792") || size.contains("1024")
        
        if isHighQuality {
            return isLargeSize ? 80 : 50
        } else {
            return isLargeSize ? 8 : 4
        }
    }
}