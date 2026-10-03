import UIKit

enum Onboarding {
    private static let key = "onboardingCompleted_v1"
    static var isCompleted: Bool { UserDefaults.standard.bool(forKey: key) }
    static func markCompleted() { UserDefaults.standard.set(true, forKey: key) }
}

private struct OnboardingPage {
    let symbol: String
    let tint: UIColor
    let title: String
    let body: String
    var showsConsent = false
}

final class OnboardingViewController: UIViewController {
    var onFinished: (() -> Void)?

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            symbol: "wand.and.stars",
            tint: .systemPurple,
            title: String(localized: "Edit any photo\nin one tap"),
            body: String(localized: "Pick a photo, then tap an edit: a pro headshot, a restored old photo, a 3D figurine and more.")
        ),
        OnboardingPage(
            symbol: "bubble.left.and.text.bubble.right.fill",
            tint: .systemPink,
            title: String(localized: "Then refine it\nby chat"),
            body: String(localized: "Ask for changes in plain words, and each message edits your latest image. Or describe a brand-new picture from scratch.")
        ),
        OnboardingPage(
            symbol: "sparkles",
            tint: .systemOrange,
            title: String(localized: "3 free images\nto start"),
            body: String(localized: "Create right now, no sign-up. After that, pay only for what you make with credit packs that never expire. No subscription, ever."),
            showsConsent: !CloudAIConsent.isGranted
        ),
    ]

    private var needsConsent: Bool { pages.last?.showsConsent ?? false }

    private var pageIndex = 0

    private var initialPage: Int {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["PX_ONBOARDING_PAGE"], let page = Int(raw), pages.indices.contains(page) {
            return page
        }
        #endif
        return 0
    }

    private lazy var pageController: UIPageViewController = {
        let controller = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        controller.dataSource = self
        controller.delegate = self
        return controller
    }()

    private lazy var pageControl: UIPageControl = {
        let control = UIPageControl()
        control.numberOfPages = pages.count
        control.currentPageIndicatorTintColor = .label
        control.pageIndicatorTintColor = .tertiaryLabel
        control.isUserInteractionEnabled = false
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()

    private lazy var primaryButton: UIButton = {
        var config: UIButton.Configuration
        if #available(iOS 26.0, *) {
            config = .prominentGlass()
        } else {
            config = .borderedProminent()
        }
        config.cornerStyle = .capsule
        config.buttonSize = .large
        let button = UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in
            self?.advance()
        })
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var skipButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.title = String(localized: "Skip")
        config.baseForegroundColor = .secondaryLabel
        let button = UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in
            self?.finish()
        })
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        isModalInPresentation = true

        addChild(pageController)
        pageController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pageController.view)
        pageController.didMove(toParent: self)

        view.addSubview(pageControl)
        view.addSubview(primaryButton)
        view.addSubview(skipButton)

        NSLayoutConstraint.activate([
            pageController.view.topAnchor.constraint(equalTo: view.topAnchor),
            pageController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageController.view.bottomAnchor.constraint(equalTo: pageControl.topAnchor, constant: -16),

            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pageControl.bottomAnchor.constraint(equalTo: primaryButton.topAnchor, constant: -20),

            primaryButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            primaryButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            primaryButton.bottomAnchor.constraint(equalTo: skipButton.topAnchor, constant: -4),

            skipButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            skipButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
        ])

        setPage(initialPage, direction: .forward, animated: false)
        updateChrome()
    }

    private func makePageVC(_ index: Int) -> OnboardingPageContentViewController {
        OnboardingPageContentViewController(page: pages[index], index: index)
    }

    private func setPage(_ index: Int, direction: UIPageViewController.NavigationDirection, animated: Bool) {
        pageIndex = index
        pageController.setViewControllers([makePageVC(index)], direction: direction, animated: animated)
        updateChrome()
    }

    private func advance() {
        HapticsManager.shared.impact(.light)
        if pageIndex >= pages.count - 1 {
            if needsConsent { CloudAIConsent.grant() }
            finish()
        } else {
            setPage(pageIndex + 1, direction: .forward, animated: true)
        }
    }

    private func finish() {
        Onboarding.markCompleted()
        onFinished?()
    }

    private func updateChrome() {
        pageControl.currentPage = pageIndex
        let isLast = pageIndex == pages.count - 1
        let primaryTitle = isLast ? (needsConsent ? String(localized: "Agree & Start Creating") : String(localized: "Start Creating")) : String(localized: "Continue")
        primaryButton.configuration?.title = primaryTitle
        skipButton.configuration?.title = isLast ? String(localized: "Not Now") : String(localized: "Skip")
        skipButton.isHidden = isLast && !needsConsent
    }
}

extension OnboardingViewController: UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let content = viewController as? OnboardingPageContentViewController, content.index > 0 else { return nil }
        return makePageVC(content.index - 1)
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let content = viewController as? OnboardingPageContentViewController, content.index < pages.count - 1 else { return nil }
        return makePageVC(content.index + 1)
    }

    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        guard completed, let content = pageController.viewControllers?.first as? OnboardingPageContentViewController else { return }
        pageIndex = content.index
        updateChrome()
    }
}

private final class OnboardingPageContentViewController: UIViewController {
    let index: Int
    private let page: OnboardingPage

    init(page: OnboardingPage, index: Int) {
        self.page = page
        self.index = index
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()

        let iconContainer = GlassMaterial.cardView(cornerRadius: 44)
        iconContainer.heightAnchor.constraint(equalToConstant: 132).isActive = true
        iconContainer.widthAnchor.constraint(equalToConstant: 132).isActive = true

        let config = UIImage.SymbolConfiguration(pointSize: 56, weight: .semibold)
        let iconView = UIImageView(image: UIImage(systemName: page.symbol, withConfiguration: config))
        iconView.tintColor = page.tint
        iconView.contentMode = .center
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.contentView.addSubview(iconView)
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: iconContainer.contentView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.contentView.centerYAnchor),
        ])

        let titleLabel = UILabel()
        titleLabel.text = page.title
        titleLabel.font = UIFont.systemFont(ofSize: 34, weight: .bold).rounded()
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center

        let bodyLabel = UILabel()
        bodyLabel.text = page.body
        bodyLabel.font = .preferredFont(forTextStyle: .body)
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.numberOfLines = 0
        bodyLabel.textAlignment = .center

        var arranged: [UIView] = [iconContainer, titleLabel, bodyLabel]
        iconContainer.isHidden = page.showsConsent && UIScreen.main.bounds.height < 700
        let consentCard = page.showsConsent ? makeConsentCard() : nil
        if let consentCard { arranged.append(consentCard) }

        let stack = UIStackView(arrangedSubviews: arranged)
        stack.axis = .vertical
        stack.spacing = 24
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        consentCard?.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        CenteredScrollContent.make(containing: stack, in: view, horizontalInset: 36)
    }

    /// The same third-party disclosure the consent sheet shows, so tapping the primary
    /// button on this page is an informed, explicit agreement.
    private func makeConsentCard() -> UIView {
        let card = GlassMaterial.cardView(cornerRadius: 20)

        let icon = UIImageView(image: UIImage(systemName: "cloud.fill"))
        icon.tintColor = .systemPurple
        icon.setContentHuggingPriority(.required, for: .horizontal)
        icon.setContentCompressionResistancePriority(.required, for: .horizontal)

        let label = UILabel()
        label.text = CloudAIConsent.disclosure
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0

        let row = UIStackView(arrangedSubviews: [icon, label])
        row.axis = .horizontal
        row.alignment = .top
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        card.contentView.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 14),
            row.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -14),
            row.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -14),
        ])
        return card
    }
}
