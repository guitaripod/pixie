import UIKit

private final class ResultActionButton: UIButton {
    private let action: ResultAction
    private let symbol: String
    private let caption: String
    private var isSuccess = false {
        didSet { setNeedsUpdateConfiguration() }
    }
    private var revertWork: DispatchWorkItem?
    var showsTitle = true {
        didSet {
            guard oldValue != showsTitle else { return }
            setNeedsUpdateConfiguration()
        }
    }

    /// The width the icon, the gap and the full title need, which the row compares with the
    /// share it can give this capsule.
    var titledWidth: CGFloat {
        Self.titledWidth(caption: caption, symbol: symbol)
    }

    static func titledWidth(caption: String, symbol: String) -> CGFloat {
        let font = Theme.TextStyle.subhead.font
        let title = (caption as NSString).size(withAttributes: [.font: font]).width.rounded(.up)
        let icon = (UIImage(systemName: symbol, withConfiguration: symbolConfiguration)?.size.width ?? 0).rounded(.up)
        return title + icon + imagePadding + horizontalInset * 2
    }

    private static let imagePadding: CGFloat = 5
    private static let horizontalInset: CGFloat = 8
    private static let symbolConfiguration = UIImage.SymbolConfiguration(textStyle: .subheadline, scale: .medium).applying(UIImage.SymbolConfiguration(weight: .semibold))

    init(action: ResultAction, title: String, symbol: String, accessibilityLabel spoken: String) {
        self.action = action
        self.symbol = symbol
        self.caption = title
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        accessibilityLabel = spoken
        configurationUpdateHandler = { [weak self] _ in self?.refresh() }
        heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var isHighlighted: Bool {
        didSet {
            guard oldValue != isHighlighted, !Motion.isReduced else { return }
            Motion.animate(0.15, options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
            }
        }
    }

    func showSuccess() {
        revertWork?.cancel()
        isSuccess = true
        let work = DispatchWorkItem { [weak self] in self?.isSuccess = false }
        revertWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    func reset() {
        revertWork?.cancel()
        isSuccess = false
    }

    private func refresh() {
        var config = UIButton.Configuration.plain()
        config.cornerStyle = .capsule
        config.imagePadding = Self.imagePadding
        config.imagePlacement = .leading
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: Self.horizontalInset, bottom: 10, trailing: Self.horizontalInset)
        config.title = showsTitle ? caption : nil
        config.image = UIImage(systemName: isSuccess ? "checkmark" : symbol, withConfiguration: Self.symbolConfiguration)
        config.titleLineBreakMode = .byTruncatingTail
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = Theme.TextStyle.subhead.font
            return outgoing
        }
        config.baseForegroundColor = isSuccess ? Theme.Color.success : Theme.Color.ink
        config.background.backgroundColor = isSuccess ? Theme.Color.success.withAlphaComponent(0.16) : Theme.Color.surface
        config.background.strokeColor = isSuccess ? Theme.Color.success.withAlphaComponent(0.4) : Theme.Color.line
        config.background.strokeWidth = 1
        configuration = config
    }
}

/// Three equal capsules that keep their titles while every title fits in its share of the
/// row and fall back to icons alone, still spoken in full, when one would be cut short.
private final class ResultActionRow: UIStackView {
    override func layoutSubviews() {
        super.layoutSubviews()
        fitTitles()
    }

    private func fitTitles() {
        let buttons = arrangedSubviews.compactMap { $0 as? ResultActionButton }
        guard axis == .horizontal, bounds.width > 0, !buttons.isEmpty else {
            buttons.forEach { $0.showsTitle = true }
            return
        }
        let share = (bounds.width - spacing * CGFloat(buttons.count - 1)) / CGFloat(buttons.count)
        let fits = buttons.allSatisfy { $0.titledWidth <= share }
        buttons.forEach { $0.showsTitle = fits }
    }
}

