import UIKit

class SectionHeaderView: UICollectionReusableView {
    
    struct Configuration: Hashable {
        let title: String
        let subtitle: String?
        let actionTitle: String?
        let action: (() -> Void)?
        
        static func == (lhs: Configuration, rhs: Configuration) -> Bool {
            lhs.title == rhs.title && lhs.subtitle == rhs.subtitle && lhs.actionTitle == rhs.actionTitle
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(title)
            hasher.combine(subtitle)
            hasher.combine(actionTitle)
        }
    }
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .headline)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let actionButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private var action: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        subtitleLabel.text = nil
        subtitleLabel.isHidden = true
        actionButton.setTitle(nil, for: .normal)
        actionButton.isHidden = true
        action = nil
    }
    
    private func setupViews() {
        addSubview(titleLabel)
        addSubview(subtitleLabel)
        addSubview(actionButton)
        
        actionButton.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            
            actionButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            actionButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            actionButton.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 16)
        ])
    }
    
    func configure(with configuration: Configuration) {
        titleLabel.text = configuration.title
        
        if let subtitle = configuration.subtitle {
            subtitleLabel.text = subtitle
            subtitleLabel.isHidden = false
        } else {
            subtitleLabel.isHidden = true
        }
        
        if let actionTitle = configuration.actionTitle {
            actionButton.setTitle(actionTitle, for: .normal)
            actionButton.isHidden = false
            action = configuration.action
        } else {
            actionButton.isHidden = true
            action = nil
        }
    }
    
    @objc private func actionButtonTapped() {
        action?()
    }
    
    static func registration() -> UICollectionView.SupplementaryRegistration<SectionHeaderView> {
        UICollectionView.SupplementaryRegistration<SectionHeaderView>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { headerView, elementKind, indexPath in
        }
    }
    
    static func registration(
        configurationProvider: @escaping (IndexPath) -> Configuration
    ) -> UICollectionView.SupplementaryRegistration<SectionHeaderView> {
        UICollectionView.SupplementaryRegistration<SectionHeaderView>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { headerView, elementKind, indexPath in
            let configuration = configurationProvider(indexPath)
            headerView.configure(with: configuration)
        }
    }
}