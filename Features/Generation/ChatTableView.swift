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
        tv.contentInsetAdjustmentBehavior = .never // duo-audit:ignore the view lays itself out from safeAreaInsets, the top bar and the composer
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
    var onResultWidthChange: (() -> Void)?
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
                let fit = self?.resultFit(for: message)
                cell.configure(with: message, maxImageHeight: fit?.imageHeight ?? 0, actionsBeside: fit?.actionsBeside ?? false)
                cell.delegate = self
                return cell
            case .loading:
                let cell = tableView.dequeueReusableCell(withIdentifier: LoadingMessageCell.identifier, for: indexPath) as! LoadingMessageCell
                let fit = self?.resultFit(for: message)
                cell.configure(with: message, aspect: self?.expectedAspect(of: message) ?? 1, maxImageHeight: fit?.imageHeight ?? 0, actionsBeside: fit?.actionsBeside ?? false)
                cell.startAnimating()
                return cell
            }
        }
        dataSource.defaultRowAnimation = .fade
    }
    private var isShortWindow: Bool {
        traitCollection.verticalSizeClass == .compact
    }

    /// How a result is laid out: how tall its picture may be and whether Save, Share and
    /// Compare stand in a column beside it instead of in a row under it.
    struct ResultFit {
        let imageHeight: CGFloat
        let actionsBeside: Bool
    }

    /// A result never outgrows the band between the top bar and the composer. Under its
    /// picture the actions take a row of the band; beside it they take a column of the width.
    /// The column wins when it lets the picture grow, which is what a window wider than tall
    /// or a narrow pane beside a sidebar gives; a phone held upright, where the width is what
    /// limits the picture, keeps its row. The picture is never more than
    /// 70% of the transcript. Zero means the table has no size yet and the width decides.
    private func resultFit(columns: Int, rows: Int, aspect: CGFloat) -> ResultFit {
        guard tableView.bounds.height > 0 else { return ResultFit(imageHeight: 0, actionsBeside: false) }
        let visible = tableView.bounds.height - topInset - bottomInset
        let share = tableView.bounds.height * Self.maximumResultHeightShare
        let below = max(min(visible - Self.resultActionsHeight, share), Self.minimumResultImageHeight)
        let stacked = ResultFit(imageHeight: below, actionsBeside: false)
        guard !traitCollection.preferredContentSizeCategory.isAccessibilityCategory else { return stacked }
        let beside = max(min(visible - ChatColumnCell.turnSpacing * 2, share), Self.minimumResultImageHeight)
        let belowHeight = AssistantMessageCell.imageHeight(
            width: min(AssistantMessageCell.widthCap(columns: columns, rows: rows, aspect: aspect, maxHeight: below), columnWidth),
            columns: columns, rows: rows, aspect: aspect)
        let besideWidth = min(
            AssistantMessageCell.widthCap(columns: columns, rows: rows, aspect: aspect, maxHeight: beside),
            columnWidth - AssistantMessageCell.sideActionsWidth - AssistantMessageCell.sideActionsSpacing)
        guard besideWidth > 0 else { return stacked }
        let besideHeight = AssistantMessageCell.imageHeight(width: besideWidth, columns: columns, rows: rows, aspect: aspect)
        guard besideHeight > belowHeight else { return stacked }
        return ResultFit(imageHeight: besideHeight, actionsBeside: true)
    }

    private func resultFit(for message: ChatMessage) -> ResultFit {
        guard let images = message.images, !images.isEmpty else {
            return resultFit(columns: 1, rows: 1, aspect: expectedAspect(of: message))
        }
        let columns = images.count == 1 ? 1 : 2
        return resultFit(columns: columns, rows: (images.count + columns - 1) / columns, aspect: images[0].clampedAspect)
    }

    private var columnWidth: CGFloat {
        let margin = Theme.screenMargin(for: traitCollection)
        return min(bounds.width - tableView.contentInset.left - tableView.contentInset.right - margin * 2, ChatColumnCell.maximumColumnWidth)
    }
    private static let resultActionsHeight: CGFloat = 80
    private static let minimumResultImageHeight: CGFloat = 96
    private static let maximumResultHeightShare: CGFloat = 0.7

    /// The width the newest result takes at the current size with its actions, so the composer
    /// can match it instead of spanning a pane far wider than the picture above it.
    var latestResultWidth: CGFloat? {
        guard let message = dataSource.snapshot().itemIdentifiers.last(where: { $0.role == .assistant }),
              let images = message.images, !images.isEmpty else { return nil }
        let columns = images.count == 1 ? 1 : 2
        let rows = (images.count + columns - 1) / columns
        let fit = resultFit(for: message)
        guard fit.imageHeight > 0 else { return columnWidth }
        let cap = AssistantMessageCell.widthCap(columns: columns, rows: rows, aspect: images[0].clampedAspect, maxHeight: fit.imageHeight)
        let beside = fit.actionsBeside ? AssistantMessageCell.sideActionsWidth + AssistantMessageCell.sideActionsSpacing : 0
        return min(cap + beside, columnWidth)
    }

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
        let base = composerClearance ?? Self.regularBottomInset
        return keyboardInset + base + (keyboardInset > 0 ? 0 : safeAreaInsets.bottom)
    }
    /// The room kept between the last turn and the composer's capsule in a short window, where
    /// every point of the band counts: most of the composer's soft edge, so the actions under a
    /// result stay clear of the fade without a wide gap above the composer.
    static let shortWindowComposerGap: CGFloat = Theme.Space.xxxl + Theme.Space.xs

    /// The height of the floating composer, so the last turn always rests above it in every
    /// window size.
    var composerClearance: CGFloat? {
        didSet { applyInsets() }
    }
    /// Where the floating top bar ends, in this view's coordinates; the first turn starts
    /// below it and the fade that follows.
    var topBarBottom: CGFloat? {
        didSet { applyInsets() }
    }
    private var topInset: CGFloat {
        (topBarBottom ?? safeAreaInsets.top + Self.defaultTopBarHeight) + Self.topFadeLength
    }
    /// How far below the top bar the transcript fades out; the controller draws the fade.
    static let topFadeLength: CGFloat = Theme.Space.xxl
    private static let regularBottomInset: CGFloat = 120
    private static let defaultTopBarHeight: CGFloat = 60

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
        refitResultsToBand()
    }

    /// Results are sized to the band between the insets, so when the band changes after the
    /// rows were measured they are measured again.
    private func refitResultsToBand() {
        guard laidOutSize != .zero, dataSource != nil, !isRefittingResults,
              !dataSource.snapshot().itemIdentifiers.isEmpty else { return }
        isRefittingResults = true
        reloadAllRows(keepingBottom: true)
        isRefittingResults = false
    }
    private var isRefittingResults = false

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
        onResultWidthChange?()
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
            self?.onResultWidthChange?()
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
            self?.onResultWidthChange?()
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

extension UIImage {
    /// Height over width, kept within a range a chat card can hold.
    var clampedAspect: CGFloat {
        guard size.width > 0, size.height > 0 else { return 1 }
        return min(max(size.height / size.width, 0.5), 1.8)
    }
}