class AssistantMessageCell: ChatColumnCell {
    static let identifier = "AssistantMessageCell"
    weak var delegate: AssistantMessageCellDelegate?
    private let contentStackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = Theme.Space.md
        stack.alignment = .fill
        return stack
    }()
    private var imageViews: [UIImageView] = []
    private var actionRow: ResultActionRow?
    private var actionButtons: [ResultAction: ResultActionButton] = [:]
    private var canCompare = false
    private var actionsBeside = false
    private var imageCornerRadius: CGFloat = Theme.Radius.xl
    private static let cardRadius: CGFloat = 24
    private static let gridGap: CGFloat = 6
    var primaryAccessibilityElement: Any? {
        imageViews.first ?? self
    }
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(contentStackView)
        NSLayoutConstraint.activate([
            contentStackView.topAnchor.constraint(equalTo: column.topAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: column.bottomAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: column.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: column.trailingAnchor)
        ])
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        contentStackView.alpha = 1
        contentStackView.transform = .identity
        actionButtons.values.forEach { $0.reset() }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateActionAxis()
    }

    func configure(with message: ChatMessage, maxImageHeight: CGFloat = 0, actionsBeside: Bool = false) {
        contentStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        imageViews.removeAll()
        actionButtons.removeAll()
        actionRow = nil
        self.actionsBeside = actionsBeside
        contentStackView.alignment = actionsBeside ? .center : .fill
        isAccessibilityElement = false
        accessibilityLabel = nil
        accessibilityTraits = .none
        if let images = message.images, !images.isEmpty {
            canCompare = message.sourceImage != nil
            let card = makeImageCard(images, maxImageHeight: maxImageHeight)
            let row = makeActionRow(canCompare: canCompare)
            actionRow = row
            updateActionAxis()
            if actionsBeside {
                let pair = makeSideBySide(card, row, imageHeight: maxImageHeight, images: images)
                contentStackView.addArrangedSubview(pair)
                pair.widthAnchor.constraint(lessThanOrEqualTo: contentStackView.widthAnchor).isActive = true
            } else {
                contentStackView.addArrangedSubview(card)
                contentStackView.addArrangedSubview(row)
            }
        } else if let text = message.content, !text.isEmpty {
            contentStackView.addArrangedSubview(makeNotice(text))
            describe(String(localized: "Pixie: \(text)"), traits: .staticText)
        }
    }

    func playReveal() {
        guard !Motion.isReduced else { return }
        contentStackView.alpha = 0
        contentStackView.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        Motion.spring(0.6, damping: 0.85, options: [.allowUserInteraction]) {
            self.contentStackView.alpha = 1
            self.contentStackView.transform = .identity
        }
    }

    func showSuccess(for action: ResultAction) {
        actionButtons[action]?.showSuccess()
    }

    /// Three capsules side by side, stacked once the text is large enough that they would
    /// not fit on a line, and always stacked when they stand beside the picture.
    private func updateActionAxis() {
        let stacked = actionsBeside || traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        actionRow?.axis = stacked ? .vertical : .horizontal
    }

    /// The picture with its actions in a column to the right, the pair centred in the column
    /// of the transcript and the actions centred on the picture's height.
    private func makeSideBySide(_ card: UIView, _ row: UIView, imageHeight: CGFloat, images: [UIImage]) -> UIView {
        let columns = images.count == 1 ? 1 : 2
        let rows = (images.count + columns - 1) / columns
        let width = Self.widthCap(columns: columns, rows: rows, aspect: images[0].clampedAspect, maxHeight: imageHeight)
        let pair = UIStackView(arrangedSubviews: [card, row])
        pair.axis = .horizontal
        pair.alignment = .center
        pair.spacing = Self.sideActionsSpacing
        let cardWidth = card.widthAnchor.constraint(equalToConstant: width)
        cardWidth.priority = UILayoutPriority(rawValue: 900)
        NSLayoutConstraint.activate([
            cardWidth,
            row.widthAnchor.constraint(equalToConstant: Self.sideActionsWidth)
        ])
        return pair
    }

    private func makeNotice(_ text: String) -> UIView {
        let tint = Theme.Color.warning
        let surface = SurfaceView(style: .tinted(tint.withAlphaComponent(0.14)), cornerRadius: Theme.Radius.lg)
        let icon = UIImageView(image: UIImage(systemName: "exclamationmark.triangle.fill"))
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.tintColor = tint
        icon.contentMode = .scaleAspectFit
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .headline, scale: .medium)
        icon.setContentHuggingPriority(.required, for: .horizontal)
        icon.setContentCompressionResistancePriority(.required, for: .horizontal)
        icon.isAccessibilityElement = false
        let label = UILabel()
        label.apply(.callout, color: Theme.Color.ink)
        label.text = text
        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.axis = .horizontal
        stack.alignment = .top
        stack.spacing = Theme.Space.md
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: Theme.Space.md + 2, leading: Theme.Space.lg, bottom: Theme.Space.md + 2, trailing: Theme.Space.lg)
        surface.contentView.addSubview(stack)
        stack.pinEdges(to: surface.contentView)
        return surface
    }

    /// A single result fills one card at its own aspect; a pack of results becomes a grid of
    /// two columns inside the same card, 6 points apart, so four headshots fit the screen.
    private func makeImageCard(_ images: [UIImage], maxImageHeight: CGFloat) -> UIView {
        let card = SurfaceView(style: .card, cornerRadius: Self.cardRadius)
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(card)
        let columns = images.count == 1 ? 1 : 2
        let rows = (images.count + columns - 1) / columns
        let aspect = images[0].clampedAspect
        imageCornerRadius = columns == 1 ? Self.cardRadius : Theme.Radius.sm
        let grid = makeGrid(images, columns: columns, aspect: aspect)
        card.contentView.addSubview(grid)
        grid.pinEdges(to: card.contentView)
        let maxWidth = maxImageHeight > 0 ? Self.widthCap(columns: columns, rows: rows, aspect: aspect, maxHeight: maxImageHeight) : nil
        sizeCard(card, in: container, aspect: nil, maxWidth: maxWidth)
        return container
    }

    static let sideActionsSpacing: CGFloat = Theme.Space.md

    /// The width of the column of actions beside a picture: the widest of the three titles in
    /// the current language and text size, with its icon and padding.
    static var sideActionsWidth: CGFloat {
        let titles = [(String(localized: "Save"), "square.and.arrow.down"),
                      (String(localized: "Share"), "square.and.arrow.up"),
                      (String(localized: "Compare"), "rectangle.split.2x1")]
        return (titles.map { ResultActionButton.titledWidth(caption: $0.0, symbol: $0.1) }.max() ?? 0) + Theme.Space.xs
    }

    /// The height a card of `width` takes at `aspect`, the inverse of `widthCap`.
    static func imageHeight(width: CGFloat, columns: Int, rows: Int, aspect: CGFloat) -> CGFloat {
        if columns == 1 { return width * aspect }
        let cellWidth = (width - Self.gridGap) / 2
        return cellWidth * aspect * CGFloat(rows) + Self.gridGap * CGFloat(rows - 1)
    }

    static func widthCap(columns: Int, rows: Int, aspect: CGFloat, maxHeight: CGFloat) -> CGFloat {
        if columns == 1 { return maxHeight / aspect }
        let cellHeight = (maxHeight - Self.gridGap * CGFloat(rows - 1)) / CGFloat(rows)
        return cellHeight / aspect * 2 + Self.gridGap
    }

    private func makeGrid(_ images: [UIImage], columns: Int, aspect: CGFloat) -> UIView {
        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = Self.gridGap
        grid.distribution = .fill
        var rowStacks: [UIStackView] = []
        for (index, image) in images.enumerated() {
            if index % columns == 0 {
                let rowStack = UIStackView()
                rowStack.axis = .horizontal
                rowStack.spacing = Self.gridGap
                rowStack.distribution = .fillEqually
                grid.addArrangedSubview(rowStack)
                rowStacks.append(rowStack)
            }
            let imageView = makeImageView(image, index: index, total: images.count)
            rowStacks.last?.addArrangedSubview(imageView)
            imageViews.append(imageView)
        }
        if let first = rowStacks.first, let firstView = first.arrangedSubviews.first {
            let ratio = firstView.heightAnchor.constraint(equalTo: firstView.widthAnchor, multiplier: aspect)
            ratio.isActive = true
            for other in rowStacks.dropFirst() {
                other.heightAnchor.constraint(equalTo: first.heightAnchor).isActive = true
            }
        }
        return grid
    }

    private func makeImageView(_ image: UIImage, index: Int, total: Int) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = Theme.Color.fill
        imageView.isUserInteractionEnabled = true
        imageView.tag = index
        imageView.image = image
        imageView.accessibilityIgnoresInvertColors = true
        imageView.describe(String(localized: "Generated image \(index + 1) of \(total)"), traits: [.image, .button])
        imageView.accessibilityCustomActions = customActions(forImageAt: index, in: imageView)
        imageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(imageTapped(_:))))
        imageView.addInteraction(UIContextMenuInteraction(delegate: self))
        return imageView
    }

    /// The result's actions as VoiceOver custom actions, so each image can be saved, shared,
    /// edited or compared without finding the capsules below it.
    private func customActions(forImageAt index: Int, in imageView: UIImageView) -> [UIAccessibilityCustomAction] {
        var actions = [
            makeCustomAction(String(localized: "Save")) { cell in
                cell.delegate?.assistantMessageCell(cell, didRequest: .save, imageIndex: index, from: imageView)
            },
            makeCustomAction(String(localized: "Share")) { cell in
                cell.delegate?.assistantMessageCell(cell, didRequest: .share, imageIndex: index, from: imageView)
            },
            makeCustomAction(String(localized: "Edit Image")) { cell in
                cell.delegate?.assistantMessageCell(cell, didSelectImageForEdit: index)
            }
        ]
        if canCompare {
            actions.append(makeCustomAction(String(localized: "Before & after")) { cell in
                cell.delegate?.assistantMessageCell(cell, didRequest: .beforeAfter, imageIndex: index, from: imageView)
            })
        }
        return actions
    }

    private func makeCustomAction(_ name: String, perform: @escaping (AssistantMessageCell) -> Void) -> UIAccessibilityCustomAction {
        UIAccessibilityCustomAction(name: name) { [weak self] _ in
            guard let self else { return false }
            perform(self)
            return true
        }
    }

    private func makeActionRow(canCompare: Bool) -> ResultActionRow {
        let row = ResultActionRow()
        row.axis = .horizontal
        row.spacing = Theme.Space.sm
        row.distribution = .fillEqually
        let save = String(localized: "Save")
        let share = String(localized: "Share")
        addActionButton(to: row, action: .save, title: save, accessibilityLabel: save, symbol: "square.and.arrow.down")
        addActionButton(to: row, action: .share, title: share, accessibilityLabel: share, symbol: "square.and.arrow.up")
        if canCompare {
            addActionButton(to: row, action: .beforeAfter, title: String(localized: "Compare"), accessibilityLabel: String(localized: "Before & after"), symbol: "rectangle.split.2x1")
        }
        return row
    }

    private func addActionButton(to row: UIStackView, action: ResultAction, title: String, accessibilityLabel: String, symbol: String) {
        let button = ResultActionButton(action: action, title: title, symbol: symbol, accessibilityLabel: accessibilityLabel)
        button.addAction(UIAction { [weak self, weak button] _ in
            guard let self, let button else { return }
            HapticManager.shared.impact(.click)
            self.delegate?.assistantMessageCell(self, didRequest: action, imageIndex: nil, from: button)
        }, for: .touchUpInside)
        actionButtons[action] = button
        row.addArrangedSubview(button)
    }

    @objc private func imageTapped(_ gesture: UITapGestureRecognizer) {
        guard let imageView = gesture.view else { return }
        delegate?.assistantMessageCell(self, didTapImageAt: imageView.tag)
    }
}

