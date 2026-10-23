import AuthenticationServices
import MidgarKit
import UIKit

class SettingsViewController: UIViewController {
    private static let selectableModels: [ImageModel] = [.gemini, .geminiPro, .openai]
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
    private var isAdvancedExpanded = false
    private var builtSignature = ""
    private var lastCompressionHaptic = -1

    private var appearanceStack: UIStackView?
    private var appearanceTiles: [AppTheme: SettingsAppearanceTile] = [:]
    private var modelCards: [ImageModel: SettingsOptionCard] = [:]
    private var qualityGroup: SettingsChipGroup?
    private var sizeGroup: SettingsChipGroup?
    private var formatGroup: SettingsChipGroup?
    private var backgroundGroup: SettingsChipGroup?
    private var moderationGroup: SettingsChipGroup?
    private var compressionSlider: PercentSlider?
    private var compressionValueLabel: UILabel?
    private var compressionNote: UILabel?
    private var advancedRow: SettingsRowView?
    private var advancedBody: UIView?
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
        column.stack.addArrangedSubview(makeAdvancedSection())
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

    private func labelledGroup(_ title: String, _ group: SettingsChipGroup) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: [subheading(title), group])
        stack.axis = .vertical
        stack.spacing = Theme.Space.sm
        return stack
    }

    private func inset(_ stack: UIStackView, in card: SurfaceView, padding: CGFloat = Theme.Space.lg) {
        card.contentView.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.pinEdges(to: card.contentView, insets: UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding))
    }

    private func makeMidgarEntry() -> UIView {
        let entry = MidgarEntryView()
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
            detail = String(localized: "Your images and credits are only on this device")
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

        let quality = SettingsChipGroup(options: Self.qualityOptions, selected: nil, label: String(localized: "Quality"))
        quality.onSelect = { [weak self] id in self?.configurationManager.defaultQuality = id }
        qualityGroup = quality
        let size = SettingsChipGroup(options: Self.sizeOptions, selected: nil, label: String(localized: "Size"))
        size.onSelect = { [weak self] id in self?.configurationManager.defaultSize = id }
        sizeGroup = size

        let optionsStack = UIStackView(arrangedSubviews: [labelledGroup(String(localized: "Quality"), quality), labelledGroup(String(localized: "Size"), size)])
        optionsStack.axis = .vertical
        optionsStack.spacing = Theme.Space.lg
        let optionsCard = SurfaceView(style: .card)
        inset(optionsStack, in: optionsCard)

        let hint = SettingsLayout.footnote(String(localized: "Quality, size and the advanced options apply to GPT Image. Higher quality costs more credits."))

        return SettingsLayout.section(
            title: String(localized: "Defaults"),
            content: [subheading(String(localized: "Model")), cardStack, optionsCard, hint]
        )
    }

    private func makeAdvancedSection() -> UIView {
        let header = SettingsRowView(title: String(localized: "Advanced"), symbol: "slider.horizontal.3", showsChevron: true)
        header.onTap = { [weak self] in self?.toggleAdvanced() }
        header.setExpanded(isAdvancedExpanded)
        advancedRow = header

        let format = SettingsChipGroup(options: Self.formatOptions, selected: nil, label: String(localized: "Format"))
        format.onSelect = { [weak self] id in self?.configurationManager.defaultOutputFormat = id }
        formatGroup = format
        let background = SettingsChipGroup(options: Self.backgroundOptions, selected: nil, label: String(localized: "Background"))
        background.onSelect = { [weak self] id in self?.configurationManager.defaultBackground = id }
        backgroundGroup = background
        let moderation = SettingsChipGroup(options: Self.moderationOptions, selected: nil, label: String(localized: "Moderation"))
        moderation.onSelect = { [weak self] id in self?.configurationManager.defaultModeration = id }
        moderationGroup = moderation

        let compressionTitle = UILabel()
        compressionTitle.apply(.subhead, color: Theme.Color.ink)
        compressionTitle.text = String(localized: "Compression Level")
        compressionTitle.hideFromAccessibility()
        let valueLabel = UILabel()
        valueLabel.apply(.numeral(17))
        valueLabel.textColor = Theme.Color.inkSecondary
        valueLabel.numberOfLines = 1
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
        valueLabel.hideFromAccessibility()
        compressionValueLabel = valueLabel
        let compressionHeader = UIStackView(arrangedSubviews: [compressionTitle, valueLabel])
        compressionHeader.axis = .horizontal
        compressionHeader.alignment = .firstBaseline
        compressionHeader.spacing = Theme.Space.sm

        let slider = PercentSlider()
        slider.minimumValue = 0
        slider.maximumValue = 100
        slider.accessibilityLabel = String(localized: "Compression Level")
        slider.addTarget(self, action: #selector(compressionChanged(_:)), for: .valueChanged)
        slider.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        compressionSlider = slider

        let note = SettingsLayout.footnote("")
        compressionNote = note

        let compression = UIStackView(arrangedSubviews: [compressionHeader, slider, note])
        compression.axis = .vertical
        compression.spacing = Theme.Space.sm

        let groups = UIStackView(arrangedSubviews: [
            labelledGroup(String(localized: "Format"), format),
            compression,
            labelledGroup(String(localized: "Background"), background),
            labelledGroup(String(localized: "Moderation"), moderation),
        ])
        groups.axis = .vertical
        groups.spacing = Theme.Space.xl
        groups.isLayoutMarginsRelativeArrangement = true
        groups.layoutMargins = UIEdgeInsets(top: Theme.Space.lg, left: Theme.Space.lg, bottom: Theme.Space.lg, right: Theme.Space.lg)

        let body = UIStackView(arrangedSubviews: [RowDivider(inset: 0), groups])
        body.axis = .vertical
        body.isHidden = !isAdvancedExpanded
        advancedBody = body

        let stack = UIStackView(arrangedSubviews: [header, body])
        stack.axis = .vertical
        let card = SurfaceView(style: .card)
        card.contentView.addSubview(stack)
        stack.pinEdges(to: card.contentView)
        refreshAdvancedAccessibility()
        return card
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

        var rows: [UIView] = [help, contact]
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            rows.append(ListRowView(title: String(localized: "Version"), value: "\(version) (\(build))", symbol: "info.circle.fill"))
        }
        return SettingsLayout.section(title: String(localized: "Support"), content: [SettingsLayout.card(rows: rows)])
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

    private static var qualityOptions: [SettingsChipGroup.Option] {
        [
            .init(id: "low", title: String(localized: "Low"), symbol: nil),
            .init(id: "medium", title: String(localized: "Medium"), symbol: nil),
            .init(id: "high", title: String(localized: "High"), symbol: nil),
            .init(id: "auto", title: String(localized: "Auto"), symbol: nil),
        ]
    }

    private static var sizeOptions: [SettingsChipGroup.Option] {
        [
            .init(id: "1024x1024", title: String(localized: "Square"), symbol: "square"),
            .init(id: "1792x1024", title: String(localized: "Landscape"), symbol: "rectangle"),
            .init(id: "1024x1792", title: String(localized: "Portrait"), symbol: "rectangle.portrait"),
            .init(id: "auto", title: String(localized: "Auto"), symbol: "wand.and.stars"),
        ]
    }

    private static var formatOptions: [SettingsChipGroup.Option] {
        [
            .init(id: "png", title: "PNG", symbol: nil),
            .init(id: "jpeg", title: "JPEG", symbol: nil),
            .init(id: "webp", title: "WebP", symbol: nil),
        ]
    }

    private static var backgroundOptions: [SettingsChipGroup.Option] {
        [
            .init(id: "auto", title: String(localized: "Auto"), symbol: nil),
            .init(id: "transparent", title: String(localized: "Transparent"), symbol: nil),
            .init(id: "opaque", title: String(localized: "Opaque"), symbol: nil),
            .init(id: "none", title: String(localized: "None"), symbol: nil),
        ]
    }

    private static var moderationOptions: [SettingsChipGroup.Option] {
        [
            .init(id: "default", title: String(localized: "Default"), symbol: nil),
            .init(id: "auto", title: String(localized: "Auto"), symbol: nil),
            .init(id: "low", title: String(localized: "Low"), symbol: nil),
        ]
    }

    private func normalized(_ raw: String, allowed: [String], fallback: String) -> String {
        allowed.contains(raw) ? raw : fallback
    }

    private var normalizedSize: String {
        switch configurationManager.defaultSize {
        case "1024x1024", "square": return "1024x1024"
        case "1792x1024", "landscape": return "1792x1024"
        case "1024x1792", "portrait": return "1024x1792"
        default: return "auto"
        }
    }

    private var normalizedFormat: String {
        let raw = configurationManager.defaultOutputFormat
        return normalized(raw == "jpg" ? "jpeg" : raw, allowed: ["png", "jpeg", "webp"], fallback: "webp")
    }

    /// Brings every control in line with the stored configuration, leaving a slider alone while a finger is on it.
    private func refreshFromConfiguration() {
        for (theme, tile) in appearanceTiles {
            tile.isSelected = theme == configurationManager.theme
        }
        let model = ImageModel(rawValue: configurationManager.defaultModel).flatMap { Self.selectableModels.contains($0) ? $0 : nil } ?? .gemini
        for (candidate, card) in modelCards {
            card.isSelected = candidate == model
        }
        qualityGroup?.select(normalized(configurationManager.defaultQuality, allowed: ["low", "medium", "high", "auto"], fallback: "low"))
        sizeGroup?.select(normalizedSize)
        formatGroup?.select(normalizedFormat)
        backgroundGroup?.select(normalized(configurationManager.defaultBackground, allowed: ["auto", "transparent", "opaque", "none"], fallback: "auto"))
        moderationGroup?.select(normalized(configurationManager.defaultModeration, allowed: ["default", "auto", "low"], fallback: "auto"))
        refreshCompression()
    }

    private func refreshCompression() {
        let level = configurationManager.defaultCompression
        let isAvailable = configurationManager.defaultOutputFormat != "png"
        if let slider = compressionSlider {
            if !slider.isTracking { slider.value = Float(level) }
            slider.isEnabled = isAvailable
            slider.alpha = isAvailable ? 1 : 0.5
        }
        compressionValueLabel?.text = String(localized: "\(level)%")
        compressionValueLabel?.alpha = isAvailable ? 1 : 0.5
        compressionNote?.text = advancedFooterText
    }

    private var advancedFooterText: String {
        configurationManager.defaultOutputFormat == "png"
            ? String(localized: "Compression isn't available for PNG")
            : String(localized: "Compression applies to JPEG and WebP")
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

    @objc private func compressionChanged(_ sender: UISlider) {
        let value = Int(sender.value)
        if value % 5 == 0, value != lastCompressionHaptic {
            haptics.impact(.sliderTick)
            lastCompressionHaptic = value
        }
        configurationManager.defaultCompression = value
        compressionValueLabel?.text = String(localized: "\(value)%")
    }

    private func toggleAdvanced() {
        isAdvancedExpanded.toggle()
        haptics.impact(.click)
        Motion.spring(0.35, damping: 0.85) {
            self.advancedBody?.isHidden = !self.isAdvancedExpanded
            self.advancedRow?.setExpanded(self.isAdvancedExpanded)
            self.view.layoutIfNeeded()
        }
        refreshAdvancedAccessibility()
        Announce.say(isAdvancedExpanded ? String(localized: "Expanded") : String(localized: "Collapsed"))
    }

    private func refreshAdvancedAccessibility() {
        advancedRow?.accessibilityValue = isAdvancedExpanded ? String(localized: "Expanded") : String(localized: "Collapsed")
        advancedRow?.accessibilityTraits = .button
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
