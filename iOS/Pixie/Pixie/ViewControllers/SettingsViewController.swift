import UIKit

class SettingsViewController: UIViewController {
    
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let authenticationManager = AuthenticationManager.shared
    private let configurationManager = ConfigurationManager.shared
    private let cacheManager = CacheManager.shared
    private let haptics = HapticManager.shared
    private let networkService = AppContainer.shared.networkService
    
    private var cacheSize: String = "Calculating..."
    private var connectionStatus: ConnectionStatus = .idle
    private var isTestingConnection = false
    
    private enum ConnectionStatus {
        case idle
        case testing
        case success
        case error(String)
    }
    
    private enum Section: Int, CaseIterable {
        case appearance
        case defaults
        case storage
        case api
        case admin
        case help
        case account
        
        var title: String {
            switch self {
            case .appearance: return "Appearance"
            case .defaults: return "Defaults"
            case .storage: return "Storage"
            case .api: return "API"
            case .admin: return "Admin"
            case .help: return "Help & Support"
            case .account: return "Account"
            }
        }
        
        var isVisible: Bool {
            if self == .admin {
                return AuthenticationManager.shared.currentUser?.isAdmin == true
            }
            return true
        }
    }
    
    private enum AppearanceRow: Int, CaseIterable {
        case theme
    }
    
    private enum DefaultsRow: Int, CaseIterable {
        case quality
        case size
        case format
        case compression
        case background
        case moderation
    }
    
    private enum StorageRow: Int, CaseIterable {
        case cache
    }
    
    private enum APIRow: Int, CaseIterable {
        case connection
    }
    
    private enum AdminRow: Int, CaseIterable {
        case dashboard
    }
    
    private enum HelpRow: Int, CaseIterable {
        case documentation
        case about
    }
    
    private enum AccountRow: Int, CaseIterable {
        case userId
        case logout
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Settings"
        view.backgroundColor = .systemGroupedBackground
        
        setupTableView()
        setupConstraints()
        setupNotifications()
        loadCacheSize()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(configurationDidChange),
            name: ConfigurationManager.configurationDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func configurationDidChange() {
        DispatchQueue.main.async { [weak self] in
            self?.tableView.reloadData()
        }
    }
    
    private func loadCacheSize() {
        Task {
            let size = await cacheManager.getCacheSize()
            await MainActor.run {
                self.cacheSize = cacheManager.formatCacheSize(size)
                if let indexPath = self.indexPathForRow(StorageRow.cache, inSection: .storage) {
                    self.tableView.reloadRows(at: [indexPath], with: .none)
                }
            }
        }
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
        
        // Update cache size when view appears
        loadCacheSize()
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
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
        return Section.allCases.filter { $0.isVisible }.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let visibleSections = Section.allCases.filter { $0.isVisible }
        guard section < visibleSections.count else { return 0 }
        
        switch visibleSections[section] {
        case .appearance:
            return AppearanceRow.allCases.count
        case .defaults:
            return DefaultsRow.allCases.count
        case .storage:
            return StorageRow.allCases.count
        case .api:
            return APIRow.allCases.count
        case .admin:
            return AdminRow.allCases.count
        case .help:
            return HelpRow.allCases.count
        case .account:
            return AccountRow.allCases.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let visibleSections = Section.allCases.filter { $0.isVisible }
        guard indexPath.section < visibleSections.count else {
            return UITableViewCell()
        }
        
        let section = visibleSections[indexPath.section]
        
        switch section {
        case .appearance:
            return configureAppearanceCell(at: indexPath)
        case .defaults:
            return configureDefaultsCell(at: indexPath)
        case .storage:
            return configureStorageCell(at: indexPath)
        case .api:
            return configureAPICell(at: indexPath)
        case .admin:
            return configureAdminCell(at: indexPath)
        case .help:
            return configureHelpCell(at: indexPath)
        case .account:
            return configureAccountCell(at: indexPath)
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let visibleSections = Section.allCases.filter { $0.isVisible }
        guard section < visibleSections.count else { return nil }
        return visibleSections[section].title
    }
    
    private func configureAppearanceCell(at indexPath: IndexPath) -> UITableViewCell {
        guard let row = AppearanceRow(rawValue: indexPath.row) else {
            return UITableViewCell()
        }
        
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.selectionStyle = .none
        
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(containerView)
        
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .preferredFont(forTextStyle: .body)
        containerView.addSubview(label)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -8),
            
            label.topAnchor.constraint(equalTo: containerView.topAnchor),
            label.leadingAnchor.constraint(equalTo: containerView.leadingAnchor)
        ])
        
