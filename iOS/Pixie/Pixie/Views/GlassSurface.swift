import UIKit

final class GlassSurface: UIView {
    private let shadowHost = UIView()
    private let shadowMask = CAShapeLayer()
    private let effectView: UIVisualEffectView

    var contentView: UIView { effectView.contentView }

    var maximumCornerRadius: CGFloat {
        didSet { setNeedsLayout() }
    }

    init(interactive: Bool = false, tintAlpha: CGFloat = 0, maximumCornerRadius: CGFloat = .greatestFiniteMagnitude) {
        effectView = UIVisualEffectView(effect: GlassMaterial.effect(interactive: interactive))
        self.maximumCornerRadius = maximumCornerRadius
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        shadowHost.isUserInteractionEnabled = false
        shadowHost.translatesAutoresizingMaskIntoConstraints = false
        shadowHost.layer.cornerCurve = .continuous
        shadowMask.fillRule = .evenOdd
        shadowHost.layer.mask = shadowMask
        addSubview(shadowHost)
        shadowHost.pinEdges(to: self)

        effectView.translatesAutoresizingMaskIntoConstraints = false
        effectView.clipsToBounds = true
        effectView.layer.cornerCurve = .continuous
        effectView.layer.borderWidth = 1
        addSubview(effectView)
        effectView.pinEdges(to: self)
        if tintAlpha > 0 {
            let tint = UIView()
            tint.isUserInteractionEnabled = false
            tint.backgroundColor = Theme.Color.surface.withAlphaComponent(tintAlpha)
            effectView.contentView.addSubview(tint)
            tint.pinEdges(to: effectView.contentView)
        }
        applyAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let radius = min(bounds.height / 2, maximumCornerRadius)
        effectView.layer.cornerRadius = radius
        let body = UIBezierPath(roundedRect: bounds, cornerRadius: radius)
        shadowHost.layer.shadowPath = body.cgPath
        let cutout = UIBezierPath(rect: bounds.insetBy(dx: -120, dy: -120))
        cutout.append(body)
        shadowMask.frame = bounds
        shadowMask.path = cutout.cgPath
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyAppearance()
    }

    private func applyAppearance() {
        let isDark = traitCollection.userInterfaceStyle == .dark
        effectView.layer.borderColor = Theme.Color.line.resolvedColor(with: traitCollection).cgColor
        shadowHost.layer.shadowColor = (isDark ? UIColor.black : UIColor(hex: 0x1B0F4A)).cgColor
        shadowHost.layer.shadowOpacity = isDark ? 0.45 : 0.14
        shadowHost.layer.shadowRadius = 22
        shadowHost.layer.shadowOffset = CGSize(width: 0, height: 8)
    }
}

final class EdgeFadeView: UIView {
    enum Edge {
        case top
        case bottom
    }

    override class var layerClass: AnyClass { CAGradientLayer.self }

    private let edge: Edge

    private var gradientLayer: CAGradientLayer { layer as! CAGradientLayer }

    init(edge: Edge) {
        self.edge = edge
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        gradientLayer.locations = [0, 0.55, 1]
        applyColors()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyColors()
    }

    private func applyColors() {
        let canvas = Theme.Color.canvas.resolvedColor(with: traitCollection)
        let solid = canvas.withAlphaComponent(0.96).cgColor
        let soft = canvas.withAlphaComponent(0.7).cgColor
        let clear = canvas.withAlphaComponent(0).cgColor
        gradientLayer.colors = edge == .top ? [solid, soft, clear] : [clear, soft, solid]
    }
}
