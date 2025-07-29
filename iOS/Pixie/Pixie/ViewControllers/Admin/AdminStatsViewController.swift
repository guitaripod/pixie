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
    private let errorLabel = UILabel()
    
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
        title = "System Statistics"
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
        
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.font = .systemFont(ofSize: 17)
        errorLabel.textColor = .secondaryLabel
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true
        
        userStatsCard.configure(
            title: "Users",
            icon: UIImage(systemName: "person.2.fill"),
            color: .systemBlue
        )
        
        creditStatsCard.configure(
            title: "Credits",
            icon: UIImage(systemName: "creditcard.fill"),
            color: .systemGreen
        )
        
        revenueStatsCard.configure(
            title: "Revenue",
            icon: UIImage(systemName: "dollarsign.circle.fill"),
            color: .systemOrange
        )
        
        imageStatsCard.configure(
            title: "Images",
            icon: UIImage(systemName: "photo.fill"),
            color: .systemPurple
        )
        
        view.addSubview(scrollView)
        view.addSubview(loadingView)
        view.addSubview(errorLabel)
        
        scrollView.addSubview(contentStackView)
        
        contentStackView.addArrangedSubview(userStatsCard)
        contentStackView.addArrangedSubview(creditStatsCard)
        contentStackView.addArrangedSubview(revenueStatsCard)
        contentStackView.addArrangedSubview(imageStatsCard)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentStackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            errorLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            errorLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
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
        userStatsCard.addStatItem(label: "Total Users", value: "\(stats.users.total)")
        
        creditStatsCard.addStatItem(label: "Total Balance", value: "\(stats.credits.totalBalance)")
        creditStatsCard.addStatItem(label: "Total Purchased", value: "\(stats.credits.totalPurchased)")
        creditStatsCard.addStatItem(label: "Total Spent", value: "\(stats.credits.totalSpent)")
        
        revenueStatsCard.addStatItem(label: "Total Revenue", value: "$\(stats.revenue.totalUsd)")
        revenueStatsCard.addStatItem(label: "OpenAI Costs", value: "$\(stats.revenue.openaiCostsUsd)")
        revenueStatsCard.addStatItem(label: "Gross Profit", value: "$\(stats.revenue.grossProfitUsd)")
        revenueStatsCard.addStatItem(label: "Profit Margin", value: "\(stats.revenue.profitMargin)%")
        
        imageStatsCard.addStatItem(label: "Total Generated", value: "\(stats.images.totalGenerated)")
    }
    
    private func showLoading() {
        loadingView.startAnimating()
        scrollView.isHidden = true
        errorLabel.isHidden = true
    }
    
    private func hideLoading() {
        loadingView.stopAnimating()
        scrollView.isHidden = false
    }
    
    private func showError(_ message: String) {
        errorLabel.text = message
        errorLabel.isHidden = false
        scrollView.isHidden = true
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
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        
        statsStackView.translatesAutoresizingMaskIntoConstraints = false
        statsStackView.axis = .vertical
        statsStackView.spacing = 12
        
        addSubview(iconImageView)
        addSubview(titleLabel)
        addSubview(statsStackView)
        
        NSLayoutConstraint.activate([
            iconImageView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            iconImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            iconImageView.widthAnchor.constraint(equalToConstant: 32),
            iconImageView.heightAnchor.constraint(equalToConstant: 32),
            
            titleLabel.centerYAnchor.constraint(equalTo: iconImageView.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            statsStackView.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 16),
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
    
    func addStatItem(label: String, value: String) {
        let containerView = UIView()
        
        let labelView = UILabel()
        labelView.translatesAutoresizingMaskIntoConstraints = false
        labelView.font = .systemFont(ofSize: 15)
        labelView.textColor = .secondaryLabel
        labelView.text = label
        
        let valueView = UILabel()
        valueView.translatesAutoresizingMaskIntoConstraints = false
        valueView.font = .systemFont(ofSize: 17, weight: .medium)
        valueView.textColor = .label
        valueView.text = value
        valueView.textAlignment = .right
        
        containerView.addSubview(labelView)
        containerView.addSubview(valueView)
        
        NSLayoutConstraint.activate([
            labelView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            labelView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            valueView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            valueView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            valueView.leadingAnchor.constraint(greaterThanOrEqualTo: labelView.trailingAnchor, constant: 8),
            
            containerView.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        statsStackView.addArrangedSubview(containerView)
    }
}