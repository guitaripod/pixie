import UIKit
import Combine

class TransactionHistoryViewController: UIViewController {
    private let viewModel: CreditsViewModel
    private var cancellables = Set<AnyCancellable>()
    
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let loadingView = UIActivityIndicatorView(style: .large)
    private let emptyStateView = EmptyStateView()
    
    private var transactions: [CreditTransaction] = []
    private var groupedTransactions: [(date: String, transactions: [CreditTransaction])] = []
    
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
        Task {
            await viewModel.loadTransactions(limit: 50)
        }
    }
    
    private func setupUI() {
        title = "Transaction History"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .never
        
        setupTableView()
        setupLoadingView()
        setupEmptyStateView()
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(TransactionCell.self, forCellReuseIdentifier: "TransactionCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
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
        view.addSubview(loadingView)
        
        NSLayoutConstraint.activate([
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func setupEmptyStateView() {
        emptyStateView.configure(for: .transactions)
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.isHidden = true
        
        view.addSubview(emptyStateView)
        
        NSLayoutConstraint.activate([
            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])
    }
    
    private func bindViewModel() {
        viewModel.$transactions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] transactions in
                self?.updateTransactions(transactions)
            }
            .store(in: &cancellables)
        
        viewModel.$isLoadingTransactions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                if isLoading {
                    self?.loadingView.startAnimating()
                } else {
                    self?.loadingView.stopAnimating()
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateTransactions(_ transactions: [CreditTransaction]) {
        self.transactions = transactions
        groupTransactionsByDate()
        tableView.reloadData()
        
        emptyStateView.isHidden = !transactions.isEmpty
        tableView.isHidden = transactions.isEmpty
    }
    
    private func groupTransactionsByDate() {
        // First, create a dictionary that maps date strings to actual dates for sorting
        var dateMapping: [String: Date] = [:]
        
        let grouped = Dictionary(grouping: transactions) { transaction -> String in
            let dateString = formatDate(transaction.createdAt)
            
            // Store the actual date for this group if we haven't already
            if dateMapping[dateString] == nil {
                dateMapping[dateString] = parseDate(transaction.createdAt) ?? Date()
            }
            
            return dateString
        }
        
        // Sort by actual dates, not by the formatted string
        groupedTransactions = grouped
            .sorted { (first, second) in
                // Special handling for "Today", "Yesterday", etc.
                let specialOrder = ["Today": 0, "Yesterday": 1]
                
                if let order1 = specialOrder[first.key], let order2 = specialOrder[second.key] {
                    return order1 < order2
                } else if specialOrder[first.key] != nil {
                    return true // Special days come first
                } else if specialOrder[second.key] != nil {
                    return false
                }
                
                // For other dates, sort by actual date
                let date1 = dateMapping[first.key] ?? Date()
                let date2 = dateMapping[second.key] ?? Date()
                return date1 > date2 // Most recent first
            }
            .map { (date: $0.key, transactions: $0.value.sorted { 
                // Sort transactions within each group by actual date
                let date1 = parseDate($0.createdAt) ?? Date()
                let date2 = parseDate($1.createdAt) ?? Date()
                return date1 > date2
            }) }
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        // Try ISO8601 formatter first
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        // Try without fractional seconds
        let formatterNoFraction = ISO8601DateFormatter()
        if let date = formatterNoFraction.date(from: dateString) {
            return date
        }
        
        // Try custom formatter for the backend format
        let customFormatter = DateFormatter()
        customFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        if let date = customFormatter.date(from: dateString) {
            return date
        }
        
        // Try another format
        customFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = customFormatter.date(from: dateString) {
            return date
        }
        
        return nil
    }
    
    private func formatDate(_ dateString: String) -> String {
        // Try ISO8601 formatter first
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Also try without fractional seconds
        let formatterNoFraction = ISO8601DateFormatter()
        
        guard let date = formatter.date(from: dateString) ?? formatterNoFraction.date(from: dateString) else {
            // Try a custom formatter for the backend format
            let customFormatter = DateFormatter()
            customFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            if let customDate = customFormatter.date(from: dateString) {
                return formatDateDisplay(customDate)
            }
            return "Recent"
        }
        
        return formatDateDisplay(date)
    }
    
    private func formatDateDisplay(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if let daysAgo = calendar.dateComponents([.day], from: date, to: Date()).day, daysAgo < 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE" // Day name
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }
    
    private func formatTime(_ dateString: String) -> String {
        // Try multiple date formats
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let formatterNoFraction = ISO8601DateFormatter()
        
        guard let date = formatter.date(from: dateString) ?? formatterNoFraction.date(from: dateString) else {
            // Try custom formatter
            let customFormatter = DateFormatter()
            customFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            if let customDate = customFormatter.date(from: dateString) {
                let timeFormatter = DateFormatter()
                timeFormatter.dateStyle = .none
                timeFormatter.timeStyle = .short
                return timeFormatter.string(from: customDate)
            }
            return ""
        }
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short
        
        return timeFormatter.string(from: date)
    }
}

// MARK: - UITableViewDataSource
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
        cell.configure(with: transaction, time: formatTime(transaction.createdAt))
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return groupedTransactions[section].date
    }
}

// MARK: - UITableViewDelegate
extension TransactionHistoryViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 72
    }
}

