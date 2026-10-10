import UIKit

class OAuthButton: UIButton {

    private var textColor: UIColor = .white
    private var fillColor: UIColor = .clear
    private var strokeColor: UIColor?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }

    var isLoading = false {
        didSet {
            guard isLoading != oldValue else { return }
            setNeedsUpdateConfiguration()
        }
    }

    private func setupButton() {
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(greaterThanOrEqualToConstant: 56).isActive = true

        configurationUpdateHandler = { [weak self] button in
            guard let self, var config = button.configuration else { return }

            config.background.backgroundColor = self.fillColor
            config.background.strokeColor = self.strokeColor
            config.background.strokeWidth = self.strokeColor == nil ? 0 : 1
            config.showsActivityIndicator = self.isLoading
            config.activityIndicatorColorTransformer = UIConfigurationColorTransformer { _ in self.textColor }
            button.configuration = config

            button.alpha = button.isEnabled || self.isLoading ? 1 : 0.45
            let pressed = button.isHighlighted && !Motion.isReduced
            Motion.animate(0.15, options: [.allowUserInteraction, .beginFromCurrentState]) {
                button.transform = pressed ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
            }
        }
    }

    func configure(provider: AuthProvider, title: String, backgroundColor: UIColor, textColor: UIColor, borderColor: UIColor?, iconName: String?) {
        self.textColor = textColor
        fillColor = backgroundColor
        strokeColor = borderColor
        accessibilityLabel = title

        var config = UIButton.Configuration.plain()
        config.title = title
        config.baseForegroundColor = textColor
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 24, bottom: 14, trailing: 24)
        config.titleLineBreakMode = .byWordWrapping
        config.titleAlignment = .center
        config.imagePlacement = .leading
        config.imagePadding = 10
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = Theme.TextStyle.headline.font
            return outgoing
        }

        switch provider {
        case .google:
            config.image = UIImage(named: "google_mark")?.withRenderingMode(.alwaysOriginal)
        case .github:
            config.image = UIImage(named: "github_mark")?.withRenderingMode(.alwaysTemplate)
        case .apple:
            break
        }

        self.configuration = config
        setNeedsUpdateConfiguration()
    }
}
