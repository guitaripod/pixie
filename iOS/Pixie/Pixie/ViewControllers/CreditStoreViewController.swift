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
    var imageEstimate: Int { max(1, totalCredits / max(1, WelcomeCredits.standardImageCost)) }
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
    private var appliedBarInset: CGFloat = 0
    private var barConstraints: [NSLayoutConstraint] = []
    private var barColumn: ColumnContainer?
    private var isBarInline = false
    private var isCompactHeader = false

    private enum PacksState {
        case loading
        case failed
        case loaded
    }

    private static let packsLoadTimeout: UInt64 = 10_000_000_000
    private static let dismissDelay: TimeInterval = 1.1
    private static let voiceOverDismissDelay: TimeInterval = 2.5
    private static let skeletonCardCount = 5
    private static let shortSheetHeight: CGFloat = 560

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
            sheet.preferredCornerRadius = Theme.Radius.sheet
        }
        presenter.present(navigation, animated: true)
    }

    private lazy var scrollView = ColumnScrollView(spacing: Theme.Space.md, topInset: Theme.Space.sm, bottomInset: Theme.Space.xl)

    private lazy var headerBadge = IconBadge(symbol: "sparkles", size: 64, symbolScale: 0.5)

    private lazy var headerStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [headerBadge, titleLabel, subtitleLabel, balancePill])
        stack.axis = .vertical
        stack.spacing = Theme.Space.sm
        stack.alignment = .center
        stack.setCustomSpacing(Theme.Space.lg, after: headerBadge)
        stack.setCustomSpacing(Theme.Space.lg, after: subtitleLabel)
        return stack
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.setStyledText(String(localized: "Credits"), .title, alignment: .center)
        label.accessibilityTraits = .header
        return label
    }()

    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.setStyledText(String(localized: "Pay for what you create.\nNo subscription — ever."), .callout, alignment: .center)
        return label
    }()

    private lazy var balancePill: CreditPill = {
        let pill = CreditPill()
        pill.isUserInteractionEnabled = false
        pill.accessibilityTraits = .staticText
        pill.isHidden = true
        return pill
    }()

    private lazy var packsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = Theme.Space.md
        return stack
    }()

    private lazy var skeletonStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = Theme.Space.md
        for _ in 0..<Self.skeletonCardCount {
            let card = ShimmerView()
            card.layer.cornerRadius = Theme.Radius.lg
            card.translatesAutoresizingMaskIntoConstraints = false
            card.heightAnchor.constraint(equalToConstant: 92).isActive = true
            card.hideFromAccessibility()
            stack.addArrangedSubview(card)
        }
        stack.describe(String(localized: "Loading…"), traits: .staticText)
        return stack
    }()

    private lazy var failedState: StateView = {
        let state = StateView(
            symbol: "exclamationmark.icloud.fill",
            title: String(localized: "Couldn't load credit packs"),
            actionTitle: String(localized: "Retry"),
            colors: [UIColor(hex: 0xFF9F43), UIColor(hex: 0xFF6F61)]
        ) { [weak self] in
            self?.retryPacks()
        }
        state.isHidden = true
        return state
    }()

    private lazy var perksLabel: UILabel = {
        let label = UILabel()
        label.setStyledText(String(localized: "Credits never expire  ·  Every quality tier  ·  No account required"), .footnote, color: Theme.Color.inkTertiary, alignment: .center)
        return label
    }()

    private lazy var ctaButton: PixieButton = {
        let button = PixieButton(style: .primary, size: .large, title: String(localized: "Loading…")) { [weak self] in
            self?.purchaseSelectedPack()
        }
        button.isEnabled = false
        return button
    }()

    private lazy var ctaNoteLabel: UILabel = {
        let label = UILabel()
        label.apply(.footnote, color: Theme.Color.inkSecondary)
        label.textAlignment = .center
        return label
    }()

    private lazy var footerStack: UIStackView = {
        let privacy = PixieButton(style: .plain, size: .small, title: String(localized: "Privacy")) { [weak self] in
            self?.open(url: "https://mako.midgarcorp.cc/privacy/pixie")
        }
        let terms = PixieButton(style: .plain, size: .small, title: String(localized: "Terms")) { [weak self] in
            self?.open(url: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
        }
        privacy.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        terms.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        let dot = UILabel()
        dot.apply(.footnote, color: Theme.Color.inkTertiary)
        dot.text = "·"
        dot.hideFromAccessibility()
        let stack = UIStackView(arrangedSubviews: [privacy, dot, terms])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = Theme.Space.xs
        return stack
    }()

    private lazy var barStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [ctaButton, ctaNoteLabel, footerStack])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = Theme.Space.xs
        stack.setCustomSpacing(Theme.Space.sm, after: ctaButton)
        stack.translatesAutoresizingMaskIntoConstraints = false
        ctaButton.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        ctaNoteLabel.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return stack
    }()

    private lazy var bottomBar: UIVisualEffectView = {
        let bar = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
        bar.translatesAutoresizingMaskIntoConstraints = false
        let hairline = HairlineView()
        bar.contentView.addSubview(hairline)
        let column = ColumnContainer(in: bar.contentView, maxWidth: Theme.Width.form, top: Theme.Space.md, bottom: 0)
        barColumn = column
        column.addSubview(barStack)
        barConstraints = [
            barStack.topAnchor.constraint(equalTo: column.topAnchor),
            barStack.leadingAnchor.constraint(equalTo: column.leadingAnchor),
            barStack.trailingAnchor.constraint(equalTo: column.trailingAnchor),
            barStack.bottomAnchor.constraint(equalTo: bar.contentView.safeAreaLayoutGuide.bottomAnchor, constant: -Theme.Space.xs),
        ]
        NSLayoutConstraint.activate(barConstraints + [
            hairline.topAnchor.constraint(equalTo: bar.contentView.topAnchor),
            hairline.leadingAnchor.constraint(equalTo: bar.contentView.leadingAnchor),
            hairline.trailingAnchor.constraint(equalTo: bar.contentView.trailingAnchor),
        ])
        return bar
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.canvas
        configureNavigationBar()
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
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        placePurchaseBar()
        updateScrollInsets()
    }

    private var isShortSheet: Bool { view.bounds.height < Self.shortSheetHeight }

    /// In a short sheet the badge and tagline give way so the packs get the room.
    private func applyHeaderDensity() {
        guard isShortSheet != isCompactHeader else { return }
        isCompactHeader = isShortSheet
        headerBadge.isHidden = isCompactHeader
        subtitleLabel.isHidden = isCompactHeader
    }

    /// At accessibility text sizes and in short sheets the purchase controls would cover most of the screen, so they scroll with the packs instead of sticking.
    private func placePurchaseBar() {
        applyHeaderDensity()
        let shouldInline = traitCollection.preferredContentSizeCategory.isAccessibilityCategory || isShortSheet
        guard shouldInline != isBarInline, let barColumn else { return }
        isBarInline = shouldInline
        NSLayoutConstraint.deactivate(barConstraints)
        barStack.removeFromSuperview()
        bottomBar.isHidden = shouldInline
        if shouldInline {
            scrollView.column.addArrangedSubview(barStack)
        } else {
            barColumn.addSubview(barStack)
            NSLayoutConstraint.activate(barConstraints)
        }
    }

    /// Lets the pack list scroll under the purchase bar and stop just above it.
    private func updateScrollInsets() {
        let inset = isBarInline ? 0 : max(0, bottomBar.frame.height - view.safeAreaInsets.bottom)
        guard inset != appliedBarInset else { return }
        appliedBarInset = inset
        scrollView.contentInset.bottom = inset
        scrollView.verticalScrollIndicatorInsets.bottom = inset
    }

    private func configureNavigationBar() {
        if #available(iOS 26.0, *) { return }
        let standard = UINavigationBarAppearance()
        standard.configureWithOpaqueBackground()
        standard.backgroundColor = Theme.Color.canvas
        standard.shadowColor = .clear
        let edge = UINavigationBarAppearance()
        edge.configureWithTransparentBackground()
        navigationItem.standardAppearance = standard
        navigationItem.scrollEdgeAppearance = edge
    }

    private func layoutUI() {
        view.addSubview(scrollView)
        view.addSubview(bottomBar)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func buildHeader() {
        let column = scrollView.column
        column.addArrangedSubview(headerStack)
        column.setCustomSpacing(Theme.Space.xl, after: headerStack)

        if let shortfall, shortfall > 0 {
            column.addArrangedSubview(makeShortfallBanner(shortfall))
        }

        column.addArrangedSubview(skeletonStack)
        column.addArrangedSubview(failedState)
        column.addArrangedSubview(packsStack)
        column.addArrangedSubview(perksLabel)
        column.setCustomSpacing(Theme.Space.lg, after: packsStack)
        applyPacksState()
    }

    private func makeShortfallBanner(_ shortfall: Int) -> UIView {
        let card = SurfaceView(style: .tinted(Theme.Color.warning.withAlphaComponent(0.16)), cornerRadius: Theme.Radius.lg)
        let icon = UIImageView(image: UIImage(systemName: "exclamationmark.circle.fill"))
        icon.tintColor = Theme.Color.warning
        icon.setContentHuggingPriority(.required, for: .horizontal)
        icon.hideFromAccessibility()
        let label = UILabel()
        label.apply(.subhead, color: Theme.Color.ink)
        label.text = String(localized: "You need \(shortfall) more credits to finish this image.")
        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.axis = .horizontal
        stack.spacing = Theme.Space.md
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.contentView.addSubview(stack)
        stack.pinEdges(to: card.contentView, insets: UIEdgeInsets(top: Theme.Space.md, left: Theme.Space.lg, bottom: Theme.Space.md, right: Theme.Space.lg))
        card.describe(label.text ?? "", traits: .staticText)
        return card
    }

    private func showBalance(_ balance: Int) {
        balancePill.isHidden = false
        balancePill.configure(
            amount: balance,
            kind: "credits",
            format: { "\(NumberFormatter.localizedString(from: NSNumber(value: $0), number: .decimal)) \(String(localized: "credits"))" },
            isLow: balance < CreditsViewModel.lowBalanceThreshold,
            accessibilityLabel: String(localized: "Current balance: \(balance) credits"),
            hint: nil
        )
    }

    private func bind() {
        viewModel.$balance
            .receive(on: DispatchQueue.main)
            .sink { [weak self] balance in
                guard let balance else { return }
                self?.showBalance(balance.balance)
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

    /// Shows shimmering cards while packs load, the error state with Retry when they cannot, and the pack list and purchase button once loaded.
    private func applyPacksState() {
        let isFailed = packsState == .failed
        skeletonStack.isHidden = packsState != .loading
        failedState.isHidden = !isFailed
        packsStack.isHidden = packsState != .loaded
        perksLabel.isHidden = isFailed
        ctaButton.isHidden = isFailed
        ctaNoteLabel.isHidden = isFailed || ctaNoteLabel.text == nil
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
        ctaButton.title = String(localized: "Get \(formatted(pack.totalCredits)) credits · \(pack.price)")
        ctaNoteLabel.text = String(localized: "One-time purchase · ≈ \(pack.imageEstimate) images")
        ctaNoteLabel.isHidden = false
        ctaButton.isUserInteractionEnabled = true
        ctaButton.isEnabled = true
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
        ctaButton.isLoading = true
        Announce.say(String(localized: "Processing purchase"))

        Task {
            let result = await purchaseManager.purchaseCreditPack(package: package)
            await MainActor.run {
                self.isPurchasing = false
                self.ctaButton.isLoading = false
                switch result {
                case .success(let purchase):
                    HapticsManager.shared.notification(.success)
                    Announce.say(String(localized: "\(self.formatted(purchase.credits)) credits added"))
                    self.ctaButton.title = String(localized: "Added \(self.formatted(purchase.credits)) credits")
                    self.ctaNoteLabel.text = String(localized: "New balance: \(self.formatted(purchase.newBalance))")
                    self.ctaButton.isUserInteractionEnabled = false
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
        showBalance(DemoContent.balance)
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
        didSet {
            guard oldValue != isSelectedPack else { return }
            Motion.animate(0.2, options: [.beginFromCurrentState, .allowUserInteraction]) { self.updateSelection() }
        }
    }

    private static let ringWidth: CGFloat = 2

    private let ring = GradientView()
    private let inner = UIView()
    private let tintFill = UIView()
    private let radioView = UIImageView()
    private let priceCapsule = PriceCapsule()
    private let priceLabel = UILabel()
    private let rowSpacer = UIView()
    private let rowStack = UIStackView()

    init(pack: StorePackDisplay, badge: String?) {
        self.packId = pack.id
        super.init(frame: .zero)
        build(pack: pack, badge: badge)
        addAction(UIAction { [weak self] _ in self?.onTap?() }, for: .touchUpInside)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func build(pack: StorePackDisplay, badge: String?) {
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = Theme.Radius.lg
        layer.cornerCurve = .continuous
        backgroundColor = Theme.Color.surface

        ring.cornerRadius = Theme.Radius.lg
        ring.translatesAutoresizingMaskIntoConstraints = false
        addSubview(ring)
        ring.pinEdges(to: self)

        inner.backgroundColor = Theme.Color.surface
        inner.layer.cornerRadius = Theme.Radius.lg - Self.ringWidth
        inner.layer.cornerCurve = .continuous
        inner.clipsToBounds = true
        inner.isUserInteractionEnabled = false
        inner.translatesAutoresizingMaskIntoConstraints = false
        addSubview(inner)
        inner.pinEdges(to: self, insets: UIEdgeInsets(top: Self.ringWidth, left: Self.ringWidth, bottom: Self.ringWidth, right: Self.ringWidth))

        tintFill.backgroundColor = Theme.Color.accentSoft
        tintFill.translatesAutoresizingMaskIntoConstraints = false
        inner.addSubview(tintFill)
        tintFill.pinEdges(to: inner)

        let total = NumberFormatter.localizedString(from: NSNumber(value: pack.totalCredits), number: .decimal)

        let imagesLabel = UILabel()
        imagesLabel.apply(.numeral(22))
        imagesLabel.text = String(localized: "≈ \(pack.imageEstimate) images")

        let creditsLabel = UILabel()
        creditsLabel.apply(.subhead)
        creditsLabel.text = pack.bonusCredits > 0
            ? String(localized: "\(total) credits · +\(pack.bonusPercent)% bonus")
            : String(localized: "\(total) credits")

        let textStack = UIStackView(arrangedSubviews: [imagesLabel, creditsLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        radioView.contentMode = .scaleAspectFit
        radioView.setContentHuggingPriority(.required, for: .horizontal)
        radioView.setContentCompressionResistancePriority(.required, for: .horizontal)

        priceLabel.apply(.numeral(17))
        priceLabel.numberOfLines = 1
        priceLabel.text = pack.price
        priceLabel.translatesAutoresizingMaskIntoConstraints = false
        priceCapsule.addSubview(priceLabel)
        priceLabel.pinEdges(to: priceCapsule, insets: UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14))
        priceCapsule.setContentHuggingPriority(.required, for: .horizontal)
        priceCapsule.setContentCompressionResistancePriority(.required, for: .horizontal)

        rowStack.addArrangedSubview(radioView)
        rowStack.addArrangedSubview(textStack)
        rowStack.addArrangedSubview(rowSpacer)
        rowStack.addArrangedSubview(priceCapsule)
        rowStack.axis = .horizontal
        rowStack.spacing = Theme.Space.md
        rowStack.alignment = .center

        let content = UIStackView()
        content.axis = .vertical
        content.alignment = .fill
        content.spacing = Theme.Space.sm
        content.isUserInteractionEnabled = false
        content.translatesAutoresizingMaskIntoConstraints = false
        if let badge {
            let capsule = BadgeCapsule(text: badge, colors: packId == "popular" ? Theme.Color.gradient : Self.bestValueColors)
            let holder = UIStackView(arrangedSubviews: [capsule, UIView()])
            holder.axis = .horizontal
            content.addArrangedSubview(holder)
        }
        content.addArrangedSubview(rowStack)
        inner.addSubview(content)
        content.pinEdges(to: inner, insets: UIEdgeInsets(top: Theme.Space.md, left: Theme.Space.lg, bottom: Theme.Space.md, right: Theme.Space.lg))

        NSLayoutConstraint.activate([
            radioView.widthAnchor.constraint(equalToConstant: 26),
            radioView.heightAnchor.constraint(equalToConstant: 26),
        ])

        describeForAccessibility(pack: pack, badge: badge, total: total)
        updateSelection()
    }

    private static let bestValueColors = [UIColor(hex: 0x0B7A52), UIColor(hex: 0x12A06B)]

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
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: Theme.Radius.lg).cgPath
        applyContentSizeLayout()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateSelection()
    }

    override var isHighlighted: Bool {
        didSet {
            guard oldValue != isHighlighted, !Motion.isReduced else { return }
            Motion.animate(0.15, options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.98, y: 0.98) : .identity
            }
        }
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
        let isDark = traitCollection.userInterfaceStyle == .dark
        let radioConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
        accessibilityTraits = isSelectedPack ? [.button, .selected] : .button
        ring.alpha = isSelectedPack ? 1 : 0
        tintFill.alpha = isSelectedPack ? 1 : 0
        layer.borderWidth = isSelectedPack ? 0 : 1
        layer.borderColor = Theme.Color.line.resolvedColor(with: traitCollection).cgColor
        layer.shadowColor = (isSelectedPack ? UIColor(hex: 0x6C47FF) : UIColor(hex: 0x1B0F4A)).cgColor
        layer.shadowOpacity = isDark ? (isSelectedPack ? 0.28 : 0) : (isSelectedPack ? 0.22 : 0.07)
        layer.shadowRadius = isSelectedPack ? 20 : 16
        layer.shadowOffset = CGSize(width: 0, height: isSelectedPack ? 8 : 6)
        priceCapsule.backgroundColor = isSelectedPack ? Theme.Color.accent : Theme.Color.fill
        priceLabel.textColor = isSelectedPack ? .white : Theme.Color.ink
        if isSelectedPack {
            radioView.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: radioConfig)
            radioView.tintColor = Theme.Color.accentText
        } else {
            radioView.image = UIImage(systemName: "circle", withConfiguration: radioConfig)
            radioView.tintColor = Theme.Color.inkTertiary
        }
    }
}

private final class PriceCapsule: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerCurve = .continuous
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }
}

private final class BadgeCapsule: UIView {
    private let gradient: GradientView
    private let label = UILabel()

    init(text: String, colors: [UIColor]) {
        gradient = GradientView(colors: colors, start: CGPoint(x: 0, y: 0.5), end: CGPoint(x: 1, y: 0.5))
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerCurve = .continuous
        clipsToBounds = true
        gradient.translatesAutoresizingMaskIntoConstraints = false
        addSubview(gradient)
        gradient.pinEdges(to: self)
        label.setStyledText(text, .caption, color: .white)
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        label.pinEdges(to: self, insets: UIEdgeInsets(top: 3, left: 10, bottom: 3, right: 10))
        hideFromAccessibility()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }
}
