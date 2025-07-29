import UIKit

class SettingsViewController: UIViewController {
    
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let authenticationManager = AuthenticationManager.shared
    private let haptics = HapticManager.shared
    
    private enum Section: Int, CaseIterable {
        case account
        case admin
        
        var title: String {
            switch self {
            case .account: return "Account"
            case .admin: return "Admin"
            }
        }
    }
    
    private enum AccountRow: Int, CaseIterable {
        case userId
        case logout
    }
    
    private enum AdminRow: Int, CaseIterable {
        case dashboard
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Settings"
        view.backgroundColor = .systemGroupedBackground
        
        setupTableView()
        setupConstraints()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        Task {
            let adminRepository = AdminRepository(networkService: AppContainer.shared.networkService)
            let isAdmin = await adminRepository.checkAdminStatus()
            
            if isAdmin && authenticationManager.currentUser?.isAdmin != true {
                // Update user admin status
                if let user = authenticationManager.currentUser {
                    let updatedUser = User(
                        id: user.id,
                        email: user.email,
                        name: user.name,
                        isAdmin: true,
                        createdAt: user.createdAt
                    )
                    try? await AppContainer.shared.authenticationService.setCurrentUser(updatedUser)
                }
            }
            
            await MainActor.run {
                tableView.reloadData()
            }
        }
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func handleLogout() {
        let alert = UIAlertController(
            title: "Logout",
            message: "Are you sure you want to logout?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Logout", style: .destructive) { _ in
            Task {
                do {
                    try await self.authenticationManager.logout()
                    
                    await MainActor.run {
                        if let sceneDelegate = self.view.window?.windowScene?.delegate as? SceneDelegate {
                            sceneDelegate.window?.rootViewController = AuthenticationViewController()
                        }
                    }
                } catch {
                    await MainActor.run {
                        let errorAlert = UIAlertController(
                            title: "Error",
                            message: "Failed to logout: \(error.localizedDescription)",
                            preferredStyle: .alert
                        )
                        errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(errorAlert, animated: true)
                    }
                }
            }
        })
        
        present(alert, animated: true)
    }
}

extension SettingsViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return authenticationManager.currentUser?.isAdmin == true ? Section.allCases.count : 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == Section.account.rawValue {
            return AccountRow.allCases.count
        } else if section == Section.admin.rawValue && authenticationManager.currentUser?.isAdmin == true {
            return AdminRow.allCases.count
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        
        if indexPath.section == Section.account.rawValue {
            switch AccountRow(rawValue: indexPath.row) {
            case .userId:
                cell.textLabel?.text = "User ID"
                cell.detailTextLabel?.text = authenticationManager.currentUser?.id ?? "Not logged in"
                cell.detailTextLabel?.textColor = .systemBlue
                cell.selectionStyle = .none
            case .logout:
                cell.textLabel?.text = "Logout"
                cell.textLabel?.textColor = .systemRed
            case .none:
                break
            }
        } else if indexPath.section == Section.admin.rawValue {
            switch AdminRow(rawValue: indexPath.row) {
            case .dashboard:
                cell.textLabel?.text = "Admin Dashboard"
                cell.accessoryType = .disclosureIndicator
            case .none:
                break
            }
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return Section(rawValue: section)?.title
    }
}

extension SettingsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        haptics.impact(.click)
        
        if indexPath.section == Section.account.rawValue {
            switch AccountRow(rawValue: indexPath.row) {
            case .logout:
                handleLogout()
            default:
                break
            }
        } else if indexPath.section == Section.admin.rawValue {
            switch AdminRow(rawValue: indexPath.row) {
            case .dashboard:
                presentAdminDashboard()
            default:
                break
            }
        }
    }
    
    private func presentAdminDashboard() {
        let adminVC = AdminDashboardViewController()
        navigationController?.pushViewController(adminVC, animated: true)
    }
}