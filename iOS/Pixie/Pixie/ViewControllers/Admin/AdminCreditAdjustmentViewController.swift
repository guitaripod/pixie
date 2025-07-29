import UIKit

class AdminCreditAdjustmentViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let contentStackView = UIStackView()
    private let haptics = HapticManager.shared
    
    private let searchBar = UISearchBar()
    private let tableView = UITableView()
    private let loadingView = UIActivityIndicatorView(style: .large)
    private let emptyStateLabel = UILabel()
    
    private let adminRepository: AdminRepositoryProtocol
    private var searchResults: [UserSearchResult] = []
    private var selectedUser: UserSearchResult?
    private var searchTimer: Timer?
    
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
    }
    
    private func setupUI() {
        title = "Credit Adjustments"
        view.backgroundColor = .systemGroupedBackground
        
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.placeholder = "Search users by email or ID"
        searchBar.delegate = self
        searchBar.searchBarStyle = .minimal
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.register(UserSearchResultCell.self, forCellReuseIdentifier: "UserCell")
        
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.hidesWhenStopped = true
        
        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyStateLabel.text = "Search for users to adjust their credits"
        emptyStateLabel.font = .systemFont(ofSize: 17)
        emptyStateLabel.textColor = .secondaryLabel
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.numberOfLines = 0
        
        view.addSubview(searchBar)
        view.addSubview(tableView)
        view.addSubview(loadingView)
        view.addSubview(emptyStateLabel)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
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
    
    private func searchUsers(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            tableView.reloadData()
            updateEmptyState()
            return
        }
        
        loadingView.startAnimating()
        emptyStateLabel.isHidden = true
        
        Task {
            do {
                let results = try await adminRepository.searchUsers(query: query)
                await MainActor.run {
                    self.searchResults = results
                    self.tableView.reloadData()
                    self.loadingView.stopAnimating()
                    self.updateEmptyState()
                }
            } catch {
                await MainActor.run {
                    self.searchResults = []
                    self.tableView.reloadData()
                    self.loadingView.stopAnimating()
                    self.showError(error.localizedDescription)
                }
            }
        }
    }
    
    private func updateEmptyState() {
        if searchResults.isEmpty && !searchBar.text!.isEmpty {
            emptyStateLabel.text = "No users found"
            emptyStateLabel.isHidden = false
        } else if searchResults.isEmpty {
            emptyStateLabel.text = "Search for users to adjust their credits"
            emptyStateLabel.isHidden = false
        } else {
            emptyStateLabel.isHidden = true
        }
    }
    
    private func showAdjustmentDialog(for user: UserSearchResult) {
        let alertController = UIAlertController(
            title: "Adjust Credits",
            message: "Current balance: \(user.credits) credits\nUser: \(user.email ?? user.id)",
            preferredStyle: .alert
        )
        
        alertController.addTextField { textField in
            textField.placeholder = "Amount (positive to add, negative to remove)"
            textField.keyboardType = .numbersAndPunctuation
        }
        
        alertController.addTextField { textField in
            textField.placeholder = "Reason for adjustment"
        }
        
        let adjustAction = UIAlertAction(title: "Adjust", style: .default) { [weak self] _ in
            guard let amountText = alertController.textFields?[0].text,
                  let amount = Int(amountText),
                  let reason = alertController.textFields?[1].text,
                  !reason.isEmpty else {
                self?.showError("Please enter a valid amount and reason")
                return
            }
            
            self?.performAdjustment(userId: user.id, amount: amount, reason: reason)
        }
        
        alertController.addAction(adjustAction)
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        haptics.impact(.click)
        present(alertController, animated: true)
    }
    
    private func performAdjustment(userId: String, amount: Int, reason: String) {
        let loadingAlert = UIAlertController(title: "Adjusting Credits", message: "Please wait...", preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        Task {
            do {
                let request = AdminCreditAdjustmentRequest(userId: userId, amount: amount, reason: reason)
                let response = try await adminRepository.adjustCredits(request: request)
                
                await MainActor.run {
                    loadingAlert.dismiss(animated: true) {
                        self.haptics.notification(.success)
                        let successAlert = UIAlertController(
                            title: "Success",
                            message: "Credits adjusted successfully. New balance: \(response.newBalance)",
                            preferredStyle: .alert
                        )
                        successAlert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                            self.searchBar.text = ""
                            self.searchResults = []
                            self.tableView.reloadData()
                            self.updateEmptyState()
                        })
                        self.present(successAlert, animated: true)
                    }
                }
            } catch {
                await MainActor.run {
                    loadingAlert.dismiss(animated: true) {
                        self.haptics.notification(.error)
                        self.showError(error.localizedDescription)
                    }
                }
            }
        }
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

extension AdminCreditAdjustmentViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchTimer?.invalidate()
        
        searchTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.searchUsers(query: searchText)
        }
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

extension AdminCreditAdjustmentViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "UserCell", for: indexPath) as! UserSearchResultCell
        let user = searchResults[indexPath.row]
        cell.configure(with: user)
        return cell
    }
}

extension AdminCreditAdjustmentViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let user = searchResults[indexPath.row]
        showAdjustmentDialog(for: user)
    }
}

class UserSearchResultCell: UITableViewCell {
    
    private let containerView = UIView()
    private let emailLabel = UILabel()
    private let idLabel = UILabel()
    private let creditsLabel = UILabel()
    private let adminBadge = UILabel()
    
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
        
        emailLabel.translatesAutoresizingMaskIntoConstraints = false
        emailLabel.font = .systemFont(ofSize: 17, weight: .medium)
        
        idLabel.translatesAutoresizingMaskIntoConstraints = false
        idLabel.font = .systemFont(ofSize: 13)
        idLabel.textColor = .secondaryLabel
        
        creditsLabel.translatesAutoresizingMaskIntoConstraints = false
        creditsLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        creditsLabel.textColor = UIColor(red: 103/255, green: 80/255, blue: 164/255, alpha: 1.0)
        
        adminBadge.translatesAutoresizingMaskIntoConstraints = false
        adminBadge.text = "ADMIN"
        adminBadge.font = .systemFont(ofSize: 11, weight: .bold)
        adminBadge.textColor = .white
        adminBadge.backgroundColor = .systemOrange
        adminBadge.layer.cornerRadius = 4
        adminBadge.textAlignment = .center
        adminBadge.isHidden = true
        
        contentView.addSubview(containerView)
        containerView.addSubview(emailLabel)
        containerView.addSubview(idLabel)
        containerView.addSubview(creditsLabel)
        containerView.addSubview(adminBadge)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            emailLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            emailLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            emailLabel.trailingAnchor.constraint(lessThanOrEqualTo: adminBadge.leadingAnchor, constant: -8),
            
            idLabel.topAnchor.constraint(equalTo: emailLabel.bottomAnchor, constant: 4),
            idLabel.leadingAnchor.constraint(equalTo: emailLabel.leadingAnchor),
            idLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            
            creditsLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            creditsLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            adminBadge.centerYAnchor.constraint(equalTo: emailLabel.centerYAnchor),
            adminBadge.trailingAnchor.constraint(equalTo: creditsLabel.leadingAnchor, constant: -8),
            adminBadge.widthAnchor.constraint(equalToConstant: 50),
            adminBadge.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    func configure(with user: UserSearchResult) {
        emailLabel.text = user.email ?? "No email"
        idLabel.text = "ID: \(user.id)"
        creditsLabel.text = "\(user.credits)"
        adminBadge.isHidden = !user.isAdmin
    }
}