import UIKit
import Combine

class CreditsMainViewController: UIViewController {
    private let viewModel: CreditsViewModel
    private var cancellables = Set<AnyCancellable>()
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private static let maxContentWidth: CGFloat = 600
    private static let freshnessRefreshInterval: TimeInterval = 30
    
    private let topStack = UIStackView()
    private let balanceCard = UIView()
    private let balanceSkeletonLoader = BalanceSkeletonLoaderView()
    private let balanceContentStack = UIStackView()
    private let balanceTitleLabel = UILabel()
    private let amountRow = UIStackView()
    private let balanceAmountLabel = UILabel()
    private let creditsLabel = UILabel()
    private let freeImagesLabel = UILabel()
    private let lowBalanceIcon = UIImageView()
    private let lowBalanceLabel = UILabel()
    private let lowBalanceStack = UIStackView()
    private let freshnessLabel = UILabel()
    
    private let errorBanner = UIView()
    private let errorStack = UIStackView()
    private let errorIcon = UIImageView()
    private let errorLabel = UILabel()
    private let retryButton = UIButton(type: .system)
    
    private let quickActionsLabel = UILabel()
    private let quickActionsStackView = UIStackView()
    
    private let featuresLabel = UILabel()
    private let featuresStackView = UIStackView()
    
    private let recentTransactionsCard = UIView()
    private let recentTransactionsStackView = UIStackView()
    
