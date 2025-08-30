import UIKit
import AuthenticationServices

class AuthenticationViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let contentStackView = UIStackView()
    
    private let showcaseCarousel = UIView()
    private let showcasePageControl = UIPageControl()
    private var showcaseImages: [UIView] = []
    private var showcaseTimer: Timer?
    private var currentShowcaseIndex = 0
    
    private let headerStackView = UIStackView()
    private let titleLabel = UILabel()
    private let whySignInButton = UIButton(type: .system)
    private let subtitleLabel = UILabel()
    
    private let featuresStackView = UIStackView()
    private let creditsHintView = UIView()
    private let creditsHintLabel = UILabel()
    private let securityHintView = UIView()
    private let securityIconView = UIImageView()
    private let securityLabel = UILabel()
    
    private let getStartedButton = UIButton(type: .system)
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
    
    private var areButtonsVisible = false
    
    private let authenticationManager = AuthenticationManager.shared
    private let haptics = HapticManager.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupAuthenticationObservers()
        startShowcaseAnimation()
        addSubtleAnimations()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        showcaseTimer?.invalidate()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)
        
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.axis = .vertical
        contentStackView.spacing = 24
        contentStackView.alignment = .fill
        scrollView.addSubview(contentStackView)
        
        setupShowcaseCarousel()
        setupHeaderSection()
        setupFeaturesSection()
        setupGetStartedButton()
        
        buttonContainerView.translatesAutoresizingMaskIntoConstraints = false
        buttonContainerView.alpha = 0
        buttonContainerView.isHidden = true
        view.addSubview(buttonContainerView)
        
        buttonStackView.translatesAutoresizingMaskIntoConstraints = false
        buttonStackView.axis = .vertical
        buttonStackView.spacing = 12
        buttonStackView.distribution = .fill
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
    
    private func setupShowcaseCarousel() {
        showcaseCarousel.translatesAutoresizingMaskIntoConstraints = false
        showcaseCarousel.clipsToBounds = true
        showcaseCarousel.layer.cornerRadius = 16
        contentStackView.addArrangedSubview(showcaseCarousel)
        
        for i in 0..<4 {
            let imageView = UIView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.layer.cornerRadius = 12
            
            let colors: [UIColor] = [
                UIColor(red: 0.6, green: 0.4, blue: 0.8, alpha: 1.0),
                UIColor(red: 0.4, green: 0.6, blue: 0.9, alpha: 1.0),
                UIColor(red: 0.9, green: 0.5, blue: 0.4, alpha: 1.0),
                UIColor(red: 0.4, green: 0.8, blue: 0.6, alpha: 1.0)
            ]
            imageView.backgroundColor = colors[i].withAlphaComponent(0.3)
            
            let placeholderLabel = UILabel()
            placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
            placeholderLabel.text = ["Anime Art", "Photorealistic", "Abstract", "Fantasy"][i]
            placeholderLabel.font = .systemFont(ofSize: 14, weight: .medium)
            placeholderLabel.textColor = colors[i]
            placeholderLabel.textAlignment = .center
            imageView.addSubview(placeholderLabel)
            
            NSLayoutConstraint.activate([
                placeholderLabel.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
                placeholderLabel.centerYAnchor.constraint(equalTo: imageView.centerYAnchor)
            ])
            
            imageView.alpha = i == 0 ? 1 : 0
            showcaseCarousel.addSubview(imageView)
            showcaseImages.append(imageView)
        }
        
        showcasePageControl.translatesAutoresizingMaskIntoConstraints = false
        showcasePageControl.numberOfPages = showcaseImages.count
        showcasePageControl.currentPage = 0
        showcasePageControl.pageIndicatorTintColor = .systemGray4
        showcasePageControl.currentPageIndicatorTintColor = UIColor(red: 0.404, green: 0.314, blue: 0.643, alpha: 1.0)
        showcaseCarousel.addSubview(showcasePageControl)
    }
    
    private func setupHeaderSection() {
        headerStackView.translatesAutoresizingMaskIntoConstraints = false
        headerStackView.axis = .vertical
        headerStackView.spacing = 12
        headerStackView.alignment = .center
        contentStackView.addArrangedSubview(headerStackView)
        
        titleLabel.text = "Turn ideas into stunning visuals"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        
        subtitleLabel.text = "Create AI-powered images in seconds"
        subtitleLabel.font = .systemFont(ofSize: 15)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        
        headerStackView.addArrangedSubview(titleLabel)
        headerStackView.addArrangedSubview(subtitleLabel)
    }
    
    private func setupFeaturesSection() {
        featuresStackView.translatesAutoresizingMaskIntoConstraints = false
        featuresStackView.axis = .vertical
        featuresStackView.spacing = 12
        featuresStackView.alignment = .fill
        contentStackView.addArrangedSubview(featuresStackView)
        
        creditsHintView.translatesAutoresizingMaskIntoConstraints = false
        creditsHintView.backgroundColor = UIColor(red: 0.404, green: 0.314, blue: 0.643, alpha: 0.1)
        creditsHintView.layer.cornerRadius = 12
        
        creditsHintLabel.translatesAutoresizingMaskIntoConstraints = false
        creditsHintLabel.text = "✨ Get free credits to start creating"
        creditsHintLabel.font = .systemFont(ofSize: 14, weight: .medium)
        creditsHintLabel.textColor = UIColor(red: 0.404, green: 0.314, blue: 0.643, alpha: 1.0)
        creditsHintLabel.textAlignment = .center
        creditsHintView.addSubview(creditsHintLabel)
        
        securityHintView.translatesAutoresizingMaskIntoConstraints = false
        securityHintView.backgroundColor = .systemGray6
        securityHintView.layer.cornerRadius = 12
        
        let securityStack = UIStackView()
        securityStack.translatesAutoresizingMaskIntoConstraints = false
        securityStack.axis = .horizontal
        securityStack.spacing = 8
        securityStack.alignment = .center
        
        securityIconView.image = UIImage(systemName: "lock.shield")
        securityIconView.tintColor = .systemGray
        securityIconView.contentMode = .scaleAspectFit
        
        securityLabel.text = "Secure sign-in • We never post on your behalf"
        securityLabel.font = .systemFont(ofSize: 13)
        securityLabel.textColor = .systemGray
        securityLabel.textAlignment = .center
        
        securityStack.addArrangedSubview(securityIconView)
        securityStack.addArrangedSubview(securityLabel)
        securityHintView.addSubview(securityStack)
        
        featuresStackView.addArrangedSubview(creditsHintView)
        featuresStackView.addArrangedSubview(securityHintView)
        
        NSLayoutConstraint.activate([
            creditsHintLabel.topAnchor.constraint(equalTo: creditsHintView.topAnchor, constant: 12),
            creditsHintLabel.leadingAnchor.constraint(equalTo: creditsHintView.leadingAnchor, constant: 16),
            creditsHintLabel.trailingAnchor.constraint(equalTo: creditsHintView.trailingAnchor, constant: -16),
            creditsHintLabel.bottomAnchor.constraint(equalTo: creditsHintView.bottomAnchor, constant: -12),
            
            securityIconView.widthAnchor.constraint(equalToConstant: 16),
            securityIconView.heightAnchor.constraint(equalToConstant: 16),
            
            securityStack.centerXAnchor.constraint(equalTo: securityHintView.centerXAnchor),
            securityStack.topAnchor.constraint(equalTo: securityHintView.topAnchor, constant: 12),
            securityStack.leadingAnchor.constraint(greaterThanOrEqualTo: securityHintView.leadingAnchor, constant: 16),
            securityStack.trailingAnchor.constraint(lessThanOrEqualTo: securityHintView.trailingAnchor, constant: -16),
            securityStack.bottomAnchor.constraint(equalTo: securityHintView.bottomAnchor, constant: -12)
        ])
    }
    
    private func setupGetStartedButton() {
        let buttonStackView = UIStackView()
        buttonStackView.translatesAutoresizingMaskIntoConstraints = false
        buttonStackView.axis = .vertical
        buttonStackView.spacing = 12
        buttonStackView.alignment = .fill
        
        getStartedButton.translatesAutoresizingMaskIntoConstraints = false
        var config = UIButton.Configuration.filled()
        config.title = "Get Started"
        config.baseBackgroundColor = UIColor(red: 0.404, green: 0.314, blue: 0.643, alpha: 1.0)
        config.baseForegroundColor = .white
        config.cornerStyle = .medium
        config.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 32, bottom: 16, trailing: 32)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 17, weight: .semibold)
            return outgoing
        }
        getStartedButton.configuration = config
        getStartedButton.addAction(UIAction { [weak self] _ in
            self?.toggleAuthButtons()
        }, for: .touchUpInside)
        
        whySignInButton.translatesAutoresizingMaskIntoConstraints = false
        var whyConfig = UIButton.Configuration.plain()
        whyConfig.title = "Why do I need to sign in?"
        whyConfig.baseForegroundColor = .systemGray
        whyConfig.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        whyConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 14)
            return outgoing
        }
        whySignInButton.configuration = whyConfig
        whySignInButton.addAction(UIAction { [weak self] _ in
            self?.showWhySignInModal()
        }, for: .touchUpInside)
        
        buttonStackView.addArrangedSubview(getStartedButton)
        buttonStackView.addArrangedSubview(whySignInButton)
        contentStackView.addArrangedSubview(buttonStackView)
        
        NSLayoutConstraint.activate([
            getStartedButton.heightAnchor.constraint(equalToConstant: 52)
        ])
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            contentStackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 24),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -24),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -48),
            
            showcaseCarousel.heightAnchor.constraint(equalToConstant: 200),
            
            buttonContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            buttonContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            buttonContainerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            
        ])
        
        for (_, imageView) in showcaseImages.enumerated() {
            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: showcaseCarousel.topAnchor, constant: 8),
                imageView.leadingAnchor.constraint(equalTo: showcaseCarousel.leadingAnchor, constant: 8),
                imageView.trailingAnchor.constraint(equalTo: showcaseCarousel.trailingAnchor, constant: -8),
                imageView.bottomAnchor.constraint(equalTo: showcasePageControl.topAnchor, constant: -8)
            ])
        }
        
        NSLayoutConstraint.activate([
            showcasePageControl.centerXAnchor.constraint(equalTo: showcaseCarousel.centerXAnchor),
            showcasePageControl.bottomAnchor.constraint(equalTo: showcaseCarousel.bottomAnchor, constant: -8),
            
            buttonContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            buttonContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            buttonContainerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            
            buttonStackView.leadingAnchor.constraint(equalTo: buttonContainerView.leadingAnchor, constant: 24),
            buttonStackView.trailingAnchor.constraint(equalTo: buttonContainerView.trailingAnchor, constant: -24),
            buttonStackView.topAnchor.constraint(equalTo: buttonContainerView.topAnchor),
            
            appleButton.heightAnchor.constraint(equalToConstant: 50),
            googleButton.heightAnchor.constraint(equalToConstant: 48),
            githubButton.heightAnchor.constraint(equalToConstant: 50),
            
            termsLabel.topAnchor.constraint(equalTo: buttonStackView.bottomAnchor, constant: 16),
            termsLabel.leadingAnchor.constraint(equalTo: buttonContainerView.leadingAnchor, constant: 24),
            termsLabel.trailingAnchor.constraint(equalTo: buttonContainerView.trailingAnchor, constant: -24),
            termsLabel.bottomAnchor.constraint(equalTo: buttonContainerView.bottomAnchor),
            
            errorCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            errorCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            errorCard.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -100),
            
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
        getStartedButton.isEnabled = !show
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
    
    private func startShowcaseAnimation() {
        showcaseTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.animateToNextShowcase()
        }
    }
    
    private func animateToNextShowcase() {
        let previousIndex = currentShowcaseIndex
        currentShowcaseIndex = (currentShowcaseIndex + 1) % showcaseImages.count
        
        UIView.animate(withDuration: 0.5, animations: { [weak self] in
            self?.showcaseImages[previousIndex].alpha = 0
            self?.showcaseImages[self?.currentShowcaseIndex ?? 0].alpha = 1
        })
        
        showcasePageControl.currentPage = currentShowcaseIndex
    }
    
    private func toggleAuthButtons() {
        haptics.impact(.click)
        
        if !areButtonsVisible {
            buttonContainerView.isHidden = false
            
            UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: { [weak self] in
                self?.buttonContainerView.alpha = 1
                self?.getStartedButton.alpha = 0
                self?.whySignInButton.alpha = 0
                self?.showcaseCarousel.alpha = 0
                self?.showcaseCarousel.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
                self?.headerStackView.alpha = 0
                self?.featuresStackView.alpha = 0
            }) { [weak self] _ in
                self?.areButtonsVisible = true
                self?.getStartedButton.isHidden = true
                self?.whySignInButton.isHidden = true
                self?.showcaseCarousel.isHidden = true
                self?.headerStackView.isHidden = true
                self?.featuresStackView.isHidden = true
            }
        }
    }
    
    private func showWhySignInModal() {
        haptics.impact(.click)
        
        let modalVC = UIViewController()
        modalVC.modalPresentationStyle = .pageSheet
        
        if let sheet = modalVC.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
        
        let blurEffect = UIBlurEffect(style: .systemMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        modalVC.view.addSubview(blurView)
        
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: modalVC.view.topAnchor),
            blurView.leadingAnchor.constraint(equalTo: modalVC.view.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: modalVC.view.trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: modalVC.view.bottomAnchor)
        ])
        
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = .clear
        modalVC.view.addSubview(containerView)
        
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Why Sign In?"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textAlignment = .center
        
        let contentStackView = UIStackView()
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.axis = .vertical
        contentStackView.spacing = 20
        contentStackView.alignment = .fill
        
        let benefits = [
            ("cloud", "Sync across all your devices"),
            ("photo.on.rectangle.angled", "Save your creations to gallery"),
            ("clock.arrow.circlepath", "Access generation history"),
            ("creditcard", "Track your credits and usage"),
            ("lock.shield", "Secure and private")
        ]
        
        for (icon, text) in benefits {
            let benefitStack = UIStackView()
            benefitStack.axis = .horizontal
            benefitStack.spacing = 12
            benefitStack.alignment = .center
            
            let iconView = UIImageView()
            iconView.translatesAutoresizingMaskIntoConstraints = false
            iconView.image = UIImage(systemName: icon)
            iconView.tintColor = UIColor(red: 0.404, green: 0.314, blue: 0.643, alpha: 1.0)
            iconView.contentMode = .scaleAspectFit
            
            let label = UILabel()
            label.text = text
            label.font = .systemFont(ofSize: 16)
            label.textColor = .label
            label.numberOfLines = 0
            
            benefitStack.addArrangedSubview(iconView)
            benefitStack.addArrangedSubview(label)
            contentStackView.addArrangedSubview(benefitStack)
            
            NSLayoutConstraint.activate([
                iconView.widthAnchor.constraint(equalToConstant: 24),
                iconView.heightAnchor.constraint(equalToConstant: 24)
            ])
        }
        
        let closeButton = UIButton(type: .system)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        var config = UIButton.Configuration.filled()
        config.title = "Got it"
        config.baseBackgroundColor = UIColor(red: 0.404, green: 0.314, blue: 0.643, alpha: 1.0)
        config.baseForegroundColor = .white
        config.cornerStyle = .medium
        closeButton.configuration = config
        closeButton.addAction(UIAction { _ in
            modalVC.dismiss(animated: true)
        }, for: .touchUpInside)
        
        containerView.addSubview(titleLabel)
        containerView.addSubview(contentStackView)
        containerView.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: modalVC.view.safeAreaLayoutGuide.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: modalVC.view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: modalVC.view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: modalVC.view.safeAreaLayoutGuide.bottomAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            
            contentStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 32),
            contentStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            contentStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            
            closeButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            closeButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            closeButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24),
            closeButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        present(modalVC, animated: true)
    }
    
    private func addSubtleAnimations() {
        UIView.animate(withDuration: 2.0, delay: 0.5, options: [.repeat, .autoreverse, .curveEaseInOut], animations: { [weak self] in
            self?.creditsHintView.transform = CGAffineTransform(scaleX: 1.02, y: 1.02)
        })
        
        UIView.animate(withDuration: 1.0, delay: 0, options: [.curveEaseOut], animations: { [weak self] in
            self?.headerStackView.alpha = 0
            self?.headerStackView.transform = CGAffineTransform(translationX: 0, y: 20)
        }) { _ in
            UIView.animate(withDuration: 0.8, delay: 0, options: [.curveEaseOut], animations: { [weak self] in
                self?.headerStackView.alpha = 1
                self?.headerStackView.transform = .identity
            })
        }
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