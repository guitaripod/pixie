import UIKit

class AdminStatsViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let contentStackView = UIStackView()
    private let refreshControl = UIRefreshControl()
    private let haptics = HapticManager.shared
    
    private let userStatsCard = StatsCardView()
    private let creditStatsCard = StatsCardView()
    private let revenueStatsCard = StatsCardView()
    private let imageStatsCard = StatsCardView()
    
    private let adminRepository: AdminRepositoryProtocol
    private var systemStats: SystemStatsResponse?
    
    private let loadingView = UIActivityIndicatorView(style: .large)
    private let errorView = AdminInlineMessageView()
    
    init() {
        self.adminRepository = AdminRepository(networkService: AppContainer.shared.networkService)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupConstraints()
        loadStats()
    }
    
    private func setupUI() {
        title = String(localized: "System Statistics")
        view.backgroundColor = .systemGroupedBackground
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(refreshStats), for: .valueChanged)
        
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.axis = .vertical
        contentStackView.spacing = 16
        contentStackView.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        contentStackView.isLayoutMarginsRelativeArrangement = true
        
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.hidesWhenStopped = true
        
        errorView.translatesAutoresizingMaskIntoConstraints = false
        
        userStatsCard.configure(
            title: String(localized: "Users"),
            icon: UIImage(systemName: "person.2.fill"),
            color: .systemBlue
        )
        
        creditStatsCard.configure(
            title: String(localized: "Credits"),
            icon: UIImage(systemName: "creditcard.fill"),
            color: .systemGreen
        )
        
        revenueStatsCard.configure(
            title: String(localized: "Revenue"),
            icon: UIImage(systemName: "dollarsign.circle.fill"),
            color: .systemOrange
        )
        
        imageStatsCard.configure(
            title: String(localized: "Images"),
            icon: UIImage(systemName: "photo.fill"),
            color: .brandText
        )
        
        view.addSubview(scrollView)
        view.addSubview(loadingView)
        view.addSubview(errorView)
        
        scrollView.addSubview(contentStackView)
        
        contentStackView.addArrangedSubview(userStatsCard)
        contentStackView.addArrangedSubview(creditStatsCard)
        contentStackView.addArrangedSubview(revenueStatsCard)
        contentStackView.addArrangedSubview(imageStatsCard)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentStackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            errorView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 32),
            errorView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -32)
        ])
    }
    
    private func loadStats() {
        showLoading()
        
        Task {
            do {
                let stats = try await adminRepository.getSystemStats()
                await MainActor.run {
                    self.systemStats = stats
                    self.updateUI(with: stats)
                    self.hideLoading()
                }
            } catch {
                await MainActor.run {
                    self.showError(error.localizedDescription)
                    self.hideLoading()
                }
            }
        }
    }
    
    @objc private func refreshStats() {
        Task {
            do {
                let stats = try await adminRepository.getSystemStats()
                await MainActor.run {
                    self.systemStats = stats
                    self.updateUI(with: stats)
                    self.errorView.hide()
                    self.scrollView.isHidden = false
                    self.refreshControl.endRefreshing()
                }
            } catch {
                await MainActor.run {
                    self.showError(error.localizedDescription)
                    self.refreshControl.endRefreshing()
                }
            }
        }
    }
    
    private func updateUI(with stats: SystemStatsResponse) {
        [userStatsCard, creditStatsCard, revenueStatsCard, imageStatsCard].forEach { $0.removeStatItems() }

        let users = stats.users.total.formatted()
        userStatsCard.addStatItem(label: String(localized: "Total Users"), value: users, spokenValue: String(localized: "\(users) users"))
        
        let balance = stats.credits.totalBalance.formatted()
        let purchased = stats.credits.totalPurchased.formatted()
        let spent = stats.credits.totalSpent.formatted()
        creditStatsCard.addStatItem(label: String(localized: "Total Balance"), value: balance, spokenValue: String(localized: "\(balance) credits"))
        creditStatsCard.addStatItem(label: String(localized: "Total Purchased"), value: purchased, spokenValue: String(localized: "\(purchased) credits"))
        creditStatsCard.addStatItem(label: String(localized: "Total Spent"), value: spent, spokenValue: String(localized: "\(spent) credits"))
        
        revenueStatsCard.addStatItem(label: String(localized: "Total Revenue"), value: String(localized: "$\(stats.revenue.totalUsd)"), spokenValue: String(localized: "\(stats.revenue.totalUsd) dollars"))
        revenueStatsCard.addStatItem(label: String(localized: "OpenAI Costs"), value: String(localized: "$\(stats.revenue.openaiCostsUsd)"), spokenValue: String(localized: "\(stats.revenue.openaiCostsUsd) dollars"))
        revenueStatsCard.addStatItem(label: String(localized: "Gross Profit"), value: String(localized: "$\(stats.revenue.grossProfitUsd)"), spokenValue: String(localized: "\(stats.revenue.grossProfitUsd) dollars"))
        revenueStatsCard.addStatItem(label: String(localized: "Profit Margin"), value: String(localized: "\(stats.revenue.profitMargin)%"), spokenValue: String(localized: "\(stats.revenue.profitMargin) percent"))
        
        let generated = stats.images.totalGenerated.formatted()
        imageStatsCard.addStatItem(label: String(localized: "Total Generated"), value: generated, spokenValue: String(localized: "\(generated) images"))
    }
    
    private func showLoading() {
        loadingView.startAnimating()
        scrollView.isHidden = true
        errorView.hide()
    }
    
    private func hideLoading() {
        loadingView.stopAnimating()
        scrollView.isHidden = false
    }
    
    private func showError(_ message: String) {
        errorView.show(message) { [weak self] in
            self?.loadStats()
        }
        scrollView.isHidden = true
        haptics.notification(.error)
    }
}

