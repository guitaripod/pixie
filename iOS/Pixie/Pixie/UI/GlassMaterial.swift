import UIKit

enum GlassMaterial {
    static func effect(interactive: Bool = false, fallback: UIBlurEffect.Style = .systemThinMaterial) -> UIVisualEffect {
        if #available(iOS 26.0, *) {
            let glass = UIGlassEffect()
            glass.isInteractive = interactive
            return glass
        }
        return UIBlurEffect(style: fallback)
    }

    static func cardView(cornerRadius: CGFloat = 22, interactive: Bool = false) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: effect(interactive: interactive))
        view.layer.cornerRadius = cornerRadius
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }
}
