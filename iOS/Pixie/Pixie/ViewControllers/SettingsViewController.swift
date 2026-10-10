import AuthenticationServices
import MidgarKit
import UIKit

class SettingsViewController: UIViewController {
    private static let selectableModels: [ImageModel] = [.gemini, .geminiPro, .openai]
    private static let cacheSizeTimeout: UInt64 = 10_000_000_000

    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let authenticationManager = AuthenticationManager.shared
    private let configurationManager = ConfigurationManager.shared
    private let cacheManager = CacheManager.shared
    private let haptics = HapticManager.shared
    private let networkService = AppContainer.shared.networkService

    private var cacheSize: String = String(localized: "Calculating...")
    private var isCacheSizePending = true
    private var cacheSizeRequest = 0
    private var connectionStatus: ConnectionStatus = .idle
    private var isTestingConnection = false
    private var isDeletingAccount = false
    private var deletionOverlay: AccountDeletionProgressView?

    private enum ConnectionStatus {
        case idle
        case testing
        case success
        case error(String)
    }

    private enum Section: Int, CaseIterable {
        case appearance
        case imageDefaults
        case advanced
        case storage
        case api
        case admin
        case help
        case account

        var title: String {
            switch self {
            case .appearance: return String(localized: "Appearance")
            case .imageDefaults: return String(localized: "Image defaults")
            case .advanced: return String(localized: "Advanced")
            case .storage: return String(localized: "Storage")
            case .api: return String(localized: "API")
            case .admin: return String(localized: "Admin")
            case .help: return String(localized: "Help & Support")
            case .account: return String(localized: "Account")
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

    private enum ImageDefaultsRow: Int, CaseIterable {
        case model
        case quality
        case size
    }

    private enum AdvancedRow: Int, CaseIterable {
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
        case cloudAIConsent
        case moreApps
        case about
    }

    private enum AccountRow: Int, CaseIterable {
        case userId
        case logout
        case deleteAccount
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = String(localized: "Settings")
        view.backgroundColor = .systemGroupedBackground

        setupTableView()
        setupConstraints()
        setupNotifications()
        loadCacheSize()

        preferredContentSize = CGSize(width: 600, height: 800)
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
            self?.refreshCompressionRow()
        }
    }

    /// Reloads only the compression row so a segmented control the person is using keeps its VoiceOver focus.
    private func refreshCompressionRow() {
        guard let indexPath = indexPathForRow(AdvancedRow.compression, inSection: .advanced) else { return }
        tableView.reloadRows(at: [indexPath], with: .none)
    }

    /// Reads the cache size and gives up after the timeout so the row never stays on "Calculating..." forever.
    private func loadCacheSize() {
        cacheSizeRequest += 1
        isCacheSizePending = true
        let request = cacheSizeRequest

        Task { [weak self] in
            guard let self else { return }
            let size = await self.cacheManager.getCacheSize()
            self.showCacheSize(self.cacheManager.formatCacheSize(size), request: request)
        }

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.cacheSizeTimeout)
            guard let self, self.isCacheSizePending else { return }
            self.showCacheSize(String(localized: "Unavailable"), request: request)
        }
    }

