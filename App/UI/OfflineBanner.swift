import UIKit

class OfflineBanner: UIView {
    private let pillView = UIView()
    private let tintView = UIView()
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

        pillView.translatesAutoresizingMaskIntoConstraints = false
        pillView.backgroundColor = Theme.Color.surfaceRaised
        pillView.layer.cornerCurve = .continuous
        pillView.layer.borderWidth = 1
        pillView.layer.shadowColor = UIColor(hex: 0x1B0F4A).cgColor
        pillView.layer.shadowRadius = 16
        pillView.layer.shadowOffset = CGSize(width: 0, height: 6)
        addSubview(pillView)

        tintView.translatesAutoresizingMaskIntoConstraints = false
        tintView.backgroundColor = Theme.Color.danger.withAlphaComponent(0.14)
        tintView.layer.cornerCurve = .continuous
        tintView.clipsToBounds = true
        tintView.isUserInteractionEnabled = false
        pillView.addSubview(tintView)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = Theme.Space.sm
        stackView.distribution = .fill
        pillView.addSubview(stackView)

        iconImageView.image = UIImage(systemName: "wifi.slash")
        iconImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .subheadline, scale: .medium)
        iconImageView.tintColor = Theme.Color.danger
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.setContentHuggingPriority(.required, for: .horizontal)
        iconImageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        iconImageView.hideFromAccessibility()
        stackView.addArrangedSubview(iconImageView)

        messageLabel.apply(.subhead, color: Theme.Color.ink)
        messageLabel.text = String(localized: "No Internet Connection")
        stackView.addArrangedSubview(messageLabel)
        applyAppearance()
    }

    private func setupConstraints() {
        let margin = Theme.Space.lg
        NSLayoutConstraint.activate([
            pillView.centerXAnchor.constraint(equalTo: centerXAnchor),
            pillView.topAnchor.constraint(equalTo: topAnchor, constant: Theme.Space.sm),
            pillView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Theme.Space.sm),
            pillView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: margin),
            pillView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -margin),

            tintView.topAnchor.constraint(equalTo: pillView.topAnchor),
            tintView.bottomAnchor.constraint(equalTo: pillView.bottomAnchor),
            tintView.leadingAnchor.constraint(equalTo: pillView.leadingAnchor),
            tintView.trailingAnchor.constraint(equalTo: pillView.trailingAnchor),

            stackView.leadingAnchor.constraint(equalTo: pillView.leadingAnchor, constant: Theme.Space.lg),
            stackView.trailingAnchor.constraint(equalTo: pillView.trailingAnchor, constant: -Theme.Space.lg),
            stackView.topAnchor.constraint(equalTo: pillView.topAnchor, constant: 10),
            stackView.bottomAnchor.constraint(equalTo: pillView.bottomAnchor, constant: -10),
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let radius = min(pillView.bounds.height / 2, Theme.Radius.lg)
        pillView.layer.cornerRadius = radius
        tintView.layer.cornerRadius = radius
        pillView.layer.shadowPath = UIBezierPath(roundedRect: pillView.bounds, cornerRadius: radius).cgPath
        syncHiddenOffset()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyAppearance()
    }

    /// Layer colours do not follow dynamic colours by themselves, so they are resolved again whenever the appearance changes.
    private func applyAppearance() {
        pillView.layer.borderColor = Theme.Color.danger.withAlphaComponent(0.4).resolvedColor(with: traitCollection).cgColor
        pillView.layer.shadowOpacity = traitCollection.userInterfaceStyle == .dark ? 0 : 0.12
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

        Motion.spring(0.4, damping: 0.82, options: [.curveEaseOut]) {
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

        Motion.animate(0.25, options: [.curveEaseIn]) {
            self.superview?.layoutIfNeeded()
            self.alpha = 0
        }
    }

    func setTopConstraint(_ constraint: NSLayoutConstraint) {
        topConstraint = constraint
        topConstraint.constant = isShowing ? 0 : -fittingHeight
    }
}
