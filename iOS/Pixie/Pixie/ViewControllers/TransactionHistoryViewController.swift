import UIKit
import Combine

class TransactionHistoryViewController: UIViewController {
    private let viewModel: CreditsViewModel
    private var cancellables = Set<AnyCancellable>()

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let loadingView = UIActivityIndicatorView(style: .large)
    private let stateView = HistoryStateView()
    private let refreshControl = UIRefreshControl()

    private var groupedTransactions: [(date: String, transactions: [CreditTransaction])] = []
    private var shownTransactionIds: [String] = []
    private var hasFinishedLoading = false
    private var isShowingRefreshError = false
    private var lastAnnouncedState: ListState?

    private static let pageSize = 50

    private enum ListState: Equatable {
        case loading
        case content
        case empty
        case failed
    }

    init(viewModel: CreditsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindViewModel()
        render()
        load()
    }

    private func setupUI() {
        title = String(localized: "Transaction History")
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .never

        setupTableView()
        setupLoadingView()
        setupStateView()
    }

    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(TransactionCell.self, forCellReuseIdentifier: "TransactionCell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 72
        tableView.translatesAutoresizingMaskIntoConstraints = false

        refreshControl.addAction(UIAction { [weak self] _ in self?.load() }, for: .valueChanged)
        tableView.refreshControl = refreshControl

        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupLoadingView() {
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.hidesWhenStopped = true
        loadingView.accessibilityLabel = String(localized: "Loading…")
        view.addSubview(loadingView)

        NSLayoutConstraint.activate([
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func setupStateView() {
        stateView.translatesAutoresizingMaskIntoConstraints = false
        stateView.isHidden = true
        stateView.onRetry = { [weak self] in
            HapticsManager.shared.selection()
            self?.load()
        }

        view.addSubview(stateView)

        NSLayoutConstraint.activate([
            stateView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stateView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            stateView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            stateView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func bindViewModel() {
        viewModel.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.render()
            }
            .store(in: &cancellables)
    }

    private func load() {
        Task {
            await viewModel.loadTransactions(limit: Self.pageSize)
            hasFinishedLoading = true
            refreshControl.endRefreshing()
            render()
        }
    }

    private var currentState: ListState {
        if !viewModel.transactions.isEmpty { return .content }
        if viewModel.isLoadingTransactions || !hasFinishedLoading { return .loading }
        return viewModel.transactionsErrorMessage != nil ? .failed : .empty
    }

    private func render() {
        let state = currentState
        updateRows()

        tableView.isHidden = state != .content
        stateView.isHidden = state != .empty && state != .failed
        if state == .loading {
            loadingView.startAnimating()
        } else {
            loadingView.stopAnimating()
        }

        switch state {
        case .empty: stateView.show(.empty)
        case .failed: stateView.show(.failed)
        case .loading, .content: break
        }

        updateRefreshError(for: state)
        announce(state)
    }

    private func updateRows() {
        let transactions = viewModel.transactions
        let ids = transactions.map(\.id)
        guard ids != shownTransactionIds else { return }
        shownTransactionIds = ids
        groupedTransactions = TransactionDates.group(transactions)
        tableView.reloadData()
    }

    /// Keeps the rows on screen when a pull to refresh fails and says so in the navigation bar.
    private func updateRefreshError(for state: ListState) {
        let hasError = state == .content && hasFinishedLoading && !viewModel.isLoadingTransactions && viewModel.transactionsErrorMessage != nil
        guard hasError != isShowingRefreshError else { return }
        isShowingRefreshError = hasError
        navigationItem.prompt = hasError ? String(localized: "Couldn't load your activity") : nil
        if hasError {
            HapticsManager.shared.notification(.error)
            Announce.say(String(localized: "Couldn't load your activity"))
        }
    }

    private func announce(_ state: ListState) {
        guard state != lastAnnouncedState else { return }
        lastAnnouncedState = state
        switch state {
        case .failed:
            HapticsManager.shared.notification(.error)
            Announce.layoutChanged(stateView)
        case .empty:
            Announce.layoutChanged(stateView)
        case .loading, .content:
            break
        }
    }
}

extension TransactionHistoryViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return groupedTransactions.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return groupedTransactions[section].transactions.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TransactionCell", for: indexPath) as! TransactionCell
        let transaction = groupedTransactions[indexPath.section].transactions[indexPath.row]
        cell.configure(with: transaction, time: TransactionDates.timeText(for: transaction.createdAt))
        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return groupedTransactions[section].date
    }

}

extension TransactionHistoryViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let isLastSection = indexPath.section == groupedTransactions.count - 1
        let isLastRow = indexPath.row == groupedTransactions[indexPath.section].transactions.count - 1
        guard isLastSection, isLastRow, viewModel.hasMoreTransactions else { return }
        Task { await viewModel.loadMoreTransactions(limit: Self.pageSize) }
    }
}

private enum TransactionDates {
    private static let isoWithFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoPlain = ISO8601DateFormatter()

    private static let backendFormats: [DateFormatter] = ["yyyy-MM-dd'T'HH:mm:ss.SSSZ", "yyyy-MM-dd HH:mm:ss"].map { format in
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter
    }

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEE")
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    static func parse(_ dateString: String) -> Date? {
        if let date = isoWithFraction.date(from: dateString) ?? isoPlain.date(from: dateString) {
            return date
        }
        for formatter in backendFormats {
            if let date = formatter.date(from: dateString) { return date }
        }
        return nil
    }

    static func timeText(for dateString: String) -> String {
        if let date = parse(dateString) { return timeFormatter.string(from: date) }
        if let tIndex = dateString.firstIndex(of: "T") { return String(dateString[..<tIndex]) }
        return dateString
    }

    /// Today, Yesterday, the weekday inside the last week, otherwise the calendar date.
    static func sectionTitle(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return String(localized: "Today") }
        if calendar.isDateInYesterday(date) { return String(localized: "Yesterday") }
        if let daysAgo = calendar.dateComponents([.day], from: date, to: Date()).day, daysAgo < 7 {
            return weekdayFormatter.string(from: date)
        }
        return dayFormatter.string(from: date)
    }

    /// Newest first, grouped into consecutive sections; rows with an unreadable date go under "Recent".
    static func group(_ transactions: [CreditTransaction]) -> [(date: String, transactions: [CreditTransaction])] {
        let now = Date()
        let dated = transactions
            .map { (transaction: $0, date: parse($0.createdAt)) }
            .sorted { ($0.date ?? now) > ($1.date ?? now) }

        var groups: [(date: String, transactions: [CreditTransaction])] = []
        for entry in dated {
            let title = entry.date.map(sectionTitle(for:)) ?? String(localized: "Recent")
            if let last = groups.last, last.date == title {
                groups[groups.count - 1].transactions.append(entry.transaction)
            } else {
                groups.append((date: title, transactions: [entry.transaction]))
            }
        }
        return groups
    }
}

private final class HistoryStateView: UIView {
    enum Kind {
        case empty
        case failed
    }

