import Combine
import MidgarCommerce
import UIKit

/// One choice on the store screen: PixiePocket Plus or a pack of edits.
struct StorePackDisplay {
    static let plusID = "plus"

    let id: String
    let title: String
    let detail: String
    let price: String
    let edits: Int

    var isPlus: Bool { id == Self.plusID }

    /// A pack: its edits, what one edit costs in the customer's currency and that it never expires.
    static func pack(id: String, edits: Int, price: String, perEdit: String?) -> StorePackDisplay {
        let never = String(localized: "Never expires")
        let detail = perEdit.map { String(localized: "\($0) per edit · \(never)") } ?? never
        return StorePackDisplay(id: id, title: EditPrice.label(edits: edits), detail: detail, price: price, edits: edits)
    }

    /// Plus: weekly, its edits and its price; the button below says the price per week again.
    static func plus(price: String) -> StorePackDisplay {
        StorePackDisplay(
            id: plusID,
            title: String(localized: "Plus"),
            detail: String(localized: "Weekly · \(PixiePacks.plusWeeklyEdits) edits · Standard or Max"),
            price: price,
            edits: PixiePacks.plusWeeklyEdits
        )
    }

    /// What one edit of a pack costs, formatted like the store's own price, or nil without a numeric price.
    static func perEditPrice(of product: StoreProduct, edits: Int) -> String? {
        guard edits > 0, product.price > 0 else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceLocale ?? .current
        if let code = product.currencyCode { formatter.currencyCode = code }
        formatter.maximumFractionDigits = 2
        return formatter.string(from: (product.price / Decimal(edits)) as NSDecimalNumber)
    }
}

final class CreditStoreViewController: UIViewController {

    private let viewModel = CreditsViewModel()
    private let shortfall: Int?
    private let purchaseManager = CreditPurchaseManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var packs: [StorePackDisplay] = []
    private var selectedPackId = StorePackDisplay.plusID
    private var plus: StorePackDisplay?
    private var hasPlus = false
    private var isConfirmingPurchase = false
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

    private var hasNotedShown = false