class StatsCardView: UIView {
    
    private let titleLabel = UILabel()
    private let iconImageView = UIImageView()
    private let statsStackView = UIStackView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 12
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.1
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.useScaledFont(.title3, size: 20, weight: .semibold)
        titleLabel.numberOfLines = 0
        titleLabel.accessibilityTraits = .header
        iconImageView.hideFromAccessibility()
        
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        
        statsStackView.translatesAutoresizingMaskIntoConstraints = false
        statsStackView.axis = .vertical
        statsStackView.spacing = 12
        
        addSubview(iconImageView)
        addSubview(titleLabel)
        addSubview(statsStackView)
        
        let titleCentering = titleLabel.centerYAnchor.constraint(equalTo: iconImageView.centerYAnchor)
        titleCentering.priority = .defaultHigh
        
        NSLayoutConstraint.activate([
            titleCentering,
            iconImageView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            iconImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            iconImageView.widthAnchor.constraint(equalToConstant: 32),
            iconImageView.heightAnchor.constraint(equalToConstant: 32),
            
            titleLabel.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            statsStackView.topAnchor.constraint(greaterThanOrEqualTo: iconImageView.bottomAnchor, constant: 16),
            statsStackView.topAnchor.constraint(greaterThanOrEqualTo: titleLabel.bottomAnchor, constant: 16),
            statsStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            statsStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            statsStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }
    
    func configure(title: String, icon: UIImage?, color: UIColor) {
        titleLabel.text = title
        iconImageView.image = icon
        iconImageView.tintColor = color
    }
    
    func removeStatItems() {
        statsStackView.arrangedSubviews.forEach {
            statsStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
    }
    
    func addStatItem(label: String, value: String, spokenValue: String) {
        let labelView = UILabel()
        labelView.useScaledFont(.subheadline, size: 15)
        labelView.textColor = .secondaryLabel
        labelView.numberOfLines = 0
        labelView.text = label
        labelView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        let valueView = UILabel()
        valueView.useScaledFont(.body, size: 17, weight: .medium)
        valueView.textColor = .label
        valueView.text = value
        valueView.textAlignment = .right
        valueView.numberOfLines = 0
        valueView.setContentHuggingPriority(.required, for: .horizontal)
        valueView.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        let row = UIStackView(arrangedSubviews: [labelView, valueView])
        row.axis = .horizontal
        row.alignment = .firstBaseline
        row.spacing = 8
        row.heightAnchor.constraint(greaterThanOrEqualToConstant: 24).isActive = true
        row.describe(label, value: spokenValue)
        
        statsStackView.addArrangedSubview(row)
    }
}
