import AuthenticationServices
import MidgarCore
import MidgarPortal
import MidgarUI
import UIKit

class SettingsViewController: UIViewController {
    private static let selectableModels: [ImageModel] = [.standard, .max]
    private static let cacheSizeTimeout: UInt64 = 10_000_000_000
    private static let supportURL = URL(string: "https://x.com/guitaripod")

    private let column = SettingsColumnView()
    private let authenticationManager = AuthenticationManager.shared
    private let configurationManager = ConfigurationManager.shared
    private let cacheManager = CacheManager.shared
    private let haptics = HapticManager.shared

    private var cacheSize: String = String(localized: "Calculating...")
    private var isCacheSizePending = true
    private var cacheSizeRequest = 0
    private var connectionStatus: ConnectionStatus = .idle
    private var isTestingConnection = false
    private var isDeletingAccount = false
    private var deletionOverlay: AccountDeletionProgressView?
    private var builtSignature = ""

    private var appearanceStack: UIStackView?
    private var appearanceTiles: [AppTheme: SettingsAppearanceTile] = [:]
    private var modelCards: [ImageModel: SettingsOptionCard] = [:]
    private var consentSwitch: UISwitch?
    private var consentRow: SettingsRowView?
    private var cacheRow: SettingsRowView?
    private var connectionRow: SettingsRowView?
    private var deleteRow: SettingsRowView?
    private var signInButton: PixieButton?

    private enum ConnectionStatus {
        case idle
        case testing
        case success
        case error(String)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = String(localized: "Settings")
        navigationItem.largeTitleDisplayMode = .always
        view.backgroundColor = Theme.Color.canvas

        column.install(in: view)
        setupNotifications()
        buildContent()
        loadCacheSize()

