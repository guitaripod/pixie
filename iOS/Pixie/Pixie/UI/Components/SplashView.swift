import UIKit

class SplashView: UIView {
    
    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let gradientLayer = CAGradientLayer()
    private var slowLaunchTask: Task<Void, Never>?
    private static let slowLaunchDelay: Duration = .seconds(6)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
    
    private func setupView() {
        backgroundColor = .systemBackground
        
        gradientLayer.colors = [
            UIColor.systemPurple.withAlphaComponent(0.3).cgColor,
            UIColor.systemBlue.withAlphaComponent(0.3).cgColor,
            UIColor.systemBackground.cgColor
        ]
        gradientLayer.locations = [0, 0.5, 1]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        layer.insertSublayer(gradientLayer, at: 0)
        
        titleLabel.text = "Pixie"
        titleLabel.useScaledFont(.largeTitle, size: 48, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(titleLabel)

        statusLabel.text = String(localized: "Taking longer than usual…")
        statusLabel.useScaledFont(.subheadline, size: 15)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.alpha = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.trailingAnchor, constant: -24),
            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            statusLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.trailingAnchor, constant: -24)
        ])

        describe(String(localized: "Pixie, loading"), traits: .staticText)
        animateElements()
        watchForSlowLaunch()
    }

    /// Fades in a status line when the host has not dismissed the splash after a few
    /// seconds, so a slow launch never looks like a frozen app.
    private func watchForSlowLaunch() {
        slowLaunchTask = Task { [weak self] in
            try? await Task.sleep(for: Self.slowLaunchDelay)
            guard !Task.isCancelled, let self else { return }
            Motion.animate(0.3) { self.statusLabel.alpha = 1 }
            Announce.say(String(localized: "Taking longer than usual…"))
        }
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if superview == nil { slowLaunchTask?.cancel() }
    }

    deinit {
        slowLaunchTask?.cancel()
    }
    
    private func animateElements() {
        guard !Motion.isReduced else { return }
        titleLabel.alpha = 0
        titleLabel.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        Motion.spring(0.8, damping: 0.7, velocity: 0.5) {
            self.titleLabel.transform = .identity
            self.titleLabel.alpha = 1
        }
    }
    
    func animateOut(completion: @escaping () -> Void) {
        slowLaunchTask?.cancel()
        Motion.animate(0.5, options: [.curveEaseInOut]) {
            self.transform = CGAffineTransform(translationX: 0, y: -self.bounds.height)
            self.alpha = 0
        } completion: { _ in
            completion()
        }
    }
}