// MARK: - TransactionCell
class TransactionCell: UITableViewCell {
    private let iconContainer = UIView()
    private let iconImageView = UIImageView()
    private let descriptionLabel = UILabel()
    private let timeLabel = UILabel()
    private let amountLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .secondarySystemGroupedBackground
        
        iconContainer.layer.cornerRadius = 20
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .white
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        descriptionLabel.font = .systemFont(ofSize: 16, weight: .medium)
        descriptionLabel.numberOfLines = 1
        descriptionLabel.lineBreakMode = .byTruncatingTail
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        timeLabel.font = .systemFont(ofSize: 13)
        timeLabel.textColor = .secondaryLabel
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        amountLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        amountLabel.textAlignment = .right
        amountLabel.translatesAutoresizingMaskIntoConstraints = false
        
        iconContainer.addSubview(iconImageView)
        contentView.addSubview(iconContainer)
        contentView.addSubview(descriptionLabel)
        contentView.addSubview(timeLabel)
        contentView.addSubview(amountLabel)
        
        NSLayoutConstraint.activate([
            iconContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconContainer.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 40),
            iconContainer.heightAnchor.constraint(equalToConstant: 40),
            
            iconImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 22),
            iconImageView.heightAnchor.constraint(equalToConstant: 22),
            
            descriptionLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            descriptionLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12),
            descriptionLabel.trailingAnchor.constraint(lessThanOrEqualTo: amountLabel.leadingAnchor, constant: -12),
            
            timeLabel.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 2),
            timeLabel.leadingAnchor.constraint(equalTo: descriptionLabel.leadingAnchor),
            timeLabel.trailingAnchor.constraint(lessThanOrEqualTo: amountLabel.leadingAnchor, constant: -12),
            
            amountLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            amountLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            amountLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 60)
        ])
    }
    
    private func formatDateTime(_ dateString: String) -> String {
        // Try to parse the date in various formats
        let formatters = [
            ISO8601DateFormatter(),
            { () -> DateFormatter in
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                return f
            }(),
            { () -> DateFormatter in
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd HH:mm:ss"
                return f
            }()
        ]
        
        for formatter in formatters {
            if let iso8601 = formatter as? ISO8601DateFormatter {
                iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = iso8601.date(from: dateString) {
                    let displayFormatter = DateFormatter()
                    displayFormatter.dateStyle = .short
                    displayFormatter.timeStyle = .short
                    return displayFormatter.string(from: date)
                }
            } else if let dateFormatter = formatter as? DateFormatter {
                if let date = dateFormatter.date(from: dateString) {
                    let displayFormatter = DateFormatter()
                    displayFormatter.dateStyle = .short
                    displayFormatter.timeStyle = .short
                    return displayFormatter.string(from: date)
                }
            }
        }
        
        // If all parsing fails, try to extract date portion
        if let tIndex = dateString.firstIndex(of: "T") {
            let datePart = String(dateString[..<tIndex])
            return datePart
        }
        
        return dateString
    }
    
    func configure(with transaction: CreditTransaction, time: String) {
        descriptionLabel.text = transaction.description
        
        // Show the date and time
        let dateTimeText = time.isEmpty ? formatDateTime(transaction.createdAt) : time
        timeLabel.text = dateTimeText
        
        let isSpend = transaction.transactionType == "spend"
        amountLabel.text = isSpend ? "\(transaction.amount)" : "+\(transaction.amount)"
        amountLabel.textColor = isSpend ? .systemRed : .systemPurple
        
        // Better icon mapping based on transaction description
        if isSpend {
            iconContainer.backgroundColor = .systemRed.withAlphaComponent(0.15)
            iconImageView.tintColor = .systemRed
            
            // Choose icon based on description
            let description = transaction.description.lowercased()
            if description.contains("edit") {
                iconImageView.image = UIImage(systemName: "wand.and.rays")
            } else if description.contains("generat") || description.contains("created") {
                iconImageView.image = UIImage(systemName: "sparkles")
            } else if description.contains("upscale") {
                iconImageView.image = UIImage(systemName: "arrow.up.right.square")
            } else {
                iconImageView.image = UIImage(systemName: "sparkles")
            }
        } else {
            iconContainer.backgroundColor = .systemPurple.withAlphaComponent(0.15)
            iconImageView.tintColor = .systemPurple
            
            // Credit additions
            let description = transaction.description.lowercased()
            if description.contains("purchase") {
                iconImageView.image = UIImage(systemName: "creditcard.fill")
            } else if description.contains("bonus") {
                iconImageView.image = UIImage(systemName: "gift.fill")
            } else if description.contains("refund") {
                iconImageView.image = UIImage(systemName: "arrow.uturn.backward.circle.fill")
            } else if description.contains("admin") {
                iconImageView.image = UIImage(systemName: "person.badge.shield.checkmark.fill")
            } else {
                iconImageView.image = UIImage(systemName: "plus.circle.fill")
            }
        }
    }
}