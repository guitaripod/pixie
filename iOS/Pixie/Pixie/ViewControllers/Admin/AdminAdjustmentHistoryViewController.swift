import UIKit

class AdminAdjustmentHistoryViewController: UIViewController {
    
    private let tableView = UITableView()
    private let refreshControl = UIRefreshControl()
    private let loadingView = UIActivityIndicatorView(style: .large)
    private let emptyStateLabel = UILabel()
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
        title = "Adjustment History"
        view.backgroundColor = .systemGroupedBackground
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.refreshControl = refreshControl
        tableView.register(AdjustmentHistoryCell.self, forCellReuseIdentifier: "HistoryCell")
        
        refreshControl.addTarget(self, action: #selector(refreshHistory), for: .valueChanged)
        
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.hidesWhenStopped = true
        
        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyStateLabel.text = "No adjustment history"
        emptyStateLabel.font = .systemFont(ofSize: 17)
        emptyStateLabel.textColor = .secondaryLabel
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.numberOfLines = 0
        emptyStateLabel.isHidden = true
        
        view.addSubview(tableView)
        view.addSubview(loadingView)
        view.addSubview(emptyStateLabel)
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
            emptyStateLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            emptyStateLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
    }
    
    private func loadHistory() {
        loadingView.startAnimating()
        
        Task {
            do {
                let response = try await adminRepository.getAdjustmentHistory(userId: nil)
                await MainActor.run {
                    self.adjustmentHistory = response.adjustments
                    self.tableView.reloadData()
                    self.loadingView.stopAnimating()
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
        emptyStateLabel.isHidden = !adjustmentHistory.isEmpty
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
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
            title: "Adjustment Details",
            message: """
            User ID: \(item.userId)
            Admin ID: \(item.adminId)
            Amount: \(item.amount > 0 ? "+" : "")\(item.amount)
            New Balance: \(item.newBalance)
            Reason: \(item.reason)
            Date: \(dateFormatter.string(from: ISO8601DateFormatter().date(from: item.createdAt) ?? Date()))
            """,
            preferredStyle: .alert
        )
        detailAlert.addAction(UIAlertAction(title: "OK", style: .default))
        
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
        
        amountLabel.translatesAutoresizingMaskIntoConstraints = false
        amountLabel.font = .systemFont(ofSize: 24, weight: .bold)
        
        reasonLabel.translatesAutoresizingMaskIntoConstraints = false
        reasonLabel.font = .systemFont(ofSize: 15)
        reasonLabel.textColor = .secondaryLabel
        reasonLabel.numberOfLines = 2
        
        userIdLabel.translatesAutoresizingMaskIntoConstraints = false
        userIdLabel.font = .systemFont(ofSize: 13)
        userIdLabel.textColor = .tertiaryLabel
        
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.font = .systemFont(ofSize: 13)
        dateLabel.textColor = .tertiaryLabel
        
        newBalanceLabel.translatesAutoresizingMaskIntoConstraints = false
        newBalanceLabel.font = .systemFont(ofSize: 15, weight: .medium)
        newBalanceLabel.textColor = .secondaryLabel
        
        contentView.addSubview(containerView)
        containerView.addSubview(amountLabel)
        containerView.addSubview(reasonLabel)
        containerView.addSubview(userIdLabel)
        containerView.addSubview(dateLabel)
        containerView.addSubview(newBalanceLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            amountLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            amountLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            
            newBalanceLabel.centerYAnchor.constraint(equalTo: amountLabel.centerYAnchor),
            newBalanceLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            reasonLabel.topAnchor.constraint(equalTo: amountLabel.bottomAnchor, constant: 8),
            reasonLabel.leadingAnchor.constraint(equalTo: amountLabel.leadingAnchor),
            reasonLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            userIdLabel.topAnchor.constraint(equalTo: reasonLabel.bottomAnchor, constant: 8),
            userIdLabel.leadingAnchor.constraint(equalTo: amountLabel.leadingAnchor),
            userIdLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            
            dateLabel.centerYAnchor.constraint(equalTo: userIdLabel.centerYAnchor),
            dateLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16)
        ])
    }
    
    func configure(with item: AdjustmentHistoryItem, dateFormatter: DateFormatter) {
        let amount = item.amount
        amountLabel.text = amount > 0 ? "+\(amount)" : "\(amount)"
        amountLabel.textColor = amount > 0 ? .systemGreen : .systemRed
        
        reasonLabel.text = item.reason
        userIdLabel.text = "User: \(item.userId)"
        newBalanceLabel.text = "Balance: \(item.newBalance)"
        
        if let date = ISO8601DateFormatter().date(from: item.createdAt) {
            dateLabel.text = dateFormatter.string(from: date)
        } else {
            dateLabel.text = item.createdAt
        }
    }
}