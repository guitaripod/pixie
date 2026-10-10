import UIKit
import AuthenticationServices

private final class PhotoFanView: UIView {
    private static let imageNames = ["onboarding_after_1", "onboarding_after_2", "onboarding_after_3"]
    private static let angles: [CGFloat] = [-8, 0, 8]
    private static let driftDuration: CFTimeInterval = 12
    private static let cardAspect: CGFloat = 0.75

    private let stage = UIView()
    private var cards: [UIView] = []
    private var hasPlayedIntro = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        hideFromAccessibility()
        stage.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stage)
        stage.pinEdges(to: self)

        let order = [0, 2, 1]
        for index in order {
            let card = makeCard(imageName: Self.imageNames[index])
            card.tag = index
            stage.addSubview(card)
            cards.append(card)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func makeCard(imageName: String) -> UIView {
        let card = UIView()
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.45
        card.layer.shadowRadius = 20
        card.layer.shadowOffset = CGSize(width: 0, height: 10)

        let imageView = UIImageView(image: UIImage(named: imageName))
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = Theme.Radius.lg
        imageView.layer.cornerCurve = .continuous
        imageView.layer.borderWidth = 1
        imageView.layer.borderColor = UIColor(white: 1, alpha: 0.28).cgColor
        imageView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(imageView)
        imageView.pinEdges(to: card)
        return card
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let height = min(bounds.height * 0.88, (bounds.width - Theme.Space.xxxl) / (2 * Self.cardAspect))
        guard height > 0 else { return }
        let width = height * Self.cardAspect
        let spread = width * 0.52
        for card in cards {
            let slot = card.tag
            card.transform = .identity
            card.bounds = CGRect(x: 0, y: 0, width: width, height: height)
            card.layer.shadowPath = UIBezierPath(roundedRect: card.bounds, cornerRadius: Theme.Radius.lg).cgPath
            let sideDrop: CGFloat = slot == 1 ? 0 : height * 0.05
            card.center = CGPoint(
                x: bounds.midX + CGFloat(slot - 1) * spread,
                y: bounds.midY + sideDrop - (slot == 1 ? height * 0.02 : 0)
            )
            card.transform = CGAffineTransform(rotationAngle: Self.angles[slot] * .pi / 180)
        }
        playIntroOnce()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateMotion()
        playIntroOnce()
    }

    private func playIntroOnce() {
        guard !hasPlayedIntro, window != nil, !Motion.isReduced else { return }
        hasPlayedIntro = true
        stage.alpha = 0
        stage.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        Motion.spring(0.7, delay: 0.1, damping: 0.85) {
            self.stage.alpha = 1
            self.stage.transform = .identity
        }
    }

    /// Drifts the cards slowly while motion is allowed; they sit still under Reduce Motion.
    func updateMotion() {
        for card in cards {
            card.layer.removeAnimation(forKey: "sway")
            card.layer.removeAnimation(forKey: "lift")
        }
        guard window != nil, !Motion.isReduced else { return }
        for card in cards {
            let phase = Double(card.tag) / 3 * Self.driftDuration
            card.layer.add(drift(keyPath: "transform.rotation.z", amplitude: 0.03, phase: phase), forKey: "sway")
            card.layer.add(drift(keyPath: "transform.translation.y", amplitude: 5, phase: phase), forKey: "lift")
        }
    }

    private func drift(keyPath: String, amplitude: CGFloat, phase: CFTimeInterval) -> CABasicAnimation {
        let animation = CABasicAnimation(keyPath: keyPath)
        animation.fromValue = -amplitude
        animation.toValue = amplitude
        animation.isAdditive = true
        animation.duration = Self.driftDuration
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timeOffset = phase
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        return animation
    }
}

