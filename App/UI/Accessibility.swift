import UIKit

extension UIFont {
    static func scaled(_ style: UIFont.TextStyle, size: CGFloat, weight: UIFont.Weight = .regular, rounded: Bool = false) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        return UIFontMetrics(forTextStyle: style).scaledFont(for: rounded ? base.rounded() : base)
    }
}

extension UILabel {
    func useScaledFont(_ style: UIFont.TextStyle, size: CGFloat, weight: UIFont.Weight = .regular, rounded: Bool = false) {
        font = .scaled(style, size: size, weight: weight, rounded: rounded)
        adjustsFontForContentSizeCategory = true
    }
}

extension UIColor {
    static let brand = Theme.Color.accent
    static let brandText = Theme.Color.accentText
    static let brandTint = Theme.Color.accentSoft
}

enum Motion {
    static var isReduced: Bool { UIAccessibility.isReduceMotionEnabled }

    static func animate(
        _ duration: TimeInterval,
        delay: TimeInterval = 0,
        options: UIView.AnimationOptions = [],
        animations: @escaping () -> Void,
        completion: ((Bool) -> Void)? = nil
    ) {
        UIView.animate(withDuration: isReduced ? 0 : duration, delay: isReduced ? 0 : delay, options: options, animations: animations, completion: completion)
    }

    static func spring(
        _ duration: TimeInterval,
        delay: TimeInterval = 0,
        damping: CGFloat = 0.8,
        velocity: CGFloat = 0,
        options: UIView.AnimationOptions = [],
        animations: @escaping () -> Void,
        completion: ((Bool) -> Void)? = nil
    ) {
        if isReduced {
            UIView.animate(withDuration: 0, animations: animations, completion: completion)
            return
        }
        UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: damping, initialSpringVelocity: velocity, options: options, animations: animations, completion: completion)
    }

    static func transition(
        with view: UIView,
        duration: TimeInterval,
        options: UIView.AnimationOptions = [],
        animations: (() -> Void)?,
        completion: ((Bool) -> Void)? = nil
    ) {
        UIView.transition(with: view, duration: isReduced ? 0 : duration, options: options, animations: animations, completion: completion)
    }
}

enum Announce {
    static func say(_ text: String) {
        UIAccessibility.post(notification: .announcement, argument: text)
    }

    static func screenChanged(_ focus: Any? = nil) {
        UIAccessibility.post(notification: .screenChanged, argument: focus)
    }

    static func layoutChanged(_ focus: Any? = nil) {
        UIAccessibility.post(notification: .layoutChanged, argument: focus)
    }
}

extension UIView {
    func describe(_ label: String, hint: String? = nil, value: String? = nil, traits: UIAccessibilityTraits? = nil) {
        isAccessibilityElement = true
        accessibilityLabel = label
        accessibilityHint = hint
        accessibilityValue = value
        if let traits { accessibilityTraits = traits }
    }

    func hideFromAccessibility() {
        isAccessibilityElement = false
        accessibilityElementsHidden = true
    }
}
