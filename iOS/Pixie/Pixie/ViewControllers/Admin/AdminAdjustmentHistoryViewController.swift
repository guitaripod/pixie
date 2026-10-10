import UIKit

class AdminAdjustmentHistoryViewController: UIViewController {
    
    private let tableView = UITableView()
    private let refreshControl = UIRefreshControl()
    private let loadingView = UIActivityIndicatorView(style: .large)
    private let emptyStateLabel = UILabel()
    private let errorView = AdminInlineMessageView()
    private let haptics = HapticManager.shared
    
    private let adminRepository: AdminRepositoryProtocol
    private var adjustmentHistory: [AdjustmentHistoryItem] = []
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    init() {
        self.adminRepository = AdminRepository(networkService: AppContainer.shared.networkService)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupConstraints()
        loadHistory()
    }
    
    private func setupUI() {
        title = String(localized: "Adjustment History")
        view.backgroundColor = .systemGroupedBackground
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.refreshControl = refreshControl
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 120
        tableView.register(AdjustmentHistoryCell.self, forCellReuseIdentifier: "HistoryCell")
        
        refreshControl.addTarget(self, action: #selector(refreshHistory), for: .valueChanged)
        
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.hidesWhenStopped = true
        
        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyStateLabel.text = String(localized: "No adjustment history")
        emptyStateLabel.useScaledFont(.body, size: 17)
        emptyStateLabel.textColor = .secondaryLabel
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.numberOfLines = 0
        emptyStateLabel.isHidden = true
        
        view.addSubview(tableView)
        view.addSubview(loadingView)
        view.addSubview(emptyStateLabel)
        errorView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(errorView)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 32),
            emptyStateLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -32),
            
            errorView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 32),
            errorView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -32)
        ])
    }
    
    private func loadHistory() {
        loadingView.startAnimating()
        errorView.hide()
        
        Task {
            do {
                let response = try await adminRepository.getAdjustmentHistory(userId: nil)
                await MainActor.run {
                    self.adjustmentHistory = response.adjustments
                    self.tableView.reloadData()
                    self.loadingView.stopAnimating()
                    self.errorView.hide()
                    self.updateEmptyState()
                }
            } catch {
                await MainActor.run {
                    self.loadingView.stopAnimating()
                    self.showError(error.localizedDescription)
                }
            }
        }
    }
    
    @objc private func refreshHistory() {
        Task {
            do {
                let response = try await adminRepository.getAdjustmentHistory(userId: nil)
                await MainActor.run {
                    self.adjustmentHistory = response.adjustments
                    self.tableView.reloadData()
                    self.refreshControl.endRefreshing()
                    self.errorView.hide()
                    self.updateEmptyState()
                }
            } catch {
                await MainActor.run {
                    self.refreshControl.endRefreshing()
                    self.showError(error.localizedDescription)
                }
            }
        }
    }
    
    private func updateEmptyState() {
        emptyStateLabel.isHidden = !adjustmentHistory.isEmpty || !errorView.isHidden
    }
    
    private func showError(_ message: String) {
        haptics.notification(.error)
        emptyStateLabel.isHidden = true
        errorView.show(message) { [weak self] in
            self?.loadHistory()
        }
    }
}

extension AdminAdjustmentHistoryViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return adjustmentHistory.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "HistoryCell", for: indexPath) as! AdjustmentHistoryCell
        let item = adjustmentHistory[indexPath.row]
        cell.configure(with: item, dateFormatter: dateFormatter)
        return cell
    }
}

extension AdminAdjustmentHistoryViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let item = adjustmentHistory[indexPath.row]
        let detailAlert = UIAlertController(
            title: String(localized: "Adjustment Details"),
            message: String(localized: """
            User ID: \(item.userId)
            Admin ID: \(item.adminId)
            Amount: \(item.amount > 0 ? "+" : "")\(item.amount)
            New Balance: \(item.newBalance)
            Reason: \(item.reason)
            Date: \(dateFormatter.string(from: ISO8601DateFormatter().date(from: item.createdAt) ?? Date()))
            """),
            preferredStyle: .alert
        )
        detailAlert.addAction(UIAlertAction(title: String(localized: "OK"), style: .default))
        
        haptics.impact(.click)
        present(detailAlert, animated: true)
    }
}