private final class WhySignInViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = Theme.Color.surfaceRaised

        let titleLabel = UILabel()
        titleLabel.setStyledText(String(localized: "Why Sign In?"), .title, alignment: .center)
        titleLabel.accessibilityTraits = .header

        let benefits = [
            ("cloud", String(localized: "Sync across all your devices")),
            ("photo.on.rectangle.angled", String(localized: "Back up your images")),
            ("creditcard", String(localized: "Keep your credits if you switch phones")),
            ("lock.shield", String(localized: "Secure and private")),
        ]
        let list = UIStackView(arrangedSubviews: benefits.map(makeBenefitRow))
        list.axis = .vertical
        list.spacing = Theme.Space.lg

        let footnote = UILabel()
        footnote.setStyledText(String(localized: "You can keep using Pixie without an account."), .footnote, color: Theme.Color.inkTertiary, alignment: .center)

        let doneButton = PixieButton(style: .primary, size: .large, title: String(localized: "Got it")) { [weak self] in
            self?.dismiss(animated: true)
        }

        let stack = UIStackView(arrangedSubviews: [titleLabel, list, footnote, doneButton])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = Theme.Space.xl
        stack.setCustomSpacing(Theme.Space.xxxl, after: titleLabel)
        stack.setCustomSpacing(Theme.Space.xxl, after: footnote)
        stack.translatesAutoresizingMaskIntoConstraints = false
        CenteredScrollContent.make(containing: stack, in: view, horizontalInset: Theme.Space.xxl)
    }

    private func makeBenefitRow(symbol: String, text: String) -> UIView {
        let badge = IconBadge(symbol: symbol, size: 40, symbolScale: 0.5)
        badge.setContentHuggingPriority(.required, for: .horizontal)
        badge.setContentCompressionResistancePriority(.required, for: .horizontal)
        let label = UILabel()
        label.apply(.body)
        label.text = text
        let row = UIStackView(arrangedSubviews: [badge, label])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = Theme.Space.md
        return row
    }
}

class AuthenticationViewController: UIViewController {

    private static let columnsMinWidth: CGFloat = 640
    private static let columnsMinAspect: CGFloat = 1.2
    private static let columnsMaxWidth: CGFloat = 880
    private static let shortColumnsHeight: CGFloat = 560

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let contentStackView = UIStackView()

    private let fanView = PhotoFanView()
    private let heroColumn = UIStackView()
    private let actionColumn = UIStackView()
    private var stackMaxWidth: NSLayoutConstraint!
    private var usesColumns = false
    private let headerStackView = UIStackView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    private let buttonStackView = UIStackView()
    private let appleButton = AppleSignInButton()
    private let googleButton = GoogleSignInButtonWrapper()
    private let githubButton = OAuthButton()
    private var debugButton: PixieButton?

    private lazy var whySignInButton = BackdropTextButton(title: String(localized: "Why do I need to sign in?")) { [weak self] in
        self?.showWhySignInModal()
    }

    private lazy var notNowButton = BackdropTextButton(title: String(localized: "Not now")) { [weak self] in
        self?.dismissAuthentication()
    }

    private let termsLabel = UILabel()
    private let errorCard = SurfaceView(style: .tinted(Theme.Color.danger.withAlphaComponent(0.2)), cornerRadius: Theme.Radius.md)
    private let errorIconView = UIImageView()
    private let errorLabel = UILabel()
    private let loadingOverlay = UIView()

