import UIKit
import Combine

class CreditsMainViewController: UIViewController {
    private let viewModel: CreditsViewModel
    private var cancellables = Set<AnyCancellable>()
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private var contentWidthConstraint: NSLayoutConstraint!
    private var contentLeadingConstraint: NSLayoutConstraint!
    private var contentTrailingConstraint: NSLayoutConstraint!
    
    private let balanceCard = UIView()
    private let balanceSkeletonLoader = BalanceSkeletonLoaderView()
    private let balanceLabel = UILabel()
    private let balanceTitleLabel = UILabel()
    private let balanceAmountLabel = UILabel()
    private let creditsLabel = UILabel()
    
    private let quickActionsLabel = UILabel()
    private let quickActionsStackView = UIStackView()
    
    private let featuresLabel = UILabel()
    private let featuresStackView = UIStackView()
    
    private let recentTransactionsCard = UIView()
    private let recentTransactionsStackView = UIStackView()
    
    private let tipsCard = UIView()
    private let tipsLabel = UILabel()
    
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
        viewModel.refresh()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.refresh()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Update gradient layer frame
        if let gradientLayer = balanceCard.layer.value(forKey: "gradientLayer") as? CAGradientLayer {
            gradientLayer.frame = balanceCard.bounds
        }
    }
    
    private func setupUI() {
        title = "Credits & Usage"
        view.backgroundColor = .systemBackground
        navigationItem.largeTitleDisplayMode = .never
        
        setupScrollView()
        setupBalanceCard()
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
        
        let layout = AdaptiveLayout(traitCollection: traitCollection)
        let insets = layout.contentInsets
        
        if UIDevice.isPad && traitCollection.horizontalSizeClass == .regular {
            contentWidthConstraint = contentView.widthAnchor.constraint(equalToConstant: min(600, view.bounds.width - insets.left - insets.right))
            contentLeadingConstraint = contentView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor)
            contentTrailingConstraint = contentView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor)
            
            NSLayoutConstraint.activate([
                scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                
                contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
                contentLeadingConstraint,
                contentTrailingConstraint,
                contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
                contentWidthConstraint
            ])
        } else {
            NSLayoutConstraint.activate([
                scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                
                contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
                contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
                contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
                contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
                contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
            ])
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.horizontalSizeClass != previousTraitCollection?.horizontalSizeClass {
            updateLayoutForSizeClass()
        }
    }
    
    private func updateLayoutForSizeClass() {
        if UIDevice.isPad && traitCollection.horizontalSizeClass == .regular {
            if contentWidthConstraint == nil {
                view.setNeedsLayout()
            }
        }
    }
    
    private func setupBalanceCard() {
        balanceCard.backgroundColor = .secondarySystemBackground
        balanceCard.layer.cornerRadius = 20
        balanceCard.layer.shadowColor = UIColor.black.cgColor
        balanceCard.layer.shadowOpacity = 0.08
        balanceCard.layer.shadowOffset = CGSize(width: 0, height: 4)
        balanceCard.layer.shadowRadius = 12
        balanceCard.translatesAutoresizingMaskIntoConstraints = false
        
        // Add gradient background
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.systemPurple.withAlphaComponent(0.1).cgColor,
            UIColor.systemPurple.withAlphaComponent(0.05).cgColor
        ]
        gradientLayer.locations = [0, 1]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = 20
        balanceCard.layer.insertSublayer(gradientLayer, at: 0)
        
        // Store gradient layer reference for layout updates
        balanceCard.layer.setValue(gradientLayer, forKey: "gradientLayer")
        
        balanceTitleLabel.text = "Current Balance"
        balanceTitleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        balanceTitleLabel.textColor = .secondaryLabel
        balanceTitleLabel.textAlignment = .center
        balanceTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        balanceAmountLabel.font = .systemFont(ofSize: 48, weight: .bold)
        balanceAmountLabel.textAlignment = .center
        balanceAmountLabel.translatesAutoresizingMaskIntoConstraints = false
        
        creditsLabel.text = "credits"
        creditsLabel.font = .systemFont(ofSize: 22, weight: .medium)
        creditsLabel.textColor = .secondaryLabel
        creditsLabel.translatesAutoresizingMaskIntoConstraints = false
        
        balanceSkeletonLoader.translatesAutoresizingMaskIntoConstraints = false
        
        balanceCard.addSubview(balanceTitleLabel)
        balanceCard.addSubview(balanceAmountLabel)
        balanceCard.addSubview(creditsLabel)
        balanceCard.addSubview(balanceSkeletonLoader)
    }
    
    private func setupQuickActions() {
        quickActionsLabel.text = "Quick Actions"
        quickActionsLabel.font = .systemFont(ofSize: 18, weight: .bold)
        quickActionsLabel.translatesAutoresizingMaskIntoConstraints = false
        
        quickActionsStackView.axis = .horizontal
        quickActionsStackView.distribution = .fillEqually
        quickActionsStackView.spacing = 8
        quickActionsStackView.translatesAutoresizingMaskIntoConstraints = false
        
        let buyCreditsCard = createQuickActionCard(
            icon: UIImage(systemName: "wallet.pass"),
            title: "Buy Credits",
            subtitle: "View packs"
        ) { [weak self] in
            self?.navigateToCreditPacks()
        }
        
        let estimateCard = createQuickActionCard(
            icon: UIImage(systemName: "function"),
            title: "Estimate",
            subtitle: "Calculate cost"
        ) { [weak self] in
            self?.navigateToEstimator()
        }
        
        quickActionsStackView.addArrangedSubview(buyCreditsCard)
        quickActionsStackView.addArrangedSubview(estimateCard)
    }
    
    private func setupFeatures() {
        featuresLabel.text = "Features"
        featuresLabel.font = .systemFont(ofSize: 18, weight: .bold)
        featuresLabel.translatesAutoresizingMaskIntoConstraints = false
        
        featuresStackView.axis = .vertical
        featuresStackView.spacing = 12
        featuresStackView.translatesAutoresizingMaskIntoConstraints = false
        
        let historyCard = createFeatureCard(
            icon: UIImage(systemName: "clock"),
            title: "Transaction History",
            description: "See all your credit transactions"
        ) { [weak self] in
            self?.navigateToHistory()
        }
        
        let packsCard = createFeatureCard(
            icon: UIImage(systemName: "cart"),
            title: "Credit Packs",
            description: "Browse and purchase credit packs"
        ) { [weak self] in
            self?.navigateToCreditPacks()
        }
        
        let estimatorCard = createFeatureCard(
            icon: UIImage(systemName: "function"),
            title: "Cost Estimator",
            description: "Calculate costs before generating images"
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
        titleLabel.text = "Recent Transactions"
        titleLabel.font = .systemFont(ofSize: 16, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let viewAllButton = UIButton(type: .system)
        viewAllButton.setTitle("View All", for: .normal)
        viewAllButton.titleLabel?.font = .systemFont(ofSize: 14)
        viewAllButton.addTarget(self, action: #selector(viewAllTransactionsTapped), for: .touchUpInside)
        viewAllButton.translatesAutoresizingMaskIntoConstraints = false
        
        headerView.addSubview(titleLabel)
        headerView.addSubview(viewAllButton)
        
        recentTransactionsStackView.axis = .vertical
        recentTransactionsStackView.spacing = 8
        recentTransactionsStackView.translatesAutoresizingMaskIntoConstraints = false
        
        recentTransactionsCard.addSubview(headerView)
        recentTransactionsCard.addSubview(recentTransactionsStackView)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: recentTransactionsCard.topAnchor, constant: 16),
            headerView.leadingAnchor.constraint(equalTo: recentTransactionsCard.leadingAnchor, constant: 16),
            headerView.trailingAnchor.constraint(equalTo: recentTransactionsCard.trailingAnchor, constant: -16),
            headerView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            viewAllButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            viewAllButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            recentTransactionsStackView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 8),
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
        tipText.append(NSAttributedString(string: "Tip: ", attributes: [.font: UIFont.systemFont(ofSize: 14, weight: .bold)]))
        tipText.append(NSAttributedString(string: "View transaction history to see recent credit usage\nBrowse credit packs to purchase more credits", attributes: [.font: UIFont.systemFont(ofSize: 14)]))
        tipLabel.attributedText = tipText
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
        contentView.addSubview(balanceCard)
        contentView.addSubview(quickActionsLabel)
        contentView.addSubview(quickActionsStackView)
        contentView.addSubview(featuresLabel)
        contentView.addSubview(featuresStackView)
        contentView.addSubview(recentTransactionsCard)
        contentView.addSubview(tipsCard)
        
        NSLayoutConstraint.activate([
            balanceCard.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            balanceCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            balanceCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            balanceCard.heightAnchor.constraint(equalToConstant: 140),
            
            balanceTitleLabel.centerXAnchor.constraint(equalTo: balanceCard.centerXAnchor),
            balanceTitleLabel.topAnchor.constraint(equalTo: balanceCard.topAnchor, constant: 20),
            
            balanceAmountLabel.centerXAnchor.constraint(equalTo: balanceCard.centerXAnchor),
            balanceAmountLabel.topAnchor.constraint(equalTo: balanceTitleLabel.bottomAnchor, constant: 8),
            
            creditsLabel.leadingAnchor.constraint(equalTo: balanceAmountLabel.trailingAnchor, constant: 8),
            creditsLabel.bottomAnchor.constraint(equalTo: balanceAmountLabel.bottomAnchor, constant: -8),
            
            balanceSkeletonLoader.centerXAnchor.constraint(equalTo: balanceCard.centerXAnchor),
            balanceSkeletonLoader.centerYAnchor.constraint(equalTo: balanceCard.centerYAnchor),
            
            quickActionsLabel.topAnchor.constraint(equalTo: balanceCard.bottomAnchor, constant: 24),
            quickActionsLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
            quickActionsStackView.topAnchor.constraint(equalTo: quickActionsLabel.bottomAnchor, constant: 12),
            quickActionsStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            quickActionsStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            quickActionsStackView.heightAnchor.constraint(equalToConstant: 120),
            
            featuresLabel.topAnchor.constraint(equalTo: quickActionsStackView.bottomAnchor, constant: 24),
            featuresLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
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
    
    private func bindViewModel() {
        viewModel.$isLoadingBalance
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                self?.updateBalanceCard(isLoading: isLoading)
            }
            .store(in: &cancellables)
        
        viewModel.$balance
            .receive(on: DispatchQueue.main)
            .sink { [weak self] balance in
                self?.updateBalance(balance)
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
    }
    
    private func updateBalanceCard(isLoading: Bool) {
        balanceSkeletonLoader.isHidden = !isLoading
        balanceTitleLabel.isHidden = isLoading
        balanceAmountLabel.isHidden = isLoading
        creditsLabel.isHidden = isLoading
        
        if isLoading {
            balanceSkeletonLoader.startAnimating()
        } else {
            balanceSkeletonLoader.stopAnimating()
        }
    }
    
    private func updateBalance(_ balance: CreditBalance?) {
        guard let balance = balance else { return }
        
        balanceAmountLabel.text = "\(balance.balance)"
        balanceAmountLabel.textColor = balance.getBalanceColor()
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
        guard showWarning else { return }
        
        // Animate the balance card to grab attention
        UIView.animate(withDuration: 0.3, animations: {
            self.balanceCard.transform = CGAffineTransform(scaleX: 1.02, y: 1.02)
        }) { _ in
            UIView.animate(withDuration: 0.3) {
                self.balanceCard.transform = .identity
            }
        }
        
        // Add haptic feedback
        HapticsManager.shared.notification(.warning)
    }
    
    private func createTransactionView(_ transaction: CreditTransaction) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let descriptionLabel = UILabel()
        descriptionLabel.text = transaction.description
        descriptionLabel.font = .systemFont(ofSize: 14)
        descriptionLabel.textColor = .label
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let amountLabel = UILabel()
        let isSpend = transaction.transactionType == "spend"
        amountLabel.text = "\(isSpend ? "-" : "+")\(transaction.amount)"
        amountLabel.font = .systemFont(ofSize: 14, weight: .medium)
        amountLabel.textColor = isSpend ? .systemRed : .systemPurple
        amountLabel.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(descriptionLabel)
        container.addSubview(amountLabel)
        
        NSLayoutConstraint.activate([
            descriptionLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            descriptionLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            descriptionLabel.trailingAnchor.constraint(lessThanOrEqualTo: amountLabel.leadingAnchor, constant: -8),
            
            amountLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            amountLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            container.heightAnchor.constraint(equalToConstant: 20)
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
        
        let iconContainer = UIView()
        iconContainer.backgroundColor = .systemPurple.withAlphaComponent(0.15)
        iconContainer.layer.cornerRadius = 14
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.isUserInteractionEnabled = false
        
        let iconImageView = UIImageView(image: icon)
        iconImageView.tintColor = .systemPurple
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.isUserInteractionEnabled = false
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
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
            subtitleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8)
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
        
        let iconImageView = UIImageView(image: icon)
        iconImageView.tintColor = .systemPurple
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.isUserInteractionEnabled = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.isUserInteractionEnabled = false
        
        let descriptionLabel = UILabel()
        descriptionLabel.text = description
        descriptionLabel.font = .systemFont(ofSize: 14)
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
        
        UIView.animate(withDuration: 0.1, animations: {
            gesture.view?.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                gesture.view?.transform = .identity
            }
            
            if let card = gesture.view as? QuickActionCard {
                card.action()
            }
        }
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
        let creditPacksVC = CreditPacksViewController(viewModel: viewModel)
        navigationController?.pushViewController(creditPacksVC, animated: true)
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
}