import UIKit

class AdminStatsViewController: UIViewController {
    
    private let scrollView = SettingsColumnView(spacing: Theme.Space.lg)
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
    
    private var contentStackView: UIStackView { scrollView.stack }
    
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
        view.backgroundColor = Theme.Color.canvas
        
        scrollView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(refreshStats), for: .valueChanged)
        
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.hidesWhenStopped = true
        loadingView.color = Theme.Color.accentText
        
        errorView.translatesAutoresizingMaskIntoConstraints = false
        
        userStatsCard.configure(
            title: String(localized: "Users"),
            symbol: "person.2.fill",
            color: Theme.Color.accent
        )
        
        creditStatsCard.configure(
            title: String(localized: "Credits"),
            symbol: "creditcard.fill",
            color: Theme.Color.success
        )
        
        revenueStatsCard.configure(
            title: String(localized: "Revenue"),
            symbol: "dollarsign.circle.fill",
            color: Theme.Color.warning
        )
        
        imageStatsCard.configure(
            title: String(localized: "Images"),
            symbol: "photo.fill",
            color: Theme.Color.accent
        )
        
        scrollView.install(in: view, top: Theme.Space.lg)
        view.addSubview(loadingView)
        view.addSubview(errorView)
        
        contentStackView.addArrangedSubview(userStatsCard)
        contentStackView.addArrangedSubview(creditStatsCard)
        contentStackView.addArrangedSubview(revenueStatsCard)
        contentStackView.addArrangedSubview(imageStatsCard)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
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
                    self.hideLoading()
                    self.showError(error.localizedDescription)
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
    private let statsStackView = UIStackView()
    private var badge: IconBadge?
    private let card = SurfaceView(style: .card)
    private let headerStack = UIStackView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        titleLabel.apply(.title2)
        titleLabel.accessibilityTraits = .header
        
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.spacing = Theme.Space.md
        headerStack.addArrangedSubview(titleLabel)
        
        statsStackView.axis = .vertical
        statsStackView.spacing = Theme.Space.md
        
        let content = UIStackView(arrangedSubviews: [headerStack, statsStackView])
        content.axis = .vertical
        content.spacing = Theme.Space.lg
        content.translatesAutoresizingMaskIntoConstraints = false
        
        card.contentView.addSubview(content)
        content.pinEdges(to: card.contentView, insets: UIEdgeInsets(top: Theme.Space.lg, left: Theme.Space.lg, bottom: Theme.Space.lg, right: Theme.Space.lg))
        addSubview(card)
        card.pinEdges(to: self)
    }
    
    func configure(title: String, symbol: String, color: UIColor) {
        titleLabel.text = title
        badge?.removeFromSuperview()
        let newBadge = IconBadge(symbol: symbol, colors: SettingsTint.solid(color), size: 36)
        headerStack.insertArrangedSubview(newBadge, at: 0)
        badge = newBadge
    }
    
    func removeStatItems() {
        statsStackView.arrangedSubviews.forEach {
            statsStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
    }
    
    func addStatItem(label: String, value: String, spokenValue: String) {
        let labelView = UILabel()
        labelView.apply(.subhead)
        labelView.text = label
        labelView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        let valueView = UILabel()
        valueView.apply(.numeral(17))
        valueView.text = value
        valueView.textAlignment = .right
        valueView.setContentHuggingPriority(.required, for: .horizontal)
        valueView.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        let row = UIStackView(arrangedSubviews: [labelView, valueView])
        row.axis = .horizontal
        row.alignment = .firstBaseline
        row.spacing = Theme.Space.sm
        row.heightAnchor.constraint(greaterThanOrEqualToConstant: 24).isActive = true
        row.describe(label, value: spokenValue)
        
        statsStackView.addArrangedSubview(row)
    }
}
