import UIKit
import Photos

class ChatTableView: UIView {
    enum Section: Int, CaseIterable {
        case messages
    }
    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.backgroundColor = .clear
        tv.separatorStyle = .none
        tv.keyboardDismissMode = .interactive
        tv.contentInsetAdjustmentBehavior = .never
        tv.allowsSelection = false
        tv.estimatedRowHeight = 320
        tv.delegate = self
        return tv
    }()
    private var dataSource: UITableViewDiffableDataSource<Section, ChatMessage>!
    private let emptyStateView = ChatEmptyStateView()
    private var pendingRevealID: String?
    weak var delegate: ChatTableViewDelegate?
    var onStarterPromptSelected: ((String) -> Void)?
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupDataSource()
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    private func setupViews() {
        backgroundColor = Theme.Color.canvas
        addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: topAnchor),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.onPromptSelected = { [weak self] prompt in
            self?.onStarterPromptSelected?(prompt)
        }
        addSubview(emptyStateView)
        NSLayoutConstraint.activate([
            emptyStateView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        registerCells()
    }
    private func registerCells() {
        tableView.register(UserMessageCell.self, forCellReuseIdentifier: UserMessageCell.identifier)
        tableView.register(AssistantMessageCell.self, forCellReuseIdentifier: AssistantMessageCell.identifier)
        tableView.register(LoadingMessageCell.self, forCellReuseIdentifier: LoadingMessageCell.identifier)
    }
    private func setupDataSource() {
        dataSource = UITableViewDiffableDataSource<Section, ChatMessage>(
            tableView: tableView
        ) { [weak self] tableView, indexPath, message in
            switch message.role {
            case .user:
                let cell = tableView.dequeueReusableCell(withIdentifier: UserMessageCell.identifier, for: indexPath) as! UserMessageCell
                cell.configure(with: message)
                return cell
            case .assistant:
                let cell = tableView.dequeueReusableCell(withIdentifier: AssistantMessageCell.identifier, for: indexPath) as! AssistantMessageCell
                cell.configure(with: message, maxImageHeight: self?.maxResultImageHeight ?? 0)
                cell.delegate = self
                return cell
            case .loading:
                let cell = tableView.dequeueReusableCell(withIdentifier: LoadingMessageCell.identifier, for: indexPath) as! LoadingMessageCell
                cell.configure(with: message, aspect: self?.expectedAspect(of: message) ?? 1, maxImageHeight: self?.maxResultImageHeight ?? 0)
                cell.startAnimating()
                return cell
            }
        }
        dataSource.defaultRowAnimation = .fade
    }
    private var isShortWindow: Bool {
        traitCollection.verticalSizeClass == .compact
    }

    /// A result is never taller than 70% of the transcript; in a window with compact height
    /// (a landscape phone) it is capped so it fits between the top and bottom insets together
    /// with its actions. Zero means the table has no size yet and the width decides.
    private var maxResultImageHeight: CGFloat {
        guard tableView.bounds.height > 0 else { return 0 }
        if isShortWindow {
            let visible = tableView.bounds.height - tableView.contentInset.top - tableView.contentInset.bottom
            return max(visible - Self.resultActionsHeight, Self.minimumResultImageHeight)
        }
        return max(tableView.bounds.height * Self.maximumResultHeightShare, Self.minimumResultImageHeight)
    }
    private static let resultActionsHeight: CGFloat = 80
    private static let minimumResultImageHeight: CGFloat = 120
    private static let maximumResultHeightShare: CGFloat = 0.7

    /// The height-to-width ratio a generating card reserves: the one of the photo being
    /// edited when there is one, a square otherwise, so the result lands without a jump.
    private func expectedAspect(of message: ChatMessage) -> CGFloat {
        let items = dataSource.snapshot().itemIdentifiers
        guard let index = items.firstIndex(of: message), index > 0,
              let source = items[index - 1].editingImage else { return 1 }
        return source.clampedAspect
    }
    private var keyboardInset: CGFloat = 0
    private var laidOutSize = CGSize.zero

    private var bottomInset: CGFloat {
        let base = isShortWindow ? Self.shortWindowBottomInset : (composerClearance ?? Self.regularBottomInset)
        return keyboardInset + base + (keyboardInset > 0 ? 0 : safeAreaInsets.bottom)
    }
    /// The height of the floating composer when it is taller than the default 120 points, so
    /// the last turn always rests above it.
    var composerClearance: CGFloat? {
        didSet { applyInsets() }
    }
    private var topInset: CGFloat {
        safeAreaInsets.top + Self.topBarClearance
    }
    private static let regularBottomInset: CGFloat = 120
    private static let shortWindowBottomInset: CGFloat = 20
    private static let topBarClearance: CGFloat = 76

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory,
              dataSource != nil else { return }
        reloadAllRows(keepingBottom: true)
    }

    /// Row heights are measured once, so a change of text size has to measure them again.
    private func reloadAllRows(keepingBottom: Bool) {
        let wasAtBottom = isShowingLastMessage
        var snapshot = dataSource.snapshot()
        snapshot.reloadItems(snapshot.itemIdentifiers)
        dataSource.apply(snapshot, animatingDifferences: false)
        tableView.layoutIfNeeded()
        if keepingBottom, wasAtBottom {
            scrollToBottom(animated: false)
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil, dataSource != nil, !dataSource.snapshot().itemIdentifiers.isEmpty else { return }
        reloadAllRows(keepingBottom: true)
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        applyInsets()
    }

    /// Keeps a transcript that has not been scrolled pinned to its first line under the top
    /// bar while the insets change.
    private func applyInsets() {
        let top = topInset
        let bottom = bottomInset
        let old = tableView.contentInset
        guard abs(old.top - top) > 0.5 || abs(old.bottom - bottom) > 0.5 else { return }
        let wasAtTop = tableView.contentOffset.y <= -old.top + 1
        tableView.contentInset.top = top
        tableView.contentInset.bottom = bottom
        tableView.verticalScrollIndicatorInsets = UIEdgeInsets(top: top, left: 0, bottom: bottom, right: 0)
        if wasAtTop {
            tableView.contentOffset.y = -top
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyInsets()
        guard abs(bounds.height - laidOutSize.height) > 1 || abs(bounds.width - laidOutSize.width) > 1 else { return }
        let hadLayout = laidOutSize != .zero
        laidOutSize = bounds.size
        let wasAtBottom = isShowingLastMessage
        let anchor = tableView.indexPathsForVisibleRows?.first
        var snapshot = dataSource.snapshot()
        snapshot.reloadItems(snapshot.itemIdentifiers)
        dataSource.apply(snapshot, animatingDifferences: false)
        tableView.layoutIfNeeded()
        if !hadLayout || wasAtBottom {
            scrollToBottom(animated: false)
        } else if let anchor {
            tableView.scrollToRow(at: anchor, at: .top, animated: false)
        }
    }

    private var isShowingLastMessage: Bool {
        guard tableView.numberOfSections > 0 else { return false }
        let lastRow = tableView.numberOfRows(inSection: 0) - 1
        guard lastRow >= 0 else { return false }
        return tableView.indexPathsForVisibleRows?.contains(IndexPath(row: lastRow, section: 0)) ?? false
    }

    func setMessages(_ messages: [ChatMessage], animated: Bool = true) {
        let previous = dataSource.snapshot().itemIdentifiers
        prepareReveal(of: messages.last, previous: previous, animated: animated)
        var snapshot = NSDiffableDataSourceSnapshot<Section, ChatMessage>()
        snapshot.appendSections([.messages])
        snapshot.appendItems(messages, toSection: .messages)
        dataSource.apply(snapshot, animatingDifferences: animated) { [weak self] in
            if !messages.isEmpty {
                self?.scrollToBottom(animated: animated)
            }
        }
        updateEmptyState(isEmpty: messages.isEmpty, animated: animated)
    }

    /// Only a result that arrives while the transcript is open gets the fade-in; opening a
    /// saved conversation or scrolling back never replays it.
    private func prepareReveal(of latest: ChatMessage?, previous: [ChatMessage], animated: Bool) {
        guard animated, !previous.isEmpty, let latest,
              latest.role == .assistant, latest.images?.isEmpty == false,
              !previous.contains(latest) else { return }
        pendingRevealID = latest.id
    }

    private func updateEmptyState(isEmpty: Bool, animated: Bool) {
        emptyStateView.isUserInteractionEnabled = isEmpty
        if isEmpty {
            emptyStateView.isHidden = false
        }
        let apply = { self.emptyStateView.alpha = isEmpty ? 1 : 0 }
        let finish = { self.emptyStateView.isHidden = !isEmpty }
        emptyStateView.accessibilityElementsHidden = !isEmpty
        if animated {
            Motion.animate(0.25, animations: apply, completion: { _ in finish() })
        } else {
            apply()
            finish()
        }
    }
    func addMessage(_ message: ChatMessage, animated: Bool = true) {
        var snapshot = dataSource.snapshot()
        prepareReveal(of: message, previous: snapshot.itemIdentifiers, animated: animated)
        if !snapshot.sectionIdentifiers.contains(.messages) {
            snapshot.appendSections([.messages])
        }
        snapshot.appendItems([message], toSection: .messages)
        dataSource.apply(snapshot, animatingDifferences: animated) { [weak self] in
            self?.scrollToBottom(animated: animated)
        }
        updateEmptyState(isEmpty: false, animated: animated)
    }

    /// Turns the Save or Share capsule of a result green with a check for a moment. The
    /// controller calls it once the save has gone through or the share sheet has completed.
    func showActionSucceeded(_ action: ResultAction, for message: ChatMessage) {
        guard let indexPath = dataSource.indexPath(for: message),
              let cell = tableView.cellForRow(at: indexPath) as? AssistantMessageCell else { return }
        cell.showSuccess(for: action)
    }

    /// Moves VoiceOver to the newest result once it is on screen, after the "ready"
    /// announcement has had time to finish.
    func focusLatestResult() {
        guard UIAccessibility.isVoiceOverRunning else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.resultFocusDelay) { [weak self] in
            guard let self,
                  let message = self.dataSource.snapshot().itemIdentifiers.last(where: { $0.role == .assistant }),
                  let indexPath = self.dataSource.indexPath(for: message) else { return }
            self.tableView.layoutIfNeeded()
            let cell = self.tableView.cellForRow(at: indexPath) as? AssistantMessageCell
            Announce.layoutChanged(cell?.primaryAccessibilityElement ?? self.tableView)
        }
    }

    private static let resultFocusDelay: TimeInterval = 1.3

    func scrollToBottom(animated: Bool = true) {
        let animated = animated && !Motion.isReduced
        guard let lastSection = dataSource.snapshot().sectionIdentifiers.last,
              let lastItem = dataSource.snapshot().itemIdentifiers(inSection: lastSection).last,
              let indexPath = dataSource.indexPath(for: lastItem) else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let contentHeight = self.tableView.contentSize.height
            let frameHeight = self.tableView.frame.height
            let inset = self.tableView.contentInset

            if contentHeight > frameHeight - inset.top - inset.bottom {
                self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: animated)
            } else if self.tableView.contentOffset.y > -inset.top {
                self.tableView.setContentOffset(CGPoint(x: 0, y: -inset.top), animated: false)
            }
        }
    }
    func adjustForKeyboard(height: CGFloat, duration: TimeInterval) {
        keyboardInset = height > 0 ? height - 20 : 0
        applyInsets()
        if height > 0 {
            scrollToBottom(animated: true)
        }
    }

    func setHorizontalContentInsets(left: CGFloat, right: CGFloat) {
        tableView.contentInset.left = left
        tableView.contentInset.right = right
        tableView.scrollIndicatorInsets.left = 0
        tableView.scrollIndicatorInsets.right = 0
    }

    var contentInset: UIEdgeInsets {
        get { tableView.contentInset }
        set {
            tableView.contentInset = newValue
            tableView.scrollIndicatorInsets = UIEdgeInsets(top: tableView.scrollIndicatorInsets.top,
                                                           left: 0,
                                                           bottom: tableView.scrollIndicatorInsets.bottom,
                                                           right: 0)
        }
    }

    var scrollIndicatorInsets: UIEdgeInsets {
        get { tableView.scrollIndicatorInsets }
        set { tableView.scrollIndicatorInsets = newValue }
    }
}

