import UIKit
import Combine

class CreditsMainViewController: UIViewController {
    private let viewModel: CreditsViewModel
    private var cancellables = Set<AnyCancellable>()

    private static let freshnessRefreshInterval: TimeInterval = 30
    private static let recentTransactionCount = 5

    private let scrollView = ColumnScrollView()
    private let hero = BalanceHeroView()

    private let errorBanner = SurfaceView(style: .tinted(Theme.Color.danger.withAlphaComponent(0.12)), cornerRadius: Theme.Radius.lg)
    private let errorStack = UIStackView()
    private let errorIcon = UIImageView()
    private let errorLabel = UILabel()
    private let retryButton = PixieButton(style: .secondary, size: .medium, title: String(localized: "Retry"))

    private let recentStack = UIStackView()
    private let recentRowsHost = UIView()

    private var freshnessTimer: Timer?
    private var isShowingBalanceError = false
    private var hasAnnouncedLowBalance = false

    init(viewModel: CreditsViewModel? = nil) {
        self.viewModel = viewModel ?? CreditsViewModel()
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindViewModel()
        renderBalance()
        viewModel.refresh()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.refresh()
        startFreshnessTimer()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        freshnessTimer?.invalidate()
        freshnessTimer = nil
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyContentSizeLayout()
    }

    private func setupUI() {
        title = String(localized: "Credits & Usage")
        view.backgroundColor = Theme.Color.canvas
        navigationItem.largeTitleDisplayMode = .never

        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        hero.buyButton.addAction(UIAction { [weak self] _ in self?.navigateToCreditPacks() }, for: .touchUpInside)
        setupErrorBanner()

        let top = UIStackView(arrangedSubviews: [hero, errorBanner])
        top.axis = .vertical
        top.spacing = Theme.Space.md

        setupRecentTransactions()

        let estimator = ListRowView(
            title: String(localized: "Cost Estimator"),
            subtitle: String(localized: "Calculate costs before generating images"),
            symbol: "function",
            colors: [UIColor(hex: 0x2F80ED), UIColor(hex: 0x6C47FF)],
            showsChevron: true
        )
        estimator.onTap = { [weak self] in self?.navigateToEstimator() }
        estimator.accessibilityLabel = String(localized: "Cost Estimator")
        estimator.accessibilityHint = String(localized: "Calculate costs before generating images")
        let toolsCard = RowCard.make([estimator])

        scrollView.column.addArrangedSubview(top)
        scrollView.column.addArrangedSubview(recentStack)
        scrollView.column.addArrangedSubview(toolsCard)
    }

    private func setupErrorBanner() {
        errorBanner.isHidden = true

        errorIcon.image = UIImage(systemName: "exclamationmark.triangle.fill")
        errorIcon.tintColor = Theme.Color.danger
        errorIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .body)
        errorIcon.contentMode = .scaleAspectFit
        errorIcon.setContentHuggingPriority(.required, for: .horizontal)
        errorIcon.hideFromAccessibility()

        errorLabel.apply(.subhead, color: Theme.Color.ink)
        errorLabel.text = String(localized: "Couldn't refresh your balance")