class AdjustmentHistoryCell: UITableViewCell {
    
    private let containerView = UIView()
    private let amountLabel = UILabel()
    private let reasonLabel = UILabel()
    private let userIdLabel = UILabel()
    private let dateLabel = UILabel()
    private let newBalanceLabel = UILabel()
    private let headerStack = UIStackView()
    private let footerStack = UIStackView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = .secondarySystemGroupedBackground
        containerView.layer.cornerRadius = 12
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.05
        containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        containerView.layer.shadowRadius = 4
        
        amountLabel.useScaledFont(.title2, size: 24, weight: .bold)
        
        reasonLabel.useScaledFont(.subheadline, size: 15)
        reasonLabel.textColor = .secondaryLabel
        reasonLabel.numberOfLines = 0
        
        userIdLabel.useScaledFont(.footnote, size: 13)
        userIdLabel.textColor = .secondaryLabel
        userIdLabel.lineBreakMode = .byTruncatingMiddle
        userIdLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        dateLabel.useScaledFont(.footnote, size: 13)
        dateLabel.textColor = .secondaryLabel
        dateLabel.textAlignment = .right
        dateLabel.numberOfLines = 0
        dateLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        newBalanceLabel.useScaledFont(.subheadline, size: 15, weight: .medium)
        newBalanceLabel.textColor = .secondaryLabel
        newBalanceLabel.textAlignment = .right
        newBalanceLabel.numberOfLines = 0
        
        headerStack.addArrangedSubview(amountLabel)
        headerStack.addArrangedSubview(newBalanceLabel)
        headerStack.alignment = .center
        headerStack.spacing = 8
        
        footerStack.addArrangedSubview(userIdLabel)
        footerStack.addArrangedSubview(dateLabel)
        footerStack.alignment = .center
        footerStack.spacing = 8
        
        let contentStack = UIStackView(arrangedSubviews: [headerStack, reasonLabel, footerStack])
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 8
        
        contentView.addSubview(containerView)
        containerView.addSubview(contentStack)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            contentStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16)
        ])
        updateAxes()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
            updateAxes()
        }
    }
    
    /// Stacks the two-sided rows vertically at accessibility text sizes so nothing overlaps or clips.
    private func updateAxes() {
        let stacked = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        [headerStack, footerStack].forEach {
            $0.axis = stacked ? .vertical : .horizontal
            $0.alignment = stacked ? .leading : .center
        }
        newBalanceLabel.textAlignment = stacked ? .left : .right
        dateLabel.textAlignment = stacked ? .left : .right
    }
    
    func configure(with item: AdjustmentHistoryItem, dateFormatter: DateFormatter) {
        let amount = item.amount
        amountLabel.text = amount > 0 ? "+\(amount)" : "\(amount)"
        amountLabel.textColor = amount > 0 ? .systemGreen : .systemRed
        
        reasonLabel.text = item.reason
        userIdLabel.text = String(localized: "User: \(item.userId)")
        newBalanceLabel.text = String(localized: "Balance: \(item.newBalance)")
        
        if let date = ISO8601DateFormatter().date(from: item.createdAt) {
            dateLabel.text = dateFormatter.string(from: date)
        } else {
            dateLabel.text = item.createdAt
        }
        
        let change = amount > 0
            ? String(localized: "Added \(amount) credits")
            : String(localized: "Removed \(abs(amount)) credits")
        describe(
            change,
            hint: String(localized: "Shows adjustment details"),
            value: [item.reason, userIdLabel.text, newBalanceLabel.text, dateLabel.text].compactMap { $0 }.joined(separator: ", "),
            traits: .button
        )
    }
}
