import UIKit

private final class SplashOrbView: UIView {
    static let diameter: CGFloat = 120
    private static let glowScale: CGFloat = 2.4

    private let glow = CAGradientLayer()
    private let disc = GradientView()
    private let ring = UIView()
    private let sparkle = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = false
        hideFromAccessibility()

        glow.type = .radial
        glow.startPoint = CGPoint(x: 0.5, y: 0.5)
        glow.endPoint = CGPoint(x: 1, y: 1)
        glow.colors = [
            UIColor(hex: 0xB04BFF, alpha: 0.55).cgColor,
            UIColor(hex: 0x6C47FF, alpha: 0.18).cgColor,
            UIColor(hex: 0x6C47FF, alpha: 0).cgColor,
        ]
        glow.locations = [0, 0.45, 1]
        layer.addSublayer(glow)

        disc.cornerRadius = Self.diameter / 2
        disc.translatesAutoresizingMaskIntoConstraints = false
        addSubview(disc)

        ring.layer.cornerRadius = Self.diameter / 2
        ring.layer.borderWidth = 1
        ring.layer.borderColor = UIColor(white: 1, alpha: 0.28).cgColor
        ring.translatesAutoresizingMaskIntoConstraints = false
        addSubview(ring)

        sparkle.image = UIImage(systemName: "sparkles", withConfiguration: UIImage.SymbolConfiguration(pointSize: 54, weight: .semibold))
        sparkle.tintColor = .white
        sparkle.contentMode = .center
        sparkle.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sparkle)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.diameter),
            heightAnchor.constraint(equalToConstant: Self.diameter),
            sparkle.centerXAnchor.constraint(equalTo: centerXAnchor),
            sparkle.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        disc.pinEdges(to: self)
        ring.pinEdges(to: self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let side = bounds.width * Self.glowScale
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        glow.frame = CGRect(x: (bounds.width - side) / 2, y: (bounds.height - side) / 2, width: side, height: side)
        CATransaction.commit()
    }
}

class SplashView: UIView {
    private let backdrop = InkBackdropView()
    private let orb = SplashOrbView()
    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private var slowLaunchTask: Task<Void, Never>?
    private static let slowLaunchDelay: Duration = .seconds(6)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        overrideUserInterfaceStyle = .dark
        backgroundColor = Theme.Color.backdrop

        backdrop.translatesAutoresizingMaskIntoConstraints = false
        addSubview(backdrop)
        backdrop.pinEdges(to: self)

        addSubview(orb)

        titleLabel.attributedText = NSAttributedString(
            string: "Pixie",
            attributes: [
                .font: UIFont.scaled(.largeTitle, size: 40, weight: .heavy, rounded: true),
                .foregroundColor: Theme.Color.onBackdrop,
                .kern: -0.5,
            ]
        )
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.5
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        statusLabel.setStyledText(String(localized: "Taking longer than usual…"), .subhead, color: UIColor(white: 1, alpha: 0.6), alignment: .center)
        statusLabel.alpha = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(statusLabel)

        let margin = Theme.Space.xxl
        NSLayoutConstraint.activate([
            orb.centerXAnchor.constraint(equalTo: centerXAnchor),
            orb.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -Theme.Space.xxxl),
            titleLabel.topAnchor.constraint(equalTo: orb.bottomAnchor, constant: Theme.Space.xxl),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.leadingAnchor, constant: margin),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.trailingAnchor, constant: -margin),
            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Theme.Space.md),
            statusLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.leadingAnchor, constant: margin),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.trailingAnchor, constant: -margin),
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
        orb.alpha = 0
        orb.transform = CGAffineTransform(scaleX: 0.86, y: 0.86)
        titleLabel.alpha = 0

        Motion.animate(0.5, options: [.curveEaseOut]) {
            self.orb.alpha = 1
            self.orb.transform = .identity
        }
        Motion.animate(0.4, delay: 0.2, options: [.curveEaseOut]) {
            self.titleLabel.alpha = 1
        }
    }

    func animateOut(completion: @escaping () -> Void) {
        slowLaunchTask?.cancel()
        Motion.animate(0.4, options: [.curveEaseInOut]) {
            self.transform = CGAffineTransform(scaleX: 1.04, y: 1.04)
            self.alpha = 0
        } completion: { _ in
            completion()
        }
    }
}
