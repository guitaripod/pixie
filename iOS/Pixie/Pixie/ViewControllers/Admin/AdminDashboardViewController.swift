import UIKit

class AdminDashboardViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let contentStackView = UIStackView()
    private let haptics = HapticManager.shared
    
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    private let systemStatsCard = AdminFeatureCardView()
    private let creditAdjustmentCard = AdminFeatureCardView()
    private let adjustmentHistoryCard = AdminFeatureCardView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupConstraints()
        setupNavigationBar()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.axis = .vertical
        contentStackView.spacing = 16
        contentStackView.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        contentStackView.isLayoutMarginsRelativeArrangement = true
        
        titleLabel.text = "Admin Dashboard"
        titleLabel.font = .systemFont(ofSize: 34, weight: .bold)
        titleLabel.textColor = .label
        
        subtitleLabel.text = "Manage system resources and user accounts"
        subtitleLabel.font = .systemFont(ofSize: 17)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0
        
        systemStatsCard.configure(
            icon: UIImage(systemName: "chart.line.uptrend.xyaxis"),
            title: "System Statistics",
            description: "View system-wide metrics and revenue data"
        )
        systemStatsCard.onTap = { [weak self] in
            self?.presentSystemStats()
        }
        
        creditAdjustmentCard.configure(
            icon: UIImage(systemName: "creditcard.fill"),
            title: "Credit Adjustments",
            description: "Add or remove credits from user accounts"
        )
        creditAdjustmentCard.onTap = { [weak self] in
            self?.presentCreditAdjustment()
        }
        
        adjustmentHistoryCard.configure(
            icon: UIImage(systemName: "clock.arrow.circlepath"),
            title: "Adjustment History",
            description: "View all credit adjustment records"
        )
        adjustmentHistoryCard.onTap = { [weak self] in
            self?.presentAdjustmentHistory()
        }
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentStackView)
        
        contentStackView.addArrangedSubview(titleLabel)
        contentStackView.addArrangedSubview(subtitleLabel)
        contentStackView.setCustomSpacing(24, after: subtitleLabel)
        contentStackView.addArrangedSubview(systemStatsCard)
        contentStackView.addArrangedSubview(creditAdjustmentCard)
        contentStackView.addArrangedSubview(adjustmentHistoryCard)
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
            contentStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }
    
    private func setupNavigationBar() {
        navigationItem.title = "Admin"
        navigationItem.largeTitleDisplayMode = .never
        
        let closeButton = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(closeTapped)
        )
        navigationItem.rightBarButtonItem = closeButton
    }
    
    @objc private func closeTapped() {
        haptics.impact(.click)
        dismiss(animated: true)
    }
    
    private func presentSystemStats() {
        haptics.impact(.click)
        let statsVC = AdminStatsViewController()
        navigationController?.pushViewController(statsVC, animated: true)
    }
    
    private func presentCreditAdjustment() {
        haptics.impact(.click)
        let adjustVC = AdminCreditAdjustmentViewController()
        navigationController?.pushViewController(adjustVC, animated: true)
    }
    
    private func presentAdjustmentHistory() {
        haptics.impact(.click)
        let historyVC = AdminAdjustmentHistoryViewController()
        navigationController?.pushViewController(historyVC, animated: true)
    }
}

class AdminFeatureCardView: UIView {
    
    private let haptics = HapticManager.shared
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let chevronImageView = UIImageView()
    
    var onTap: (() -> Void)?
    
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
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
        
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .secondaryLabel
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .label
        
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.font = .systemFont(ofSize: 15)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.numberOfLines = 0
        
        chevronImageView.translatesAutoresizingMaskIntoConstraints = false
        chevronImageView.image = UIImage(systemName: "chevron.right")
        chevronImageView.tintColor = .tertiaryLabel
        chevronImageView.contentMode = .scaleAspectFit
        
        addSubview(iconImageView)
        addSubview(titleLabel)
        addSubview(descriptionLabel)
        addSubview(chevronImageView)
        
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 48),
            iconImageView.heightAnchor.constraint(equalToConstant: 48),
            
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: chevronImageView.leadingAnchor, constant: -8),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            descriptionLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            
            chevronImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevronImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            chevronImageView.widthAnchor.constraint(equalToConstant: 12),
            chevronImageView.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    func configure(icon: UIImage?, title: String, description: String) {
        iconImageView.image = icon
        titleLabel.text = title
        descriptionLabel.text = description
    }
    
    @objc private func handleTap() {
        haptics.impact(.click)
        
        UIView.animate(withDuration: 0.1, animations: {
            self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.transform = .identity
            }
            self.onTap?()
        }
    }
}