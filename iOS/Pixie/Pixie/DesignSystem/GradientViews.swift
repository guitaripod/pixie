import UIKit

final class GradientView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }

    private var gradientLayer: CAGradientLayer { layer as! CAGradientLayer }

    init(colors: [UIColor] = Theme.Color.gradient, start: CGPoint = CGPoint(x: 0, y: 0), end: CGPoint = CGPoint(x: 1, y: 1)) {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        gradientLayer.startPoint = start
        gradientLayer.endPoint = end
        apply(colors)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    var colors: [UIColor] = [] {
        didSet { apply(colors) }
    }

    var cornerRadius: CGFloat = 0 {
        didSet { layer.cornerRadius = cornerRadius; layer.cornerCurve = .continuous }
    }

    private func apply(_ colors: [UIColor]) {
        gradientLayer.colors = colors.map { $0.resolvedColor(with: traitCollection).cgColor }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        apply(colors.isEmpty ? Theme.Color.gradient : colors)
    }
}

final class InkBackdropView: UIView {
    private let violetGlow = CAGradientLayer()
    private let pinkGlow = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.Color.backdrop
        isUserInteractionEnabled = false
        for glow in [violetGlow, pinkGlow] {
            glow.type = .radial
            glow.startPoint = CGPoint(x: 0.5, y: 0.5)
            glow.endPoint = CGPoint(x: 1, y: 1)
            layer.addSublayer(glow)
        }
        violetGlow.colors = [UIColor(hex: 0x6C47FF, alpha: 0.42).cgColor, UIColor(hex: 0x6C47FF, alpha: 0).cgColor]
        pinkGlow.colors = [UIColor(hex: 0xFF6FA3, alpha: 0.20).cgColor, UIColor(hex: 0xFF6FA3, alpha: 0).cgColor]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width
        violetGlow.frame = CGRect(x: -width * 0.25, y: -width * 0.55, width: width * 1.5, height: width * 1.5)
        pinkGlow.frame = CGRect(x: -width * 0.3, y: bounds.height - width * 0.8, width: width * 1.6, height: width * 1.4)
    }
}

final class ShimmerView: UIView {
    private let highlight = CAGradientLayer()
    private var isAnimating = false
    private var animatedWidth: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.Color.fill
        clipsToBounds = true
        layer.cornerCurve = .continuous
        highlight.startPoint = CGPoint(x: 0, y: 0.5)
        highlight.endPoint = CGPoint(x: 1, y: 0.5)
        layer.addSublayer(highlight)
        applyColors()
        isAccessibilityElement = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        highlight.frame = CGRect(x: -bounds.width, y: 0, width: bounds.width * 3, height: bounds.height)
        if window != nil, bounds.width != animatedWidth {
            stop()
            start()
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { start() } else { stop() }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyColors()
    }

    private func applyColors() {
        let base = traitCollection.userInterfaceStyle == .dark ? UIColor.white : UIColor(hex: 0x15121F)
        highlight.colors = [
            base.withAlphaComponent(0).cgColor,
            base.withAlphaComponent(traitCollection.userInterfaceStyle == .dark ? 0.10 : 0.07).cgColor,
            base.withAlphaComponent(0).cgColor,
        ]
        highlight.locations = [0.3, 0.5, 0.7]
    }

    private func start() {
        guard !isAnimating, !Motion.isReduced, bounds.width > 0 else { return }
        isAnimating = true
        animatedWidth = bounds.width
        let slide = CABasicAnimation(keyPath: "transform.translation.x")
        slide.fromValue = 0
        slide.toValue = bounds.width * 2
        slide.duration = 1.4
        slide.repeatCount = .infinity
        slide.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        highlight.add(slide, forKey: "shimmer")
    }

    private func stop() {
        isAnimating = false
        animatedWidth = 0
        highlight.removeAnimation(forKey: "shimmer")
    }
}
