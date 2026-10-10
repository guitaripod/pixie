import UIKit
import GoogleSignIn

class GoogleSignInButtonWrapper: UIView {
    
    private let signInButton = GIDSignInButton()
    private let loadingScrim = UIView()
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    
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
        
        signInButton.translatesAutoresizingMaskIntoConstraints = false
        signInButton.style = .wide
        signInButton.accessibilityLabel = String(localized: "Sign in with Google")
        
        addSubview(signInButton)
        
        loadingScrim.translatesAutoresizingMaskIntoConstraints = false
        loadingScrim.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        loadingScrim.layer.cornerRadius = 4
        loadingScrim.isHidden = true
        loadingScrim.hideFromAccessibility()
        addSubview(loadingScrim)
        
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.color = .white
        loadingScrim.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            signInButton.topAnchor.constraint(equalTo: topAnchor),
            signInButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            signInButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            signInButton.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            loadingScrim.topAnchor.constraint(equalTo: topAnchor),
            loadingScrim.leadingAnchor.constraint(equalTo: leadingAnchor),
            loadingScrim.trailingAnchor.constraint(equalTo: trailingAnchor),
            loadingScrim.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: loadingScrim.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: loadingScrim.centerYAnchor)
        ])
    }
    
    func addAction(_ action: UIAction, for controlEvents: UIControl.Event) {
        signInButton.addAction(action, for: controlEvents)
    }
    
    var isEnabled: Bool = true {
        didSet {
            signInButton.isEnabled = isEnabled
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
        }
    }
}
