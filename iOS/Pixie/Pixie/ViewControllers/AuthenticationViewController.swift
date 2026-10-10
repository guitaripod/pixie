import UIKit
import AuthenticationServices

class AuthenticationViewController: UIViewController {

    private static let maximumContentWidth: CGFloat = 420
    private static let showcaseInterval: TimeInterval = 3.0

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
    private let buttonScrollView = UIScrollView()
    private let buttonContainerView = UIView()
    private let buttonStackView = UIStackView()
    private let appleButton = AppleSignInButton()
    private let googleButton = GoogleSignInButtonWrapper()
    private let githubButton = OAuthButton()
    private var debugButton: UIButton?
    private let termsLabel = UILabel()
    private let errorCard = UIView()
    private let errorIconView = UIImageView()
    private let errorLabel = UILabel()
    private let loadingOverlay = UIView()

    private var areButtonsVisible = false

    private let authenticationManager = AuthenticationManager.shared
    private let haptics = HapticManager.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupAuthenticationObservers()
        setupAccessibilityObservers()
        updateShowcaseTimer()
        addSubtleAnimations()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateShowcaseTimer()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        showcaseTimer?.invalidate()
        showcaseTimer = nil
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

        buttonScrollView.translatesAutoresizingMaskIntoConstraints = false
        buttonScrollView.showsVerticalScrollIndicator = false
        buttonScrollView.alpha = 0
        buttonScrollView.isHidden = true
        view.addSubview(buttonScrollView)

