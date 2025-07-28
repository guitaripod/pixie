import UIKit
import GoogleSignIn

class GoogleSignInButtonWrapper: UIView {
    
    private let signInButton = GIDSignInButton()
    
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
        
        addSubview(signInButton)
        
        NSLayoutConstraint.activate([
            signInButton.topAnchor.constraint(equalTo: topAnchor),
            signInButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            signInButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            signInButton.bottomAnchor.constraint(equalTo: bottomAnchor)
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
}