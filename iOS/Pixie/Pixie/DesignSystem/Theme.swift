import UIKit

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    static func adaptive(light: UIColor, dark: UIColor) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? dark : light }
    }

    static func adaptive(light: UInt32, dark: UInt32) -> UIColor {
        adaptive(light: UIColor(hex: light), dark: UIColor(hex: dark))
    }
}

enum Theme {
    enum Color {
        static let canvas = UIColor.adaptive(light: 0xF6F4FA, dark: 0x0B0A12)
        static let surface = UIColor.adaptive(light: 0xFFFFFF, dark: 0x15131F)
        static let surfaceRaised = UIColor.adaptive(light: 0xFFFFFF, dark: 0x1E1B2B)
        static let fill = UIColor.adaptive(light: UIColor(hex: 0x15121F, alpha: 0.06), dark: UIColor(hex: 0xFFFFFF, alpha: 0.08))
        static let line = UIColor.adaptive(light: UIColor(hex: 0x15121F, alpha: 0.10), dark: UIColor(hex: 0xFFFFFF, alpha: 0.10))

        static let ink = UIColor.adaptive(light: 0x15121F, dark: 0xF4F2FA)
        static let inkSecondary = UIColor.adaptive(light: 0x5E5A6E, dark: 0xA7A2B8)
        static let inkTertiary = UIColor.adaptive(light: 0x8C879C, dark: 0x75708A)

        static let accent = UIColor.adaptive(light: 0x6C47FF, dark: 0x7F62FF)
        static let accentText = UIColor.adaptive(light: 0x5B38F0, dark: 0xA99BFF)
        static let accentSoft = UIColor.adaptive(light: UIColor(hex: 0x6C47FF, alpha: 0.12), dark: UIColor(hex: 0x7F62FF, alpha: 0.24))

        static let success = UIColor.adaptive(light: 0x12A06B, dark: 0x3DD9A0)
        static let warning = UIColor.adaptive(light: 0xD98E00, dark: 0xFFC247)
        static let danger = UIColor.adaptive(light: 0xE5484D, dark: 0xFF7A80)

        static let backdrop = UIColor(hex: 0x0B0A12)
        static let onBackdrop = UIColor.white
        static let onBackdropSecondary = UIColor(white: 1, alpha: 0.70)
        static let onBackdropFill = UIColor(white: 1, alpha: 0.10)
        static let onBackdropLine = UIColor(white: 1, alpha: 0.14)

        static let gradient: [UIColor] = [UIColor(hex: 0x6C47FF), UIColor(hex: 0xB04BFF), UIColor(hex: 0xFF6FA3)]
    }

    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
        static let huge: CGFloat = 48
    }

    enum Radius {
        static let sm: CGFloat = 10
        static let md: CGFloat = 14
        static let lg: CGFloat = 20
        static let xl: CGFloat = 28
        static let sheet: CGFloat = 32
    }

    enum Width {
        static let form: CGFloat = 640
        static let grid: CGFloat = 1100
        static let button: CGFloat = 420
    }

    static func screenMargin(for traits: UITraitCollection) -> CGFloat {
        traits.horizontalSizeClass == .regular ? Space.xxxl : Space.xl
    }

    enum TextStyle {
        case display
        case title
        case title2
        case headline
        case body
        case callout
        case subhead
        case footnote
        case caption
        case numeral(CGFloat)

        var font: UIFont {
            switch self {
            case .display: return .scaled(.largeTitle, size: 34, weight: .heavy, rounded: true)
            case .title: return .scaled(.title1, size: 28, weight: .bold, rounded: true)
            case .title2: return .scaled(.title2, size: 22, weight: .semibold)
            case .headline: return .scaled(.headline, size: 17, weight: .semibold)
            case .body: return .scaled(.body, size: 17)
            case .callout: return .scaled(.callout, size: 16)
            case .subhead: return .scaled(.subheadline, size: 15, weight: .medium)
            case .footnote: return .scaled(.footnote, size: 13)
            case .caption: return .scaled(.caption1, size: 12, weight: .semibold)
            case .numeral(let size): return .scaled(.title1, size: size, weight: .heavy, rounded: true)
            }
        }

        var color: UIColor {
            switch self {
            case .display, .title, .title2, .headline, .body, .numeral: return Theme.Color.ink
            case .callout, .subhead, .footnote: return Theme.Color.inkSecondary
            case .caption: return Theme.Color.inkSecondary
            }
        }

        var kern: CGFloat {
            switch self {
            case .display: return -0.4
            case .caption: return 0.6
            default: return 0
            }
        }

        var isUppercase: Bool {
            if case .caption = self { return true }
            return false
        }
    }

    static func attributed(_ text: String, _ style: TextStyle, color: UIColor? = nil, alignment: NSTextAlignment = .natural) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        if case .display = style { paragraph.lineHeightMultiple = 0.95 }
        return NSAttributedString(
            string: style.isUppercase ? text.uppercased() : text,
            attributes: [
                .font: style.font,
                .foregroundColor: color ?? style.color,
                .kern: style.kern,
                .paragraphStyle: paragraph,
            ]
        )
    }
}

extension UILabel {
    func apply(_ style: Theme.TextStyle, color: UIColor? = nil) {
        font = style.font
        textColor = color ?? style.color
        adjustsFontForContentSizeCategory = true
        numberOfLines = 0
    }

    func setStyledText(_ text: String, _ style: Theme.TextStyle, color: UIColor? = nil, alignment: NSTextAlignment = .natural) {
        adjustsFontForContentSizeCategory = true
        numberOfLines = 0
        attributedText = Theme.attributed(text, style, color: color, alignment: alignment)
    }
}

extension UIView {
    func pinEdges(to other: UIView, insets: UIEdgeInsets = .zero) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: other.topAnchor, constant: insets.top),
            leadingAnchor.constraint(equalTo: other.leadingAnchor, constant: insets.left),
            trailingAnchor.constraint(equalTo: other.trailingAnchor, constant: -insets.right),
            bottomAnchor.constraint(equalTo: other.bottomAnchor, constant: -insets.bottom),
        ])
    }
}


extension Theme {
    static func applyGlobalAppearance() {
        UISwitch.appearance().onTintColor = Color.accent
        UISlider.appearance().minimumTrackTintColor = Color.accent
        UISegmentedControl.appearance().selectedSegmentTintColor = Color.surfaceRaised
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: Color.ink, .font: TextStyle.subhead.font], for: .selected)
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: Color.inkSecondary, .font: TextStyle.subhead.font], for: .normal)
        UIRefreshControl.appearance().tintColor = Color.accentText
        UIPageControl.appearance().currentPageIndicatorTintColor = Color.accent
        UIPageControl.appearance().pageIndicatorTintColor = Color.line
    }
}
