import UIKit
import AuthenticationServices

class AppleSignInButton: UIView {

    private let containerView = UIView()
    private let appleButton = ASAuthorizationAppleIDButton(type: .signIn, style: .white)
    private let loadingScrim = UIView()
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private var tapAction: UIAction?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }

    private func setupButton() {
        translatesAutoresizingMaskIntoConstraints = false

        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.clipsToBounds = true
        containerView.layer.cornerCurve = .continuous
        addSubview(containerView)

        appleButton.translatesAutoresizingMaskIntoConstraints = false
        appleButton.accessibilityLabel = String(localized: "Sign in with Apple")
        appleButton.addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        containerView.addSubview(appleButton)

        loadingScrim.translatesAutoresizingMaskIntoConstraints = false
        loadingScrim.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        loadingScrim.isHidden = true
        loadingScrim.hideFromAccessibility()
        containerView.addSubview(loadingScrim)

        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.color = .white
        loadingScrim.addSubview(loadingIndicator)

        let fillWidth = [
            appleButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            appleButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ]
        
        NSLayoutConstraint.activate(fillWidth + [
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),

            appleButton.topAnchor.constraint(equalTo: containerView.topAnchor),
            appleButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            loadingScrim.topAnchor.constraint(equalTo: containerView.topAnchor),
            loadingScrim.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            loadingScrim.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            loadingScrim.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            loadingIndicator.centerXAnchor.constraint(equalTo: loadingScrim.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: loadingScrim.centerYAnchor)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let radius = bounds.height / 2
        containerView.layer.cornerRadius = radius
        appleButton.cornerRadius = radius
    }

    @objc private func handleTap() {
        if let action = tapAction {
            action.performWithSender(self, target: nil)
        }
    }

    func addAction(_ action: UIAction, for event: UIControl.Event) {
        tapAction = action
    }

    var isEnabled: Bool {
        get { appleButton.isEnabled }
        set {
            appleButton.isEnabled = newValue
            containerView.alpha = newValue || isLoading ? 1.0 : 0.45
        }
    }

    var isLoading = false {
        didSet {
            guard isLoading != oldValue else { return }
            loadingScrim.isHidden = !isLoading
            if isLoading {
                loadingIndicator.startAnimating()
            } else {
                loadingIndicator.stopAnimating()
            }
            containerView.alpha = appleButton.isEnabled || isLoading ? 1.0 : 0.45
        }
    }
}
