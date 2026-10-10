import UIKit

class OfflineBanner: UIView {
    private static let bannerColor = UIColor(red: 0.75, green: 0.13, blue: 0.11, alpha: 1)

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
        accessibilityElementsHidden = true

        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = Self.bannerColor
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
        iconImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .subheadline)
        iconImageView.tintColor = .white
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.setContentHuggingPriority(.required, for: .horizontal)
        iconImageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        iconImageView.hideFromAccessibility()
        stackView.addArrangedSubview(iconImageView)

        messageLabel.text = String(localized: "No Internet Connection")
        messageLabel.textColor = .white
        messageLabel.useScaledFont(.subheadline, size: 14, weight: .medium)
        messageLabel.numberOfLines = 0
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
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -8)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        syncHiddenOffset()
    }
    
    /// Height the banner needs at the current width and text size, used to park it exactly above the safe area while hidden.
    private var fittingHeight: CGFloat {
        if bounds.height > 0 { return bounds.height }
        let width = max(superview?.bounds.width ?? 0, 320)
        let target = CGSize(width: width, height: UIView.layoutFittingCompressedSize.height)
        return systemLayoutSizeFitting(target, withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel).height
    }
    
    /// Keeps a hidden banner parked exactly its own height above the top edge when its text size or width changes.
    private func syncHiddenOffset() {
        guard !isShowing, bounds.height > 0, let topConstraint = topConstraint else { return }
        guard abs(topConstraint.constant + bounds.height) > 0.5 else { return }
        topConstraint.constant = -bounds.height
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
        accessibilityElementsHidden = false
        Announce.say(String(localized: "You're offline"))

        if let topConstraint = topConstraint {
            topConstraint.constant = 0
        }

        Motion.animate(0.3, options: [.curveEaseOut]) {
            self.superview?.layoutIfNeeded()
            self.alpha = 1
        }
    }

    func hide() {
        guard isShowing else { return }
        isShowing = false
        accessibilityElementsHidden = true
        Announce.say(String(localized: "Back online"))

        if let topConstraint = topConstraint {
            topConstraint.constant = -fittingHeight
        }

        Motion.animate(0.3, options: [.curveEaseIn]) {
            self.superview?.layoutIfNeeded()
            self.alpha = 0
        }
    }

    func setTopConstraint(_ constraint: NSLayoutConstraint) {
        topConstraint = constraint
        topConstraint.constant = isShowing ? 0 : -fittingHeight
    }
}
