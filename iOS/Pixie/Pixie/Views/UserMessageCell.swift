import UIKit

/// A transcript row: a centred column no wider than a readable measure, with the screen
/// margin on each side and 12 points above and below so two turns sit 24 apart.
class ChatColumnCell: UITableViewCell {
    static let maximumColumnWidth: CGFloat = Theme.Width.form
    static let turnSpacing: CGFloat = Theme.Space.md

    let column = UILayoutGuide()
    private var leadingMargin: NSLayoutConstraint!
    private var trailingMargin: NSLayoutConstraint!
    private var leadingFill: NSLayoutConstraint!
    private var trailingFill: NSLayoutConstraint!

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentView.addLayoutGuide(column)
        let margin = Theme.screenMargin(for: traitCollection)
        leadingMargin = column.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: margin)
        trailingMargin = column.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -margin)
        leadingFill = column.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin)
        trailingFill = column.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -margin)
        leadingFill.priority = .defaultHigh
        trailingFill.priority = .defaultHigh
        NSLayoutConstraint.activate([
            leadingMargin, trailingMargin, leadingFill, trailingFill,
            column.widthAnchor.constraint(lessThanOrEqualToConstant: Self.maximumColumnWidth),
            column.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            column.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Self.turnSpacing),
            column.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Self.turnSpacing)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        let margin = Theme.screenMargin(for: traitCollection)
        leadingMargin.constant = margin
        leadingFill.constant = margin
        trailingMargin.constant = -margin
        trailingFill.constant = -margin
    }

    /// Sizes a card: as wide as the column unless `maxWidth` is smaller, in which case it
    /// narrows and stays centred, `centerOffset` points to the side of the centre. With an `aspect`
    /// (height over width) the height follows the width.
    @discardableResult
    func sizeCard(_ card: UIView, in container: UIView, aspect: CGFloat?, maxWidth: CGFloat?, centerOffset: CGFloat = 0) -> [NSLayoutConstraint] {
        let fillWidth = card.widthAnchor.constraint(equalTo: container.widthAnchor)
        fillWidth.priority = .defaultHigh
        var constraints = [
            fillWidth,
            card.centerXAnchor.constraint(equalTo: container.centerXAnchor, constant: centerOffset),
            card.topAnchor.constraint(equalTo: container.topAnchor),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            card.widthAnchor.constraint(lessThanOrEqualTo: container.widthAnchor)
        ]
        if let maxWidth, maxWidth > 0 {
            constraints.append(card.widthAnchor.constraint(lessThanOrEqualToConstant: maxWidth))
        }
        if let aspect {
            let height = card.heightAnchor.constraint(equalTo: card.widthAnchor, multiplier: aspect)
            height.priority = UILayoutPriority(rawValue: 900)
            constraints.append(height)
        }
        NSLayoutConstraint.activate(constraints)
        return constraints
    }
}