        switch row {
        case .theme:
            label.text = "Theme"
            
            let segmentedControl = UISegmentedControl(items: ["System", "Light", "Dark"])
            segmentedControl.translatesAutoresizingMaskIntoConstraints = false
            
            switch configurationManager.theme {
            case .system: segmentedControl.selectedSegmentIndex = 0
            case .light: segmentedControl.selectedSegmentIndex = 1
            case .dark: segmentedControl.selectedSegmentIndex = 2
            }
            
            segmentedControl.addTarget(self, action: #selector(themeChanged(_:)), for: .valueChanged)
            containerView.addSubview(segmentedControl)
            
            NSLayoutConstraint.activate([
                segmentedControl.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
                segmentedControl.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                segmentedControl.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                segmentedControl.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
            
            return cell
        }
    }
    
    private func configureDefaultsCell(at indexPath: IndexPath) -> UITableViewCell {
        guard let row = DefaultsRow(rawValue: indexPath.row) else {
            return UITableViewCell()
        }
        
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.selectionStyle = .none
        
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(containerView)
        
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .preferredFont(forTextStyle: .body)
        containerView.addSubview(label)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -8),
            
            label.topAnchor.constraint(equalTo: containerView.topAnchor),
            label.leadingAnchor.constraint(equalTo: containerView.leadingAnchor)
        ])
        