    private let authenticationManager = AuthenticationManager.shared
    private let haptics = HapticManager.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        setupUI()
        setupConstraints()
        applyHeroVisibility()
        setupAuthenticationObservers()
        setupAccessibilityObservers()
        addEntranceAnimation()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.overrideUserInterfaceStyle = .dark
        notNowButton.isHidden = !canDismissAuthentication
        fanView.updateMotion()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyMargins()
        applyHeroVisibility()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let wide = prefersColumns
        guard wide != usesColumns else { return }
        usesColumns = wide
        applyColumnLayout()
        applyHeroVisibility()
    }

    /// A wide window puts the words on one side and the sign-in buttons on the other, so the
    /// buttons stay in view on a landscape phone or the inner Duo display.
    private var prefersColumns: Bool {
        let size = view.bounds.size
        return size.width >= Self.columnsMinWidth && size.width >= size.height * Self.columnsMinAspect
    }

    private func applyColumnLayout() {
        contentStackView.axis = usesColumns ? .horizontal : .vertical
        contentStackView.distribution = usesColumns ? .fillEqually : .fill
        contentStackView.alignment = usesColumns ? .center : .fill
        contentStackView.spacing = usesColumns ? Theme.Space.xxxl : Theme.Space.xxl
        stackMaxWidth.constant = usesColumns ? Self.columnsMaxWidth : Theme.Width.button
    }

    /// The photo fan is decoration, so at accessibility text sizes and in short wide windows it gives way to the words and buttons.
    private func applyHeroVisibility() {
        let size = view.bounds.size
        let isShort = usesColumns && size.height < Self.shortColumnsHeight
        fanView.isHidden = traitCollection.preferredContentSizeCategory.isAccessibilityCategory || isShort
    }

    private func applyMargins() {
        let margin = Theme.screenMargin(for: traitCollection)
        view.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: margin, bottom: 0, trailing: margin)
    }

    private func setupUI() {
        view.backgroundColor = Theme.Color.backdrop
        applyMargins()

        let backdrop = InkBackdropView()
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backdrop)
        backdrop.pinEdges(to: view)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = false
        view.addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.axis = .vertical
        contentStackView.alignment = .fill
        contentStackView.spacing = Theme.Space.xxl
        contentView.addSubview(contentStackView)

        for column in [heroColumn, actionColumn] {
            column.axis = .vertical
            column.alignment = .fill
        }
        heroColumn.spacing = Theme.Space.xl
        actionColumn.spacing = Theme.Space.sm
        contentStackView.addArrangedSubview(heroColumn)
        contentStackView.addArrangedSubview(actionColumn)

        setupHeaderSection()
        setupButtons()
        setupFooter()

        loadingOverlay.translatesAutoresizingMaskIntoConstraints = false
        loadingOverlay.backgroundColor = .clear
        loadingOverlay.isHidden = true
        loadingOverlay.hideFromAccessibility()
        view.addSubview(loadingOverlay)

        setupErrorBanner()
    }

    private func setupHeaderSection() {
        titleLabel.setStyledText(String(localized: "Keep your creations safe"), .display, color: Theme.Color.onBackdrop, alignment: .center)
        titleLabel.accessibilityTraits = .header

        subtitleLabel.setStyledText(
            String(localized: "Sign in to back up your images and credits and use them on every device. You can keep using Pixie without an account."),
            .callout,
            color: Theme.Color.onBackdropSecondary,
            alignment: .center
        )

        headerStackView.axis = .vertical
        headerStackView.alignment = .fill
        headerStackView.spacing = Theme.Space.md
        headerStackView.addArrangedSubview(titleLabel)
        headerStackView.addArrangedSubview(subtitleLabel)

        heroColumn.addArrangedSubview(fanView)
        heroColumn.addArrangedSubview(headerStackView)
    }

    private func setupButtons() {
        buttonStackView.axis = .vertical
        buttonStackView.alignment = .fill
        buttonStackView.spacing = Theme.Space.md

        googleButton.addAction(UIAction { [weak self] _ in
            self?.handleGoogleSignIn()
        }, for: .touchUpInside)

        appleButton.addAction(UIAction { [weak self] _ in
            self?.handleAppleSignIn()
        }, for: .touchUpInside)

        githubButton.configure(
            provider: .github,
            title: String(localized: "Sign in with GitHub"),
            backgroundColor: Theme.Color.onBackdropFill,
            textColor: .white,
            borderColor: Theme.Color.onBackdropLine,
            iconName: "github_mark"
        )
        githubButton.addAction(UIAction { [weak self] _ in
            self?.handleGitHubSignIn()
        }, for: .touchUpInside)

        buttonStackView.addArrangedSubview(appleButton)
        buttonStackView.addArrangedSubview(googleButton)
        buttonStackView.addArrangedSubview(githubButton)

        if DebugUtils.isRunningInSimulator {
            let debugButton = PixieButton(style: .onBackdropFill, size: .small, title: "Debug Login (Simulator Only)") { [weak self] in
                self?.handleDebugSignIn()
            }
            buttonStackView.addArrangedSubview(debugButton)
            self.debugButton = debugButton
        }

        actionColumn.addArrangedSubview(buttonStackView)
    }

    private func setupFooter() {
        termsLabel.setStyledText(
            String(localized: "By signing in, you agree to our Terms"),
            .footnote,
            color: UIColor(white: 1, alpha: 0.5),
            alignment: .center
        )

        let footer = UIStackView(arrangedSubviews: [whySignInButton, notNowButton, termsLabel])
        footer.axis = .vertical
        footer.alignment = .fill
        footer.spacing = 0
        footer.setCustomSpacing(Theme.Space.xs, after: notNowButton)
        notNowButton.isHidden = true
        actionColumn.addArrangedSubview(footer)
    }

    private func setupErrorBanner() {
        errorCard.isHidden = true
        view.addSubview(errorCard)

        errorIconView.translatesAutoresizingMaskIntoConstraints = false
        errorIconView.image = UIImage(systemName: "exclamationmark.triangle.fill")
        errorIconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .subheadline)
        errorIconView.tintColor = Theme.Color.danger
        errorIconView.contentMode = .scaleAspectFit
        errorIconView.setContentHuggingPriority(.required, for: .horizontal)
        errorIconView.hideFromAccessibility()

        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.apply(.subhead, color: Theme.Color.onBackdrop)

        let errorStack = UIStackView(arrangedSubviews: [errorIconView, errorLabel])
        errorStack.translatesAutoresizingMaskIntoConstraints = false
        errorStack.axis = .horizontal
        errorStack.alignment = .center
        errorStack.spacing = Theme.Space.sm
        errorCard.contentView.addSubview(errorStack)

        NSLayoutConstraint.activate([
            errorStack.topAnchor.constraint(equalTo: errorCard.contentView.topAnchor, constant: Theme.Space.md),
            errorStack.leadingAnchor.constraint(equalTo: errorCard.contentView.leadingAnchor, constant: Theme.Space.md),
            errorStack.trailingAnchor.constraint(equalTo: errorCard.contentView.trailingAnchor, constant: -Theme.Space.md),
            errorStack.bottomAnchor.constraint(equalTo: errorCard.contentView.bottomAnchor, constant: -Theme.Space.md),
        ])
    }

    private func setupConstraints() {
        let stackWidth = contentStackView.widthAnchor.constraint(equalTo: contentView.widthAnchor, constant: -2 * Theme.screenMargin(for: traitCollection))
        stackWidth.priority = UILayoutPriority(999)
        let bannerWidth = errorCard.widthAnchor.constraint(equalTo: view.layoutMarginsGuide.widthAnchor)
        bannerWidth.priority = .defaultHigh
        stackMaxWidth = contentStackView.widthAnchor.constraint(lessThanOrEqualToConstant: Theme.Width.button)
        let fanHeight = fanView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor, multiplier: 0.42)
        fanHeight.priority = UILayoutPriority(900)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            contentView.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor),

            contentStackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            contentStackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            contentStackView.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: Theme.Space.lg),
            contentStackView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -Theme.Space.lg),
            stackMaxWidth,
            stackWidth,

            fanHeight,
            fanView.heightAnchor.constraint(greaterThanOrEqualToConstant: 220),
            fanView.heightAnchor.constraint(lessThanOrEqualToConstant: 440),

            appleButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 56),
            googleButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 56),
            githubButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 56),

            errorCard.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Theme.Space.md),
            errorCard.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            errorCard.widthAnchor.constraint(lessThanOrEqualToConstant: Theme.Width.button),
            bannerWidth,

            loadingOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            loadingOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setupAuthenticationObservers() {
        authenticationManager.delegate = self
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupAccessibilityObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(accessibilitySettingsChanged), name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
    }

    @objc private func accessibilitySettingsChanged() {
        fanView.updateMotion()
    }

    private var canDismissAuthentication: Bool {
        presentingViewController != nil || navigationController?.presentingViewController != nil
    }

    private func dismissAuthentication() {
        haptics.impact(.click)
        dismiss(animated: true)
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
        notNowButton.isEnabled = !show

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

    private func showWhySignInModal() {
        haptics.impact(.click)

        let modalVC = WhySignInViewController()
        modalVC.modalPresentationStyle = .pageSheet
        if let sheet = modalVC.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = Theme.Radius.sheet
        }
        present(modalVC, animated: true)
    }

    private func addEntranceAnimation() {
        guard !Motion.isReduced else { return }
        for (index, view) in [headerStackView, buttonStackView].enumerated() {
            view.alpha = 0
            view.transform = CGAffineTransform(translationX: 0, y: Theme.Space.lg)
            Motion.animate(0.6, delay: 0.15 + 0.1 * Double(index), options: [.curveEaseOut]) {
                view.alpha = 1
                view.transform = .identity
            }
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