    var onRetry: (() -> Void)?

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let retryButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func build() {
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .largeTitle, scale: .large)
        iconView.hideFromAccessibility()

        titleLabel.useScaledFont(.title3, size: 20, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.accessibilityTraits = .header

        messageLabel.useScaledFont(.subheadline, size: 15)
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        var config = UIButton.Configuration.filled()
        config.title = String(localized: "Retry")
        config.baseBackgroundColor = .brand
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 28, bottom: 10, trailing: 28)
        retryButton.configuration = config
        retryButton.addAction(UIAction { [weak self] _ in self?.onRetry?() }, for: .touchUpInside)
        retryButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true

        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        [iconView, titleLabel, messageLabel, retryButton].forEach { stack.addArrangedSubview($0) }
        stack.setCustomSpacing(20, after: messageLabel)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        addSubview(scrollView)
        scrollView.addSubview(stack)

        let fillHeight = scrollView.contentLayoutGuide.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        fillHeight.priority = .defaultLow

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            scrollView.contentLayoutGuide.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            fillHeight,
            stack.topAnchor.constraint(greaterThanOrEqualTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.centerYAnchor.constraint(equalTo: scrollView.contentLayoutGuide.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -32)
        ])
    }

    func show(_ kind: Kind) {
        switch kind {
        case .empty:
            iconView.image = UIImage(systemName: "clock.arrow.circlepath")
            iconView.tintColor = .brandText
            titleLabel.text = String(localized: "No activity yet")
            messageLabel.text = String(localized: "Credits you spend, buy or receive will show up here.")
            retryButton.isHidden = true
        case .failed:
            iconView.image = UIImage(systemName: "exclamationmark.triangle.fill")
            iconView.tintColor = .systemOrange
            titleLabel.text = String(localized: "Couldn't load your activity")
            messageLabel.text = nil
            retryButton.isHidden = false
        }
        messageLabel.isHidden = messageLabel.text == nil
    }
}