extension ChatTableView: UITableViewDelegate {
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let pending = pendingRevealID,
              let cell = cell as? AssistantMessageCell,
              dataSource.itemIdentifier(for: indexPath)?.id == pending else { return }
        pendingRevealID = nil
        cell.playReveal()
    }
}

extension ChatTableView: AssistantMessageCellDelegate {
    func assistantMessageCell(_ cell: AssistantMessageCell, didTapImageAt index: Int) {
        guard let indexPath = tableView.indexPath(for: cell),
              let message = dataSource.itemIdentifier(for: indexPath) else { return }
        delegate?.chatTableView(self, didTapImageAt: index, in: message)
    }
    func assistantMessageCell(_ cell: AssistantMessageCell, didLongPressImageAt index: Int) {
        guard let indexPath = tableView.indexPath(for: cell),
              let message = dataSource.itemIdentifier(for: indexPath) else { return }
        delegate?.chatTableView(self, didLongPressImageAt: index, in: message)
    }
    func assistantMessageCell(_ cell: AssistantMessageCell, didSelectImageForEdit index: Int) {
        guard let indexPath = tableView.indexPath(for: cell),
              let message = dataSource.itemIdentifier(for: indexPath) else { return }
        delegate?.chatTableView(self, didSelectImageForEdit: index, in: message)
    }
    func assistantMessageCell(_ cell: AssistantMessageCell, didRequest action: ResultAction, imageIndex: Int?, from sourceView: UIView) {
        guard let indexPath = tableView.indexPath(for: cell),
              let message = dataSource.itemIdentifier(for: indexPath) else { return }
        delegate?.chatTableView(self, didRequest: action, imageIndex: imageIndex, for: message, from: sourceView)
    }
}