        retryButton.addAction(UIAction { [weak self] _ in self?.retryBalance() }, for: .touchUpInside)
        retryButton.setContentHuggingPriority(.required, for: .horizontal)
        retryButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        errorStack.axis = .horizontal
        errorStack.alignment = .center
        errorStack.spacing = Theme.Space.md
        errorStack.translatesAutoresizingMaskIntoConstraints = false
        errorStack.addArrangedSubview(errorIcon)
        errorStack.addArrangedSubview(errorLabel)
        errorStack.addArrangedSubview(retryButton)
        errorBanner.contentView.addSubview(errorStack)
        errorStack.pinEdges(to: errorBanner.contentView, insets: UIEdgeInsets(top: Theme.Space.md, left: Theme.Space.lg, bottom: Theme.Space.md, right: Theme.Space.md))
    }

    private func setupRecentTransactions() {
        recentStack.axis = .vertical
        recentStack.spacing = Theme.Space.xs
        recentStack.isHidden = true

        let header = CreditsSectionHeader(
            title: String(localized: "Recent Transactions"),
            actionTitle: String(localized: "View All")
        ) { [weak self] in
            self?.navigateToHistory()
        }

        recentRowsHost.translatesAutoresizingMaskIntoConstraints = false
        recentStack.addArrangedSubview(header)
        recentStack.addArrangedSubview(recentRowsHost)
    }

    /// Stacks the side-by-side rows vertically at accessibility text sizes so nothing is squeezed or clipped.
    private func applyContentSizeLayout() {
        let isAccessibilitySize = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        let axis: NSLayoutConstraint.Axis = isAccessibilitySize ? .vertical : .horizontal
        if errorStack.axis != axis {
            errorStack.axis = axis
            errorStack.alignment = isAccessibilitySize ? .leading : .center
        }
    }

    private func bindViewModel() {
        viewModel.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.renderBalance()
            }
            .store(in: &cancellables)

        viewModel.$lowCreditWarning
            .receive(on: DispatchQueue.main)
            .sink { [weak self] showWarning in
                self?.updateLowCreditWarning(showWarning)
            }
            .store(in: &cancellables)

        viewModel.$transactions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] transactions in
                self?.updateRecentTransactions(transactions)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .networkStatusChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.networkStatusChanged()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIAccessibility.reduceMotionStatusDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.renderBalance()
            }
            .store(in: &cancellables)
    }

    private func startFreshnessTimer() {
        freshnessTimer?.invalidate()
        freshnessTimer = Timer.scheduledTimer(withTimeInterval: Self.freshnessRefreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateFreshness() }
        }
    }

    private func networkStatusChanged() {
        renderBalance()
        if NetworkMonitor.shared.isConnected, viewModel.balanceErrorMessage != nil, !viewModel.isLoadingBalance {
            Task { await viewModel.loadBalance() }
        }
    }

    private func retryBalance() {
        HapticsManager.shared.selection()
        Task { await viewModel.loadBalance() }
    }

    /// Redraws the whole balance card, the inline error banner and their VoiceOver description from the view model.
    private func renderBalance() {
        let balance = viewModel.balance
        let isLoadingFirstBalance = viewModel.isLoadingBalance && balance == nil

        hero.setLoading(isLoadingFirstBalance)
        hero.amountText = balance.map { Self.formatted($0.balance) } ?? "–"
        updateStatusLines(for: balance)
        updateFreshness()
        updateErrorBanner()
        updateBalanceAccessibility(isLoading: isLoadingFirstBalance)
    }

    private func updateStatusLines(for balance: CreditBalance?) {
        guard let balance else {
            hero.imagesText = nil
            hero.freeText = nil
            hero.lowText = nil
            return
        }

        let imageCost = WelcomeCredits.standardImageCost
        let images = WelcomeCredits.freeImages(balance: balance.balance, imageCost: imageCost)
        hero.imagesText = images > 0 ? String(localized: "≈ \(images) images") : nil

        let freeImages = freeImagesLeft(for: balance.balance)
        hero.freeText = freeImages.map { String(localized: "\($0) free images left") }

        hero.lowIsEmpty = balance.balance == 0
        hero.lowText = lowBalanceText(for: balance.balance)
    }

    /// Whole images still covered by the welcome grant, or nil once the person bought credits or has none left.
    private func freeImagesLeft(for balance: Int) -> Int? {
        guard WelcomeCredits().isOnWelcomeGrant(balance: balance) else { return nil }
        let images = WelcomeCredits.freeImages(balance: balance, imageCost: WelcomeCredits.standardImageCost)
        return images > 0 ? images : nil
    }

    private func lowBalanceText(for balance: Int) -> String? {
        if balance == 0 { return String(localized: "Out of credits") }
        if balance < CreditsViewModel.lowBalanceThreshold { return String(localized: "Low balance") }
        return nil
    }

    private func freshnessText() -> String? {
        guard viewModel.balance != nil else { return nil }
        if !NetworkMonitor.shared.isConnected {
            return String(localized: "Offline, showing last balance")
        }
        guard let updatedAt = viewModel.balanceUpdatedAt else { return nil }
        if Date().timeIntervalSince(updatedAt) < 60 {
            return String(localized: "Updated just now")
        }
        let relative = RelativeDateTimeFormatter().localizedString(for: updatedAt, relativeTo: Date())
        return String(localized: "Updated \(relative)")
    }

    private func updateFreshness() {
        hero.freshnessText = freshnessText()
        if viewModel.balance != nil {
            updateBalanceAccessibility(isLoading: false)
        }
    }

    private func updateErrorBanner() {
        let shouldShow = viewModel.balanceErrorMessage != nil
        errorBanner.isHidden = !shouldShow
        retryButton.isLoading = viewModel.isLoadingBalance

        guard shouldShow != isShowingBalanceError else { return }
        isShowingBalanceError = shouldShow
        if shouldShow {
            HapticsManager.shared.notification(.error)
            Announce.say(String(localized: "Couldn't refresh your balance"))
        } else if viewModel.balance != nil {
            Announce.say(String(localized: "Balance updated"))
        }
    }

    private func updateBalanceAccessibility(isLoading: Bool) {
        guard let balance = viewModel.balance else {
            let label = isLoading ? String(localized: "Loading…") : String(localized: "Balance unavailable")
            hero.describeSummary(label, value: nil)
            return
        }
        let value = [
            spokenImages(for: balance.balance),
            hero.freeText,
            hero.lowText,
            hero.freshnessText
        ].compactMap { $0 }.joined(separator: ", ")
        hero.describeSummary(
            String(localized: "Balance: \(Self.formatted(balance.balance)) credits"),
            value: value.isEmpty ? nil : value
        )
    }

    private func spokenImages(for balance: Int) -> String? {
        let images = WelcomeCredits.freeImages(balance: balance, imageCost: WelcomeCredits.standardImageCost)
        return images > 0 ? String(localized: "About \(images) images") : nil
    }

    private static func formatted(_ value: Int) -> String {
        NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
    }

    private func updateRecentTransactions(_ transactions: [CreditTransaction]) {
        recentStack.isHidden = transactions.isEmpty
        recentRowsHost.subviews.forEach { $0.removeFromSuperview() }
        guard !transactions.isEmpty else { return }

        let rows = transactions.prefix(Self.recentTransactionCount).map {
            $0.makeListRow(stamp: TransactionDates.stamp(for: $0.createdAt))
        }
        let card = RowCard.make(rows)
        recentRowsHost.addSubview(card)
        card.pinEdges(to: recentRowsHost)
    }

    private func updateLowCreditWarning(_ showWarning: Bool) {
        guard showWarning else {
            hasAnnouncedLowBalance = false
            return
        }

        pulseBalanceCard()
        HapticsManager.shared.notification(.warning)

        if !hasAnnouncedLowBalance, let balance = viewModel.balance {
            hasAnnouncedLowBalance = true
            Announce.say(lowBalanceText(for: balance.balance) ?? String(localized: "Low balance"))
        }
    }

    private func pulseBalanceCard() {
        guard !Motion.isReduced else { return }
        Motion.animate(0.3, animations: {
            self.hero.transform = CGAffineTransform(scaleX: 1.02, y: 1.02)
        }, completion: { _ in
            Motion.animate(0.3) {
                self.hero.transform = .identity
            }
        })
    }

    private func navigateToCreditPacks() {
        if navigationController?.viewControllers.first is CreditStoreViewController {
            navigationController?.popToRootViewController(animated: true)
            return
        }
        CreditStoreViewController.present(from: self)
    }

    private func navigateToEstimator() {
        let estimatorVC = CostEstimatorViewController(viewModel: viewModel)
        navigationController?.pushViewController(estimatorVC, animated: true)
    }

    private func navigateToHistory() {
        let historyVC = TransactionHistoryViewController(viewModel: viewModel)
        navigationController?.pushViewController(historyVC, animated: true)
    }
}

