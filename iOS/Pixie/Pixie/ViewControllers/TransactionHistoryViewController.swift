import UIKit
import Combine

class TransactionHistoryViewController: UIViewController {
    private let viewModel: CreditsViewModel
    private var cancellables = Set<AnyCancellable>()

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let skeletonHost = UIView()
    private let stateContainer = HistoryStateContainer()
    private let pagingFooter = PagingFooterView()
    private let refreshControl = UIRefreshControl()

    private var groupedTransactions: [(date: String, transactions: [CreditTransaction])] = []
    private var shownTransactionIds: [String] = []
    private var hasFinishedLoading = false
    private var isShowingRefreshError = false
    private var lastAnnouncedState: ListState?
    private var previousPrefersLargeTitles: Bool?

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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let bar = navigationController?.navigationBar else { return }
        previousPrefersLargeTitles = bar.prefersLargeTitles
        bar.prefersLargeTitles = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let previous = previousPrefersLargeTitles {
            navigationController?.navigationBar.prefersLargeTitles = previous
        }
    }

    private func setupUI() {
        title = String(localized: "Transaction History")
        view.backgroundColor = Theme.Color.canvas
        navigationItem.largeTitleDisplayMode = .always

        setupTableView()
        setupSkeleton()
        setupStateView()
        setContentScrollView(tableView)
    }

    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = Theme.Color.canvas
        tableView.separatorStyle = .none
        tableView.sectionHeaderTopPadding = 0
        tableView.register(TransactionCell.self, forCellReuseIdentifier: "TransactionCell")
        tableView.register(DayHeaderView.self, forHeaderFooterViewReuseIdentifier: DayHeaderView.reuseIdentifier)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 68
        tableView.sectionHeaderHeight = UITableView.automaticDimension
        tableView.estimatedSectionHeaderHeight = 44
        tableView.tableFooterView = pagingFooter
        tableView.translatesAutoresizingMaskIntoConstraints = false

        refreshControl.addAction(UIAction { [weak self] _ in self?.load() }, for: .valueChanged)
        tableView.refreshControl = refreshControl

        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupSkeleton() {
        skeletonHost.translatesAutoresizingMaskIntoConstraints = false
        skeletonHost.describe(String(localized: "Loading…"), traits: .staticText)
        view.addSubview(skeletonHost)
        NSLayoutConstraint.activate([
            skeletonHost.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            skeletonHost.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            skeletonHost.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            skeletonHost.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let column = ColumnContainer(in: skeletonHost, top: Theme.Space.xxl, bottom: 0)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        for index in 0..<7 {
            if index > 0 { stack.addArrangedSubview(RowDivider()) }
            stack.addArrangedSubview(SkeletonRowView())
        }
        let card = SurfaceView(style: .card, cornerRadius: Theme.Radius.lg)
        card.contentView.addSubview(stack)
        stack.pinEdges(to: card.contentView)
        column.addSubview(card)
        card.topAnchor.constraint(equalTo: column.topAnchor).isActive = true
        card.leadingAnchor.constraint(equalTo: column.leadingAnchor).isActive = true
        card.trailingAnchor.constraint(equalTo: column.trailingAnchor).isActive = true
    }

    private func setupStateView() {
        stateContainer.translatesAutoresizingMaskIntoConstraints = false
        stateContainer.isHidden = true
        stateContainer.onRetry = { [weak self] in
            HapticsManager.shared.selection()
            self?.load()
        }

        view.addSubview(stateContainer)

        NSLayoutConstraint.activate([
            stateContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stateContainer.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            stateContainer.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            stateContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
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
        updatePagingFooter()

        tableView.isHidden = state != .content
        stateContainer.isHidden = state != .empty && state != .failed
        skeletonHost.isHidden = state != .loading

        switch state {
        case .empty: stateContainer.show(.empty)
        case .failed: stateContainer.show(.failed)
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

    private func updatePagingFooter() {
        let isPaging = viewModel.hasMoreTransactions || viewModel.isLoadingMoreTransactions
        guard pagingFooter.isPaging != isPaging else { return }
        pagingFooter.isPaging = isPaging
        tableView.tableFooterView = pagingFooter
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
            Announce.layoutChanged(stateContainer)
        case .empty:
            Announce.layoutChanged(stateContainer)
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
        let rows = groupedTransactions[indexPath.section].transactions
        let transaction = rows[indexPath.row]
        cell.configure(
            with: transaction,
            time: TransactionDates.timeText(for: transaction.createdAt),
            isFirst: indexPath.row == 0,
            isLast: indexPath.row == rows.count - 1
        )
        return cell
    }
}

extension TransactionHistoryViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: DayHeaderView.reuseIdentifier) as? DayHeaderView
        header?.configure(title: groupedTransactions[section].date)
        return header
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let isLastSection = indexPath.section == groupedTransactions.count - 1
        let isLastRow = indexPath.row == groupedTransactions[indexPath.section].transactions.count - 1
        guard isLastSection, isLastRow, viewModel.hasMoreTransactions else { return }
        Task { await viewModel.loadMoreTransactions(limit: Self.pageSize) }
    }
}

enum TransactionDates {
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

    private static let stampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
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

    /// "Today at 3:41 PM" style stamp for compact lists that have no day header.
    static func stamp(for dateString: String) -> String {
        guard let date = parse(dateString) else { return timeText(for: dateString) }
        return stampFormatter.string(from: date)
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

private final class DayHeaderView: UITableViewHeaderFooterView {
    static let reuseIdentifier = "DayHeaderView"

    private let label = UILabel()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        contentView.backgroundColor = Theme.Color.canvas
        backgroundView = UIView()
        backgroundView?.backgroundColor = Theme.Color.canvas
        let column = ColumnContainer(in: contentView, top: Theme.Space.lg, bottom: Theme.Space.sm)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.accessibilityTraits = .header
        column.addSubview(label)
        label.pinEdges(to: column, insets: UIEdgeInsets(top: 0, left: Theme.Space.xs, bottom: 0, right: 0))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String) {
        label.setStyledText(title, .caption)
    }
}

private final class PagingFooterView: UIView {
    private let spinner = UIActivityIndicatorView(style: .medium)

    var isPaging = false {
        didSet {
            frame.size.height = isPaging ? 72 : Theme.Space.xxxl
            if isPaging { spinner.startAnimating() } else { spinner.stopAnimating() }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: CGRect(x: 0, y: 0, width: 1, height: Theme.Space.xxxl))
        spinner.color = Theme.Color.accentText
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.isAccessibilityElement = true
        spinner.accessibilityLabel = String(localized: "Loading…")
        addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        autoresizingMask = [.flexibleWidth]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}

private final class SkeletonRowView: UIView {
    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        let badge = ShimmerView()
        badge.layer.cornerRadius = 12
        let title = ShimmerView()
        title.layer.cornerRadius = 6
        let subtitle = ShimmerView()
        subtitle.layer.cornerRadius = 5
        let amount = ShimmerView()
        amount.layer.cornerRadius = 6
        for bar in [badge, title, subtitle, amount] { bar.translatesAutoresizingMaskIntoConstraints = false; addSubview(bar) }
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 68),
            badge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Theme.Space.lg),
            badge.centerYAnchor.constraint(equalTo: centerYAnchor),
            badge.widthAnchor.constraint(equalToConstant: 40),
            badge.heightAnchor.constraint(equalToConstant: 40),
            title.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: Theme.Space.md),
            title.bottomAnchor.constraint(equalTo: centerYAnchor, constant: -3),
            title.widthAnchor.constraint(equalToConstant: 150),
            title.heightAnchor.constraint(equalToConstant: 14),
            subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            subtitle.topAnchor.constraint(equalTo: centerYAnchor, constant: 5),
            subtitle.widthAnchor.constraint(equalToConstant: 90),
            subtitle.heightAnchor.constraint(equalToConstant: 10),
            amount.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Theme.Space.lg),
            amount.centerYAnchor.constraint(equalTo: centerYAnchor),
            amount.widthAnchor.constraint(equalToConstant: 48),
            amount.heightAnchor.constraint(equalToConstant: 16),
        ])
        hideFromAccessibility()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}