        buttonContainerView.translatesAutoresizingMaskIntoConstraints = false
        buttonScrollView.addSubview(buttonContainerView)

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
            title: String(localized: "Sign in with GitHub"),
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
            config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20)
            debugButton.configuration = config
            debugButton.addAction(UIAction { [weak self] _ in
                self?.handleDebugSignIn()
            }, for: .touchUpInside)
            buttonStackView.addArrangedSubview(debugButton)
            self.debugButton = debugButton

            NSLayoutConstraint.activate([
                debugButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 50)
            ])
        }

        termsLabel.translatesAutoresizingMaskIntoConstraints = false
        termsLabel.text = String(localized: "By signing in, you agree to our Terms")
        termsLabel.useScaledFont(.caption1, size: 12)
        termsLabel.textColor = .secondaryLabel
        termsLabel.textAlignment = .center
        termsLabel.numberOfLines = 0
        buttonContainerView.addSubview(termsLabel)

        loadingOverlay.translatesAutoresizingMaskIntoConstraints = false
        loadingOverlay.backgroundColor = .clear
        loadingOverlay.isHidden = true
        loadingOverlay.hideFromAccessibility()
        view.addSubview(loadingOverlay)

        setupErrorBanner()
    }

    private func setupErrorBanner() {
        errorCard.translatesAutoresizingMaskIntoConstraints = false
        errorCard.backgroundColor = UIColor.systemRed.withAlphaComponent(0.12)
        errorCard.layer.cornerRadius = 12
        errorCard.layer.borderWidth = 1
        errorCard.layer.borderColor = UIColor.systemRed.withAlphaComponent(0.5).cgColor
        errorCard.isHidden = true
        view.addSubview(errorCard)

        errorIconView.translatesAutoresizingMaskIntoConstraints = false
        errorIconView.image = UIImage(systemName: "exclamationmark.triangle.fill")
        errorIconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .subheadline)
        errorIconView.tintColor = .systemRed
        errorIconView.contentMode = .scaleAspectFit
        errorIconView.setContentHuggingPriority(.required, for: .horizontal)
        errorIconView.hideFromAccessibility()

        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.useScaledFont(.subheadline, size: 14)
        errorLabel.textColor = .label
        errorLabel.numberOfLines = 0

        let errorStack = UIStackView(arrangedSubviews: [errorIconView, errorLabel])
        errorStack.translatesAutoresizingMaskIntoConstraints = false
        errorStack.axis = .horizontal
        errorStack.alignment = .center
        errorStack.spacing = 8
        errorCard.addSubview(errorStack)

        NSLayoutConstraint.activate([
            errorStack.topAnchor.constraint(equalTo: errorCard.topAnchor, constant: 12),
            errorStack.leadingAnchor.constraint(equalTo: errorCard.leadingAnchor, constant: 12),
            errorStack.trailingAnchor.constraint(equalTo: errorCard.trailingAnchor, constant: -12),
            errorStack.bottomAnchor.constraint(equalTo: errorCard.bottomAnchor, constant: -12)
        ])
    }

    private func setupShowcaseCarousel() {
        showcaseCarousel.translatesAutoresizingMaskIntoConstraints = false
        showcaseCarousel.clipsToBounds = true
        showcaseCarousel.layer.cornerRadius = 16
        showcaseCarousel.hideFromAccessibility()
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
            placeholderLabel.text = [String(localized: "Anime Art"), String(localized: "Photorealistic"), String(localized: "Abstract"), String(localized: "Fantasy")][i]
            placeholderLabel.useScaledFont(.subheadline, size: 14, weight: .medium)
            placeholderLabel.textColor = .label
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
        showcasePageControl.pageIndicatorTintColor = .systemGray3
        showcasePageControl.currentPageIndicatorTintColor = .brandText
        showcasePageControl.addAction(UIAction { [weak self] _ in
            self?.showcasePageControlChanged()
        }, for: .valueChanged)
        showcaseCarousel.addSubview(showcasePageControl)

        showcaseCarousel.isUserInteractionEnabled = true
        for direction in [UISwipeGestureRecognizer.Direction.left, .right] {
            let swipe = UISwipeGestureRecognizer(target: self, action: #selector(showcaseSwiped(_:)))
            swipe.direction = direction
            showcaseCarousel.addGestureRecognizer(swipe)
        }
    }

    private func setupHeaderSection() {
        headerStackView.translatesAutoresizingMaskIntoConstraints = false
        headerStackView.axis = .vertical
        headerStackView.spacing = 12
        headerStackView.alignment = .center
        contentStackView.addArrangedSubview(headerStackView)

        titleLabel.text = String(localized: "Turn ideas into stunning visuals")
        titleLabel.useScaledFont(.title2, size: 24, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.accessibilityTraits = .header

        subtitleLabel.text = String(localized: "Create AI-powered images in seconds")
        subtitleLabel.useScaledFont(.subheadline, size: 15)
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
        creditsHintView.backgroundColor = .brandTint
        creditsHintView.layer.cornerRadius = 12

        let creditsHintText = String(localized: "✨ Get free credits to start creating")
        creditsHintLabel.translatesAutoresizingMaskIntoConstraints = false
        creditsHintLabel.text = creditsHintText
        creditsHintLabel.accessibilityLabel = creditsHintText.replacingOccurrences(of: "✨ ", with: "")
        creditsHintLabel.useScaledFont(.subheadline, size: 14, weight: .medium)
        creditsHintLabel.textColor = .brandText
        creditsHintLabel.textAlignment = .center
        creditsHintLabel.numberOfLines = 0
        creditsHintView.addSubview(creditsHintLabel)

        securityHintView.translatesAutoresizingMaskIntoConstraints = false
        securityHintView.backgroundColor = .systemGray6
        securityHintView.layer.cornerRadius = 12

        let securityStack = UIStackView()
        securityStack.translatesAutoresizingMaskIntoConstraints = false
        securityStack.axis = .horizontal
        securityStack.spacing = 8
        securityStack.alignment = .center

        let securityText = String(localized: "Secure sign-in • We never post on your behalf")
        securityIconView.image = UIImage(systemName: "lock.shield")
        securityIconView.tintColor = .secondaryLabel
        securityIconView.contentMode = .scaleAspectFit
        securityIconView.setContentHuggingPriority(.required, for: .horizontal)
        securityIconView.setContentCompressionResistancePriority(.required, for: .horizontal)

        securityLabel.text = securityText
        securityLabel.useScaledFont(.footnote, size: 13)
        securityLabel.textColor = .secondaryLabel
        securityLabel.textAlignment = .center
        securityLabel.numberOfLines = 0

        securityHintView.describe(securityText.replacingOccurrences(of: " • ", with: ". "), traits: .staticText)

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
        config.title = String(localized: "Get Started")
        config.baseBackgroundColor = .brand
        config.baseForegroundColor = .white
        config.cornerStyle = .medium
        config.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 32, bottom: 16, trailing: 32)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.scaled(.body, size: 17, weight: .semibold)
            return outgoing
        }
        getStartedButton.configuration = config
        getStartedButton.addAction(UIAction { [weak self] _ in
            self?.toggleAuthButtons()
        }, for: .touchUpInside)

        whySignInButton.translatesAutoresizingMaskIntoConstraints = false
        var whyConfig = UIButton.Configuration.plain()
        whyConfig.title = String(localized: "Why do I need to sign in?")
        whyConfig.baseForegroundColor = .secondaryLabel
        whyConfig.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        whyConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.scaled(.subheadline, size: 14)
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
            getStartedButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 52)
        ])
    }

    private func setupConstraints() {
        let stackWidth = buttonStackView.widthAnchor.constraint(equalTo: buttonContainerView.widthAnchor, constant: -48)
        stackWidth.priority = .defaultHigh
        let bannerWidth = errorCard.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor, constant: -48)
        bannerWidth.priority = .defaultHigh
        let scrollHeight = buttonScrollView.heightAnchor.constraint(equalTo: buttonScrollView.contentLayoutGuide.heightAnchor)
        scrollHeight.priority = .defaultHigh

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            contentStackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 24),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -24),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -48),

            showcaseCarousel.heightAnchor.constraint(equalToConstant: 200),

            buttonScrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            buttonScrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            buttonScrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            buttonScrollView.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            scrollHeight,

            buttonContainerView.topAnchor.constraint(equalTo: buttonScrollView.contentLayoutGuide.topAnchor),
            buttonContainerView.leadingAnchor.constraint(equalTo: buttonScrollView.contentLayoutGuide.leadingAnchor),
            buttonContainerView.trailingAnchor.constraint(equalTo: buttonScrollView.contentLayoutGuide.trailingAnchor),
            buttonContainerView.bottomAnchor.constraint(equalTo: buttonScrollView.contentLayoutGuide.bottomAnchor),
            buttonContainerView.widthAnchor.constraint(equalTo: buttonScrollView.frameLayoutGuide.widthAnchor),
        ])

        for imageView in showcaseImages {
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

            buttonStackView.centerXAnchor.constraint(equalTo: buttonContainerView.centerXAnchor),
            buttonStackView.topAnchor.constraint(equalTo: buttonContainerView.topAnchor),
            buttonStackView.widthAnchor.constraint(lessThanOrEqualToConstant: Self.maximumContentWidth),
            buttonStackView.leadingAnchor.constraint(greaterThanOrEqualTo: buttonContainerView.leadingAnchor, constant: 24),
            buttonStackView.trailingAnchor.constraint(lessThanOrEqualTo: buttonContainerView.trailingAnchor, constant: -24),
            stackWidth,

            appleButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),
            googleButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 48),
            githubButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),

            termsLabel.topAnchor.constraint(equalTo: buttonStackView.bottomAnchor, constant: 16),
            termsLabel.leadingAnchor.constraint(equalTo: buttonStackView.leadingAnchor),
            termsLabel.trailingAnchor.constraint(equalTo: buttonStackView.trailingAnchor),
            termsLabel.bottomAnchor.constraint(equalTo: buttonContainerView.bottomAnchor),

            errorCard.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            errorCard.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            errorCard.widthAnchor.constraint(lessThanOrEqualToConstant: Self.maximumContentWidth),
            bannerWidth,

            loadingOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            loadingOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupAuthenticationObservers() {
        authenticationManager.delegate = self
    }

    private func setupAccessibilityObservers() {
        for name in [UIAccessibility.voiceOverStatusDidChangeNotification, UIAccessibility.reduceMotionStatusDidChangeNotification] {
            NotificationCenter.default.addObserver(self, selector: #selector(accessibilitySettingsChanged), name: name, object: nil)
        }
    }

    @objc private func accessibilitySettingsChanged() {
        updateShowcaseTimer()
        updatePulseAnimation()
    }

    private func handleGoogleSignIn() {
        haptics.impact(.click)
        showLoading(true, provider: .google)
        hideError()
        authenticationManager.authenticate(with: .google, from: self)
    }

    private func handleAppleSignIn() {
        haptics.impact(.click)
        showLoading(true, provider: .apple)
        hideError()
        authenticationManager.authenticate(with: .apple, from: self)
    }

    private func handleGitHubSignIn() {
        haptics.impact(.click)
        showLoading(true, provider: .github)
        hideError()
        authenticationManager.authenticate(with: .github, from: self)
    }

    /// Dims every sign-in button, shows a spinner on the provider that was tapped and blocks touches until the attempt ends.
    private func showLoading(_ show: Bool, provider: AuthProvider? = nil) {
        loadingOverlay.isHidden = !show

        appleButton.isLoading = show && provider == .apple
        googleButton.isLoading = show && provider == .google
        githubButton.isLoading = show && provider == .github

        appleButton.isEnabled = !show
        googleButton.isEnabled = !show
        githubButton.isEnabled = !show
        debugButton?.isEnabled = !show
        getStartedButton.isEnabled = !show

        if show {
            Announce.say(String(localized: "Signing in…"))
        }
    }

    private func showError(_ message: String) {
        errorLabel.text = message
        errorCard.describe(message, traits: .staticText)
        errorCard.alpha = 0
        errorCard.isHidden = false
        view.bringSubviewToFront(errorCard)
        Motion.animate(0.25) {
            self.errorCard.alpha = 1
        }
        haptics.notification(.error)
        Announce.say(message)
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

    private var shouldAutoRotateShowcase: Bool {
        !UIAccessibility.isVoiceOverRunning && !Motion.isReduced && !areButtonsVisible
    }

    /// Runs the auto-rotating showcase only when VoiceOver and Reduce Motion are off; swiping or the page dots still work either way.
    private func updateShowcaseTimer() {
        showcaseTimer?.invalidate()
        showcaseTimer = nil
        guard shouldAutoRotateShowcase else { return }
        showcaseTimer = Timer.scheduledTimer(withTimeInterval: Self.showcaseInterval, repeats: true) { [weak self] _ in
            self?.moveShowcase(by: 1)
        }
    }

    private func moveShowcase(by delta: Int) {
        let count = showcaseImages.count
        guard count > 0 else { return }
        showShowcase(at: (currentShowcaseIndex + delta + count) % count)
    }

    private func showShowcase(at index: Int) {
        guard showcaseImages.indices.contains(index), index != currentShowcaseIndex else { return }
        let previousIndex = currentShowcaseIndex
        currentShowcaseIndex = index

        Motion.animate(0.5) {
            self.showcaseImages[previousIndex].alpha = 0
            self.showcaseImages[index].alpha = 1
        }

        showcasePageControl.currentPage = index
    }

    private func showcasePageControlChanged() {
        haptics.selectionChanged()
        showShowcase(at: showcasePageControl.currentPage)
        updateShowcaseTimer()
    }

    @objc private func showcaseSwiped(_ gesture: UISwipeGestureRecognizer) {
        let isLeftToRight = view.effectiveUserInterfaceLayoutDirection == .leftToRight
        let advances = (gesture.direction == .left) == isLeftToRight
        haptics.selectionChanged()
        moveShowcase(by: advances ? 1 : -1)
        updateShowcaseTimer()
    }

    private func toggleAuthButtons() {
        haptics.impact(.click)

        if !areButtonsVisible {
            buttonScrollView.isHidden = false
            showcaseTimer?.invalidate()
            showcaseTimer = nil

            Motion.spring(0.4, damping: 0.8, velocity: 0.5, options: .curveEaseOut, animations: { [weak self] in
                self?.buttonScrollView.alpha = 1
                self?.getStartedButton.alpha = 0
                self?.whySignInButton.alpha = 0
                self?.showcaseCarousel.alpha = 0
                self?.showcaseCarousel.transform = Motion.isReduced ? .identity : CGAffineTransform(scaleX: 0.95, y: 0.95)
                self?.headerStackView.alpha = 0
                self?.featuresStackView.alpha = 0
            }, completion: { [weak self] _ in
                guard let self else { return }
                self.areButtonsVisible = true
                self.getStartedButton.isHidden = true
                self.whySignInButton.isHidden = true
                self.showcaseCarousel.isHidden = true
                self.headerStackView.isHidden = true
                self.featuresStackView.isHidden = true
                Announce.screenChanged(self.appleButton)
            })
        }
    }

    private func showWhySignInModal() {
        haptics.impact(.click)

        let modalVC = UIViewController()
        modalVC.modalPresentationStyle = .pageSheet

        if let sheet = modalVC.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
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
        titleLabel.text = String(localized: "Why Sign In?")
        titleLabel.useScaledFont(.title2, size: 24, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.accessibilityTraits = .header

        let contentStackView = UIStackView()
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.axis = .vertical
        contentStackView.spacing = 20
        contentStackView.alignment = .fill

        contentStackView.addArrangedSubview(titleLabel)
        contentStackView.setCustomSpacing(32, after: titleLabel)

        let benefits = [
            ("cloud", String(localized: "Sync across all your devices")),
            ("photo.on.rectangle.angled", String(localized: "Save your creations to gallery")),
            ("clock.arrow.circlepath", String(localized: "Access generation history")),
            ("creditcard", String(localized: "Track your credits and usage")),
            ("lock.shield", String(localized: "Secure and private"))
        ]

        for (icon, text) in benefits {
            let benefitStack = UIStackView()
            benefitStack.axis = .horizontal
            benefitStack.spacing = 12
            benefitStack.alignment = .center

            let iconView = UIImageView()
            iconView.translatesAutoresizingMaskIntoConstraints = false
            iconView.image = UIImage(systemName: icon)
            iconView.tintColor = .brandText
            iconView.contentMode = .scaleAspectFit
            iconView.hideFromAccessibility()

            let label = UILabel()
            label.text = text
            label.useScaledFont(.body, size: 16)
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

        let benefitsScrollView = UIScrollView()
        benefitsScrollView.translatesAutoresizingMaskIntoConstraints = false
        benefitsScrollView.alwaysBounceVertical = false
        benefitsScrollView.addSubview(contentStackView)

        let closeButton = UIButton(type: .system)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        var config = UIButton.Configuration.filled()
        config.title = String(localized: "Got it")
        config.baseBackgroundColor = .brand
        config.baseForegroundColor = .white
        config.cornerStyle = .medium
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.scaled(.body, size: 17, weight: .semibold)
            return outgoing
        }
        closeButton.configuration = config
        closeButton.addAction(UIAction { _ in
            modalVC.dismiss(animated: true)
        }, for: .touchUpInside)

        containerView.addSubview(benefitsScrollView)
        containerView.addSubview(closeButton)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: modalVC.view.safeAreaLayoutGuide.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: modalVC.view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: modalVC.view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: modalVC.view.safeAreaLayoutGuide.bottomAnchor),

            benefitsScrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
            benefitsScrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            benefitsScrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            benefitsScrollView.bottomAnchor.constraint(equalTo: closeButton.topAnchor, constant: -16),

            contentStackView.topAnchor.constraint(equalTo: benefitsScrollView.contentLayoutGuide.topAnchor, constant: 24),
            contentStackView.leadingAnchor.constraint(equalTo: benefitsScrollView.contentLayoutGuide.leadingAnchor, constant: 24),
            contentStackView.trailingAnchor.constraint(equalTo: benefitsScrollView.contentLayoutGuide.trailingAnchor, constant: -24),
            contentStackView.bottomAnchor.constraint(equalTo: benefitsScrollView.contentLayoutGuide.bottomAnchor),
            contentStackView.widthAnchor.constraint(equalTo: benefitsScrollView.frameLayoutGuide.widthAnchor, constant: -48),

            closeButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            closeButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            closeButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24),
            closeButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 50)
        ])

        present(modalVC, animated: true)
    }

    private func addSubtleAnimations() {
        updatePulseAnimation()

        guard !Motion.isReduced else { return }

        Motion.animate(1.0, delay: 0, options: [.curveEaseOut], animations: { [weak self] in
            self?.headerStackView.alpha = 0
            self?.headerStackView.transform = CGAffineTransform(translationX: 0, y: 20)
        }, completion: { _ in
            Motion.animate(0.8, delay: 0, options: [.curveEaseOut], animations: { [weak self] in
                self?.headerStackView.alpha = 1
                self?.headerStackView.transform = .identity
            })
        })
    }

    /// Pulses the free-credits hint, and leaves it still while Reduce Motion is on.
    private func updatePulseAnimation() {
        creditsHintView.layer.removeAllAnimations()
        creditsHintView.transform = .identity

        guard !Motion.isReduced else { return }

        Motion.animate(2.0, delay: 0.5, options: [.repeat, .autoreverse, .curveEaseInOut]) { [weak self] in
            self?.creditsHintView.transform = CGAffineTransform(scaleX: 1.02, y: 1.02)
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