private final class BalanceHeroView: UIView {
    let buyButton = PixieButton(style: .onBackdrop, size: .large, title: String(localized: "Buy Credits"), symbol: "sparkles")

    private let clip = UIView()
    private let gradient = GradientView()
    private let captionLabel = UILabel()
    private let amountRow = UIStackView()
    private let amountSpacer = UIView()
    private let amountLabel = UILabel()
    private let creditsLabel = UILabel()
    private let imagesLabel = UILabel()
    private let freePill = StatusPill(solid: false)
    private let lowPill = StatusPill(solid: true)
    private let freshnessLabel = UILabel()
    private let summaryStack = UIStackView()
    private let skeleton = UIStackView()

    var amountText = "–" {
        didSet { amountLabel.text = amountText }
    }

    var imagesText: String? {
        didSet {
            imagesLabel.text = imagesText
            imagesLabel.isHidden = imagesText == nil || isLoading
        }
    }

    var freeText: String? {
        didSet {
            if let freeText { freePill.configure(text: freeText, symbol: "gift.fill", tint: .white) }
            freePill.isHidden = freeText == nil || isLoading
        }
    }

    var lowIsEmpty = false

    var lowText: String? {
        didSet {
            if let lowText {
                lowPill.configure(text: lowText, symbol: "exclamationmark.triangle.fill", tint: lowIsEmpty ? Theme.Color.danger : Theme.Color.warning)
            }
            lowPill.isHidden = lowText == nil || isLoading
        }
    }