    private func showCacheSize(_ text: String, request: Int) {
        guard request == cacheSizeRequest else { return }
        isCacheSizePending = false
        cacheSize = text
        if let indexPath = indexPathForRow(StorageRow.cache, inSection: .storage) {
            tableView.reloadRows(at: [indexPath], with: .none)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        tableView.reloadData()
        loadCacheSize()
    }

    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.estimatedSectionFooterHeight = 44
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(ClearCacheFooterView.self, forHeaderFooterViewReuseIdentifier: ClearCacheFooterView.reuseIdentifier)
        tableView.register(SettingsTextFooterView.self, forHeaderFooterViewReuseIdentifier: SettingsTextFooterView.reuseIdentifier)
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
            title: String(localized: "Logout"),
            message: String(localized: "Are you sure you want to logout?"),
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: String(localized: "Cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: String(localized: "Logout"), style: .destructive) { _ in
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
                            title: String(localized: "Error"),
                            message: String(localized: "Failed to logout: \(error.localizedDescription)"),
                            preferredStyle: .alert
                        )
                        errorAlert.addAction(UIAlertAction(title: String(localized: "OK"), style: .default))
                        self.present(errorAlert, animated: true)
                    }
                }
            }
        })

        present(alert, animated: true)
    }

    private func handleDeleteAccount() {
        guard !isDeletingAccount else { return }
        haptics.impact(.warning)

        let alert = UIAlertController(
            title: String(localized: "Delete your account?"),
            message: String(localized: "Your credits, including any you bought, and every image you've made will be permanently deleted from our servers. This can't be undone."),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: String(localized: "Cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: String(localized: "Delete Account"), style: .destructive) { [weak self] _ in
            self?.deleteAccount()
        })
        present(alert, animated: true)
    }

    /// Deletes the account on the server and wipes local state; nothing local is touched when the service throws.
    private func deleteAccount() {
        guard !isDeletingAccount else { return }
        setDeletingAccount(true)

        Task { [self] in
            do {
                try await AccountDeletionService.shared.deleteAccount()
                accountDeletionSucceeded()
            } catch {
                accountDeletionFailed(error)
            }
        }
    }

    private func accountDeletionSucceeded() {
        haptics.notification(.success)
        (view.window?.windowScene?.delegate as? SceneDelegate)?.restartAsNewUser()
        setDeletingAccount(false)
    }

    private func accountDeletionFailed(_ error: Error) {
        setDeletingAccount(false)
        haptics.notification(.error)

        let alert = UIAlertController(
            title: String(localized: "Couldn't delete your account"),
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: String(localized: "Cancel"), style: .cancel))
        let retry = UIAlertAction(title: String(localized: "Retry"), style: .default) { [weak self] _ in
            self?.deleteAccount()
        }
        alert.addAction(retry)
        alert.preferredAction = retry
        present(alert, animated: true)
    }

    /// Blocks the whole window while the deletion runs and dims the row so it cannot be triggered twice.
    private func setDeletingAccount(_ deleting: Bool) {
        isDeletingAccount = deleting
        if deleting {
            let overlay = AccountDeletionProgressView()
            overlay.install(in: view.window ?? view)
            deletionOverlay = overlay
        } else {
            deletionOverlay?.remove()
            deletionOverlay = nil
        }
        if let indexPath = indexPathForRow(AccountRow.deleteAccount, inSection: .account) {
            tableView.reloadRows(at: [indexPath], with: .none)
        }
    }

    private var advancedFooterText: String {
        configurationManager.defaultOutputFormat == "png"
            ? String(localized: "Compression isn't available for PNG")
            : String(localized: "Compression applies to JPEG and WebP")
    }

    private func refreshAdvancedFooter() {
        if let section = sectionIndex(for: .advanced),
           let footer = tableView.footerView(forSection: section) as? SettingsTextFooterView {
            footer.text = advancedFooterText
        }
        tableView.performBatchUpdates(nil)
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
        case .imageDefaults:
            return ImageDefaultsRow.allCases.count
        case .advanced:
            return AdvancedRow.allCases.count
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
        case .imageDefaults:
            return configureImageDefaultsCell(at: indexPath)
        case .advanced:
            return configureAdvancedCell(at: indexPath)
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

    /// A row of label text plus a segmented control; the control is exposed to VoiceOver as a labelled group whose segments announce which one is selected.
    private func segmentedCell(title: String, items: [String], selectedIndex: Int, action: Selector) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.selectionStyle = .none

        let label = UILabel()
        label.text = title
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.hideFromAccessibility()

        let segmentedControl = UISegmentedControl(items: items)
        segmentedControl.selectedSegmentIndex = selectedIndex
        segmentedControl.accessibilityContainerType = .semanticGroup
        segmentedControl.accessibilityLabel = title
        segmentedControl.addTarget(self, action: action, for: .valueChanged)

        let stack = UIStackView(arrangedSubviews: [label, segmentedControl])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -8)
        ])

        return cell
    }

    /// A cell laid out by `UIListContentConfiguration`, which switches to a stacked layout at accessibility text sizes.
    private func contentCell(subtitle: Bool = false, _ configure: (inout UIListContentConfiguration) -> Void) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        var content: UIListContentConfiguration = subtitle ? .subtitleCell() : .valueCell()
        content.textProperties.numberOfLines = 0
        content.secondaryTextProperties.numberOfLines = 0
        configure(&content)
        cell.contentConfiguration = content
        return cell
    }

    private func configureAppearanceCell(at indexPath: IndexPath) -> UITableViewCell {
        guard let row = AppearanceRow(rawValue: indexPath.row) else {
            return UITableViewCell()
        }

        switch row {
        case .theme:
            let selectedIndex: Int
            switch configurationManager.theme {
            case .system: selectedIndex = 0
            case .light: selectedIndex = 1
            case .dark: selectedIndex = 2
            }
            return segmentedCell(
                title: String(localized: "Theme"),
                items: [String(localized: "System"), String(localized: "Light"), String(localized: "Dark")],
                selectedIndex: selectedIndex,
                action: #selector(themeChanged(_:))
            )
        }
    }

    private func configureImageDefaultsCell(at indexPath: IndexPath) -> UITableViewCell {
        guard let row = ImageDefaultsRow(rawValue: indexPath.row) else {
            return UITableViewCell()
        }

        switch row {
        case .model:
            let defaultModel = ImageModel(rawValue: configurationManager.defaultModel) ?? .gemini
            return segmentedCell(
                title: String(localized: "AI Model"),
                items: Self.selectableModels.map(\.displayName),
                selectedIndex: Self.selectableModels.firstIndex(of: defaultModel) ?? 0,
                action: #selector(modelChanged(_:))
            )

        case .quality:
            let selectedIndex: Int
            switch configurationManager.defaultQuality {
            case "low": selectedIndex = 0
            case "medium": selectedIndex = 1
            case "high": selectedIndex = 2
            case "auto": selectedIndex = 3
            default: selectedIndex = 0
            }
            return segmentedCell(
                title: String(localized: "Quality"),
                items: [String(localized: "Low"), String(localized: "Medium"), String(localized: "High"), String(localized: "Auto")],
                selectedIndex: selectedIndex,
                action: #selector(qualityChanged(_:))
            )

        case .size:
            let selectedIndex: Int
            switch configurationManager.defaultSize {
            case "1024x1024", "square": selectedIndex = 0
            case "1792x1024", "landscape": selectedIndex = 1
            case "1024x1792", "portrait": selectedIndex = 2
            case "auto": selectedIndex = 3
            default: selectedIndex = 3
            }
            return segmentedCell(
                title: String(localized: "Size"),
                items: [String(localized: "Square"), String(localized: "Landscape"), String(localized: "Portrait"), String(localized: "Auto")],
                selectedIndex: selectedIndex,
                action: #selector(sizeChanged(_:))
            )
        }
    }

    private func configureAdvancedCell(at indexPath: IndexPath) -> UITableViewCell {
        guard let row = AdvancedRow(rawValue: indexPath.row) else {
            return UITableViewCell()
        }

        switch row {
        case .format:
            let selectedIndex: Int
            switch configurationManager.defaultOutputFormat {
            case "png": selectedIndex = 0
            case "jpeg", "jpg": selectedIndex = 1
            case "webp": selectedIndex = 2
            default: selectedIndex = 2
            }
            return segmentedCell(
                title: String(localized: "Format"),
                items: ["PNG", "JPEG", "WebP"],
                selectedIndex: selectedIndex,
                action: #selector(formatChanged(_:))
            )

        case .compression:
            let isAvailable = configurationManager.defaultOutputFormat != "png"
            let cell = contentCell { content in
                content.text = String(localized: "Compression Level")
                content.secondaryText = String(localized: "\(configurationManager.defaultCompression)%")
                if !isAvailable {
                    content.textProperties.color = .secondaryLabel
                    content.secondaryTextProperties.color = .secondaryLabel
                }
            }
            if isAvailable {
                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .default
                cell.accessibilityTraits.insert(.button)
            } else {
                cell.selectionStyle = .none
                cell.accessibilityTraits.insert(.notEnabled)
                cell.accessibilityHint = String(localized: "Compression isn't available for PNG")
            }
            return cell

        case .background:
            let selectedIndex: Int
            switch configurationManager.defaultBackground {
            case "auto": selectedIndex = 0
            case "transparent": selectedIndex = 1
            case "opaque": selectedIndex = 2
            case "none": selectedIndex = 3
            default: selectedIndex = 0
            }
            return segmentedCell(
                title: String(localized: "Background"),
                items: [String(localized: "Auto"), String(localized: "Transparent"), String(localized: "Opaque"), String(localized: "None")],
                selectedIndex: selectedIndex,
                action: #selector(backgroundChanged(_:))
            )

        case .moderation:
            let selectedIndex: Int
            switch configurationManager.defaultModeration {
            case "default": selectedIndex = 0
            case "auto": selectedIndex = 1
            case "low": selectedIndex = 2
            default: selectedIndex = 1
            }
            return segmentedCell(
                title: String(localized: "Moderation"),
                items: [String(localized: "Default"), String(localized: "Auto"), String(localized: "Low")],
                selectedIndex: selectedIndex,
                action: #selector(moderationChanged(_:))
            )
        }
    }

    private func configureStorageCell(at indexPath: IndexPath) -> UITableViewCell {
        guard let row = StorageRow(rawValue: indexPath.row) else {
            return UITableViewCell()
        }

        switch row {
        case .cache:
            let cell = contentCell { content in
                content.text = String(localized: "Image Cache")
                content.secondaryText = cacheSize
            }
            cell.selectionStyle = .none
            return cell
        }
    }

    private func configureAPICell(at indexPath: IndexPath) -> UITableViewCell {
        guard let row = APIRow(rawValue: indexPath.row) else {
            return UITableViewCell()
        }

        switch row {
        case .connection:
            var accessory: UIView?
            var detail = String(localized: "Test connection to Pixie servers")

            switch connectionStatus {
            case .idle:
                break
            case .testing:
                let spinner = UIActivityIndicatorView(style: .medium)
                spinner.startAnimating()
                accessory = spinner
            case .success:
                let checkmark = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
                checkmark.tintColor = .systemGreen
                accessory = checkmark
                detail = String(localized: "Connected successfully")
            case .error(let message):
                let warning = UIImageView(image: UIImage(systemName: "exclamationmark.triangle.fill"))
                warning.tintColor = .systemRed
                accessory = warning
                detail = message
            }

            let cell = contentCell(subtitle: true) { content in
                content.text = String(localized: "API Connection")
                content.secondaryText = detail
            }
            cell.accessoryView = accessory
            cell.accessibilityTraits.insert(.button)
            return cell
        }
    }

    private func configureAdminCell(at indexPath: IndexPath) -> UITableViewCell {
        guard let row = AdminRow(rawValue: indexPath.row) else {
            return UITableViewCell()
        }

        switch row {
        case .dashboard:
            let cell = contentCell { content in
                content.text = String(localized: "Admin Dashboard")
            }
            cell.accessoryType = .disclosureIndicator
            cell.accessibilityTraits.insert(.button)
            return cell
        }
    }

    private func configureHelpCell(at indexPath: IndexPath) -> UITableViewCell {
        guard let row = HelpRow(rawValue: indexPath.row) else {
            return UITableViewCell()
        }

        switch row {
        case .documentation:
            let cell = contentCell { content in
                content.text = String(localized: "Help Documentation")
                content.secondaryText = String(localized: "Learn how to use Pixie")
            }
            cell.accessoryType = .disclosureIndicator
            cell.accessibilityTraits.insert(.button)
            return cell
        case .cloudAIConsent:
            let cell = contentCell { content in
                content.text = String(localized: "Cloud AI Consent")
                content.secondaryText = CloudAIConsent.isGranted ? String(localized: "Granted") : String(localized: "Not granted")
            }
            cell.accessoryType = .disclosureIndicator
            cell.accessibilityTraits.insert(.button)
            return cell
        case .moreApps:
            let cell = contentCell { content in
                content.text = String(localized: "More Apps")
                content.secondaryText = String(localized: "Other apps by this developer")
            }
            cell.accessoryType = .disclosureIndicator
            cell.accessibilityTraits.insert(.button)
            return cell
        case .about:
            let cell = contentCell { content in
                content.text = String(localized: "About")
                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                   let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                    content.secondaryText = String(localized: "Version \(version) (\(build))")
                }
            }
            cell.selectionStyle = .none
            return cell
        }
    }

    private func configureAccountCell(at indexPath: IndexPath) -> UITableViewCell {
        guard let row = AccountRow(rawValue: indexPath.row) else {
            return UITableViewCell()
        }

        switch row {
        case .userId:
            if authenticationManager.isAnonymous {
                let cell = contentCell { content in
                    content.text = String(localized: "Sign in with Apple")
                    content.secondaryText = String(localized: "Sync & keep your credits")
                }
                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .default
                cell.accessibilityTraits.insert(.button)
                return cell
            }
            let cell = contentCell { content in
                content.text = String(localized: "User ID")
                content.secondaryText = authenticationManager.currentUser?.id ?? String(localized: "Not logged in")
            }
            cell.selectionStyle = .none
            return cell
        case .logout:
            let cell = contentCell { content in
                content.text = String(localized: "Log Out")
                content.textProperties.color = .systemRed
                content.secondaryText = String(localized: "Sign out of your account")
            }
            cell.accessibilityTraits.insert(.button)
            return cell
        case .deleteAccount:
            let cell = contentCell { content in
                content.text = String(localized: "Delete Account")
                content.textProperties.color = .systemRed
                content.image = UIImage(systemName: "trash")
                content.imageProperties.tintColor = .systemRed
            }
            cell.accessibilityTraits.insert(.button)
            if isDeletingAccount {
                let spinner = UIActivityIndicatorView(style: .medium)
                spinner.startAnimating()
                cell.accessoryView = spinner
                cell.selectionStyle = .none
                cell.contentView.alpha = 0.5
                cell.accessibilityTraits.insert(.notEnabled)
            }
            return cell
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
        case .appearance, .imageDefaults, .storage:
            break
        case .advanced:
            handleAdvancedSelection(at: indexPath)
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

        switch visibleSections[section] {
        case .storage:
            let footer = tableView.dequeueReusableHeaderFooterView(withIdentifier: ClearCacheFooterView.reuseIdentifier) as? ClearCacheFooterView
            footer?.onTap = { [weak self] in
                self?.clearCacheTapped()
            }
            return footer
        case .advanced:
            let footer = tableView.dequeueReusableHeaderFooterView(withIdentifier: SettingsTextFooterView.reuseIdentifier) as? SettingsTextFooterView
            footer?.text = advancedFooterText
            return footer
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let visibleSections = Section.allCases.filter { $0.isVisible }
        guard section < visibleSections.count else { return 0 }

        switch visibleSections[section] {
        case .storage, .advanced:
            return UITableView.automaticDimension
        default:
            return 0
        }
    }

    private func handleAdvancedSelection(at indexPath: IndexPath) {
        guard let row = AdvancedRow(rawValue: indexPath.row) else { return }

        switch row {
        case .format, .background, .moderation:
            break
        case .compression:
            if configurationManager.defaultOutputFormat != "png" {
                presentCompressionSelector()
            }
        }
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
        case .cloudAIConsent:
            presentCloudAIConsentOptions(at: indexPath)
        case .moreApps:
            Midgar.present(from: self)
        case .about:
            break
        }
    }

    private func presentCloudAIConsentOptions(at indexPath: IndexPath) {
        let granted = CloudAIConsent.isGranted
        let alert = UIAlertController(
            title: String(localized: "Cloud AI Consent"),
            message: String(localized: "Pixie sends your prompts and attached photos to Google Gemini and OpenAI to create images. Withdrawing consent pauses image generation until you grant it again."),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: String(localized: "Cancel"), style: .cancel))
        if granted {
            alert.addAction(UIAlertAction(title: String(localized: "Withdraw Consent"), style: .destructive) { [weak self] _ in
                CloudAIConsent.withdraw()
                self?.tableView.reloadRows(at: [indexPath], with: .automatic)
            })
        } else {
            alert.addAction(UIAlertAction(title: String(localized: "Grant Consent"), style: .default) { [weak self] _ in
                CloudAIConsent.grant()
                self?.tableView.reloadRows(at: [indexPath], with: .automatic)
            })
        }
        present(alert, animated: true)
    }

    private func handleAccountSelection(at indexPath: IndexPath) {
        guard let row = AccountRow(rawValue: indexPath.row) else { return }

        switch row {
        case .userId:
            if authenticationManager.isAnonymous { startAppleLink() }
        case .logout:
            handleLogout()
        case .deleteAccount:
            handleDeleteAccount()
        }
    }

    private func startAppleLink() {
        haptics.impact(.click)
        AppleLinkCoordinator.shared.start(from: self) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.haptics.notification(.success)
                self.tableView.reloadData()
            case .failure(let error):
                if (error as NSError).code == ASAuthorizationError.canceled.rawValue { return }
                self.presentAppleLinkError(error)
            }
        }
    }

    private func presentAppleLinkError(_ error: Error) {
        let alert = UIAlertController(
            title: String(localized: "Sign in failed"),
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: String(localized: "OK"), style: .default))
        present(alert, animated: true)
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
    }

    @objc private func modelChanged(_ sender: UISegmentedControl) {
        haptics.impact(.click)
        let index = sender.selectedSegmentIndex
        guard Self.selectableModels.indices.contains(index) else { return }
        configurationManager.defaultModel = Self.selectableModels[index].value
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

        if let compressionPath = indexPathForRow(AdvancedRow.compression, inSection: .advanced) {
            tableView.reloadRows(at: [compressionPath], with: .fade)
        }
        refreshAdvancedFooter()
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
            title: String(localized: "Clear Cache"),
            message: String(localized: "This will delete all cached images. Are you sure?"),
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: String(localized: "Cancel"), style: .cancel) { _ in
            self.haptics.impact(.click)
        })

        alert.addAction(UIAlertAction(title: String(localized: "Clear"), style: .destructive) { _ in
            self.haptics.impact(.success)
            Task {
                await MainActor.run {
                    self.cacheSize = String(localized: "Clearing...")
                    if let indexPath = self.indexPathForRow(StorageRow.cache, inSection: .storage) {
                        self.tableView.reloadRows(at: [indexPath], with: .none)
                    }
                }

                await self.cacheManager.clearCache()

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
                    Announce.say(String(localized: "Connected successfully"))

                    if let indexPath = self.indexPathForRow(APIRow.connection, inSection: .api) {
                        self.tableView.reloadRows(at: [indexPath], with: .fade)
                    }

                    self.resetConnectionStatus(after: 3_000_000_000)
                }
            } catch {
                await MainActor.run {
                    self.connectionStatus = .error(error.localizedDescription)
                    self.isTestingConnection = false
                    self.haptics.impact(.error)
                    Announce.say(error.localizedDescription)

                    if let indexPath = self.indexPathForRow(APIRow.connection, inSection: .api) {
                        self.tableView.reloadRows(at: [indexPath], with: .fade)
                    }

                    self.resetConnectionStatus(after: 5_000_000_000)
                }
            }
        }
    }

    private func resetConnectionStatus(after nanoseconds: UInt64) {
        Task { [self] in
            try? await Task.sleep(nanoseconds: nanoseconds)
            connectionStatus = .idle
            if let indexPath = indexPathForRow(APIRow.connection, inSection: .api) {
                tableView.reloadRows(at: [indexPath], with: .fade)
            }
        }
    }

    private func presentHelpDocumentation() {
        let helpVC = HelpViewController()
        navigationController?.pushViewController(helpVC, animated: true)
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
        case .system: return String(localized: "System")
        case .light: return String(localized: "Light")
        case .dark: return String(localized: "Dark")
        }
    }
}