protocol ChatTableViewDelegate: AnyObject {
    func chatTableView(_ chatTableView: ChatTableView, didTapImageAt index: Int, in message: ChatMessage)
    func chatTableView(_ chatTableView: ChatTableView, didLongPressImageAt index: Int, in message: ChatMessage)
    func chatTableView(_ chatTableView: ChatTableView, didSelectImageForEdit index: Int, in message: ChatMessage)
    func chatTableView(_ chatTableView: ChatTableView, didRequest action: ResultAction, imageIndex: Int?, for message: ChatMessage, from sourceView: UIView)
}

enum ResultAction {
    case save
    case share
    case beforeAfter
}

private extension UIImage {
    /// Height over width, kept within a range a chat card can hold.
    var clampedAspect: CGFloat {
        guard size.width > 0, size.height > 0 else { return 1 }
        return min(max(size.height / size.width, 0.5), 1.8)
    }
}

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
    /// narrows and stays centred. With an `aspect` (height over width) the height follows the width.
    @discardableResult
    func sizeCard(_ card: UIView, in container: UIView, aspect: CGFloat?, maxWidth: CGFloat?) -> [NSLayoutConstraint] {
        let fillWidth = card.widthAnchor.constraint(equalTo: container.widthAnchor)
        fillWidth.priority = .defaultHigh
        var constraints = [
            fillWidth,
            card.centerXAnchor.constraint(equalTo: container.centerXAnchor),
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

private final class ResultActionButton: UIButton {
    private let action: ResultAction
    private let symbol: String
    private let caption: String
    private var isSuccess = false {
        didSet { setNeedsUpdateConfiguration() }
    }
    private var revertWork: DispatchWorkItem?

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
        config.imagePadding = 5
        config.imagePlacement = .leading
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 8, bottom: 10, trailing: 8)
        config.title = caption
        config.image = UIImage(
            systemName: isSuccess ? "checkmark" : symbol,
            withConfiguration: UIImage.SymbolConfiguration(textStyle: .subheadline, scale: .medium).applying(UIImage.SymbolConfiguration(weight: .semibold))
        )
        config.titleLineBreakMode = .byTruncatingTail
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = Theme.TextStyle.subhead.font
            return outgoing
        }
        config.baseForegroundColor = isSuccess ? Theme.Color.success : Theme.Color.ink
        config.background.backgroundColor = isSuccess ? Theme.Color.success.withAlphaComponent(0.16) : Theme.Color.fill
        configuration = config
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
    private var actionRow: UIStackView?
    private var actionButtons: [ResultAction: ResultActionButton] = [:]
    private var canCompare = false
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

    func configure(with message: ChatMessage, maxImageHeight: CGFloat = 0) {
        contentStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        imageViews.removeAll()
        actionButtons.removeAll()
        actionRow = nil
        isAccessibilityElement = false
        accessibilityLabel = nil
        accessibilityTraits = .none
        if let images = message.images, !images.isEmpty {
            canCompare = message.sourceImage != nil
            contentStackView.addArrangedSubview(makeImageCard(images, maxImageHeight: maxImageHeight))
            let row = makeActionRow(canCompare: canCompare)
            actionRow = row
            contentStackView.addArrangedSubview(row)
            updateActionAxis()
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
    /// not fit on a line.
    private func updateActionAxis() {
        actionRow?.axis = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? .vertical : .horizontal
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
        let maxWidth = maxImageHeight > 0 ? widthCap(columns: columns, rows: rows, aspect: aspect, maxHeight: maxImageHeight) : nil
        sizeCard(card, in: container, aspect: nil, maxWidth: maxWidth)
        return container
    }

    private func widthCap(columns: Int, rows: Int, aspect: CGFloat, maxHeight: CGFloat) -> CGFloat {
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

    private func makeActionRow(canCompare: Bool) -> UIStackView {
        let row = UIStackView()
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

class LoadingMessageCell: ChatColumnCell {
    static let identifier = "LoadingMessageCell"
    private let container = UIView()
    private let card = SurfaceView(style: .card, cornerRadius: 24)
    private let shimmer = ShimmerView()
    private let sparkle = IconBadge(symbol: "sparkles", size: 56)
    private let titleLabel = UILabel()
    private let elapsedLabel = UILabel()
    private var startedAt = Date()
    private var timer: Timer?
    private var sizingConstraints: [NSLayoutConstraint] = []

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    private func setupViews() {
        container.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(container)
        container.addSubview(card)
        card.contentView.addSubview(shimmer)
        shimmer.pinEdges(to: card.contentView)

        titleLabel.apply(.headline)
        titleLabel.textAlignment = .center
        elapsedLabel.apply(.footnote)
        elapsedLabel.textAlignment = .center
        elapsedLabel.font = UIFont.monospacedDigitSystemFont(ofSize: elapsedLabel.font.pointSize, weight: .medium)
        elapsedLabel.adjustsFontForContentSizeCategory = true
        elapsedLabel.hideFromAccessibility()

        let stack = UIStackView(arrangedSubviews: [sparkle, titleLabel, elapsedLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = Theme.Space.sm
        stack.setCustomSpacing(Theme.Space.md, after: sparkle)
        card.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: column.topAnchor),
            container.bottomAnchor.constraint(equalTo: column.bottomAnchor),
            container.leadingAnchor.constraint(equalTo: column.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: column.trailingAnchor),
            stack.centerXAnchor.constraint(equalTo: card.contentView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: card.contentView.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: card.contentView.leadingAnchor, constant: Theme.Space.lg),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: card.contentView.trailingAnchor, constant: -Theme.Space.lg),
            stack.topAnchor.constraint(greaterThanOrEqualTo: card.contentView.topAnchor, constant: Theme.Space.lg),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: card.contentView.bottomAnchor, constant: -Theme.Space.lg)
        ])
        shimmer.layer.cornerRadius = 24
        shimmer.backgroundColor = Theme.Color.accentSoft
        describe(String(localized: "Generating image"), traits: .staticText)
    }

    func configure(with message: ChatMessage, aspect: CGFloat, maxImageHeight: CGFloat) {
        startedAt = message.timestamp
        titleLabel.text = String(localized: "Creating your image") + "\u{2026}"
        updateElapsed()
        NSLayoutConstraint.deactivate(sizingConstraints)
        sizingConstraints = sizeCard(card, in: container, aspect: aspect, maxWidth: maxImageHeight > 0 ? maxImageHeight / aspect : nil)
    }

    func startAnimating() {
        startTimer()
        startPulse()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        stopTimer()
        sparkle.layer.removeAllAnimations()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            stopTimer()
        } else {
            startAnimating()
        }
    }

    private func startTimer() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.updateElapsed() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateElapsed() {
        let seconds = max(0, Int(Date().timeIntervalSince(startedAt)))
        elapsedLabel.text = String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func startPulse() {
        sparkle.layer.removeAllAnimations()
        guard !Motion.isReduced else { return }
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.92
        scale.toValue = 1.08
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0.7
        fade.toValue = 1
        let group = CAAnimationGroup()
        group.animations = [scale, fade]
        group.duration = 1.1
        group.autoreverses = true
        group.repeatCount = .infinity
        group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        sparkle.layer.add(group, forKey: "pulse")
    }
}

protocol AssistantMessageCellDelegate: AnyObject {
    func assistantMessageCell(_ cell: AssistantMessageCell, didTapImageAt index: Int)
    func assistantMessageCell(_ cell: AssistantMessageCell, didLongPressImageAt index: Int)
    func assistantMessageCell(_ cell: AssistantMessageCell, didSelectImageForEdit index: Int)
    func assistantMessageCell(_ cell: AssistantMessageCell, didRequest action: ResultAction, imageIndex: Int?, from sourceView: UIView)
}