class UserMessageCell: ChatColumnCell {
    static let identifier = "UserMessageCell"
    private let bubbleView = SurfaceView(style: .sunken, cornerRadius: Theme.Radius.lg)
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.apply(.body)
        return label
    }()
    private let photoView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = Theme.Radius.md
        imageView.layer.cornerCurve = .continuous
        imageView.backgroundColor = Theme.Color.fill
        imageView.accessibilityIgnoresInvertColors = true
        imageView.isHidden = true
        return imageView
    }()
    private lazy var photoWidthConstraint = photoView.widthAnchor.constraint(equalToConstant: 0)
    private lazy var labelLeadingConstraint = messageLabel.leadingAnchor.constraint(equalTo: photoView.trailingAnchor, constant: Theme.Space.xs)
    private var messageText = ""
    private var timestamp = Date()
    private static let photoSize: CGFloat = 56
    private static let bubbleLeadingGap: CGFloat = Theme.Space.xxxl + Theme.Space.sm

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    private func setupViews() {
        contentView.addSubview(bubbleView)
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.contentView.addSubview(photoView)
        bubbleView.contentView.addSubview(messageLabel)
        let content = bubbleView.contentView
        let centred = messageLabel.centerYAnchor.constraint(equalTo: content.centerYAnchor)
        centred.priority = .defaultHigh
        NSLayoutConstraint.activate([
            photoView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: Theme.Space.md),
            photoView.topAnchor.constraint(equalTo: content.topAnchor, constant: Theme.Space.md),
            photoView.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -Theme.Space.md),
            labelLeadingConstraint,
            messageLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -Theme.Space.lg),
            messageLabel.topAnchor.constraint(greaterThanOrEqualTo: content.topAnchor, constant: Theme.Space.md),
            messageLabel.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -Theme.Space.md),
            centred,
            photoWidthConstraint,
            photoView.heightAnchor.constraint(equalTo: photoView.widthAnchor)
        ])
        let topFit = messageLabel.topAnchor.constraint(equalTo: content.topAnchor, constant: Theme.Space.md)
        topFit.priority = UILayoutPriority(rawValue: 700)
        let bottomFit = messageLabel.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -Theme.Space.md)
        bottomFit.priority = UILayoutPriority(rawValue: 700)
        NSLayoutConstraint.activate([topFit, bottomFit])
        bubbleView.addInteraction(UIContextMenuInteraction(delegate: self))
        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: column.topAnchor),
            bubbleView.bottomAnchor.constraint(equalTo: column.bottomAnchor),
            bubbleView.trailingAnchor.constraint(equalTo: column.trailingAnchor),
            bubbleView.leadingAnchor.constraint(greaterThanOrEqualTo: column.leadingAnchor, constant: Self.bubbleLeadingGap),
            messageLabel.widthAnchor.constraint(lessThanOrEqualTo: column.widthAnchor, constant: -(Self.bubbleLeadingGap + Theme.Space.md + Theme.Space.lg))
        ])
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        messageLabel.attributedText = nil
        photoView.image = nil
        photoView.isHidden = true
        photoWidthConstraint.constant = 0
        accessibilityCustomActions = nil
    }

    func configure(with message: ChatMessage) {
        timestamp = message.timestamp
        let rows = metadataRows(for: message.metadata)
        messageText = message.content ?? ""
        messageLabel.attributedText = requestText(message.content ?? "", detail: rows.map(\.value).joined(separator: " · "))
        photoView.image = message.editingImage
        photoView.isHidden = message.editingImage == nil
        photoWidthConstraint.constant = message.editingImage == nil ? 0 : Self.photoSize
        labelLeadingConstraint.constant = message.editingImage == nil ? Theme.Space.xs : Theme.Space.md
        let summary = rows.map { "\($0.label) \($0.value)" }
        describe(String(localized: "You: \(message.content ?? "")"), value: summary.isEmpty ? nil : summary.joined(separator: ", "), traits: .staticText)
        accessibilityCustomActions = [
            UIAccessibilityCustomAction(name: String(localized: "Copy")) { [weak self] _ in
                guard let text = self?.messageText, !text.isEmpty else { return false }
                UIPasteboard.general.string = text
                return true
            }
        ]
    }

    /// The prompt with the request's options as one quiet line under it, in one label so
    /// the row measures a single block of text.
    private func requestText(_ text: String, detail: String) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: Theme.attributed(text, .body))
        if !detail.isEmpty {
            result.append(Theme.attributed("\n" + detail, .footnote))
        }
        return result
    }

    /// The quality, size, format and similar choices of a request, labelled for VoiceOver
    /// and shown as one quiet line; requests that went to Gemini carry none.
    private func metadataRows(for metadata: ChatMessage.MessageMetadata?) -> [(label: String, value: String)] {
        guard let metadata, !(metadata.model?.starts(with: "gemini") ?? false) else { return [] }
        var rows: [(label: String, value: String)] = []
        if let quality = metadata.quality {
            rows.append((String(localized: "Quality"), quality.uppercased()))
        }
        if let size = metadata.sizeDisplay {
            rows.append((String(localized: "Size"), size))
        }
        if let background = metadata.background {
            rows.append((String(localized: "Background"), background))
        }
        if let format = metadata.format {
            rows.append((String(localized: "Format"), format))
            if let compression = metadata.compression {
                rows.append((String(localized: "Compress"), String(localized: "\(compression)%")))
            }
        }
        if let moderation = metadata.moderation {
            rows.append((String(localized: "Moderation"), moderation))
        }
        return rows
    }
}

extension UserMessageCell: UIContextMenuInteractionDelegate {
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        guard !messageText.isEmpty else { return nil }
        let text = messageText
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        let title = formatter.string(from: timestamp)
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let copy = UIAction(title: String(localized: "Copy"), image: UIImage(systemName: "doc.on.doc")) { _ in
                UIPasteboard.general.string = text
                HapticManager.shared.impact(.success)
            }
            return UIMenu(title: title, children: [copy])
        }
    }
}
