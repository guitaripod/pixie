import UIKit

class OfflineBanner: UIView {
    private let containerView = UIView()
    private let stackView = UIStackView()
    private let iconImageView = UIImageView()
    private let messageLabel = UILabel()
    
    private var topConstraint: NSLayoutConstraint!
    private var isShowing = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
        startMonitoring()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupUI() {
        translatesAutoresizingMaskIntoConstraints = false
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = .systemRed
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.1
        containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        containerView.layer.shadowRadius = 4
        addSubview(containerView)
        
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 8
        stackView.distribution = .fill
        containerView.addSubview(stackView)
        
        iconImageView.image = UIImage(systemName: "wifi.slash")
        iconImageView.tintColor = .white
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(iconImageView)
        
        messageLabel.text = "No Internet Connection"
        messageLabel.textColor = .white
        messageLabel.font = .systemFont(ofSize: 14, weight: .medium)
        messageLabel.numberOfLines = 1
        stackView.addArrangedSubview(messageLabel)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -8),
            
            iconImageView.widthAnchor.constraint(equalToConstant: 20),
            iconImageView.heightAnchor.constraint(equalToConstant: 20),
            
            heightAnchor.constraint(equalToConstant: 36)
        ])
    }
    
    private func startMonitoring() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(networkStatusChanged(_:)),
            name: .networkStatusChanged,
            object: nil
        )
        
        updateBannerVisibility(isConnected: NetworkMonitor.shared.isConnected)
    }
    
    @objc private func networkStatusChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let isConnected = userInfo["isConnected"] as? Bool else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.updateBannerVisibility(isConnected: isConnected)
        }
    }
    
    private func updateBannerVisibility(isConnected: Bool) {
        if isConnected && isShowing {
            hide()
        } else if !isConnected && !isShowing {
            show()
        }
    }
    
    func show() {
        guard !isShowing else { return }
        isShowing = true
        
        if let topConstraint = topConstraint {
            topConstraint.constant = 0
        }
        
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseOut]) {
            self.superview?.layoutIfNeeded()
            self.alpha = 1
        }
    }
    
    func hide() {
        guard isShowing else { return }
        isShowing = false
        
        if let topConstraint = topConstraint {
            topConstraint.constant = -36
        }
        
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseIn]) {
            self.superview?.layoutIfNeeded()
            self.alpha = 0
        }
    }
    
    func setTopConstraint(_ constraint: NSLayoutConstraint) {
        topConstraint = constraint
        topConstraint.constant = isShowing ? 0 : -36
    }
}