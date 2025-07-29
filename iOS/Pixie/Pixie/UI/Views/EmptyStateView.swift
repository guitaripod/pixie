import UIKit

final class EmptyStateView: UIView {
    
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let actionButton = UIButton()
    private var actionHandler: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = UIColor(red: 103/255, green: 80/255, blue: 164/255, alpha: 0.6)
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        
        subtitleLabel.font = .systemFont(ofSize: 16)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = UIColor(red: 103/255, green: 80/255, blue: 164/255, alpha: 1.0)
        config.baseForegroundColor = .white
        config.cornerStyle = .medium
        config.buttonSize = .large
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 16, weight: .medium)
            return outgoing
        }
        
        actionButton.configuration = config
        actionButton.configurationUpdateHandler = { button in
            var config = button.configuration
            switch button.state {
            case .highlighted:
                config?.baseBackgroundColor = UIColor(red: 103/255, green: 80/255, blue: 164/255, alpha: 0.8)
                button.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            default:
                config?.baseBackgroundColor = UIColor(red: 103/255, green: 80/255, blue: 164/255, alpha: 1.0)
                button.transform = .identity
            }
            button.configuration = config
        }
        
        actionButton.addAction(UIAction { [weak self] _ in
            HapticsManager.shared.impact(.light)
            self?.actionHandler?()
        }, for: .touchUpInside)
        
        stackView.addArrangedSubview(iconImageView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)
        stackView.setCustomSpacing(32, after: subtitleLabel)
        stackView.addArrangedSubview(actionButton)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            
            iconImageView.widthAnchor.constraint(equalToConstant: 80),
            iconImageView.heightAnchor.constraint(equalToConstant: 80),
            
            actionButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }
    
    func configure(for type: GalleryType, action: @escaping () -> Void) {
        self.actionHandler = action
        
        switch type {
        case .personal:
            iconImageView.image = UIImage(systemName: "photo.on.rectangle.angled")
            titleLabel.text = "No images yet"
            subtitleLabel.text = "Start creating amazing images with AI"
            actionButton.configuration?.title = "Generate Your First Image"
            actionButton.configuration?.image = UIImage(systemName: "plus.circle.fill")
            actionButton.configuration?.imagePadding = 8
            actionButton.isHidden = false
            
        case .explore:
            iconImageView.image = UIImage(systemName: "globe.americas.fill")
            titleLabel.text = "Gallery is empty"
            subtitleLabel.text = "Be the first to share your creations"
            actionButton.isHidden = true
        }
    }
}