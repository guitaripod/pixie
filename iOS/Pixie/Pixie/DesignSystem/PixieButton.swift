import UIKit

final class PixieButton: UIButton {
    enum Style {
        case primary
        case secondary
        case plain
        case destructive
        case onBackdrop
        case onBackdropFill
    }

    enum Size {
        case large
        case medium
        case small

        var minHeight: CGFloat {
            switch self {
            case .large: return 56
            case .medium: return 46
            case .small: return 36
            }
        }

        var textStyle: Theme.TextStyle {
            switch self {
            case .large: return .headline
            case .medium: return .subhead
            case .small: return .footnote
            }
        }

        var horizontalInset: CGFloat {
            switch self {
            case .large: return 28
            case .medium: return 22
            case .small: return 14
            }
        }
    }

    private(set) var pixieStyle: Style
    private let size: Size
    private let gradientBackground = GradientView()

    var title: String? {
        didSet { setNeedsUpdateConfiguration() }
    }

    var symbol: String? {
        didSet { setNeedsUpdateConfiguration() }
    }

    var isLoading = false {
        didSet {
            setNeedsUpdateConfiguration()
            isUserInteractionEnabled = !isLoading
        }
    }

    init(style: Style = .primary, size: Size = .large, title: String? = nil, symbol: String? = nil, handler: (() -> Void)? = nil) {
        pixieStyle = style
        self.size = size
        self.title = title
        self.symbol = symbol
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(greaterThanOrEqualToConstant: size.minHeight).isActive = true
        configurationUpdateHandler = { [weak self] _ in self?.refresh() }
        if let handler {
            addAction(UIAction { _ in
                HapticsManager.shared.selection()
                handler()
            }, for: .touchUpInside)
        }
        refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var isHighlighted: Bool {
        didSet {
            guard oldValue != isHighlighted, !Motion.isReduced else { return }
            Motion.animate(0.15, options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientBackground.cornerRadius = bounds.height / 2
    }

    private func refresh() {
        var config = UIButton.Configuration.plain()
        config.cornerStyle = .capsule
        config.imagePadding = 8
        config.titleAlignment = .center
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: size.horizontalInset, bottom: 12, trailing: size.horizontalInset)
        config.title = title
        config.image = symbol.flatMap { UIImage(systemName: $0, withConfiguration: UIImage.SymbolConfiguration(weight: .semibold)) }
        config.showsActivityIndicator = isLoading
        let textStyle = size.textStyle
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = textStyle.font
            return outgoing
        }

        let enabled = isEnabled
        switch pixieStyle {
        case .primary:
            config.baseForegroundColor = .white
            config.background.backgroundColor = .clear
            config.background.customView = gradientBackground
            gradientBackground.alpha = enabled ? 1 : 0.35
        case .secondary:
            config.baseForegroundColor = Theme.Color.accentText
            config.background.backgroundColor = Theme.Color.accentSoft
        case .plain:
            config.baseForegroundColor = Theme.Color.accentText
            config.background.backgroundColor = .clear
        case .destructive:
            config.baseForegroundColor = Theme.Color.danger
            config.background.backgroundColor = Theme.Color.danger.withAlphaComponent(0.14)
        case .onBackdrop:
            config.baseForegroundColor = UIColor(hex: 0x15121F)
            config.background.backgroundColor = .white
        case .onBackdropFill:
            config.baseForegroundColor = .white
            config.background.backgroundColor = Theme.Color.onBackdropFill
        }
        if !enabled, pixieStyle != .primary {
            config.baseForegroundColor = Theme.Color.inkTertiary
        }
        configuration = config
        alpha = enabled || pixieStyle == .primary ? 1 : 0.6
    }

    override var isEnabled: Bool {
        didSet { setNeedsUpdateConfiguration() }
    }
}
