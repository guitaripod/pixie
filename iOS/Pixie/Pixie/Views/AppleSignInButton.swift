import UIKit
import AuthenticationServices

class AppleSignInButton: UIView {
    
    private static let maximumWidth: CGFloat = 420
    
    private let containerView = UIView()
    private let appleButton = ASAuthorizationAppleIDButton(type: .signIn, style: .black)
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
        containerView.layer.cornerRadius = 8
        containerView.clipsToBounds = true
        containerView.layer.borderWidth = 1
        applyBorderColor()
        addSubview(containerView)
        
        appleButton.translatesAutoresizingMaskIntoConstraints = false
        appleButton.cornerRadius = 8
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
        fillWidth.forEach { $0.priority = .defaultHigh }
        
        NSLayoutConstraint.activate(fillWidth + [
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            appleButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            appleButton.topAnchor.constraint(equalTo: containerView.topAnchor),
            appleButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            appleButton.widthAnchor.constraint(lessThanOrEqualToConstant: Self.maximumWidth),
            
            loadingScrim.topAnchor.constraint(equalTo: containerView.topAnchor),
            loadingScrim.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            loadingScrim.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            loadingScrim.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: loadingScrim.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: loadingScrim.centerYAnchor)
        ])
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            applyBorderColor()
        }
    }

    /// The black Apple button vanishes on a dark background, so a hairline keeps its edge visible.
    private func applyBorderColor() {
        containerView.layer.borderColor = UIColor.separator.resolvedColor(with: traitCollection).cgColor
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
            containerView.alpha = newValue || isLoading ? 1.0 : 0.5
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
            containerView.alpha = appleButton.isEnabled || isLoading ? 1.0 : 0.5
        }
    }
}
