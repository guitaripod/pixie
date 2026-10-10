import UIKit

final class GalleryImageCell: UICollectionViewCell {

    static let identifier = "GalleryImageCell"

    private let placeholder = ShimmerView()
    private let imageView = UIImageView()
    private let selectionDimView = UIView()
    private let selectionBadge = GallerySelectionBadge()
    private let failureIcon = UIImageView()

    private var currentImageMetadata: ImageMetadata?
    private var isSelectionMode = false
    private var isMarked = false
    private var isPlaceholder = false

    var onAction: ((ImageAction) -> Void)?

    private static let markedScale: CGFloat = 0.88
    private static let markedRadius: CGFloat = Theme.Radius.sm

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
        currentImageMetadata = nil
        failureIcon.isHidden = true
        placeholder.isHidden = false
        onAction = nil
        isSelectionMode = false
        isMarked = false
        isPlaceholder = false
        isAccessibilityElement = true
        updateSelectionAppearance(animated: false)
    }

    private func setupUI() {
        contentView.backgroundColor = Theme.Color.canvas
        contentView.clipsToBounds = true

        setupPointerInteraction()

        placeholder.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(placeholder)

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerCurve = .continuous
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)

        selectionDimView.backgroundColor = UIColor.black.withAlphaComponent(0.28)
        selectionDimView.alpha = 0
        selectionDimView.isUserInteractionEnabled = false
        selectionDimView.translatesAutoresizingMaskIntoConstraints = false
        imageView.addSubview(selectionDimView)

        selectionBadge.isHidden = true
        selectionBadge.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(selectionBadge)

        failureIcon.image = UIImage(systemName: "exclamationmark.triangle")
        failureIcon.tintColor = Theme.Color.inkTertiary
        failureIcon.contentMode = .scaleAspectFit
        failureIcon.isHidden = true
        failureIcon.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(failureIcon)

        placeholder.pinEdges(to: contentView)
        imageView.pinEdges(to: contentView)
        selectionDimView.pinEdges(to: imageView)
        NSLayoutConstraint.activate([
            selectionBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Space.sm),
            selectionBadge.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Theme.Space.sm),
            failureIcon.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            failureIcon.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            failureIcon.widthAnchor.constraint(equalToConstant: 24),
            failureIcon.heightAnchor.constraint(equalToConstant: 24),
        ])

        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    /// Switches the cell between browsing and picking. While picking, a badge in the corner
    /// shows whether the image is chosen, and VoiceOver hears the chosen state instead of
    /// the per-image actions.
    func setSelection(mode: Bool, marked: Bool) {
        isSelectionMode = mode
        isMarked = marked
        updateSelectionAppearance(animated: window != nil)
        updateAccessibility()
    }

    private func updateSelectionAppearance(animated: Bool) {
        let showsMarked = isSelectionMode && isMarked
        selectionBadge.isHidden = !isSelectionMode
        selectionBadge.setMarked(showsMarked, animated: animated)
        let apply = {
            self.selectionDimView.alpha = showsMarked ? 1 : 0
            self.imageView.transform = showsMarked ? CGAffineTransform(scaleX: Self.markedScale, y: Self.markedScale) : .identity
            self.imageView.layer.cornerRadius = showsMarked ? Self.markedRadius / Self.markedScale : 0
        }
        if animated {
            Motion.spring(0.4, damping: 0.82, options: [.allowUserInteraction, .beginFromCurrentState], animations: apply)
        } else {
            apply()
        }
    }

    func configure(with metadata: ImageMetadata) {
        isPlaceholder = false
        currentImageMetadata = metadata
        failureIcon.isHidden = true
        placeholder.isHidden = false
        isAccessibilityElement = true
        loadImage(from: metadata.thumbnailUrl ?? metadata.url)
        updateAccessibility()
    }

    /// A loading square for the skeleton grid: shimmer only, invisible to VoiceOver.
    func configurePlaceholder() {
        isPlaceholder = true
        currentImageMetadata = nil
        imageView.image = nil
        failureIcon.isHidden = true
        placeholder.isHidden = false
        isAccessibilityElement = false
        accessibilityCustomActions = nil
    }

    private func loadImage(from urlString: String) {
        Task { @MainActor in
            let image = await ImageCache.shared.loadImage(from: urlString)
            guard self.currentImageMetadata?.url == urlString || self.currentImageMetadata?.thumbnailUrl == urlString else { return }
            if let image {
                self.imageView.image = image
                self.placeholder.isHidden = true
                self.failureIcon.isHidden = true
            } else {
                self.failureIcon.isHidden = false
            }
        }
    }

    private func updateAccessibility() {
        guard let metadata = currentImageMetadata, !isPlaceholder else { return }
        accessibilityLabel = accessibilityDescription(for: metadata)
        accessibilityTraits = isSelectionMode && isMarked ? [.button, .selected] : .button
        accessibilityCustomActions = isSelectionMode ? [] : makeCustomActions()
    }

    /// The cell as one spoken phrase: the prompt, when it was made and what it cost. The
    /// picture carries no text, so this is where that information lives for VoiceOver.
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
}

private final class GallerySelectionBadge: UIView {

    private let fillView = GradientView()
    private let checkView = UIImageView()
    private let ringLayer = CAShapeLayer()

    private static let diameter: CGFloat = 24

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.3
        layer.shadowRadius = 3
        layer.shadowOffset = CGSize(width: 0, height: 1)

        fillView.cornerRadius = Self.diameter / 2
        fillView.alpha = 0
        fillView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(fillView)

        ringLayer.fillColor = UIColor.black.withAlphaComponent(0.22).cgColor
        ringLayer.strokeColor = UIColor.white.cgColor
        ringLayer.lineWidth = 2
        layer.insertSublayer(ringLayer, at: 0)

        checkView.image = UIImage(systemName: "checkmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .heavy))
        checkView.tintColor = .white
        checkView.contentMode = .center
        checkView.alpha = 0
        checkView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(checkView)

        fillView.pinEdges(to: self)
        checkView.pinEdges(to: self)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.diameter),
            heightAnchor.constraint(equalToConstant: Self.diameter),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        ringLayer.path = UIBezierPath(ovalIn: bounds.insetBy(dx: ringLayer.lineWidth / 2, dy: ringLayer.lineWidth / 2)).cgPath
        ringLayer.frame = bounds
    }

    func setMarked(_ marked: Bool, animated: Bool) {
        let apply = {
            self.fillView.alpha = marked ? 1 : 0
            self.checkView.alpha = marked ? 1 : 0
            self.transform = marked ? CGAffineTransform(scaleX: 1.08, y: 1.08) : .identity
        }
        if animated {
            Motion.spring(0.35, damping: 0.7, options: [.allowUserInteraction, .beginFromCurrentState], animations: apply)
        } else {
            apply()
        }
    }
}
