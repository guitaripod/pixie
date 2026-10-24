import UIKit

class AdminDashboardViewController: UIViewController {
    
    private let scrollView = SettingsColumnView(spacing: Theme.Space.lg)
    private let haptics = HapticManager.shared
    
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    private let systemStatsCard = AdminFeatureCardView()
    private let creditAdjustmentCard = AdminFeatureCardView()
    private let adjustmentHistoryCard = AdminFeatureCardView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupNavigationBar()
    }
    
    private func setupUI() {
        view.backgroundColor = Theme.Color.canvas
        
        titleLabel.apply(.title)
        titleLabel.text = String(localized: "Admin Dashboard")
        titleLabel.accessibilityTraits = .header
        
        subtitleLabel.apply(.callout)
        subtitleLabel.text = String(localized: "Manage system resources and user accounts")
        
        systemStatsCard.configure(
            symbol: "chart.line.uptrend.xyaxis",
            title: String(localized: "System Statistics"),
            description: String(localized: "View system-wide metrics and revenue data")
        )
        systemStatsCard.onTap = { [weak self] in
            self?.presentSystemStats()
        }
        
        creditAdjustmentCard.configure(
            symbol: "creditcard.fill",
            title: String(localized: "Credit Adjustments"),
            description: String(localized: "Add or remove credits from user accounts")
        )
        creditAdjustmentCard.onTap = { [weak self] in
            self?.presentCreditAdjustment()
        }
        
        adjustmentHistoryCard.configure(
            symbol: "clock.arrow.circlepath",
            title: String(localized: "Adjustment History"),
            description: String(localized: "View all credit adjustment records")
        )
        adjustmentHistoryCard.onTap = { [weak self] in
            self?.presentAdjustmentHistory()
        }
        
        scrollView.install(in: view, top: Theme.Space.lg)
        
        let header = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        header.axis = .vertical
        header.spacing = Theme.Space.xs
        scrollView.stack.addArrangedSubview(header)
        scrollView.stack.setCustomSpacing(Theme.Space.xxl, after: header)
        scrollView.stack.addArrangedSubview(systemStatsCard)
        scrollView.stack.addArrangedSubview(creditAdjustmentCard)
        scrollView.stack.addArrangedSubview(adjustmentHistoryCard)
    }
    
    private func setupNavigationBar() {
        navigationItem.title = String(localized: "Admin")
        navigationItem.largeTitleDisplayMode = .never
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
    
    var onTap: (() -> Void)?
    
    func configure(symbol: String, title: String, description: String) {
        subviews.forEach { $0.removeFromSuperview() }
        let row = ListRowView(title: title, subtitle: description, symbol: symbol, showsChevron: true)
        row.onTap = { [weak self] in
            self?.onTap?()
        }
        let card = SurfaceView(style: .card)
        card.contentView.addSubview(row)
        row.pinEdges(to: card.contentView)
        addSubview(card)
        card.pinEdges(to: self)
    }
}

final class AdminInlineMessageView: UIView {

    private let label = UILabel()
    private let retryButton = PixieButton(style: .primary, size: .medium, title: String(localized: "Retry"))
    private let stack = UIStackView()
    private var onRetry: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        isHidden = true
        label.apply(.callout)
        label.textAlignment = .center

        retryButton.addAction(UIAction { [weak self] _ in self?.onRetry?() }, for: .touchUpInside)
        retryButton.isHidden = true

        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = Theme.Space.lg
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(label)
        stack.addArrangedSubview(retryButton)
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    func show(_ message: String, retry: (() -> Void)? = nil) {
        label.text = message
        onRetry = retry
        retryButton.isHidden = retry == nil
        isHidden = false
        Announce.say(message)
    }

    func hide() {
        isHidden = true
    }
}
