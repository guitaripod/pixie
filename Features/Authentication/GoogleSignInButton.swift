import UIKit

class GoogleSignInButtonWrapper: UIView {

    private let signInButton = OAuthButton()

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

        signInButton.configure(
            provider: .google,
            title: String(localized: "Sign in with Google"),
            backgroundColor: .white,
            textColor: UIColor(hex: 0x1F1F1F),
            borderColor: nil,
            iconName: nil
        )
        addSubview(signInButton)
        signInButton.pinEdges(to: self)
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
            signInButton.isLoading = isLoading
        }
    }
}