class TransactionCell: UITableViewCell {
    private let iconContainer = UIView()
    private let iconImageView = UIImageView()
    private let descriptionLabel = UILabel()
    private let timeLabel = UILabel()
    private let amountLabel = UILabel()
    private let textStack = UIStackView()
    private let rowStack = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyContentSizeLayout()
    }

    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .secondarySystemGroupedBackground

        iconContainer.layer.cornerRadius = 20
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.setContentHuggingPriority(.required, for: .horizontal)
        iconContainer.setContentCompressionResistancePriority(.required, for: .horizontal)

        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false

        descriptionLabel.useScaledFont(.callout, size: 16, weight: .medium)
        descriptionLabel.numberOfLines = 0

        timeLabel.useScaledFont(.footnote, size: 13)
        timeLabel.textColor = .secondaryLabel
        timeLabel.numberOfLines = 0

        amountLabel.useScaledFont(.body, size: 17, weight: .semibold)
        amountLabel.textAlignment = .right
        amountLabel.setContentHuggingPriority(.required, for: .horizontal)
        amountLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.addArrangedSubview(descriptionLabel)
        textStack.addArrangedSubview(timeLabel)

        rowStack.axis = .horizontal
        rowStack.alignment = .center
        rowStack.spacing = 12
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        rowStack.addArrangedSubview(iconContainer)
        rowStack.addArrangedSubview(textStack)
        rowStack.addArrangedSubview(amountLabel)

        iconContainer.addSubview(iconImageView)
        contentView.addSubview(rowStack)

        NSLayoutConstraint.activate([
            iconContainer.widthAnchor.constraint(equalToConstant: 40),
            iconContainer.heightAnchor.constraint(equalToConstant: 40),

            iconImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 22),
            iconImageView.heightAnchor.constraint(equalToConstant: 22),

            rowStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            rowStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),
            rowStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            rowStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }

    /// Stacks icon, text and amount vertically at accessibility text sizes so long descriptions keep their full width.
    private func applyContentSizeLayout() {
        let isAccessibilitySize = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        let axis: NSLayoutConstraint.Axis = isAccessibilitySize ? .vertical : .horizontal
        guard rowStack.axis != axis else { return }
        rowStack.axis = axis
        rowStack.alignment = isAccessibilitySize ? .leading : .center
        amountLabel.textAlignment = isAccessibilitySize ? .left : .right
    }

    func configure(with transaction: CreditTransaction, time: String) {
        descriptionLabel.text = transaction.description
        timeLabel.text = time
        timeLabel.isHidden = time.isEmpty

        amountLabel.text = transaction.signedAmountText
        amountLabel.textColor = transaction.isDebit ? .label : .brandText

        iconImageView.image = UIImage(systemName: transaction.symbolName)
        if transaction.isDebit {
            iconContainer.backgroundColor = .systemRed.withAlphaComponent(0.15)
            iconImageView.tintColor = .systemRed
        } else {
            iconContainer.backgroundColor = .brandTint
            iconImageView.tintColor = .brandText
        }

        isAccessibilityElement = true
        accessibilityLabel = "\(transaction.kindName), \(transaction.description)"
        accessibilityValue = [transaction.spokenAmount, time].filter { !$0.isEmpty }.joined(separator: ", ")
    }
}