        preferredContentSize = CGSize(width: 600, height: 800)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = true
        if builtSignature != accountSignature {
            buildContent()
        } else {
            refreshFromConfiguration()
            refreshConsent()
        }
        loadCacheSize()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.navigationBar.prefersLargeTitles = false
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateAdaptiveAxes()
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
            self?.refreshFromConfiguration()
        }
    }

    private var isAnonymousAccount: Bool {
        authenticationManager.isAnonymous
    }

    private var isAdmin: Bool {
        authenticationManager.currentUser?.isAdmin == true
    }

    private var authProvider: AuthProvider? {
        guard let raw = try? AppContainer.shared.keychainManager.getString(forKey: KeychainKeys.authProvider) else { return nil }
        return AuthProvider(rawValue: raw)
    }

    private var accountSignature: String {
        [
            isAnonymousAccount ? "anonymous" : "account",
            authProvider?.rawValue ?? "-",
            authenticationManager.currentUser?.id ?? "-",
            isAdmin ? "admin" : "user",
        ].joined(separator: "|")
    }

    private func updateAdaptiveAxes() {
        let stacked = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        appearanceStack?.axis = stacked ? .vertical : .horizontal
        appearanceStack?.alignment = stacked ? .fill : .top
    }

    private func buildContent() {
        builtSignature = accountSignature
        column.removeAllContent()
        signInButton = nil

        column.stack.addArrangedSubview(makeMidgarEntry())
        column.stack.addArrangedSubview(makeAccountSection())
        column.stack.addArrangedSubview(makeAppearanceSection())
        column.stack.addArrangedSubview(makeDefaultsSection())
        column.stack.addArrangedSubview(makePrivacySection())
        column.stack.addArrangedSubview(makeSupportSection())
        if isAdmin {
            column.stack.addArrangedSubview(makeAdminSection())
        }
        column.stack.addArrangedSubview(makeDangerSection())

        refreshFromConfiguration()
        refreshConsent()
        updateAdaptiveAxes()
    }

    private func subheading(_ text: String) -> UILabel {
        let label = UILabel()
        label.apply(.subhead, color: Theme.Color.ink)
        label.text = text
        label.accessibilityTraits = .header
        return label
    }

    private func inset(_ stack: UIStackView, in card: SurfaceView, padding: CGFloat = Theme.Space.lg) {
        card.contentView.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.pinEdges(to: card.contentView, insets: UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding))
    }

    private func makeMidgarEntry() -> UIView {
        let entry = MidgarEntryView(config: PixieMidgar.shared.portalConfig)
        entry.heightAnchor.constraint(equalToConstant: MidgarEntryView.preferredHeight).isActive = true
        return entry
    }

    private func makeAccountSection() -> UIView {
        let isAnonymous = isAnonymousAccount
        let provider = authProvider

        let title: String
        let detail: String?
        let symbol: String
        if isAnonymous {
            title = String(localized: "Not signed in")
            detail = String(localized: "Your images and edits live in an anonymous account")
            symbol = "person.crop.circle.badge.questionmark"
        } else if let provider {
            title = String(localized: "Signed in with \(provider.displayName)")
            detail = nil
            symbol = Self.symbol(for: provider)
        } else {
            title = String(localized: "Signed in")
            detail = nil
            symbol = "person.crop.circle.fill"
        }

        let badge = IconBadge(symbol: symbol, size: 52)
        let titleLabel = UILabel()
        titleLabel.apply(.title2)
        titleLabel.text = title
        titleLabel.accessibilityTraits = .header
        let textStack = UIStackView(arrangedSubviews: [titleLabel])
        textStack.axis = .vertical
        textStack.spacing = Theme.Space.xs
        if let detail {
            let detailLabel = UILabel()
            detailLabel.apply(.callout)
            detailLabel.text = detail
            textStack.addArrangedSubview(detailLabel)
        }
        let header = UIStackView(arrangedSubviews: [badge, textStack])
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = Theme.Space.lg

        let content = UIStackView(arrangedSubviews: [header])
        content.axis = .vertical
        content.spacing = Theme.Space.lg

        if isAnonymous {
            let button = PixieButton(style: .primary, size: .large, title: String(localized: "Sign in to back up"), symbol: "apple.logo") { [weak self] in
                self?.startAppleLink()
            }
            signInButton = button
            content.addArrangedSubview(button)
        } else if let id = authenticationManager.currentUser?.id {
            content.addArrangedSubview(SettingsCopyableIDView(title: String(localized: "User ID"), value: id))
        }

        let card = SurfaceView(style: .card, cornerRadius: Theme.Radius.xl)
        inset(content, in: card, padding: Theme.Space.xl)
        return SettingsLayout.section(title: String(localized: "Account"), content: [card])
    }

    private static func symbol(for provider: AuthProvider) -> String {
        switch provider {
        case .apple: return "apple.logo"
        case .google: return "g.circle.fill"
        case .github: return "chevron.left.forwardslash.chevron.right"
        }
    }

    private func makeAppearanceSection() -> UIView {
        let entries: [(AppTheme, String, UIUserInterfaceStyle?)] = [
            (.system, String(localized: "System"), nil),
            (.light, String(localized: "Light"), .light),
            (.dark, String(localized: "Dark"), .dark),
        ]
        appearanceTiles = [:]
        var tiles: [UIView] = []
        for (theme, name, style) in entries {
            let tile = SettingsAppearanceTile(title: name, style: style)
            tile.onTap = { [weak self] in self?.select(theme: theme) }
            appearanceTiles[theme] = tile
            tiles.append(tile)
        }
        let stack = UIStackView(arrangedSubviews: tiles)
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .top
        stack.spacing = Theme.Space.md
        stack.accessibilityContainerType = .semanticGroup
        stack.accessibilityLabel = String(localized: "Theme")
        appearanceStack = stack
        return SettingsLayout.section(title: String(localized: "Appearance"), content: [stack])
    }

    private func makeDefaultsSection() -> UIView {
        modelCards = [:]
        let cards = Self.selectableModels.map { model -> SettingsOptionCard in
            let card = SettingsOptionCard(title: model.displayName, detail: model.description)
            card.onTap = { [weak self] in self?.select(model: model) }
            modelCards[model] = card
            return card
        }
        let cardStack = UIStackView(arrangedSubviews: cards)
        cardStack.axis = .vertical
        cardStack.spacing = Theme.Space.sm
        cardStack.accessibilityContainerType = .semanticGroup
        cardStack.accessibilityLabel = String(localized: "Model")

        let hint = SettingsLayout.footnote(String(localized: "Standard costs one edit, Max costs five. You can switch for any single edit in the composer."))

        return SettingsLayout.section(
            title: String(localized: "Defaults"),
            content: [subheading(String(localized: "Model")), cardStack, hint]
        )
    }

    private func makePrivacySection() -> UIView {
        let consentSwitch = UISwitch()
        consentSwitch.accessibilityLabel = String(localized: "Cloud AI Consent")
        consentSwitch.accessibilityHint = CloudAIConsent.disclosure
        consentSwitch.addAction(UIAction { [weak self] _ in self?.presentCloudAIConsentOptions() }, for: .valueChanged)
        self.consentSwitch = consentSwitch

        let consent = SettingsRowView(title: String(localized: "Cloud AI Consent"), symbol: "cloud.fill")
        consent.setAccessory(consentSwitch)
        consent.isAccessibilityElement = false
        consent.onTap = { [weak self] in self?.presentCloudAIConsentOptions() }
        consentRow = consent

        let cache = SettingsRowView(title: String(localized: "Image Cache"), symbol: "internaldrive.fill", value: cacheSize)
        cacheRow = cache

        let clear = SettingsRowView(title: String(localized: "Clear Cache"), symbol: "trash.fill", colors: SettingsTint.solid(Theme.Color.danger), showsChevron: false)
        clear.accessibilityTraits = .button
        clear.onTap = { [weak self] in self?.clearCacheTapped() }

        let connection = SettingsRowView(title: String(localized: "API Connection"), subtitle: String(localized: "Test connection to Pixie servers"), symbol: "antenna.radiowaves.left.and.right")
        connection.accessibilityTraits = .button
        connection.onTap = { [weak self] in self?.testConnection() }
        connectionRow = connection
        applyConnectionStatus()

        let card = SettingsLayout.card(rows: [consent, cache, clear, connection])
        return SettingsLayout.section(title: String(localized: "Privacy & data"), content: [card, SettingsLayout.footnote(CloudAIConsent.disclosure)])
    }

    private func makeSupportSection() -> UIView {
        let help = ListRowView(title: String(localized: "Help"), subtitle: String(localized: "Learn how to use Pixie"), symbol: "questionmark.circle.fill", showsChevron: true)
        help.onTap = { [weak self] in self?.presentHelpDocumentation() }

        let contact = ListRowView(title: String(localized: "Contact"), subtitle: String(localized: "@guitaripod on X"), symbol: "bubble.left.fill", showsChevron: true)
        contact.onTap = { [weak self] in self?.openSupport() }

        let about = ListRowView(title: String(localized: "About"), value: MidgarVersionInfo().display, symbol: "info.circle.fill", showsChevron: true)
        about.onTap = { [weak self] in self?.presentAbout() }

        return SettingsLayout.section(title: String(localized: "Support"), content: [SettingsLayout.card(rows: [help, contact, about])])
    }

    private func makeAdminSection() -> UIView {
        let dashboard = ListRowView(title: String(localized: "Admin Dashboard"), symbol: "person.badge.shield.checkmark", showsChevron: true)
        dashboard.onTap = { [weak self] in self?.presentAdminDashboard() }
        return SettingsLayout.section(title: String(localized: "Admin"), content: [SettingsLayout.card(rows: [dashboard])])
    }

    private func makeDangerSection() -> UIView {
        var rows: [UIView] = []
        if !isAnonymousAccount {
            let logout = SettingsRowView(
                title: String(localized: "Log Out"),
                subtitle: String(localized: "Sign out of your account"),
                symbol: "rectangle.portrait.and.arrow.right",
                colors: SettingsTint.solid(Theme.Color.danger)
            )
            logout.accessibilityTraits = .button
            logout.onTap = { [weak self] in self?.handleLogout() }
            rows.append(logout)
        }
        let delete = SettingsRowView(
            title: String(localized: "Delete Account"),
            symbol: "trash.fill",
            colors: SettingsTint.solid(Theme.Color.danger),
            titleColor: Theme.Color.danger
        )
        delete.accessibilityTraits = .button
        delete.onTap = { [weak self] in self?.handleDeleteAccount() }
        delete.setBusy(isDeletingAccount)
        deleteRow = delete
        rows.append(delete)

        let card = SettingsLayout.card(rows: rows, style: .tinted(Theme.Color.danger.withAlphaComponent(0.10)))
        return SettingsLayout.section(title: String(localized: "Danger zone"), content: [card])
    }

    /// Brings every control in line with the stored configuration, leaving a slider alone while a finger is on it.
    private func refreshFromConfiguration() {
        for (theme, tile) in appearanceTiles {
            tile.isSelected = theme == configurationManager.theme
        }
        let model = ImageModel(storedValue: configurationManager.defaultModel)
        for (candidate, card) in modelCards {
            card.isSelected = candidate == model
        }
    }

    private func refreshConsent() {
        consentSwitch?.setOn(CloudAIConsent.isGranted, animated: false)
    }

    private func select(theme: AppTheme) {
        guard configurationManager.theme != theme else { return }
        configurationManager.theme = theme
        updateAppearance()
    }

    private func select(model: ImageModel) {
        configurationManager.defaultModel = model.value
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
        cacheRow?.setValue(text)
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
            message: String(localized: "Your edits, including any you bought, and every image you've made will be permanently deleted from our servers. Deleting the account does not cancel Plus: cancel it in the App Store first. This can't be undone."),
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
        deleteRow?.setBusy(deleting)
    }

    private func presentCloudAIConsentOptions() {
        let granted = CloudAIConsent.isGranted
        let alert = UIAlertController(
            title: String(localized: "Cloud AI Consent"),
            message: String(localized: "Pixie sends your prompts and attached photos to Google Gemini and OpenAI to create images. Withdrawing consent pauses image generation until you grant it again."),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: String(localized: "Cancel"), style: .cancel) { [weak self] _ in
            self?.refreshConsent()
        })
        if granted {
            alert.addAction(UIAlertAction(title: String(localized: "Withdraw Consent"), style: .destructive) { [weak self] _ in
                CloudAIConsent.withdraw()
                self?.refreshConsent()
            })
        } else {
            alert.addAction(UIAlertAction(title: String(localized: "Grant Consent"), style: .default) { [weak self] _ in
                CloudAIConsent.grant()
                self?.refreshConsent()
            })
        }
        present(alert, animated: true)
    }

    private func startAppleLink() {
        haptics.impact(.click)
        signInButton?.isLoading = true
        AppleLinkCoordinator.shared.start(from: self) { [weak self] result in
            guard let self else { return }
            self.signInButton?.isLoading = false
            switch result {
            case .success:
                self.haptics.notification(.success)
                self.buildContent()
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

    private func presentHelpDocumentation() {
        let helpVC = HelpViewController()
        navigationController?.pushViewController(helpVC, animated: true)
    }

    private func presentAbout() {
        navigationController?.pushViewController(AboutSettings.makeViewController(), animated: true)
    }

    private func openSupport() {
        guard let url = Self.supportURL else { return }
        UIApplication.shared.open(url)
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
                    self.cacheRow?.setValue(self.cacheSize)
                }

                await self.cacheManager.clearCache()

                self.loadCacheSize()
            }
        })

        present(alert, animated: true)
    }

    private func applyConnectionStatus() {
        guard let row = connectionRow else { return }
        switch connectionStatus {
        case .idle:
            row.setAccessory(nil)
            row.setSubtitle(String(localized: "Test connection to Pixie servers"))
        case .testing:
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.startAnimating()
            spinner.hideFromAccessibility()
            row.setAccessory(spinner)
            row.setSubtitle(String(localized: "Test connection to Pixie servers"))
        case .success:
            row.setAccessory(Self.statusIcon("checkmark.circle.fill", color: Theme.Color.success))
            row.setSubtitle(String(localized: "Connected successfully"))
        case .error(let message):
            row.setAccessory(Self.statusIcon("exclamationmark.triangle.fill", color: Theme.Color.danger))
            row.setSubtitle(message)
        }
    }

    private static func statusIcon(_ name: String, color: UIColor) -> UIImageView {
        let icon = UIImageView(image: UIImage(systemName: name))
        icon.tintColor = color
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .title3)
        icon.hideFromAccessibility()
        return icon
    }

    private func testConnection() {
        guard !isTestingConnection else { return }
        haptics.impact(.click)

        isTestingConnection = true
        connectionStatus = .testing
        applyConnectionStatus()

        Task {
            do {
                _ = try await AppContainer.shared.apiService.getCreditPacks()

                await MainActor.run {
                    self.connectionStatus = .success
                    self.isTestingConnection = false
                    self.haptics.impact(.success)
                    Announce.say(String(localized: "Connected successfully"))
                    self.applyConnectionStatus()
                    self.resetConnectionStatus(after: 3_000_000_000)
                }
            } catch {
                await MainActor.run {
                    self.connectionStatus = .error(error.localizedDescription)
                    self.isTestingConnection = false
                    self.haptics.impact(.error)
                    Announce.say(error.localizedDescription)
                    self.applyConnectionStatus()
                    self.resetConnectionStatus(after: 5_000_000_000)
                }
            }
        }
    }

    private func resetConnectionStatus(after nanoseconds: UInt64) {
        Task { [self] in
            try? await Task.sleep(nanoseconds: nanoseconds)
            connectionStatus = .idle
            applyConnectionStatus()
        }
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
}
