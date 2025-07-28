import UIKit
import AuthenticationServices

class AppleSignInButton: UIView {
    
    private let containerView = UIView()
    private let appleButton = ASAuthorizationAppleIDButton(type: .signIn, style: .black)
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
        containerView.backgroundColor = .black
        containerView.layer.cornerRadius = 8
        containerView.clipsToBounds = true
        addSubview(containerView)
        
        appleButton.translatesAutoresizingMaskIntoConstraints = false
        appleButton.cornerRadius = 8
        appleButton.addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        containerView.addSubview(appleButton)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            appleButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            appleButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            appleButton.heightAnchor.constraint(equalToConstant: 44),
            appleButton.widthAnchor.constraint(equalToConstant: 260)
        ])
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
            containerView.alpha = newValue ? 1.0 : 0.5
        }
    }
}