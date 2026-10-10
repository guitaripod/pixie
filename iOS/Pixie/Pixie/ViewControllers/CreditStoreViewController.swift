import UIKit
import Combine
import RevenueCat

struct StorePackDisplay {
    let id: String
    let name: String
    let baseCredits: Int
    let bonusCredits: Int
    let price: String
    let rcPackage: Package?

    var totalCredits: Int { baseCredits + bonusCredits }
    var bonusPercent: Int { baseCredits > 0 ? Int((Double(bonusCredits) / Double(baseCredits) * 100).rounded()) : 0 }
    var imageEstimate: Int { max(1, totalCredits / 21) }
}

final class CreditStoreViewController: UIViewController {
    static let defaultImageCreditCost = 21

    private let viewModel = CreditsViewModel()
    private let shortfall: Int?
    private let purchaseManager = CreditPurchaseManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var packs: [StorePackDisplay] = []
    private var selectedPackId = "popular"
    private var isPurchasing = false
    private var packsState = PacksState.loading
    private var packsTimeoutTask: Task<Void, Never>?

    private enum PacksState {
        case loading
        case failed
        case loaded
    }

    private static let packsLoadTimeout: UInt64 = 10_000_000_000
    private static let dismissDelay: TimeInterval = 1.1
    private static let voiceOverDismissDelay: TimeInterval = 2.5

    init(shortfall: Int? = nil) {
        self.shortfall = shortfall
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    static func present(from presenter: UIViewController, shortfall: Int? = nil) {
        let store = CreditStoreViewController(shortfall: shortfall)
        let navigation = UINavigationController(rootViewController: store)
        navigation.modalPresentationStyle = .pageSheet
        if let sheet = navigation.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        presenter.present(navigation, animated: true)
    }

    private lazy var scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.alwaysBounceVertical = true
        return scroll
    }()

    private lazy var contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var heroIconView: UIImageView = {
        let config = UIImage.SymbolConfiguration(textStyle: .largeTitle, scale: .large).applying(UIImage.SymbolConfiguration(weight: .semibold))
        let imageView = UIImageView(image: UIImage(systemName: "sparkles", withConfiguration: config))
        imageView.tintColor = .brandText
        imageView.contentMode = .scaleAspectFit
        imageView.hideFromAccessibility()
        return imageView
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = String(localized: "Pixie Credits")
        label.useScaledFont(.title1, size: 30, weight: .bold, rounded: true)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.accessibilityTraits = .header
        return label
    }()

    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = String(localized: "Pay for what you create.\nNo subscription — ever.")
        label.useScaledFont(.subheadline, size: 15)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var balanceLabel: UILabel = {
        let label = UILabel()
        label.useScaledFont(.footnote, size: 13)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var packsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        return stack
    }()

    private lazy var perksLabel: UILabel = {
        let label = UILabel()
        label.text = String(localized: "Credits never expire  ·  Every quality tier  ·  No account required")
        label.useScaledFont(.caption1, size: 12)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var packsStatusSpinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.hidesWhenStopped = true
        return spinner
    }()