    init(shortfall: Int? = nil) {
        self.shortfall = shortfall
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Opens the store; `shortfall` is how many edits the request in hand is short of.
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
        label.setStyledText(String(localized: "Edits"), .title, alignment: .center)
        label.accessibilityTraits = .header
        return label
    }()

    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.setStyledText(String(localized: "Plus every week, or a pack\nthat never expires."), .callout, alignment: .center)
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
            title: String(localized: "Couldn't load the store"),
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
        label.setStyledText(String(localized: "Packs never expire  ·  Standard and Max  ·  No account required"), .footnote, color: Theme.Color.inkTertiary, alignment: .center)
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
            self?.open(url: AboutSettings.privacyPolicyURL.absoluteString)
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
        navigationItem.leftBarButtonItem?.accessibilityLabel = String(localized: "Edits & Usage")
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
        loadPacks()
    }

    deinit {
        packsTimeoutTask?.cancel()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        noteShownOnce()
    }

    /// Reports the store once per presentation as a `limit` when a request ran short of credits, otherwise as a `feature`.
    private func noteShownOnce() {
        guard !hasNotedShown else { return }
        hasNotedShown = true
        MidgarPaywallMoments.noteShown(placement: shortfall == nil ? .feature : .limit)
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
        label.text = String(localized: "You need \(EditPrice.label(edits: shortfall)) more for this.")
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

    private func showBalance(_ edits: Int) {
        balancePill.isHidden = false
        balancePill.configure(
            amount: edits,
            kind: "edits",
            format: EditPrice.label(edits:),
            isLow: edits < CreditsViewModel.lowEditsThreshold,
            accessibilityLabel: String(localized: "Current balance: \(EditPrice.label(edits: edits))"),
            hint: nil
        )
    }

    private func bind() {
        viewModel.$balance
            .receive(on: DispatchQueue.main)
            .sink { [weak self] balance in
                guard let self, let balance else { return }
                self.showBalance(EditPrice.edits(of: balance))
                self.applyPlusHeld(balance.edits?.premium != nil)
            }
            .store(in: &cancellables)

        purchaseManager.getCreditPacksWithPricing()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] packsWithPricing in
                guard let self, !packsWithPricing.isEmpty else { return }
                self.packsTimeoutTask?.cancel()
                let balance = CreditBalanceStore.shared.balance
                self.packs = packsWithPricing.map {
                    let edits = EditPrice.edits(inCredits: $0.creditPack.credits + $0.creditPack.bonusCredits, balance: balance)
                    return .pack(
                        id: $0.creditPack.id,
                        edits: edits,
                        price: $0.localizedPrice,
                        perEdit: StorePackDisplay.perEditPrice(of: $0.product, edits: edits)
                    )
                }
                self.reloadPacks()
            }
            .store(in: &cancellables)

        purchaseManager.$plusProduct
            .receive(on: DispatchQueue.main)
            .sink { [weak self] product in
                self?.plus = product.map { StorePackDisplay.plus(price: $0.displayPrice) }
                if self?.packsState == .loaded { self?.reloadPacks() }
            }
            .store(in: &cancellables)
    }

    private func loadPacks() {
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
            } else if purchaseManager.offers.isEmpty {
                await purchaseManager.fetchOffers()
            }
            if purchaseManager.plusProduct == nil {
                await purchaseManager.fetchPlus()
            }
        }
    }

    private func failPacksIfStillEmpty() {
        guard packs.isEmpty, packsState != .failed else { return }
        packsTimeoutTask?.cancel()
        packsState = .failed
        applyPacksState()
        HapticsManager.shared.notification(.error)
        Announce.say(String(localized: "Couldn't load the store"))
    }

    private func retryPacks() {
        HapticsManager.shared.selection()
        loadPacks()
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

    /// Rebuilds the cards when the balance says Plus started or ended after they were laid out, so a Plus card is never
    /// on screen while `choices` leaves it out, where tapping it would neither change the button nor buy anything.
    private func applyPlusHeld(_ held: Bool) {
        guard held != hasPlus else { return }
        hasPlus = held
        if packsState == .loaded && !isConfirmingPurchase { reloadPacks() }
    }

    /// Plus first while the person does not hold it, then the packs.
    private var choices: [StorePackDisplay] {
        (hasPlus ? [] : [plus].compactMap { $0 }) + packs
    }

    private func reloadPacks() {
        packsState = .loaded
        applyPacksState()
        packsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let choices = choices
        if choices.first(where: { $0.id == selectedPackId }) == nil {
            selectedPackId = choices.first?.id ?? selectedPackId
        }
        for pack in choices {
            let card = PackCardView(pack: pack, badge: badge(for: pack.id))
            card.isSelectedPack = pack.id == selectedPackId
            card.onTap = { [weak self] in self?.select(packId: pack.id) }
            packsStack.addArrangedSubview(card)
        }
        updateCTA()
    }

    private func badge(for packId: String) -> String? {
        switch packId {
        case StorePackDisplay.plusID: return String(localized: "BEST VALUE")
        case "basic": return String(localized: "MOST POPULAR")
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
        guard let pack = choices.first(where: { $0.id == selectedPackId }) else { return }
        if pack.isPlus {
            ctaButton.title = String(localized: "Subscribe · \(String(localized: "\(pack.price)/week"))")
            ctaNoteLabel.text = String(localized: "\(pack.edits) edits every week. Renews weekly until you cancel in Settings.")
        } else {
            ctaButton.title = String(localized: "Get \(pack.title) · \(pack.price)")
            ctaNoteLabel.text = String(localized: "One-time purchase · Never expires")
        }
        ctaNoteLabel.isHidden = false
        ctaButton.isUserInteractionEnabled = true
        ctaButton.isEnabled = true
    }

    private func purchaseSelectedPack() {
        guard let pack = choices.first(where: { $0.id == selectedPackId }), !isPurchasing else { return }
        HapticsManager.shared.impact(.medium)
        isPurchasing = true
        ctaButton.isLoading = true
        Announce.say(String(localized: "Processing purchase"))

        if pack.isPlus {
            subscribeToPlus()
            return
        }
        Task {
            do {
                let outcome = try await purchaseManager.purchaseCreditPack(id: pack.id)
                endPurchase()
                show(outcome)
            } catch {
                endPurchase()
                showPurchaseFailure(error)
            }
        }
    }

    private func subscribeToPlus() {
        guard let scene = view.window?.windowScene else {
            endPurchase()
            return
        }
        Task {
            do {
                let result = try await purchaseManager.purchasePlus(confirmIn: scene)
                endPurchase()
                showPlus(result)
            } catch {
                endPurchase()
                showPurchaseFailure(error)
            }
        }
    }

    private func showPlus(_ result: MidgarPurchaseResult) {
        switch result {
        case .purchased:
            HapticsManager.shared.notification(.success)
            let note = String(localized: "Welcome to Plus: \(PixiePacks.plusWeeklyEdits) edits every week.")
            Announce.say(note)
            ctaButton.title = String(localized: "You have Plus")
            ctaNoteLabel.text = note
            ctaButton.isUserInteractionEnabled = false
            isConfirmingPurchase = true
            dismissAfterPurchase()
        case .pending:
            updateCTA()
            let note = String(localized: "Waiting for approval. Plus starts as soon as it is approved.")
            ctaNoteLabel.text = note
            Announce.say(note)
        case .cancelled:
            updateCTA()
        }
    }

    private func endPurchase() {
        isPurchasing = false
        ctaButton.isLoading = false
    }

    /// A credited pack shows what arrived and the new balance; a paid pack mako has not credited yet says the credits
    /// arrive shortly, and the balance follows the credit on its own; a purchase waiting for approval says so; a
    /// cancelled one leaves the button as it was.
    private func show(_ outcome: CreditPurchaseOutcome) {
        switch outcome {
        case .credited(let credits, let newBalance):
            HapticsManager.shared.notification(.success)
            let added = EditPrice.label(edits: EditPrice.edits(inCredits: credits, balance: CreditBalanceStore.shared.balance))
            let total = EditPrice.label(edits: EditPrice.edits(inCredits: newBalance, balance: CreditBalanceStore.shared.balance))
            Announce.say(String(localized: "\(added) added"))
            ctaButton.title = String(localized: "Added \(added)")
            ctaNoteLabel.text = String(localized: "New balance: \(total)")
            ctaButton.isUserInteractionEnabled = false
            isConfirmingPurchase = true
            Task { await viewModel.loadBalance() }
            dismissAfterPurchase()
        case .creditPending:
            HapticsManager.shared.notification(.success)
            let note = String(localized: "Your edits arrive shortly. No need to buy again.")
            Announce.say(note)
            ctaButton.title = String(localized: "Purchase received")
            ctaNoteLabel.text = note
            ctaButton.isUserInteractionEnabled = false
            isConfirmingPurchase = true
            dismissAfterPurchase()
        case .awaitingApproval:
            updateCTA()
            let note = String(localized: "Waiting for approval. Your edits arrive as soon as it is approved.")
            ctaNoteLabel.text = note
            Announce.say(note)
        case .cancelled:
            updateCTA()
        }
    }

    private func showPurchaseFailure(_ error: Error) {
        updateCTA()
        HapticsManager.shared.notification(.error)
        let alert = UIAlertController(title: String(localized: "Purchase Failed"), message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String(localized: "OK"), style: .default))
        present(alert, animated: true)
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
        showBalance(DemoContent.balanceEdits)
        plus = .plus(price: PixiePacks.plusListPrice)
        packs = PixiePacks.offered.map {
            .pack(id: $0.id, edits: $0.totalCredits / EditPrice.fallbackCreditsPerEdit, price: $0.listPrice, perEdit: nil)
        }
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

        let titleLabel = UILabel()
        titleLabel.apply(.numeral(22))
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.6
        titleLabel.text = pack.title

        let detailLabel = UILabel()
        detailLabel.apply(.subhead)
        detailLabel.numberOfLines = 0
        detailLabel.text = pack.detail

        let textStack = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
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
            let capsule = BadgeCapsule(text: badge, colors: packId == StorePackDisplay.plusID ? Theme.Color.gradient : Self.bestValueColors)
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

        describeForAccessibility(pack: pack, badge: badge)
        updateSelection()
    }

    private static let bestValueColors = [UIColor(hex: 0x0B7A52), UIColor(hex: 0x12A06B)]

    /// Makes the whole card one VoiceOver button: what it is and its price, with the badge and the detail as its value.
    private func describeForAccessibility(pack: StorePackDisplay, badge: String?) {
        describe("\(pack.title), \(pack.price)", value: [badge, pack.detail].compactMap { $0 }.joined(separator: ", "), traits: .button)
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