@available(iOS 13.0, *)
extension AssistantMessageCell: UIContextMenuInteractionDelegate {
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        guard let imageView = interaction.view as? UIImageView,
              let image = imageView.image else { return nil }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: {
            let previewController = UIViewController()
            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false
            previewController.view.addSubview(imageView)
            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: previewController.view.topAnchor),
                imageView.leadingAnchor.constraint(equalTo: previewController.view.leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: previewController.view.trailingAnchor),
                imageView.bottomAnchor.constraint(equalTo: previewController.view.bottomAnchor)
            ])
            previewController.preferredContentSize = image.size
            return previewController
        }) { _ in
            let save = UIAction(title: String(localized: "Save to Photos"), image: UIImage(systemName: "square.and.arrow.down")) { _ in
                PhotoSavingService.shared.saveToLibrary([image]) { result in
                    switch result {
                    case .success:
                        HapticManager.shared.impact(.success)
                        Announce.say(String(localized: "Saved to Photos"))
                    case .failure(let error):
                        HapticManager.shared.impact(.error)
                        Announce.say(error.localizedDescription)
                    }
                }
            }
            let share = UIAction(title: String(localized: "Share"), image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
                guard let self = self,
                      let viewController = self.window?.rootViewController else { return }
                ImageSharingService.shared.shareImage(
                    image,
                    from: viewController,
                    sourceView: imageView
                )
            }
            let copy = UIAction(title: String(localized: "Copy"), image: UIImage(systemName: "doc.on.doc")) { _ in
                UIPasteboard.general.image = image
                HapticManager.shared.impact(.success)
            }
            let edit = UIAction(title: String(localized: "Edit Image"), image: UIImage(systemName: "wand.and.stars")) { [weak self] _ in
                guard let self = self else { return }
                self.delegate?.assistantMessageCell(self, didSelectImageForEdit: imageView.tag)
            }
            return UIMenu(title: "", children: [edit, save, share, copy])
        }
    }

    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, previewForHighlightingMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let view = interaction.view else { return nil }
        let parameters = UIPreviewParameters()
        parameters.visiblePath = UIBezierPath(roundedRect: view.bounds, cornerRadius: imageCornerRadius)
        return UITargetedPreview(view: view, parameters: parameters)
    }

    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        guard let imageView = interaction.view as? UIImageView else { return }
        animator.addCompletion {
            self.delegate?.assistantMessageCell(self, didTapImageAt: imageView.tag)
        }
    }
}

protocol AssistantMessageCellDelegate: AnyObject {
    func assistantMessageCell(_ cell: AssistantMessageCell, didTapImageAt index: Int)
    func assistantMessageCell(_ cell: AssistantMessageCell, didLongPressImageAt index: Int)
    func assistantMessageCell(_ cell: AssistantMessageCell, didSelectImageForEdit index: Int)
    func assistantMessageCell(_ cell: AssistantMessageCell, didRequest action: ResultAction, imageIndex: Int?, from sourceView: UIView)
}