        switch row {
        case .quality:
            label.text = "Quality"
            
            let segmentedControl = UISegmentedControl(items: ["Low", "Medium", "High", "Auto"])
            segmentedControl.translatesAutoresizingMaskIntoConstraints = false
            
            switch configurationManager.defaultQuality {
            case "low": segmentedControl.selectedSegmentIndex = 0
            case "medium": segmentedControl.selectedSegmentIndex = 1
            case "high": segmentedControl.selectedSegmentIndex = 2
            case "auto": segmentedControl.selectedSegmentIndex = 3
            default: segmentedControl.selectedSegmentIndex = 0
            }
            
            segmentedControl.addTarget(self, action: #selector(qualityChanged(_:)), for: .valueChanged)
            containerView.addSubview(segmentedControl)
            
            NSLayoutConstraint.activate([
                segmentedControl.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
                segmentedControl.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                segmentedControl.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                segmentedControl.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
            
        case .size:
            label.text = "Size"
            
            let segmentedControl = UISegmentedControl(items: ["Square", "Landscape", "Portrait", "Auto"])
            segmentedControl.translatesAutoresizingMaskIntoConstraints = false
            
            switch configurationManager.defaultSize {
            case "1024x1024", "square": segmentedControl.selectedSegmentIndex = 0
            case "1792x1024", "landscape": segmentedControl.selectedSegmentIndex = 1
            case "1024x1792", "portrait": segmentedControl.selectedSegmentIndex = 2
            case "auto": segmentedControl.selectedSegmentIndex = 3
            default: segmentedControl.selectedSegmentIndex = 3
            }
            
            segmentedControl.addTarget(self, action: #selector(sizeChanged(_:)), for: .valueChanged)
            containerView.addSubview(segmentedControl)
            
            NSLayoutConstraint.activate([
                segmentedControl.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
                segmentedControl.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                segmentedControl.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                segmentedControl.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
            
        case .format:
            label.text = "Format"
            
            let segmentedControl = UISegmentedControl(items: ["PNG", "JPEG", "WebP"])
            segmentedControl.translatesAutoresizingMaskIntoConstraints = false
            
            switch configurationManager.defaultOutputFormat {
            case "png": segmentedControl.selectedSegmentIndex = 0
            case "jpeg", "jpg": segmentedControl.selectedSegmentIndex = 1
            case "webp": segmentedControl.selectedSegmentIndex = 2
            default: segmentedControl.selectedSegmentIndex = 2
            }
            
            segmentedControl.addTarget(self, action: #selector(formatChanged(_:)), for: .valueChanged)
            containerView.addSubview(segmentedControl)
            
            NSLayoutConstraint.activate([
                segmentedControl.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
                segmentedControl.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                segmentedControl.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                segmentedControl.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
            
        case .compression:
            let compressionCell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            compressionCell.textLabel?.text = "Compression Level"
            compressionCell.detailTextLabel?.text = "\(configurationManager.defaultCompression)%"
            
            if configurationManager.defaultOutputFormat == "png" {
                compressionCell.textLabel?.textColor = .secondaryLabel
                compressionCell.detailTextLabel?.textColor = .secondaryLabel
                compressionCell.selectionStyle = .none
            } else {
                compressionCell.accessoryType = .disclosureIndicator
                compressionCell.selectionStyle = .default
            }
            return compressionCell
            
        case .background:
            label.text = "Background"
            
            let segmentedControl = UISegmentedControl(items: ["Auto", "Transparent", "Opaque", "None"])
            segmentedControl.translatesAutoresizingMaskIntoConstraints = false
            
            switch configurationManager.defaultBackground {
            case "auto": segmentedControl.selectedSegmentIndex = 0
            case "transparent": segmentedControl.selectedSegmentIndex = 1
            case "opaque": segmentedControl.selectedSegmentIndex = 2
            case "none": segmentedControl.selectedSegmentIndex = 3
            default: segmentedControl.selectedSegmentIndex = 0
            }
            
            segmentedControl.addTarget(self, action: #selector(backgroundChanged(_:)), for: .valueChanged)
            containerView.addSubview(segmentedControl)
            
            NSLayoutConstraint.activate([
                segmentedControl.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
                segmentedControl.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                segmentedControl.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                segmentedControl.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
            
        case .moderation:
            label.text = "Moderation"
            
            let segmentedControl = UISegmentedControl(items: ["Default", "Auto", "Low"])
            segmentedControl.translatesAutoresizingMaskIntoConstraints = false
            
            switch configurationManager.defaultModeration {
            case "default": segmentedControl.selectedSegmentIndex = 0
            case "auto": segmentedControl.selectedSegmentIndex = 1
            case "low": segmentedControl.selectedSegmentIndex = 2
            default: segmentedControl.selectedSegmentIndex = 1
            }
            
            segmentedControl.addTarget(self, action: #selector(moderationChanged(_:)), for: .valueChanged)
            containerView.addSubview(segmentedControl)
            
            NSLayoutConstraint.activate([
                segmentedControl.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
                segmentedControl.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                segmentedControl.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                segmentedControl.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
        }
        
        return cell
    }
    
    private func configureStorageCell(at indexPath: IndexPath) -> UITableViewCell {
        guard let row = StorageRow(rawValue: indexPath.row) else {
            return UITableViewCell()
        }
        
        switch row {
        case .cache:
            let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            cell.textLabel?.text = "Image Cache"
            cell.detailTextLabel?.text = cacheSize
            return cell
        }
    }
    
    private func configureAPICell(at indexPath: IndexPath) -> UITableViewCell {
        guard let row = APIRow(rawValue: indexPath.row) else {
            return UITableViewCell()
        }
        
        switch row {
        case .connection:
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            cell.textLabel?.text = "API Connection"
            cell.detailTextLabel?.text = "Test connection to Pixie servers"
            
            switch connectionStatus {
            case .idle:
                break
            case .testing:
                let spinner = UIActivityIndicatorView(style: .medium)
                spinner.startAnimating()
                cell.accessoryView = spinner
            case .success:
                let checkmark = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
                checkmark.tintColor = .systemGreen
                cell.accessoryView = checkmark
                cell.detailTextLabel?.text = "Connected successfully"
                cell.detailTextLabel?.textColor = .systemGreen
            case .error(let message):
                let warning = UIImageView(image: UIImage(systemName: "exclamationmark.triangle.fill"))
                warning.tintColor = .systemRed
                cell.accessoryView = warning
                cell.detailTextLabel?.text = message
                cell.detailTextLabel?.textColor = .systemRed
            }
            
            return cell
        }
    }
    
    private func configureAdminCell(at indexPath: IndexPath) -> UITableViewCell {
        guard let row = AdminRow(rawValue: indexPath.row) else {
            return UITableViewCell()
        }
        
        switch row {
        case .dashboard:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = "Admin Dashboard"
            cell.accessoryType = .disclosureIndicator
            return cell
        }
    }
    
    private func configureHelpCell(at indexPath: IndexPath) -> UITableViewCell {
        guard let row = HelpRow(rawValue: indexPath.row) else {
            return UITableViewCell()
        }
        
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        
        switch row {
        case .documentation:
            cell.textLabel?.text = "Help Documentation"
            cell.detailTextLabel?.text = "Learn how to use Pixie"
            cell.accessoryType = .disclosureIndicator
        case .about:
            cell.textLabel?.text = "About"
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
               let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                cell.detailTextLabel?.text = "Version \(version) (\(build))"
            }
            cell.selectionStyle = .none
        }
        
        return cell
    }
    
    private func configureAccountCell(at indexPath: IndexPath) -> UITableViewCell {
        guard let row = AccountRow(rawValue: indexPath.row) else {
            return UITableViewCell()
        }
        
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        
        switch row {
        case .userId:
            cell.textLabel?.text = "User ID"
            cell.detailTextLabel?.text = authenticationManager.currentUser?.id ?? "Not logged in"
            cell.detailTextLabel?.textColor = .systemBlue
            cell.selectionStyle = .none
        case .logout:
            cell.textLabel?.text = "Log Out"
            cell.textLabel?.textColor = .systemRed
            cell.detailTextLabel?.text = "Sign out of your account"
            cell.detailTextLabel?.textColor = .secondaryLabel
        }
        
        return cell
    }
    
    private func formatQuality(_ quality: String) -> String {
        switch quality.lowercased() {
        case "low": return "Low (~4-5 credits)"
        case "medium": return "Medium (~12-15 credits)"
        case "high": return "High (~50-80 credits)"
        case "auto": return "Auto (AI selects)"
        default: return quality.capitalized
        }
    }
    
    private func formatSize(_ size: String) -> String {
        switch size.lowercased() {
        case "square": return "Square (1024×1024)"
        case "landscape": return "Landscape (1536×1024)"
        case "portrait": return "Portrait (1024×1536)"
        case "auto": return "Auto (AI selects)"
        default: return size.capitalized
        }
    }
}

extension SettingsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        haptics.impact(.click)
        
        let visibleSections = Section.allCases.filter { $0.isVisible }
        guard indexPath.section < visibleSections.count else { return }
        
        let section = visibleSections[indexPath.section]
        
        switch section {
        case .appearance:
            handleAppearanceSelection(at: indexPath)
        case .defaults:
            handleDefaultsSelection(at: indexPath)
        case .storage:
            handleStorageSelection(at: indexPath)
        case .api:
            handleAPISelection(at: indexPath)
        case .admin:
            handleAdminSelection(at: indexPath)
        case .help:
            handleHelpSelection(at: indexPath)
        case .account:
            handleAccountSelection(at: indexPath)
        }
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let visibleSections = Section.allCases.filter { $0.isVisible }
        guard section < visibleSections.count else { return nil }
        
        if visibleSections[section] == .storage {
            let footerView = UIView()
            let button = UIButton(type: .system)
            button.setTitle("Clear Cache", for: .normal)
            button.setTitleColor(.systemRed, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
            button.addTarget(self, action: #selector(clearCacheTapped), for: .touchUpInside)
            button.translatesAutoresizingMaskIntoConstraints = false
            
            footerView.addSubview(button)
            NSLayoutConstraint.activate([
                button.centerXAnchor.constraint(equalTo: footerView.centerXAnchor),
                button.topAnchor.constraint(equalTo: footerView.topAnchor, constant: 16),
                button.bottomAnchor.constraint(equalTo: footerView.bottomAnchor, constant: -16)
            ])
            
            return footerView
        }
        
        return nil
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let visibleSections = Section.allCases.filter { $0.isVisible }
        guard section < visibleSections.count else { return 0 }
        
        if visibleSections[section] == .storage {
            return 60
        }
        return 0
    }
    
    private func handleAppearanceSelection(at indexPath: IndexPath) {
        // Theme is handled by the UIMenu, no action needed on row tap
    }
    
    private func handleDefaultsSelection(at indexPath: IndexPath) {
        guard let row = DefaultsRow(rawValue: indexPath.row) else { return }
        
        switch row {
        case .quality, .size, .format, .background, .moderation:
            break
        case .compression:
            if configurationManager.defaultOutputFormat != "png" {
                presentCompressionSelector()
            }
        }
    }
    
    private func handleStorageSelection(at indexPath: IndexPath) {
        // Storage rows don't have actions on tap
    }
    
    private func handleAPISelection(at indexPath: IndexPath) {
        guard let row = APIRow(rawValue: indexPath.row) else { return }
        
        switch row {
        case .connection:
            testConnection()
        }
    }
    
    private func handleAdminSelection(at indexPath: IndexPath) {
        guard let row = AdminRow(rawValue: indexPath.row) else { return }
        
        switch row {
        case .dashboard:
            presentAdminDashboard()
        }
    }
    
    private func handleHelpSelection(at indexPath: IndexPath) {
        guard let row = HelpRow(rawValue: indexPath.row) else { return }
        
        switch row {
        case .documentation:
            presentHelpDocumentation()
        case .about:
            break
        }
    }
    
    private func handleAccountSelection(at indexPath: IndexPath) {
        guard let row = AccountRow(rawValue: indexPath.row) else { return }
        
        switch row {
        case .userId:
            break
        case .logout:
            handleLogout()
        }
    }
    
    private func presentAdminDashboard() {
        let adminVC = AdminDashboardViewController()
        navigationController?.pushViewController(adminVC, animated: true)
    }
    
    @objc private func themeChanged(_ sender: UISegmentedControl) {
        haptics.impact(.click)
        let themes: [AppTheme] = [.system, .light, .dark]
        configurationManager.theme = themes[sender.selectedSegmentIndex]
        updateAppearance()
        tableView.reloadData()
    }
    
    @objc private func qualityChanged(_ sender: UISegmentedControl) {
        haptics.impact(.click)
        let qualities = ["low", "medium", "high", "auto"]
        configurationManager.defaultQuality = qualities[sender.selectedSegmentIndex]
    }
    
    @objc private func sizeChanged(_ sender: UISegmentedControl) {
        haptics.impact(.click)
        let sizes = ["1024x1024", "1792x1024", "1024x1792", "auto"]
        configurationManager.defaultSize = sizes[sender.selectedSegmentIndex]
    }
    
    @objc private func formatChanged(_ sender: UISegmentedControl) {
        haptics.impact(.click)
        let formats = ["png", "jpeg", "webp"]
        configurationManager.defaultOutputFormat = formats[sender.selectedSegmentIndex]
        
        if let compressionPath = indexPathForRow(DefaultsRow.compression, inSection: .defaults) {
            tableView.reloadRows(at: [compressionPath], with: .fade)
        }
    }
    
    @objc private func backgroundChanged(_ sender: UISegmentedControl) {
        haptics.impact(.click)
        let backgrounds = ["auto", "transparent", "opaque", "none"]
        configurationManager.defaultBackground = backgrounds[sender.selectedSegmentIndex]
    }
    
    @objc private func moderationChanged(_ sender: UISegmentedControl) {
        haptics.impact(.click)
        let moderations = ["default", "auto", "low"]
        configurationManager.defaultModeration = moderations[sender.selectedSegmentIndex]
    }
    
    @objc private func clearCacheTapped() {
        haptics.impact(.warning)
        
        let alert = UIAlertController(
            title: "Clear Cache",
            message: "This will delete all cached images. Are you sure?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            self.haptics.impact(.click)
        })
        
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { _ in
            self.haptics.impact(.success)
            Task {
                await self.cacheManager.clearCache()
                self.cacheSize = "0 KB"
                await MainActor.run {
                    if let indexPath = self.indexPathForRow(StorageRow.cache, inSection: .storage) {
                        self.tableView.reloadRows(at: [indexPath], with: .none)
                    }
                }
                self.loadCacheSize()
            }
        })
        
        present(alert, animated: true)
    }
    
    private func testConnection() {
        guard !isTestingConnection else { return }
        
        isTestingConnection = true
        connectionStatus = .testing
        
        if let indexPath = indexPathForRow(APIRow.connection, inSection: .api) {
            tableView.reloadRows(at: [indexPath], with: .none)
        }
        
        Task {
            do {
                // Use root endpoint for health check
                struct HealthResponse: Decodable {
                    // Empty response, we just care about the status
                }
                
                // The root endpoint returns plain text, so we'll just check for a successful response
                let request = URLRequest(url: URL(string: "\(configurationManager.baseURL)/")!, cachePolicy: .reloadIgnoringLocalCacheData)
                let (_, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                
                await MainActor.run {
                    self.connectionStatus = .success
                    self.isTestingConnection = false
                    self.haptics.impact(.success)
                    
                    if let indexPath = self.indexPathForRow(APIRow.connection, inSection: .api) {
                        self.tableView.reloadRows(at: [indexPath], with: .fade)
                    }
                    
                    // Reset status after 3 seconds
                    Task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        self.connectionStatus = .idle
                        if let indexPath = self.indexPathForRow(APIRow.connection, inSection: .api) {
                            self.tableView.reloadRows(at: [indexPath], with: .fade)
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.connectionStatus = .error(error.localizedDescription)
                    self.isTestingConnection = false
                    self.haptics.impact(.error)
                    
                    if let indexPath = self.indexPathForRow(APIRow.connection, inSection: .api) {
                        self.tableView.reloadRows(at: [indexPath], with: .fade)
                    }
                    
                    // Reset status after 5 seconds
                    Task {
                        try? await Task.sleep(nanoseconds: 5_000_000_000)
                        self.connectionStatus = .idle
                        if let indexPath = self.indexPathForRow(APIRow.connection, inSection: .api) {
                            self.tableView.reloadRows(at: [indexPath], with: .fade)
                        }
                    }
                }
            }
        }
    }
    
    private func presentHelpDocumentation() {
        let helpVC = HelpViewController()
        navigationController?.pushViewController(helpVC, animated: true)
    }
    
    
    private func presentQualitySelector() {
        let alert = UIAlertController(title: "Default Quality", message: nil, preferredStyle: .actionSheet)
        
        let qualities = ["low", "medium", "high", "auto"]
        for quality in qualities {
            let action = UIAlertAction(title: formatQuality(quality), style: .default) { _ in
                self.haptics.impact(.click)
                self.configurationManager.defaultQuality = quality
            }
            
            if quality == configurationManager.defaultQuality {
                action.setValue(true, forKey: "checked")
            }
            
            alert.addAction(action)
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            self.haptics.impact(.click)
        })
        
        if let popover = alert.popoverPresentationController {
            if let sectionIdx = sectionIndex(for: .defaults),
               let cell = tableView.cellForRow(at: IndexPath(row: DefaultsRow.quality.rawValue, section: sectionIdx)) {
                popover.sourceView = cell
                popover.sourceRect = cell.bounds
            }
        }
        
        present(alert, animated: true)
    }
    
    private func presentSizeSelector() {
        let alert = UIAlertController(title: "Default Size", message: nil, preferredStyle: .actionSheet)
        
        let sizes = ["square", "landscape", "portrait", "auto"]
        for size in sizes {
            let action = UIAlertAction(title: formatSize(size), style: .default) { _ in
                self.haptics.impact(.click)
                self.configurationManager.defaultSize = size
            }
            
            if size == configurationManager.defaultSize {
                action.setValue(true, forKey: "checked")
            }
            
            alert.addAction(action)
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            self.haptics.impact(.click)
        })
        
        if let popover = alert.popoverPresentationController {
            if let sectionIdx = sectionIndex(for: .defaults),
               let cell = tableView.cellForRow(at: IndexPath(row: DefaultsRow.size.rawValue, section: sectionIdx)) {
                popover.sourceView = cell
                popover.sourceRect = cell.bounds
            }
        }
        
        present(alert, animated: true)
    }
    
    private func presentFormatSelector() {
        let alert = UIAlertController(title: "Default Format", message: nil, preferredStyle: .actionSheet)
        
        let formats = ["png", "webp", "jpg"]
        for format in formats {
            let action = UIAlertAction(title: format.uppercased(), style: .default) { _ in
                self.haptics.impact(.click)
                self.configurationManager.defaultOutputFormat = format
                
                // Reload compression row when format changes
                if let indexPath = self.indexPathForRow(DefaultsRow.compression, inSection: .defaults) {
                    self.tableView.reloadRows(at: [indexPath], with: .fade)
                }
            }
            
            if format == configurationManager.defaultOutputFormat {
                action.setValue(true, forKey: "checked")
            }
            
            alert.addAction(action)
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            self.haptics.impact(.click)
        })
        
        if let popover = alert.popoverPresentationController {
            if let sectionIdx = sectionIndex(for: .defaults),
               let cell = tableView.cellForRow(at: IndexPath(row: DefaultsRow.format.rawValue, section: sectionIdx)) {
                popover.sourceView = cell
                popover.sourceRect = cell.bounds
            }
        }
        
        present(alert, animated: true)
    }
    
    private func presentCompressionSelector() {
        let compressionVC = CompressionSelectorViewController(
            currentLevel: configurationManager.defaultCompression,
            onLevelChanged: { [weak self] level in
                self?.configurationManager.defaultCompression = level
                self?.haptics.impact(.sliderTick)
            }
        )
        
        let nav = UINavigationController(rootViewController: compressionVC)
        present(nav, animated: true)
    }
    
    private func updateAppearance() {
        let style: UIUserInterfaceStyle
        switch configurationManager.theme {
        case .light:
            style = .light
        case .dark:
            style = .dark
        case .system:
            style = .unspecified
        }
        
        view.window?.overrideUserInterfaceStyle = style
        
        // Update all windows
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
    
    private func indexPathForRow<T: CaseIterable & RawRepresentable>(_ row: T, inSection section: Section) -> IndexPath? where T.RawValue == Int {
        guard let sectionIndex = sectionIndex(for: section) else { return nil }
        return IndexPath(row: row.rawValue, section: sectionIndex)
    }
    
    private func sectionIndex(for section: Section) -> Int? {
        let visibleSections = Section.allCases.filter { $0.isVisible }
        return visibleSections.firstIndex(of: section)
    }
}

extension AppTheme {
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}