private final class HistoryStateContainer: UIView {
    enum Kind {
        case empty
        case failed
    }

    var onRetry: (() -> Void)?

    private let scrollView = UIScrollView()
    private var stateView: StateView?
    private var shownKind: Kind?

    override init(frame: CGRect) {
        super.init(frame: frame)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        addSubview(scrollView)
        scrollView.pinEdges(to: self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func show(_ kind: Kind) {
        guard kind != shownKind else { return }
        shownKind = kind
        stateView?.removeFromSuperview()

        let view: StateView
        switch kind {
        case .empty:
            view = StateView(
                symbol: "clock.arrow.circlepath",
                title: String(localized: "No activity yet"),
                message: String(localized: "Credits you spend, buy or receive will show up here.")
            )
        case .failed:
            view = StateView(
                symbol: "exclamationmark.triangle.fill",
                title: String(localized: "Couldn't load your activity"),
                actionTitle: String(localized: "Retry"),
                colors: [UIColor(hex: 0xFF9F43), UIColor(hex: 0xFF6F61)]
            ) { [weak self] in
                self?.onRetry?()
            }
        }
        stateView = view
        scrollView.addSubview(view)

        let fillHeight = scrollView.contentLayoutGuide.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        fillHeight.priority = .defaultLow
        NSLayoutConstraint.activate([
            scrollView.contentLayoutGuide.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            fillHeight,
            view.topAnchor.constraint(greaterThanOrEqualTo: scrollView.contentLayoutGuide.topAnchor, constant: Theme.Space.xxl),
            view.bottomAnchor.constraint(lessThanOrEqualTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -Theme.Space.xxl),
            view.centerYAnchor.constraint(equalTo: scrollView.contentLayoutGuide.centerYAnchor),
            view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: Theme.Space.xxxl),
            view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -Theme.Space.xxxl),
        ])
    }
}

class TransactionCell: UITableViewCell {
    private var slice: ColumnContainer!
    private var row: ListRowView?
    private let divider = RowDivider()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        slice = ColumnContainer(in: contentView)
        slice.backgroundColor = Theme.Color.surface
        slice.layer.cornerRadius = Theme.Radius.lg
        slice.layer.cornerCurve = .continuous
        slice.clipsToBounds = true
        divider.translatesAutoresizingMaskIntoConstraints = false
        slice.addSubview(divider)
        NSLayoutConstraint.activate([
            divider.leadingAnchor.constraint(equalTo: slice.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: slice.trailingAnchor),
            divider.bottomAnchor.constraint(equalTo: slice.bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with transaction: CreditTransaction, time: String, isFirst: Bool = true, isLast: Bool = true) {
        row?.removeFromSuperview()
        let newRow = transaction.makeListRow(stamp: time)
        slice.insertSubview(newRow, at: 0)
        newRow.pinEdges(to: slice)
        row = newRow

        var corners: CACornerMask = []
        if isFirst { corners.formUnion([.layerMinXMinYCorner, .layerMaxXMinYCorner]) }
        if isLast { corners.formUnion([.layerMinXMaxYCorner, .layerMaxXMaxYCorner]) }
        slice.layer.maskedCorners = corners
        divider.isHidden = isLast

        isAccessibilityElement = true
        accessibilityLabel = newRow.accessibilityLabel
        accessibilityValue = newRow.accessibilityValue
    }
}