    private let tipsCard = UIView()
    private let tipsLabel = UILabel()
    
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
        if let gradientLayer = balanceCard.layer.value(forKey: "gradientLayer") as? CAGradientLayer {
            gradientLayer.frame = balanceCard.bounds
        }
        applyContentSizeLayout()
    }
    
    private func setupUI() {
        title = String(localized: "Credits & Usage")
        view.backgroundColor = .systemBackground
        navigationItem.largeTitleDisplayMode = .never
        
        setupScrollView()
        setupBalanceCard()
        setupErrorBanner()
        setupQuickActions()
        setupFeatures()
        setupRecentTransactions()
        setupTipsCard()
        
        layoutUI()
    }
    
    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        let fillWidth = contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        fillWidth.priority = .defaultHigh
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(lessThanOrEqualToConstant: Self.maxContentWidth),
            fillWidth
        ])
    }
    
    private func setupBalanceCard() {
        balanceCard.backgroundColor = .secondarySystemBackground
        balanceCard.layer.cornerRadius = 20
        balanceCard.layer.shadowColor = UIColor.black.cgColor
        balanceCard.layer.shadowOpacity = 0.08
        balanceCard.layer.shadowOffset = CGSize(width: 0, height: 4)
        balanceCard.layer.shadowRadius = 12
        balanceCard.translatesAutoresizingMaskIntoConstraints = false
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.brand.withAlphaComponent(0.1).cgColor,
            UIColor.brand.withAlphaComponent(0.05).cgColor
        ]
        gradientLayer.locations = [0, 1]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = 20
        balanceCard.layer.insertSublayer(gradientLayer, at: 0)
        balanceCard.layer.setValue(gradientLayer, forKey: "gradientLayer")
        
        balanceTitleLabel.text = String(localized: "Current Balance")
        balanceTitleLabel.useScaledFont(.callout, size: 16, weight: .medium)
        balanceTitleLabel.textColor = .secondaryLabel
        balanceTitleLabel.textAlignment = .center
        balanceTitleLabel.numberOfLines = 0
        
        balanceAmountLabel.useScaledFont(.largeTitle, size: 48, weight: .bold)
        balanceAmountLabel.textColor = .label
        balanceAmountLabel.textAlignment = .center
        balanceAmountLabel.adjustsFontSizeToFitWidth = true
        balanceAmountLabel.minimumScaleFactor = 0.5
        balanceAmountLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        
        creditsLabel.text = String(localized: "credits")
        creditsLabel.useScaledFont(.title2, size: 22, weight: .medium)
        creditsLabel.textColor = .secondaryLabel
        creditsLabel.setContentHuggingPriority(.required, for: .horizontal)
        
        amountRow.axis = .horizontal
        amountRow.alignment = .lastBaseline
        amountRow.spacing = 8
        amountRow.addArrangedSubview(balanceAmountLabel)
        amountRow.addArrangedSubview(creditsLabel)
        
        freeImagesLabel.useScaledFont(.footnote, size: 13, weight: .semibold)
        freeImagesLabel.textColor = .brandText
        freeImagesLabel.textAlignment = .center
        freeImagesLabel.numberOfLines = 0
        freeImagesLabel.isHidden = true
        
        lowBalanceIcon.image = UIImage(systemName: "exclamationmark.triangle.fill")
        lowBalanceIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .footnote)
        lowBalanceIcon.contentMode = .scaleAspectFit
        lowBalanceIcon.setContentHuggingPriority(.required, for: .horizontal)
        lowBalanceLabel.useScaledFont(.footnote, size: 13, weight: .semibold)
        lowBalanceLabel.textColor = .label
        lowBalanceLabel.numberOfLines = 0
        lowBalanceStack.axis = .horizontal
        lowBalanceStack.alignment = .firstBaseline
        lowBalanceStack.spacing = 6
        lowBalanceStack.addArrangedSubview(lowBalanceIcon)
        lowBalanceStack.addArrangedSubview(lowBalanceLabel)
        lowBalanceStack.isHidden = true
        
        freshnessLabel.useScaledFont(.caption1, size: 12)
        freshnessLabel.textColor = .secondaryLabel
        freshnessLabel.textAlignment = .center
        freshnessLabel.numberOfLines = 0
        freshnessLabel.isHidden = true
        
        balanceContentStack.axis = .vertical
        balanceContentStack.alignment = .center
        balanceContentStack.spacing = 6
        balanceContentStack.translatesAutoresizingMaskIntoConstraints = false
        balanceContentStack.addArrangedSubview(balanceTitleLabel)
        balanceContentStack.addArrangedSubview(amountRow)
        balanceContentStack.addArrangedSubview(freeImagesLabel)
        balanceContentStack.addArrangedSubview(lowBalanceStack)
        balanceContentStack.addArrangedSubview(freshnessLabel)
        balanceContentStack.setCustomSpacing(10, after: amountRow)
        
        balanceSkeletonLoader.translatesAutoresizingMaskIntoConstraints = false
        balanceSkeletonLoader.hideFromAccessibility()
        
        balanceCard.addSubview(balanceContentStack)
        balanceCard.addSubview(balanceSkeletonLoader)
    }
    
    private func setupErrorBanner() {
        errorBanner.backgroundColor = .secondarySystemBackground
        errorBanner.layer.cornerRadius = 16
        errorBanner.layer.borderWidth = 1
        errorBanner.layer.borderColor = UIColor.separator.cgColor
        errorBanner.isHidden = true
        
        errorIcon.image = UIImage(systemName: "exclamationmark.triangle.fill")
        errorIcon.tintColor = .systemOrange
        errorIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .body)
        errorIcon.contentMode = .scaleAspectFit
        errorIcon.setContentHuggingPriority(.required, for: .horizontal)
        errorIcon.hideFromAccessibility()
        
        errorLabel.text = String(localized: "Couldn't refresh your balance")
        errorLabel.useScaledFont(.subheadline, size: 15, weight: .medium)
        errorLabel.textColor = .label
        errorLabel.numberOfLines = 0
        
        var config = UIButton.Configuration.filled()
        config.title = String(localized: "Retry")
        config.baseBackgroundColor = .brand
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 18, bottom: 10, trailing: 18)
        retryButton.configuration = config
        retryButton.addAction(UIAction { [weak self] _ in self?.retryBalance() }, for: .touchUpInside)
        retryButton.setContentHuggingPriority(.required, for: .horizontal)
        retryButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        errorStack.axis = .horizontal
        errorStack.alignment = .center
        errorStack.spacing = 10
        errorStack.translatesAutoresizingMaskIntoConstraints = false
        errorStack.addArrangedSubview(errorIcon)
        errorStack.addArrangedSubview(errorLabel)
        errorStack.addArrangedSubview(retryButton)
        errorBanner.addSubview(errorStack)
        
        NSLayoutConstraint.activate([
            errorStack.topAnchor.constraint(equalTo: errorBanner.topAnchor, constant: 12),
            errorStack.leadingAnchor.constraint(equalTo: errorBanner.leadingAnchor, constant: 14),
            errorStack.trailingAnchor.constraint(equalTo: errorBanner.trailingAnchor, constant: -14),
            errorStack.bottomAnchor.constraint(equalTo: errorBanner.bottomAnchor, constant: -12),
            retryButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }
    
    private func setupQuickActions() {
        quickActionsLabel.text = String(localized: "Quick Actions")
        quickActionsLabel.useScaledFont(.title3, size: 18, weight: .bold)
        quickActionsLabel.numberOfLines = 0
        quickActionsLabel.accessibilityTraits = .header
        quickActionsLabel.translatesAutoresizingMaskIntoConstraints = false
        
        quickActionsStackView.axis = .horizontal
        quickActionsStackView.distribution = .fillEqually
        quickActionsStackView.spacing = 8
        quickActionsStackView.translatesAutoresizingMaskIntoConstraints = false
        
        let buyCreditsCard = createQuickActionCard(
            icon: UIImage(systemName: "wallet.pass"),
            title: String(localized: "Buy Credits"),
            subtitle: String(localized: "View packs")
        ) { [weak self] in
            self?.navigateToCreditPacks()
        }
        
        let estimateCard = createQuickActionCard(
            icon: UIImage(systemName: "function"),
            title: String(localized: "Estimate"),
            subtitle: String(localized: "Calculate cost")
        ) { [weak self] in
            self?.navigateToEstimator()
        }
        
        quickActionsStackView.addArrangedSubview(buyCreditsCard)
        quickActionsStackView.addArrangedSubview(estimateCard)
    }
    
    private func setupFeatures() {
        featuresLabel.text = String(localized: "Features")
        featuresLabel.useScaledFont(.title3, size: 18, weight: .bold)
        featuresLabel.numberOfLines = 0
        featuresLabel.accessibilityTraits = .header
        featuresLabel.translatesAutoresizingMaskIntoConstraints = false
        
        featuresStackView.axis = .vertical
        featuresStackView.spacing = 12
        featuresStackView.translatesAutoresizingMaskIntoConstraints = false
        
        let historyCard = createFeatureCard(
            icon: UIImage(systemName: "clock"),
            title: String(localized: "Transaction History"),
            description: String(localized: "See all your credit transactions")
        ) { [weak self] in
            self?.navigateToHistory()
        }
        
        let packsCard = createFeatureCard(
            icon: UIImage(systemName: "cart"),
            title: String(localized: "Credit Packs"),
            description: String(localized: "Browse and purchase credit packs")
        ) { [weak self] in
            self?.navigateToCreditPacks()
        }
        
        let estimatorCard = createFeatureCard(
            icon: UIImage(systemName: "function"),
            title: String(localized: "Cost Estimator"),
            description: String(localized: "Calculate costs before generating images")
        ) { [weak self] in
            self?.navigateToEstimator()
        }
        
        featuresStackView.addArrangedSubview(historyCard)
        featuresStackView.addArrangedSubview(packsCard)
        featuresStackView.addArrangedSubview(estimatorCard)
    }
    
    private func setupRecentTransactions() {
        recentTransactionsCard.backgroundColor = .tertiarySystemBackground
        recentTransactionsCard.layer.cornerRadius = 12
        recentTransactionsCard.translatesAutoresizingMaskIntoConstraints = false
        recentTransactionsCard.isHidden = true
        
        let headerView = UIView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = String(localized: "Recent Transactions")
        titleLabel.useScaledFont(.callout, size: 16, weight: .bold)
        titleLabel.numberOfLines = 0
        titleLabel.accessibilityTraits = .header
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        var viewAllConfig = UIButton.Configuration.plain()
        viewAllConfig.title = String(localized: "View All")
        viewAllConfig.baseForegroundColor = .brandText
        viewAllConfig.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 0)
        viewAllConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.scaled(.subheadline, size: 14)
            return outgoing
        }
        let viewAllButton = UIButton(configuration: viewAllConfig)
        viewAllButton.addTarget(self, action: #selector(viewAllTransactionsTapped), for: .touchUpInside)
        viewAllButton.setContentHuggingPriority(.required, for: .horizontal)
        viewAllButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        viewAllButton.translatesAutoresizingMaskIntoConstraints = false
        
        headerView.addSubview(titleLabel)
        headerView.addSubview(viewAllButton)
        
        recentTransactionsStackView.axis = .vertical
        recentTransactionsStackView.spacing = 8
        recentTransactionsStackView.translatesAutoresizingMaskIntoConstraints = false
        
        recentTransactionsCard.addSubview(headerView)
        recentTransactionsCard.addSubview(recentTransactionsStackView)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: recentTransactionsCard.topAnchor, constant: 8),
            headerView.leadingAnchor.constraint(equalTo: recentTransactionsCard.leadingAnchor, constant: 16),
            headerView.trailingAnchor.constraint(equalTo: recentTransactionsCard.trailingAnchor, constant: -16),
            
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 4),
            titleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -4),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: viewAllButton.leadingAnchor, constant: -8),
            
            viewAllButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            viewAllButton.topAnchor.constraint(greaterThanOrEqualTo: headerView.topAnchor),
            viewAllButton.bottomAnchor.constraint(lessThanOrEqualTo: headerView.bottomAnchor),
            viewAllButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            viewAllButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            headerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            
            recentTransactionsStackView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 4),
            recentTransactionsStackView.leadingAnchor.constraint(equalTo: recentTransactionsCard.leadingAnchor, constant: 16),
            recentTransactionsStackView.trailingAnchor.constraint(equalTo: recentTransactionsCard.trailingAnchor, constant: -16),
            recentTransactionsStackView.bottomAnchor.constraint(equalTo: recentTransactionsCard.bottomAnchor, constant: -16)
        ])
    }
    
    private func setupTipsCard() {
        tipsCard.backgroundColor = .systemBackground
        tipsCard.layer.cornerRadius = 12
        tipsCard.layer.borderWidth = 1
        tipsCard.layer.borderColor = UIColor.separator.cgColor
        tipsCard.translatesAutoresizingMaskIntoConstraints = false
        
        let tipLabel = UILabel()
        let tipText = NSMutableAttributedString()
        tipText.append(NSAttributedString(string: String(localized: "Tip: "), attributes: [.font: UIFont.scaled(.subheadline, size: 14, weight: .bold)]))
        tipText.append(NSAttributedString(string: String(localized: "View transaction history to see recent credit usage\nBrowse credit packs to purchase more credits"), attributes: [.font: UIFont.scaled(.subheadline, size: 14)]))
        tipLabel.attributedText = tipText
        tipLabel.adjustsFontForContentSizeCategory = true
        tipLabel.numberOfLines = 0
        tipLabel.textColor = .secondaryLabel
        tipLabel.translatesAutoresizingMaskIntoConstraints = false
        
        tipsCard.addSubview(tipLabel)
        
        NSLayoutConstraint.activate([
            tipLabel.topAnchor.constraint(equalTo: tipsCard.topAnchor, constant: 16),
            tipLabel.leadingAnchor.constraint(equalTo: tipsCard.leadingAnchor, constant: 16),
            tipLabel.trailingAnchor.constraint(equalTo: tipsCard.trailingAnchor, constant: -16),
            tipLabel.bottomAnchor.constraint(equalTo: tipsCard.bottomAnchor, constant: -16)
        ])
    }
    
    private func layoutUI() {
        topStack.axis = .vertical
        topStack.spacing = 12
        topStack.translatesAutoresizingMaskIntoConstraints = false
        topStack.addArrangedSubview(balanceCard)
        topStack.addArrangedSubview(errorBanner)
        
        contentView.addSubview(topStack)
        contentView.addSubview(quickActionsLabel)
        contentView.addSubview(quickActionsStackView)
        contentView.addSubview(featuresLabel)
        contentView.addSubview(featuresStackView)
        contentView.addSubview(recentTransactionsCard)
        contentView.addSubview(tipsCard)
        
        NSLayoutConstraint.activate([
            topStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            topStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            topStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            balanceCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 140),
            
            balanceContentStack.topAnchor.constraint(equalTo: balanceCard.topAnchor, constant: 20),
            balanceContentStack.bottomAnchor.constraint(equalTo: balanceCard.bottomAnchor, constant: -16),
            balanceContentStack.leadingAnchor.constraint(equalTo: balanceCard.leadingAnchor, constant: 16),
            balanceContentStack.trailingAnchor.constraint(equalTo: balanceCard.trailingAnchor, constant: -16),
            
            balanceSkeletonLoader.centerXAnchor.constraint(equalTo: balanceCard.centerXAnchor),
            balanceSkeletonLoader.centerYAnchor.constraint(equalTo: balanceCard.centerYAnchor),
            
            quickActionsLabel.topAnchor.constraint(equalTo: topStack.bottomAnchor, constant: 24),
            quickActionsLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            quickActionsLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            quickActionsStackView.topAnchor.constraint(equalTo: quickActionsLabel.bottomAnchor, constant: 12),
            quickActionsStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            quickActionsStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            quickActionsStackView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),
            
            featuresLabel.topAnchor.constraint(equalTo: quickActionsStackView.bottomAnchor, constant: 24),
            featuresLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            featuresLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            featuresStackView.topAnchor.constraint(equalTo: featuresLabel.bottomAnchor, constant: 12),
            featuresStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            featuresStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            recentTransactionsCard.topAnchor.constraint(equalTo: featuresStackView.bottomAnchor, constant: 16),
            recentTransactionsCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            recentTransactionsCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            tipsCard.topAnchor.constraint(equalTo: recentTransactionsCard.bottomAnchor, constant: 16),
            tipsCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            tipsCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            tipsCard.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32)
        ])
    }
    
    /// Stacks the side-by-side rows vertically at accessibility text sizes so nothing is squeezed or clipped.
    private func applyContentSizeLayout() {
        let isAccessibilitySize = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        let amountAxis: NSLayoutConstraint.Axis = isAccessibilitySize ? .vertical : .horizontal
        if amountRow.axis != amountAxis {
            amountRow.axis = amountAxis
            amountRow.alignment = isAccessibilitySize ? .center : .lastBaseline
        }
        if quickActionsStackView.axis != amountAxis {
            quickActionsStackView.axis = amountAxis
            quickActionsStackView.distribution = isAccessibilitySize ? .fill : .fillEqually
        }
        if errorStack.axis != amountAxis {
            errorStack.axis = amountAxis
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
        
        balanceSkeletonLoader.isHidden = !isLoadingFirstBalance
        balanceContentStack.isHidden = isLoadingFirstBalance
        if isLoadingFirstBalance && !Motion.isReduced {
            balanceSkeletonLoader.startAnimating()
        } else {
            balanceSkeletonLoader.stopAnimating()
        }
        
        balanceAmountLabel.text = balance.map { Self.formatted($0.balance) } ?? "–"
        updateStatusLines(for: balance)
        updateFreshness()
        updateErrorBanner()
        updateBalanceAccessibility(isLoading: isLoadingFirstBalance)
    }
    
    private func updateStatusLines(for balance: CreditBalance?) {
        guard let balance else {
            freeImagesLabel.isHidden = true
            lowBalanceStack.isHidden = true
            return
        }
        
        let freeImages = freeImagesLeft(for: balance.balance)
        freeImagesLabel.text = freeImages.map { String(localized: "\($0) free images left") }
        freeImagesLabel.isHidden = freeImages == nil
        
        let lowText = lowBalanceText(for: balance.balance)
        lowBalanceLabel.text = lowText
        lowBalanceIcon.tintColor = balance.balance == 0 ? .systemRed : .systemOrange
        lowBalanceStack.isHidden = lowText == nil
    }
    
    /// Whole images still covered by the welcome grant, or nil once the person bought credits or has none left.
    private func freeImagesLeft(for balance: Int) -> Int? {
        guard WelcomeCredits().isOnWelcomeGrant(balance: balance) else { return nil }
        let images = WelcomeCredits.freeImages(balance: balance, imageCost: CreditStoreViewController.defaultImageCreditCost)
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
        let text = freshnessText()
        freshnessLabel.text = text
        freshnessLabel.isHidden = text == nil
        if viewModel.balance != nil {
            updateBalanceAccessibility(isLoading: false)
        }
    }
    
    private func updateErrorBanner() {
        let shouldShow = viewModel.balanceErrorMessage != nil
        errorBanner.isHidden = !shouldShow
        retryButton.isEnabled = !viewModel.isLoadingBalance
        retryButton.configuration?.showsActivityIndicator = viewModel.isLoadingBalance
        
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
            balanceCard.describe(label, traits: .staticText)
            return
        }
        let value = [
            freeImagesLabel.isHidden ? nil : freeImagesLabel.text,
            lowBalanceStack.isHidden ? nil : lowBalanceLabel.text,
            freshnessLabel.isHidden ? nil : freshnessLabel.text
        ].compactMap { $0 }.joined(separator: ", ")
        balanceCard.describe(
            String(localized: "Balance: \(Self.formatted(balance.balance)) credits"),
            value: value.isEmpty ? nil : value,
            traits: .staticText
        )
    }
    
    private static func formatted(_ value: Int) -> String {
        NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
    }
    
    private func updateRecentTransactions(_ transactions: [CreditTransaction]) {
        recentTransactionsCard.isHidden = transactions.isEmpty
        
        recentTransactionsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        for transaction in transactions.prefix(3) {
            let transactionView = createTransactionView(transaction)
            recentTransactionsStackView.addArrangedSubview(transactionView)
        }
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
            self.balanceCard.transform = CGAffineTransform(scaleX: 1.02, y: 1.02)
        }, completion: { _ in
            Motion.animate(0.3) {
                self.balanceCard.transform = .identity
            }
        })
    }
    
    private func createTransactionView(_ transaction: CreditTransaction) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.describe(
            "\(transaction.kindName), \(transaction.description)",
            value: transaction.spokenAmount,
            traits: .staticText
        )
        
        let descriptionLabel = UILabel()
        descriptionLabel.text = transaction.description
        descriptionLabel.useScaledFont(.subheadline, size: 14)
        descriptionLabel.textColor = .label
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let amountLabel = UILabel()
        amountLabel.text = transaction.signedAmountText
        amountLabel.useScaledFont(.subheadline, size: 14, weight: .medium)
        amountLabel.textColor = transaction.isDebit ? .label : .brandText
        amountLabel.setContentHuggingPriority(.required, for: .horizontal)
        amountLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        amountLabel.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(descriptionLabel)
        container.addSubview(amountLabel)
        
        NSLayoutConstraint.activate([
            descriptionLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            descriptionLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 2),
            descriptionLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -2),
            descriptionLabel.trailingAnchor.constraint(lessThanOrEqualTo: amountLabel.leadingAnchor, constant: -8),
            
            amountLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            amountLabel.firstBaselineAnchor.constraint(equalTo: descriptionLabel.firstBaselineAnchor)
        ])
        
        return container
    }
    
    private func createQuickActionCard(icon: UIImage?, title: String, subtitle: String, action: @escaping () -> Void) -> UIView {
        let card = QuickActionCard(action: action)
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 16
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.06
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.layer.shadowRadius = 8
        card.translatesAutoresizingMaskIntoConstraints = false
        card.describe(title, hint: subtitle, traits: .button)
        
        let iconContainer = UIView()
        iconContainer.backgroundColor = .brandTint
        iconContainer.layer.cornerRadius = 14
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.isUserInteractionEnabled = false
        
        let iconImageView = UIImageView(image: icon)
        iconImageView.tintColor = .brandText
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.useScaledFont(.callout, size: 16, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.isUserInteractionEnabled = false
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.useScaledFont(.caption1, size: 12)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.isUserInteractionEnabled = false
        
        iconContainer.addSubview(iconImageView)
        card.addSubview(iconContainer)
        card.addSubview(titleLabel)
        card.addSubview(subtitleLabel)
        
        NSLayoutConstraint.activate([
            iconContainer.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            iconContainer.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 48),
            iconContainer.heightAnchor.constraint(equalToConstant: 48),
            
            iconImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.topAnchor.constraint(equalTo: iconContainer.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            subtitleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            subtitleLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(quickActionTapped(_:)))
        card.addGestureRecognizer(tapGesture)
        
        return card
    }
    
    private func createFeatureCard(icon: UIImage?, title: String, description: String, action: @escaping () -> Void) -> UIView {
        let card = FeatureCard(action: action)
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = 12
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor.separator.cgColor
        card.translatesAutoresizingMaskIntoConstraints = false
        card.describe(title, hint: description, traits: .button)
        
        let iconImageView = UIImageView(image: icon)
        iconImageView.tintColor = .brandText
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.isUserInteractionEnabled = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.useScaledFont(.callout, size: 16, weight: .medium)
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.isUserInteractionEnabled = false
        
        let descriptionLabel = UILabel()
        descriptionLabel.text = description
        descriptionLabel.useScaledFont(.subheadline, size: 14)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.isUserInteractionEnabled = false
        
        let chevronImageView = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevronImageView.tintColor = .tertiaryLabel
        chevronImageView.contentMode = .scaleAspectFit
        chevronImageView.translatesAutoresizingMaskIntoConstraints = false
        chevronImageView.isUserInteractionEnabled = false
        
        card.addSubview(iconImageView)
        card.addSubview(titleLabel)
        card.addSubview(descriptionLabel)
        card.addSubview(chevronImageView)
        
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            iconImageView.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 40),
            iconImageView.heightAnchor.constraint(equalToConstant: 40),
            
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: chevronImageView.leadingAnchor, constant: -8),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            descriptionLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            
            chevronImageView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            chevronImageView.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 12),
            chevronImageView.heightAnchor.constraint(equalToConstant: 20),
            
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 72)
        ])
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(featureTapped(_:)))
        card.addGestureRecognizer(tapGesture)
        
        return card
    }
    
    @objc private func quickActionTapped(_ gesture: UITapGestureRecognizer) {
        HapticsManager.shared.impact(.light)
        
        Motion.animate(0.1, animations: {
            gesture.view?.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }, completion: { _ in
            Motion.animate(0.1) {
                gesture.view?.transform = .identity
            }
            
            if let card = gesture.view as? QuickActionCard {
                card.action()
            }
        })
    }
    
    @objc private func featureTapped(_ gesture: UITapGestureRecognizer) {
        HapticsManager.shared.selection()
        if let card = gesture.view as? FeatureCard {
            card.action()
        }
    }
    
    @objc private func viewAllTransactionsTapped() {
        HapticsManager.shared.selection()
        navigateToHistory()
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

class BalanceSkeletonLoaderView: UIView {
    private let shimmerLayer = CAGradientLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupShimmer()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupShimmer() {
        let titleBox = UIView()
        titleBox.backgroundColor = .systemGray5
        titleBox.layer.cornerRadius = 4
        titleBox.translatesAutoresizingMaskIntoConstraints = false
        
        let amountBox = UIView()
        amountBox.backgroundColor = .systemGray5
        amountBox.layer.cornerRadius = 4
        amountBox.translatesAutoresizingMaskIntoConstraints = false
        
        let creditsBox = UIView()
        creditsBox.backgroundColor = .systemGray5
        creditsBox.layer.cornerRadius = 4
        creditsBox.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(titleBox)
        addSubview(amountBox)
        addSubview(creditsBox)
        
        NSLayoutConstraint.activate([
            titleBox.topAnchor.constraint(equalTo: topAnchor),
            titleBox.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleBox.widthAnchor.constraint(equalToConstant: 120),
            titleBox.heightAnchor.constraint(equalToConstant: 20),
            
            amountBox.topAnchor.constraint(equalTo: titleBox.bottomAnchor, constant: 12),
            amountBox.centerXAnchor.constraint(equalTo: centerXAnchor, constant: -30),
            amountBox.widthAnchor.constraint(equalToConstant: 100),
            amountBox.heightAnchor.constraint(equalToConstant: 40),
            
            creditsBox.leadingAnchor.constraint(equalTo: amountBox.trailingAnchor, constant: 8),
            creditsBox.bottomAnchor.constraint(equalTo: amountBox.bottomAnchor, constant: -8),
            creditsBox.widthAnchor.constraint(equalToConstant: 60),
            creditsBox.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        shimmerLayer.colors = [
            UIColor.systemGray5.cgColor,
            UIColor.systemGray4.cgColor,
            UIColor.systemGray5.cgColor
        ]
        shimmerLayer.locations = [0, 0.5, 1]
        shimmerLayer.startPoint = CGPoint(x: 0, y: 0.5)
        shimmerLayer.endPoint = CGPoint(x: 1, y: 0.5)
        
        layer.mask = shimmerLayer
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        shimmerLayer.frame = bounds
    }
    
    func startAnimating() {
        guard !Motion.isReduced, shimmerLayer.animation(forKey: "shimmer") == nil else { return }
        let animation = CABasicAnimation(keyPath: "locations")
        animation.fromValue = [0, 0, 0.25]
        animation.toValue = [0.75, 1, 1]
        animation.duration = 1.5
        animation.repeatCount = .infinity
        shimmerLayer.add(animation, forKey: "shimmer")
    }
    
    func stopAnimating() {
        shimmerLayer.removeAllAnimations()
    }
}

private class QuickActionCard: UIView {
    let action: () -> Void
    
    init(action: @escaping () -> Void) {
        self.action = action
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func accessibilityActivate() -> Bool {
        HapticsManager.shared.impact(.light)
        action()
        return true
    }
}

private class FeatureCard: UIView {
    let action: () -> Void
    
    init(action: @escaping () -> Void) {
        self.action = action
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func accessibilityActivate() -> Bool {
        HapticsManager.shared.selection()
        action()
        return true
    }
}