    var freshnessText: String? {
        didSet {
            freshnessLabel.text = freshnessText
            freshnessLabel.isHidden = freshnessText == nil || isLoading
        }
    }

    private var isLoading = false

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = Theme.Radius.xl
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor(hex: 0x6C47FF).cgColor
        layer.shadowOpacity = 0.32
        layer.shadowRadius = 28
        layer.shadowOffset = CGSize(width: 0, height: 14)

        clip.layer.cornerRadius = Theme.Radius.xl
        clip.layer.cornerCurve = .continuous
        clip.clipsToBounds = true
        clip.translatesAutoresizingMaskIntoConstraints = false
        addSubview(clip)
        clip.pinEdges(to: self)

        gradient.translatesAutoresizingMaskIntoConstraints = false
        clip.addSubview(gradient)
        gradient.pinEdges(to: clip)

        addDecorations()
        buildContent()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: Theme.Radius.xl).cgPath
        let isAccessibilitySize = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        let axis: NSLayoutConstraint.Axis = isAccessibilitySize ? .vertical : .horizontal
        guard amountRow.axis != axis else { return }
        amountRow.axis = axis
        amountRow.alignment = isAccessibilitySize ? .leading : .lastBaseline
        amountSpacer.isHidden = isAccessibilitySize
    }

    func setLoading(_ loading: Bool) {
        guard loading != isLoading else { return }
        isLoading = loading
        skeleton.isHidden = !loading
        amountRow.isHidden = loading
        imagesLabel.isHidden = loading || imagesText == nil
        freePill.isHidden = loading || freeText == nil
        lowPill.isHidden = loading || lowText == nil
        freshnessLabel.isHidden = loading || freshnessText == nil
    }

    func describeSummary(_ label: String, value: String?) {
        summaryStack.describe(label, value: value, traits: .staticText)
        accessibilityElements = [summaryStack, buyButton]
        isAccessibilityElement = false
    }

    private func addDecorations() {
        let bigOrb = UIView()
        bigOrb.backgroundColor = UIColor(white: 1, alpha: 0.10)
        bigOrb.layer.cornerRadius = 130
        let smallOrb = UIView()
        smallOrb.backgroundColor = UIColor(white: 1, alpha: 0.07)
        smallOrb.layer.cornerRadius = 80
        let sparkle = UIImageView(image: UIImage(systemName: "sparkles"))
        sparkle.tintColor = UIColor(white: 1, alpha: 0.30)
        sparkle.contentMode = .scaleAspectFit
        sparkle.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 44, weight: .semibold)
        for decoration in [bigOrb, smallOrb, sparkle] {
            decoration.translatesAutoresizingMaskIntoConstraints = false
            decoration.isUserInteractionEnabled = false
            decoration.hideFromAccessibility()
            clip.addSubview(decoration)
        }
        NSLayoutConstraint.activate([
            bigOrb.widthAnchor.constraint(equalToConstant: 260),
            bigOrb.heightAnchor.constraint(equalToConstant: 260),
            bigOrb.trailingAnchor.constraint(equalTo: clip.trailingAnchor, constant: 90),
            bigOrb.topAnchor.constraint(equalTo: clip.topAnchor, constant: -110),
            smallOrb.widthAnchor.constraint(equalToConstant: 160),
            smallOrb.heightAnchor.constraint(equalToConstant: 160),
            smallOrb.leadingAnchor.constraint(equalTo: clip.leadingAnchor, constant: -60),
            smallOrb.bottomAnchor.constraint(equalTo: clip.bottomAnchor, constant: 70),
            sparkle.topAnchor.constraint(equalTo: clip.topAnchor, constant: Theme.Space.xl),
            sparkle.trailingAnchor.constraint(equalTo: clip.trailingAnchor, constant: -Theme.Space.xxl),
        ])
    }

    private func buildContent() {
        captionLabel.setStyledText(String(localized: "Current Balance"), .caption, color: UIColor(white: 1, alpha: 0.80))

        amountLabel.apply(.numeral(56), color: .white)
        amountLabel.numberOfLines = 1
        amountLabel.adjustsFontSizeToFitWidth = true
        amountLabel.minimumScaleFactor = 0.5
        amountLabel.text = amountText
        amountLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        creditsLabel.apply(.title2, color: UIColor(white: 1, alpha: 0.80))
        creditsLabel.text = String(localized: "credits")
        creditsLabel.numberOfLines = 1
        creditsLabel.setContentHuggingPriority(.required, for: .horizontal)

        amountRow.axis = .horizontal
        amountRow.alignment = .lastBaseline
        amountRow.spacing = Theme.Space.sm
        amountLabel.setContentHuggingPriority(.required, for: .horizontal)
        amountRow.addArrangedSubview(amountLabel)
        amountRow.addArrangedSubview(creditsLabel)
        amountRow.addArrangedSubview(amountSpacer)

        imagesLabel.apply(.callout, color: UIColor(white: 1, alpha: 0.92))
        imagesLabel.isHidden = true

        freePill.isHidden = true
        lowPill.isHidden = true
        let pills = UIStackView(arrangedSubviews: [freePill, lowPill])
        pills.axis = .vertical
        pills.alignment = .leading
        pills.spacing = Theme.Space.sm

        freshnessLabel.apply(.footnote, color: UIColor(white: 1, alpha: 0.82))
        freshnessLabel.isHidden = true

        buildSkeleton()

        summaryStack.axis = .vertical
        summaryStack.spacing = Theme.Space.xs
        [captionLabel, amountRow, skeleton, imagesLabel, pills, freshnessLabel].forEach { summaryStack.addArrangedSubview($0) }
        summaryStack.setCustomSpacing(Theme.Space.md, after: imagesLabel)
        summaryStack.setCustomSpacing(Theme.Space.md, after: pills)
        summaryStack.setCustomSpacing(Theme.Space.sm, after: captionLabel)

        let content = UIStackView(arrangedSubviews: [summaryStack, buyButton])
        content.axis = .vertical
        content.spacing = Theme.Space.xl
        content.translatesAutoresizingMaskIntoConstraints = false
        clip.addSubview(content)
        content.pinEdges(to: clip, insets: UIEdgeInsets(top: Theme.Space.xl, left: Theme.Space.xxl, bottom: Theme.Space.xxl, right: Theme.Space.xxl))
    }

    private func buildSkeleton() {
        skeleton.axis = .vertical
        skeleton.alignment = .leading
        skeleton.spacing = Theme.Space.md
        skeleton.isHidden = true
        skeleton.hideFromAccessibility()
        for (width, height) in [(CGFloat(180), CGFloat(56)), (CGFloat(120), CGFloat(18))] {
            let bar = ShimmerView()
            bar.backgroundColor = UIColor(white: 1, alpha: 0.22)
            bar.layer.cornerRadius = height / 2.5
            bar.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                bar.widthAnchor.constraint(equalToConstant: width),
                bar.heightAnchor.constraint(equalToConstant: height),
            ])
            skeleton.addArrangedSubview(bar)
        }
    }
}

private final class StatusPill: UIView {
    private let iconView = UIImageView()
    private let label = UILabel()
    private let solid: Bool

    init(solid: Bool) {
        self.solid = solid
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = solid ? UIColor(white: 1, alpha: 0.96) : UIColor(white: 1, alpha: 0.20)
        layer.cornerCurve = .continuous
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .footnote, scale: .medium)
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        iconView.setContentCompressionResistancePriority(.required, for: .horizontal)
        iconView.hideFromAccessibility()
        label.apply(.footnote, color: solid ? UIColor(hex: 0x15121F) : .white)
        label.font = Theme.TextStyle.subhead.font
        let stack = UIStackView(arrangedSubviews: [iconView, label])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        stack.pinEdges(to: self, insets: UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = min(bounds.height / 2, Theme.Radius.lg)
    }

    func configure(text: String, symbol: String, tint: UIColor) {
        label.text = text
        iconView.image = UIImage(systemName: symbol)
        iconView.tintColor = tint
    }
}
