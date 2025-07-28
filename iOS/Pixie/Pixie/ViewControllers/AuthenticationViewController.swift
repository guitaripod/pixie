import UIKit
import AuthenticationServices

class AuthenticationViewController: UIViewController {
    
    private let logoStackView = UIStackView()
    private let logoImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let buttonContainerView = UIView()
    private let buttonStackView = UIStackView()
    private let appleButton = AppleSignInButton()
    private let googleButton = GoogleSignInButtonWrapper()
    private let githubButton = OAuthButton()
    private let termsLabel = UILabel()
    private let errorCard = UIView()
    private let errorLabel = UILabel()
    private let loadingOverlay = UIView()
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    
    private let authenticationManager = AuthenticationManager.shared
    private let haptics = HapticManager.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupAuthenticationObservers()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        logoStackView.translatesAutoresizingMaskIntoConstraints = false
        logoStackView.axis = .vertical
        logoStackView.alignment = .center
        logoStackView.spacing = 16
        view.addSubview(logoStackView)
        
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        logoImageView.image = UIImage(systemName: "sparkles")
        logoImageView.tintColor = UIColor(red: 0.404, green: 0.314, blue: 0.643, alpha: 1.0)
        logoImageView.contentMode = .scaleAspectFit
        
        titleLabel.text = "Pixie"
        titleLabel.font = .systemFont(ofSize: 32, weight: .bold)
        titleLabel.textAlignment = .center
        
        subtitleLabel.text = "AI-powered image generation"
        subtitleLabel.font = .systemFont(ofSize: 16)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        
        logoStackView.addArrangedSubview(logoImageView)
        logoStackView.addArrangedSubview(titleLabel)
        logoStackView.addArrangedSubview(subtitleLabel)
        
        buttonContainerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonContainerView)
        
        buttonStackView.translatesAutoresizingMaskIntoConstraints = false
        buttonStackView.axis = .vertical
        buttonStackView.spacing = 12
        buttonStackView.distribution = .fillEqually
        buttonContainerView.addSubview(buttonStackView)
        
        googleButton.addAction(UIAction { [weak self] _ in
            self?.handleGoogleSignIn()
        }, for: .touchUpInside)
        
        appleButton.addAction(UIAction { [weak self] _ in
            self?.handleAppleSignIn()
        }, for: .touchUpInside)
        
        githubButton.configure(
            provider: .github,
            title: "Sign in with GitHub",
            backgroundColor: UIColor(red: 0.141, green: 0.161, blue: 0.180, alpha: 1.0),
            textColor: .white,
            borderColor: nil,
            iconName: "github_logo"
        )
        githubButton.addAction(UIAction { [weak self] _ in
            self?.handleGitHubSignIn()
        }, for: .touchUpInside)
        
        buttonStackView.addArrangedSubview(appleButton)
        buttonStackView.addArrangedSubview(googleButton)
        buttonStackView.addArrangedSubview(githubButton)
        
        if DebugUtils.isRunningInSimulator {
            let debugButton = UIButton()
            debugButton.translatesAutoresizingMaskIntoConstraints = false
            var config = UIButton.Configuration.filled()
            config.title = "Debug Login (Simulator Only)"
            config.baseBackgroundColor = .systemPurple
            config.cornerStyle = .medium
            config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
            debugButton.configuration = config
            debugButton.addAction(UIAction { [weak self] _ in
                self?.handleDebugSignIn()
            }, for: .touchUpInside)
            buttonStackView.addArrangedSubview(debugButton)
            
            NSLayoutConstraint.activate([
                debugButton.heightAnchor.constraint(equalToConstant: 50)
            ])
        }
        
        termsLabel.translatesAutoresizingMaskIntoConstraints = false
        termsLabel.text = "By signing in, you agree to our Terms"
        termsLabel.font = .systemFont(ofSize: 12)
        termsLabel.textColor = .tertiaryLabel
        termsLabel.textAlignment = .center
        buttonContainerView.addSubview(termsLabel)
        
        errorCard.translatesAutoresizingMaskIntoConstraints = false
        errorCard.backgroundColor = .systemRed.withAlphaComponent(0.1)
        errorCard.layer.cornerRadius = 8
        errorCard.isHidden = true
        view.addSubview(errorCard)
        
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.font = .systemFont(ofSize: 14)
        errorLabel.textColor = .systemRed
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorCard.addSubview(errorLabel)
        
        loadingOverlay.translatesAutoresizingMaskIntoConstraints = false
        loadingOverlay.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.8)
        loadingOverlay.isHidden = true
        view.addSubview(loadingOverlay)
        
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingOverlay.addSubview(loadingIndicator)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            logoStackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoStackView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -100),
            
            logoImageView.widthAnchor.constraint(equalToConstant: 64),
            logoImageView.heightAnchor.constraint(equalToConstant: 64),
            
            buttonContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            buttonContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            buttonContainerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            
            buttonStackView.leadingAnchor.constraint(equalTo: buttonContainerView.leadingAnchor, constant: 24),
            buttonStackView.trailingAnchor.constraint(equalTo: buttonContainerView.trailingAnchor, constant: -24),
            buttonStackView.topAnchor.constraint(equalTo: buttonContainerView.topAnchor),
            
            appleButton.heightAnchor.constraint(equalToConstant: 50),
            googleButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 48),
            githubButton.heightAnchor.constraint(equalToConstant: 50),
            
            termsLabel.topAnchor.constraint(equalTo: buttonStackView.bottomAnchor, constant: 16),
            termsLabel.leadingAnchor.constraint(equalTo: buttonContainerView.leadingAnchor, constant: 24),
            termsLabel.trailingAnchor.constraint(equalTo: buttonContainerView.trailingAnchor, constant: -24),
            termsLabel.bottomAnchor.constraint(equalTo: buttonContainerView.bottomAnchor),
            
            errorCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            errorCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            errorCard.bottomAnchor.constraint(equalTo: buttonContainerView.topAnchor, constant: -16),
            
            errorLabel.topAnchor.constraint(equalTo: errorCard.topAnchor, constant: 12),
            errorLabel.leadingAnchor.constraint(equalTo: errorCard.leadingAnchor, constant: 12),
            errorLabel.trailingAnchor.constraint(equalTo: errorCard.trailingAnchor, constant: -12),
            errorLabel.bottomAnchor.constraint(equalTo: errorCard.bottomAnchor, constant: -12),
            
            loadingOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            loadingOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: loadingOverlay.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: loadingOverlay.centerYAnchor)
        ])
    }
    
    private func setupAuthenticationObservers() {
        authenticationManager.delegate = self
    }
    
    private func handleGoogleSignIn() {
        haptics.impact(.click)
        showLoading(true)
        hideError()
        authenticationManager.authenticate(with: .google, from: self)
    }
    
    private func handleAppleSignIn() {
        haptics.impact(.click)
        showLoading(true)
        hideError()
        authenticationManager.authenticate(with: .apple, from: self)
    }
    
    private func handleGitHubSignIn() {
        haptics.impact(.click)
        showLoading(true)
        hideError()
        authenticationManager.authenticate(with: .github, from: self)
    }
    
    private func showLoading(_ show: Bool) {
        loadingOverlay.isHidden = !show
        if show {
            loadingIndicator.startAnimating()
        } else {
            loadingIndicator.stopAnimating()
        }
        
        appleButton.isEnabled = !show
        googleButton.isEnabled = !show
        githubButton.isEnabled = !show
    }
    
    private func showError(_ message: String) {
        errorLabel.text = message
        errorCard.isHidden = false
        haptics.notification(.error)
    }
    
    private func hideError() {
        errorCard.isHidden = true
    }
    
    private func handleDebugSignIn() {
        haptics.impact(.click)
        showLoading(true)
        hideError()
        authenticationManager.authenticateDebug(from: self)
    }
}

extension AuthenticationViewController: AuthenticationManagerDelegate {
    func authenticationManager(_ manager: AuthenticationManager, didAuthenticate user: User) {
        DispatchQueue.main.async { [weak self] in
            self?.showLoading(false)
            self?.haptics.notification(.success)
            
            if let sceneDelegate = self?.view.window?.windowScene?.delegate as? SceneDelegate {
                sceneDelegate.showMainInterface()
            }
        }
    }
    
    func authenticationManager(_ manager: AuthenticationManager, didFailWithError error: String) {
        DispatchQueue.main.async { [weak self] in
            self?.showLoading(false)
            self?.showError(error)
        }
    }
}