    private lazy var packsStatusIcon: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "exclamationmark.triangle.fill"))
        imageView.tintColor = .systemOrange
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .title2)
        imageView.contentMode = .scaleAspectFit
        imageView.hideFromAccessibility()
        return imageView
    }()

    private lazy var packsStatusLabel: UILabel = {
        let label = UILabel()
        label.useScaledFont(.subheadline, size: 15, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var packsRetryButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = String(localized: "Retry")
        config.baseBackgroundColor = .brand
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 24, bottom: 10, trailing: 24)
        let button = UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in
            self?.retryPacks()
        })
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        return button
    }()

    private lazy var packsStatusCard: UIVisualEffectView = {
        let card = GlassMaterial.cardView(cornerRadius: 18)
        let stack = UIStackView(arrangedSubviews: [packsStatusSpinner, packsStatusIcon, packsStatusLabel, packsRetryButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -24),
        ])
        return card
    }()

    private lazy var ctaButton: UIButton = {
        var config = ctaConfiguration()
        config.title = String(localized: "Loading…")
        let button = UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in
            self?.purchaseSelectedPack()
        })
        button.isEnabled = false
        return button
    }()

    private lazy var footerStack: UIStackView = {
        let privacy = UIButton(configuration: plainFooterConfiguration(title: String(localized: "Privacy")), primaryAction: UIAction { [weak self] _ in
            self?.open(url: "https://mako.midgarcorp.cc/privacy/pixie")
        })
        let terms = UIButton(configuration: plainFooterConfiguration(title: String(localized: "Terms")), primaryAction: UIAction { [weak self] _ in
            self?.open(url: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
        })
        privacy.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        terms.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        let stack = UIStackView(arrangedSubviews: [privacy, terms])
        stack.axis = .horizontal
        stack.spacing = 18
        stack.distribution = .equalCentering
        return stack
    }()

    private lazy var bottomBar: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [ctaButton, footerStack])
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "clock.arrow.circlepath"),
            primaryAction: UIAction { [weak self] _ in
                self?.navigationController?.pushViewController(CreditsMainViewController(), animated: true)
            }
        )
        navigationItem.leftBarButtonItem?.accessibilityLabel = String(localized: "Credits & Usage")
        layoutUI()
        buildHeader()
        applyHeroMotion()
        NotificationCenter.default.addObserver(self, selector: #selector(reduceMotionChanged), name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
        #if DEBUG
        if DemoMode.isActive {
            applyDemoPacks()
            return
        }
        #endif
        bind()
        viewModel.refresh()
        loadPacks(retrying: false)
    }

    deinit {
        packsTimeoutTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func reduceMotionChanged() {
        applyHeroMotion()
    }

    /// Pulses the hero sparkles only while Reduce Motion is off.
    private func applyHeroMotion() {
        guard #available(iOS 18.0, *) else { return }
        heroIconView.removeAllSymbolEffects()
        if !Motion.isReduced {
            heroIconView.addSymbolEffect(.pulse, options: .repeat(.continuous))
        }
    }

    private func layoutUI() {
        view.addSubview(scrollView)
        view.addSubview(bottomBar)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -4),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40),

            bottomBar.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            bottomBar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            bottomBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            ctaButton.widthAnchor.constraint(equalTo: bottomBar.widthAnchor),
        ])
    }

    private func buildHeader() {
        let headerStack = UIStackView(arrangedSubviews: [heroIconView, titleLabel, subtitleLabel, balanceLabel])
        headerStack.axis = .vertical
        headerStack.spacing = 6
        headerStack.alignment = .center
        contentStack.addArrangedSubview(headerStack)
        contentStack.setCustomSpacing(18, after: headerStack)

        if let shortfall, shortfall > 0 {
            contentStack.addArrangedSubview(makeShortfallBanner(shortfall))
        }

        contentStack.addArrangedSubview(packsStatusCard)
        contentStack.addArrangedSubview(packsStack)
        contentStack.addArrangedSubview(perksLabel)
        applyPacksState()
    }

    private func makeShortfallBanner(_ shortfall: Int) -> UIView {
        let card = GlassMaterial.cardView(cornerRadius: 16)
        let icon = UIImageView(image: UIImage(systemName: "exclamationmark.circle.fill"))
        icon.tintColor = .systemOrange
        icon.setContentHuggingPriority(.required, for: .horizontal)
        icon.hideFromAccessibility()
        let label = UILabel()
        label.text = String(localized: "You need \(shortfall) more credits to finish this image.")
        label.useScaledFont(.footnote, size: 13)
        label.numberOfLines = 0
        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.axis = .horizontal
        stack.spacing = 10
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -12),
        ])
        card.describe(label.text ?? "", traits: .staticText)
        return card
    }

    private func bind() {
        viewModel.$balance
            .receive(on: DispatchQueue.main)
            .sink { [weak self] balance in
                guard let balance else { return }
                self?.balanceLabel.text = String(localized: "Current balance: \(balance.balance) credits")
            }
            .store(in: &cancellables)

        purchaseManager.getCreditPacksWithPricing()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] packsWithPricing in
                guard !packsWithPricing.isEmpty else { return }
                self?.packsTimeoutTask?.cancel()
                self?.packs = packsWithPricing.map {
                    StorePackDisplay(
                        id: $0.creditPack.id,
                        name: $0.creditPack.name,
                        baseCredits: $0.creditPack.credits,
                        bonusCredits: $0.creditPack.bonusCredits,
                        price: $0.localizedPrice,
                        rcPackage: $0.rcPackage
                    )
                }
                self?.reloadPacks()
            }
            .store(in: &cancellables)
    }

    private func loadPacks(retrying: Bool) {
        packsState = .loading
        applyPacksState()
        packsTimeoutTask?.cancel()
        packsTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.packsLoadTimeout)
            guard !Task.isCancelled else { return }
            self?.failPacksIfStillEmpty()
        }
        Task {
            await purchaseManager.fetchCreditPacks()
            if purchaseManager.creditPacks.isEmpty {
                failPacksIfStillEmpty()
            } else if retrying, purchaseManager.offerings == nil {
                RevenueCatManager.shared.fetchOfferings()
            }
        }
    }

    private func failPacksIfStillEmpty() {
        guard packs.isEmpty, packsState != .failed else { return }
        packsTimeoutTask?.cancel()
        packsState = .failed
        applyPacksState()
        HapticsManager.shared.notification(.error)
        Announce.say(String(localized: "Couldn't load credit packs"))
    }

    private func retryPacks() {
        HapticsManager.shared.selection()
        loadPacks(retrying: true)
    }

    /// Shows the spinner while packs load, the error card with Retry when they cannot, and the pack list and purchase button once loaded.
    private func applyPacksState() {
        let isLoading = packsState == .loading
        let isFailed = packsState == .failed
        packsStatusCard.isHidden = packsState == .loaded
        packsStack.isHidden = packsState != .loaded
        ctaButton.isHidden = isFailed
        packsStatusIcon.isHidden = !isFailed
        packsRetryButton.isHidden = !isFailed
        packsStatusLabel.text = isFailed ? String(localized: "Couldn't load credit packs") : String(localized: "Loading…")
        if isLoading {
            packsStatusSpinner.startAnimating()
        } else {
            packsStatusSpinner.stopAnimating()
        }
    }

    private func reloadPacks() {
        packsState = .loaded
        applyPacksState()
        packsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if packs.first(where: { $0.id == selectedPackId }) == nil {
            selectedPackId = packs.first?.id ?? selectedPackId
        }
        for pack in packs {
            let card = PackCardView(pack: pack, badge: badge(for: pack.id))
            card.isSelectedPack = pack.id == selectedPackId
            card.onTap = { [weak self] in self?.select(packId: pack.id) }
            packsStack.addArrangedSubview(card)
        }
        updateCTA()
    }

    private func badge(for packId: String) -> String? {
        switch packId {
        case "popular": return String(localized: "MOST POPULAR")
        case "enterprise": return String(localized: "BEST VALUE")
        default: return nil
        }
    }

    private func select(packId: String) {
        guard !isPurchasing else { return }
        HapticsManager.shared.selection()
        selectedPackId = packId
        for case let card as PackCardView in packsStack.arrangedSubviews {
            card.isSelectedPack = card.packId == packId
            if card.packId == packId, UIAccessibility.isVoiceOverRunning {
                Announce.layoutChanged(card)
            }
        }
        updateCTA()
    }

    private func updateCTA() {
        guard let pack = packs.first(where: { $0.id == selectedPackId }) else { return }
        var config = ctaButton.configuration ?? ctaConfiguration()
        config.title = String(localized: "Get \(formatted(pack.totalCredits)) credits · \(pack.price)")
        config.subtitle = String(localized: "One-time purchase · ≈ \(pack.imageEstimate) images")
        ctaButton.configuration = config
        ctaButton.isEnabled = true
    }

    private func ctaConfiguration() -> UIButton.Configuration {
        var config: UIButton.Configuration
        if #available(iOS 26.0, *) {
            config = .prominentGlass()
        } else {
            config = .borderedProminent()
        }
        config.baseBackgroundColor = .brand
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.buttonSize = .large
        config.titleAlignment = .center
        return config
    }

    private func plainFooterConfiguration(title: String) -> UIButton.Configuration {
        var config = UIButton.Configuration.plain()
        config.title = title
        config.baseForegroundColor = .secondaryLabel
        config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)
        var container = AttributeContainer()
        container.font = UIFont.scaled(.caption1, size: 12)
        config.attributedTitle = AttributedString(title, attributes: container)
        return config
    }

    private func formatted(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func purchaseSelectedPack() {
        guard let pack = packs.first(where: { $0.id == selectedPackId }), let package = pack.rcPackage, !isPurchasing else { return }
        HapticsManager.shared.impact(.medium)
        isPurchasing = true
        ctaButton.configuration?.showsActivityIndicator = true
        ctaButton.isEnabled = false
        Announce.say(String(localized: "Processing purchase"))

        Task {
            let result = await purchaseManager.purchaseCreditPack(package: package)
            await MainActor.run {
                self.isPurchasing = false
                self.ctaButton.configuration?.showsActivityIndicator = false
                switch result {
                case .success(let purchase):
                    HapticsManager.shared.notification(.success)
                    Announce.say(String(localized: "\(self.formatted(purchase.credits)) credits added"))
                    self.ctaButton.configuration?.title = String(localized: "Added \(self.formatted(purchase.credits)) credits")
                    self.ctaButton.configuration?.subtitle = String(localized: "New balance: \(self.formatted(purchase.newBalance))")
                    Task { await self.viewModel.loadBalance() }
                    self.dismissAfterPurchase()
                case .failure(let error):
                    self.updateCTA()
                    if error is PurchaseCancelledException { return }
                    HapticsManager.shared.notification(.error)
                    let alert = UIAlertController(title: String(localized: "Purchase Failed"), message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: String(localized: "OK"), style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }

    /// Closes the store shortly after a purchase, leaving VoiceOver time to read the confirmation first.
    private func dismissAfterPurchase() {
        let delay = UIAccessibility.isVoiceOverRunning ? Self.voiceOverDismissDelay : Self.dismissDelay
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.dismiss(animated: true)
        }
    }

    private func open(url: String) {
        guard let url = URL(string: url) else { return }
        UIApplication.shared.open(url)
    }

    #if DEBUG
    private func applyDemoPacks() {
        balanceLabel.text = String(localized: "Current balance: \(DemoContent.balance) credits")
        packs = [
            StorePackDisplay(id: "starter", name: "Starter", baseCredits: 150, bonusCredits: 0, price: "$2.99", rcPackage: nil),
            StorePackDisplay(id: "basic", name: "Basic", baseCredits: 475, bonusCredits: 75, price: "$9.99", rcPackage: nil),
            StorePackDisplay(id: "popular", name: "Popular", baseCredits: 1136, bonusCredits: 364, price: "$24.99", rcPackage: nil),
            StorePackDisplay(id: "business", name: "Business", baseCredits: 2174, bonusCredits: 1076, price: "$49.99", rcPackage: nil),
            StorePackDisplay(id: "enterprise", name: "Enterprise", baseCredits: 4167, bonusCredits: 2833, price: "$99.99", rcPackage: nil),
        ]
        reloadPacks()
    }
    #endif
}

final class PackCardView: UIControl {
    let packId: String
    var onTap: (() -> Void)?

    var isSelectedPack: Bool = false {
        didSet { updateSelection() }
    }

    private let glassCard: UIVisualEffectView
    private let checkmarkView: UIImageView
    private let rowSpacer = UIView()
    private var rowStack = UIStackView()

    init(pack: StorePackDisplay, badge: String?) {
        self.packId = pack.id
        self.glassCard = GlassMaterial.cardView(cornerRadius: 18)
        let checkConfig = UIImage.SymbolConfiguration(textStyle: .title3, scale: .medium).applying(UIImage.SymbolConfiguration(weight: .semibold))
        self.checkmarkView = UIImageView(image: UIImage(systemName: "circle", withConfiguration: checkConfig))
        super.init(frame: .zero)
        build(pack: pack, badge: badge)
        addAction(UIAction { [weak self] _ in self?.onTap?() }, for: .touchUpInside)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func build(pack: StorePackDisplay, badge: String?) {
        glassCard.isUserInteractionEnabled = false
        addSubview(glassCard)

        let nameLabel = UILabel()
        nameLabel.text = pack.name
        nameLabel.useScaledFont(.headline, size: 17, weight: .semibold, rounded: true)
        nameLabel.numberOfLines = 0

        let creditsLabel = UILabel()
        creditsLabel.useScaledFont(.subheadline, size: 15)
        creditsLabel.textColor = .secondaryLabel
        creditsLabel.numberOfLines = 0
        let total = NumberFormatter.localizedString(from: NSNumber(value: pack.totalCredits), number: .decimal)
        creditsLabel.text = pack.bonusCredits > 0
            ? String(localized: "\(total) credits · +\(pack.bonusPercent)% bonus")
            : String(localized: "\(total) credits")

        let imagesLabel = UILabel()
        imagesLabel.useScaledFont(.caption1, size: 12)
        imagesLabel.textColor = .secondaryLabel
        imagesLabel.numberOfLines = 0
        imagesLabel.text = String(localized: "≈ \(pack.imageEstimate) images")

        let leftStack = UIStackView(arrangedSubviews: [nameLabel, creditsLabel, imagesLabel])
        leftStack.axis = .vertical
        leftStack.spacing = 2

        let priceLabel = UILabel()
        priceLabel.text = pack.price
        priceLabel.useScaledFont(.title3, size: 20, weight: .bold, rounded: true)
        priceLabel.adjustsFontSizeToFitWidth = true
        priceLabel.minimumScaleFactor = 0.7
        priceLabel.setContentHuggingPriority(.required, for: .horizontal)
        priceLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        checkmarkView.tintColor = .tertiaryLabel
        checkmarkView.setContentHuggingPriority(.required, for: .horizontal)

        rowSpacer.isHidden = false
        rowStack = UIStackView(arrangedSubviews: [checkmarkView, leftStack, rowSpacer, priceLabel])
        rowStack.axis = .horizontal
        rowStack.spacing = 12
        rowStack.alignment = .center
        rowStack.isUserInteractionEnabled = false
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        glassCard.contentView.addSubview(rowStack)

        var constraints = [
            glassCard.topAnchor.constraint(equalTo: topAnchor),
            glassCard.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassCard.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassCard.bottomAnchor.constraint(equalTo: bottomAnchor),
            rowStack.topAnchor.constraint(equalTo: glassCard.contentView.topAnchor, constant: 14),
            rowStack.leadingAnchor.constraint(equalTo: glassCard.contentView.leadingAnchor, constant: 14),
            rowStack.trailingAnchor.constraint(equalTo: glassCard.contentView.trailingAnchor, constant: -16),
            rowStack.bottomAnchor.constraint(equalTo: glassCard.contentView.bottomAnchor, constant: -14),
        ]

        if let badge {
            let badgeLabel = PaddedLabel()
            badgeLabel.text = badge
            badgeLabel.useScaledFont(.caption2, size: 10, weight: .bold)
            badgeLabel.textColor = .white
            badgeLabel.backgroundColor = packId == "popular" ? .brand : Self.bestValueGreen
            badgeLabel.layer.cornerRadius = 8
            badgeLabel.layer.cornerCurve = .continuous
            badgeLabel.clipsToBounds = true
            badgeLabel.translatesAutoresizingMaskIntoConstraints = false
            badgeLabel.isUserInteractionEnabled = false
            badgeLabel.hideFromAccessibility()
            addSubview(badgeLabel)
            constraints.append(contentsOf: [
                badgeLabel.centerYAnchor.constraint(equalTo: topAnchor),
                badgeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            ])
        }

        NSLayoutConstraint.activate(constraints)
        layer.cornerRadius = 18
        layer.cornerCurve = .continuous
        describeForAccessibility(pack: pack, badge: badge, total: total)
        updateSelection()
        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (card: PackCardView, _) in
                card.updateSelection()
            }
        }
    }

    private static let bestValueGreen = UIColor(red: 0.1, green: 0.45, blue: 0.22, alpha: 1)

    /// Makes the whole card one VoiceOver button: name, total credits, bonus and price, with the badge and image estimate as its value.
    private func describeForAccessibility(pack: StorePackDisplay, badge: String?, total: String) {
        let label = pack.bonusCredits > 0
            ? String(localized: "\(pack.name), \(total) credits, \(pack.bonusCredits) bonus, \(pack.price)")
            : String(localized: "\(pack.name), \(total) credits, \(pack.price)")
        let images = String(localized: "About \(pack.imageEstimate) images")
        describe(label, value: [badge, images].compactMap { $0 }.joined(separator: ", "), traits: .button)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyContentSizeLayout()
    }

    /// Stacks the card's columns at accessibility text sizes so the price never squeezes the pack name.
    private func applyContentSizeLayout() {
        let isAccessibilitySize = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        let axis: NSLayoutConstraint.Axis = isAccessibilitySize ? .vertical : .horizontal
        guard rowStack.axis != axis else { return }
        rowStack.axis = axis
        rowStack.alignment = isAccessibilitySize ? .leading : .center
        rowSpacer.isHidden = isAccessibilitySize
    }

    private func updateSelection() {
        let checkConfig = UIImage.SymbolConfiguration(textStyle: .title3, scale: .medium).applying(UIImage.SymbolConfiguration(weight: .semibold))
        accessibilityTraits = isSelectedPack ? [.button, .selected] : .button
        if isSelectedPack {
            checkmarkView.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: checkConfig)
            checkmarkView.tintColor = .brandText
            glassCard.layer.borderWidth = 2
            glassCard.layer.borderColor = UIColor.brandText.resolvedColor(with: traitCollection).cgColor
        } else {
            checkmarkView.image = UIImage(systemName: "circle", withConfiguration: checkConfig)
            checkmarkView.tintColor = .tertiaryLabel
            glassCard.layer.borderWidth = 0.5
            glassCard.layer.borderColor = UIColor.separator.cgColor
        }
    }
}

final class PaddedLabel: UILabel {
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + 16, height: size.height + 8)
    }
}