private final class ClearCacheFooterView: UITableViewHeaderFooterView {
    static let reuseIdentifier = "ClearCacheFooterView"

    var onTap: (() -> Void)?

    private let button = UIButton(type: .system)

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        configureButton()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureButton() {
        var config = UIButton.Configuration.plain()
        config.title = String(localized: "Clear Cache")
        config.baseForegroundColor = .systemRed
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.scaled(.body, size: 17, weight: .medium)
            return outgoing
        }
        button.configuration = config
        button.addAction(UIAction { [weak self] _ in
            self?.onTap?()
        }, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(button)

        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            button.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            button.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            button.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.layoutMarginsGuide.leadingAnchor),
            button.trailingAnchor.constraint(lessThanOrEqualTo: contentView.layoutMarginsGuide.trailingAnchor),
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }
}

private final class SettingsTextFooterView: UITableViewHeaderFooterView {
    static let reuseIdentifier = "SettingsTextFooterView"

    var text: String? {
        didSet {
            var content = UIListContentConfiguration.groupedFooter()
            content.text = text
            contentConfiguration = content
        }
    }
}

private final class AccountDeletionProgressView: UIView {
    private let card = UIView()
    private let spinner = UIActivityIndicatorView(style: .large)
    private let messageLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func install(in host: UIView) {
        translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(self)
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: host.topAnchor),
            leadingAnchor.constraint(equalTo: host.leadingAnchor),
            trailingAnchor.constraint(equalTo: host.trailingAnchor),
            bottomAnchor.constraint(equalTo: host.bottomAnchor)
        ])
        alpha = 0
        spinner.startAnimating()
        Motion.animate(0.2) { self.alpha = 1 }
        Announce.screenChanged(messageLabel)
    }

    func remove() {
        spinner.stopAnimating()
        Motion.animate(0.2, animations: { self.alpha = 0 }, completion: { _ in
            self.removeFromSuperview()
        })
    }

    private func configureViews() {
        backgroundColor = UIColor.black.withAlphaComponent(0.4)
        accessibilityViewIsModal = true

        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 16
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)

        spinner.hideFromAccessibility()

        messageLabel.text = String(localized: "Deleting your account…")
        messageLabel.useScaledFont(.body, size: 17, weight: .medium)
        messageLabel.textColor = .label
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.isAccessibilityElement = true
        messageLabel.accessibilityTraits = [.staticText, .updatesFrequently]

        let stack = UIStackView(arrangedSubviews: [spinner, messageLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: centerXAnchor),
            card.centerYAnchor.constraint(equalTo: centerYAnchor),
            card.widthAnchor.constraint(lessThanOrEqualToConstant: 320),
            card.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            card.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),

            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24)
        ])
    }
}
