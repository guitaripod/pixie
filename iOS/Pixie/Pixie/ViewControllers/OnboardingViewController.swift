import UIKit

enum Onboarding {
    private static let key = "onboardingCompleted_v1"
    static var isCompleted: Bool { UserDefaults.standard.bool(forKey: key) }
    static func markCompleted() { UserDefaults.standard.set(true, forKey: key) }
}

private struct OnboardingPage {
    let beforeImage: String
    let afterImage: String
    let title: String
    let body: String
    var showsConsent = false
}

private final class OnboardingPageControl: UIPageControl {
    var onIncrement: (() -> Void)?
    var onDecrement: (() -> Void)?

    override func accessibilityIncrement() {
        onIncrement?()
    }

    override func accessibilityDecrement() {
        onDecrement?()
    }
}

final class OnboardingViewController: UIViewController {
    var onFinished: (() -> Void)?
    private var isWaiting = false
    private static let maxButtonWidth: CGFloat = 420

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            beforeImage: "onboarding_before_1",
            afterImage: "onboarding_after_1",
            title: String(localized: "Edit any photo\nin one tap"),
            body: String(localized: "Pick a photo, then tap an edit: a pro headshot, a restored old photo, a 3D figurine and more.")
        ),
        OnboardingPage(
            beforeImage: "onboarding_before_2",
            afterImage: "onboarding_after_2",
            title: String(localized: "Then refine it\nby chat"),
            body: String(localized: "Ask for changes in plain words, and each message edits your latest image. Or describe a brand-new picture from scratch.")
        ),
        OnboardingPage(
            beforeImage: "onboarding_before_3",
            afterImage: "onboarding_after_3",
            title: String(localized: "\(WelcomeCredits.startingFreeImages) free images\nto start"),
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

    private lazy var pageControl: OnboardingPageControl = {
        let control = OnboardingPageControl()
        control.numberOfPages = pages.count
        control.currentPageIndicatorTintColor = .label
        control.pageIndicatorTintColor = .tertiaryLabel
        control.isUserInteractionEnabled = false
        control.translatesAutoresizingMaskIntoConstraints = false
        control.onIncrement = { [weak self] in self?.step(by: 1) }
        control.onDecrement = { [weak self] in self?.step(by: -1) }
        return control
    }()

    private lazy var primaryButton: UIButton = {
        var config: UIButton.Configuration
        if #available(iOS 26.0, *) {
            config = .prominentGlass()
        } else {
            config = .borderedProminent()
        }
        config.baseBackgroundColor = .brand
        config.baseForegroundColor = .white
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

        let primaryButtonFillWidth = primaryButton.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor, constant: -56)
        primaryButtonFillWidth.priority = .defaultHigh

        NSLayoutConstraint.activate([
            pageController.view.topAnchor.constraint(equalTo: view.topAnchor),
            pageController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageController.view.bottomAnchor.constraint(equalTo: pageControl.topAnchor, constant: -16),

            pageControl.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            pageControl.bottomAnchor.constraint(equalTo: primaryButton.topAnchor, constant: -20),

            primaryButton.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            primaryButton.widthAnchor.constraint(lessThanOrEqualToConstant: Self.maxButtonWidth),
            primaryButtonFillWidth,
            primaryButton.bottomAnchor.constraint(equalTo: skipButton.topAnchor, constant: -4),

            skipButton.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
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

    /// Puts the primary button into a loading state so the host can hold the final tap while
    /// the first-launch account is created in the background.
    func showWaiting() {
        guard !isWaiting else { return }
        isWaiting = true
        updateChrome()
        Announce.say(String(localized: "Getting ready…"))
    }

    /// Restores the primary button to the title of the current page.
    func hideWaiting() {
        guard isWaiting else { return }
        isWaiting = false
        updateChrome()
    }

    private func advance() {
        guard !isWaiting else { return }
        if pageIndex >= pages.count - 1 {
            HapticsManager.shared.impact(.light)
            if needsConsent { CloudAIConsent.grant() }
            finish()
        } else {
            setPage(pageIndex + 1, direction: .forward, animated: !Motion.isReduced)
            pageDidChange()
        }
    }

    /// Moves one page for VoiceOver's adjustable page control, staying put at either end.
    private func step(by offset: Int) {
        let target = pageIndex + offset
        guard pages.indices.contains(target) else { return }
        setPage(target, direction: offset > 0 ? .forward : .reverse, animated: !Motion.isReduced)
        pageDidChange()
    }

    /// Gives the person the same feedback for a swipe as for a tap: a selection tick, and a
    /// spoken summary of the new page with the action its button now offers.
    private func pageDidChange() {
        HapticsManager.shared.selection()
        let title = pages[pageIndex].title.replacingOccurrences(of: "\n", with: " ")
        Announce.screenChanged("\(title). \(primaryButtonTitle)")
    }

    private func finish() {
        Onboarding.markCompleted()
        onFinished?()
    }

    private var isOnLastPage: Bool { pageIndex == pages.count - 1 }

    private var primaryButtonTitle: String {
        guard isOnLastPage else { return String(localized: "Continue") }
        return needsConsent ? String(localized: "Agree & Start Creating") : String(localized: "Start Creating")
    }

    private func updateChrome() {
        pageControl.currentPage = pageIndex
        pageControl.describe(
            String(localized: "Page"),
            value: String(localized: "\(pageIndex + 1) of \(pages.count)"),
            traits: .adjustable
        )
        primaryButton.configuration?.title = isWaiting ? String(localized: "Getting ready…") : primaryButtonTitle
        primaryButton.configuration?.showsActivityIndicator = isWaiting
        primaryButton.isEnabled = !isWaiting
        skipButton.configuration?.title = isOnLastPage ? String(localized: "Not Now") : String(localized: "Skip")
        skipButton.isHidden = isOnLastPage && !needsConsent
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
        pageDidChange()
    }
}

private final class PillLabel: UILabel {
    private static let insets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)

    override init(frame: CGRect) {
        super.init(frame: frame)
        useScaledFont(.caption2, size: 11, weight: .bold)
        textColor = .white
        backgroundColor = UIColor.black.withAlphaComponent(0.62)
        clipsToBounds = true
        textAlignment = .center
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: Self.insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + Self.insets.left + Self.insets.right, height: size.height + Self.insets.top + Self.insets.bottom)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }
}

/// A glass card with the original photo on the left and Pixie's result on the right, split
/// by a handle. The result wipes in from the right edge once when the card appears.
private final class BeforeAfterCardView: UIView {
    private static let cardRadius: CGFloat = 28
    private static let inset: CGFloat = 8
    private static let pillMargin: CGFloat = 10
    private static let handleSize: CGFloat = 30
    private static let dividerWidth: CGFloat = 2
    private static let restingFraction: CGFloat = 0.5

    private let glass = GlassMaterial.cardView(cornerRadius: BeforeAfterCardView.cardRadius)
    private let content = UIView()
    private let beforeView = UIImageView()
    private let afterView = UIImageView()
    private let afterMask = UIView()
    private let divider = UIView()
    private let handle = UIView()
    private let beforePill = PillLabel()
    private let afterPill = PillLabel()
    private var revealProgress: CGFloat

    init(beforeImage: String, afterImage: String) {
        revealProgress = Motion.isReduced ? 1 : 0
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(glass)
        glass.contentView.addSubview(content)

        content.clipsToBounds = true
        content.layer.cornerRadius = Self.cardRadius - Self.inset
        content.layer.cornerCurve = .continuous

        for (view, name) in [(beforeView, beforeImage), (afterView, afterImage)] {
            view.image = UIImage(named: name)
            view.contentMode = .scaleAspectFill
            view.clipsToBounds = true
            content.addSubview(view)
        }
        afterMask.backgroundColor = .black
        afterView.mask = afterMask

        divider.backgroundColor = .white
        content.addSubview(divider)

        handle.backgroundColor = .white
        handle.layer.cornerRadius = Self.handleSize / 2
        handle.layer.shadowColor = UIColor.black.cgColor
        handle.layer.shadowOpacity = 0.3
        handle.layer.shadowRadius = 4
        handle.layer.shadowOffset = CGSize(width: 0, height: 1)
        let handleIcon = UIImageView(image: UIImage(systemName: "arrow.left.and.right"))
        handleIcon.tintColor = .black
        handleIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
        handleIcon.contentMode = .center
        handleIcon.frame = CGRect(x: 0, y: 0, width: Self.handleSize, height: Self.handleSize)
        handle.addSubview(handleIcon)
        content.addSubview(handle)

        beforePill.text = String(localized: "Before")
        afterPill.text = String(localized: "After")
        content.addSubview(beforePill)
        content.addSubview(afterPill)

        describe(String(localized: "Example: before and after"), traits: .image)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func reveal() {
        guard revealProgress < 1 else { return }
        revealProgress = 1
        setNeedsLayout()
        Motion.animate(0.9, delay: 0.2, options: [.curveEaseInOut]) {
            self.layoutIfNeeded()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        glass.frame = bounds
        content.frame = bounds.insetBy(dx: Self.inset, dy: Self.inset)
        let size = content.bounds.size
        beforeView.frame = content.bounds
        afterView.frame = content.bounds

        let dividerX = size.width * (1 - revealProgress * (1 - Self.restingFraction))
        afterMask.frame = CGRect(x: dividerX, y: 0, width: max(0, size.width - dividerX), height: size.height)
        divider.frame = CGRect(x: dividerX - Self.dividerWidth / 2, y: 0, width: Self.dividerWidth, height: size.height)
        handle.frame = CGRect(x: dividerX - Self.handleSize / 2, y: (size.height - Self.handleSize) / 2, width: Self.handleSize, height: Self.handleSize)

        let beforeSize = beforePill.intrinsicContentSize
        let afterSize = afterPill.intrinsicContentSize
        let pillY = size.height - Self.pillMargin
        beforePill.frame = CGRect(x: Self.pillMargin, y: pillY - beforeSize.height, width: beforeSize.width, height: beforeSize.height)
        afterPill.frame = CGRect(x: size.width - Self.pillMargin - afterSize.width, y: pillY - afterSize.height, width: afterSize.width, height: afterSize.height)
        afterPill.alpha = revealProgress
    }
}

private final class OnboardingPageContentViewController: UIViewController {
    let index: Int
    private let page: OnboardingPage
    private var card: BeforeAfterCardView?
    private var cardHeightCap: NSLayoutConstraint?

    init(page: OnboardingPage, index: Int) {
        self.page = page
        self.index = index
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()

        let card = BeforeAfterCardView(beforeImage: page.beforeImage, afterImage: page.afterImage)
        let preferredWidth = card.widthAnchor.constraint(equalToConstant: Self.maxCardWidth)
        preferredWidth.priority = .defaultHigh
        let aspect = card.widthAnchor.constraint(equalTo: card.heightAnchor, multiplier: Self.cardAspect)
        aspect.priority = UILayoutPriority(800)
        let heightCap = card.heightAnchor.constraint(lessThanOrEqualToConstant: Self.maxCardHeight)
        NSLayoutConstraint.activate([
            card.widthAnchor.constraint(lessThanOrEqualToConstant: Self.maxCardWidth),
            preferredWidth,
            aspect,
            heightCap,
        ])
        cardHeightCap = heightCap

        let titleLabel = UILabel()
        titleLabel.text = page.title
        titleLabel.useScaledFont(.largeTitle, size: 34, weight: .bold, rounded: true)
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center
        titleLabel.accessibilityTraits = .header

        let bodyLabel = UILabel()
        bodyLabel.text = page.body
        bodyLabel.font = .preferredFont(forTextStyle: .body)
        bodyLabel.adjustsFontForContentSizeCategory = true
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.numberOfLines = 0
        bodyLabel.textAlignment = .center

        var arranged: [UIView] = [card, titleLabel, bodyLabel]
        self.card = card
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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        card?.reveal()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scaleCardToWindow()
        hideCardWhenWindowIsShort()
    }

    private var windowHeight: CGFloat {
        view.window?.bounds.height ?? view.bounds.height
    }

    /// The card takes a share of the window's height, so it shrinks on short phones and
    /// windows instead of pushing the title and the body off the screen.
    private func scaleCardToWindow() {
        let height = min(Self.maxCardHeight, max(Self.minCardHeight, windowHeight * Self.cardHeightShare))
        guard abs((cardHeightCap?.constant ?? 0) - height) > 0.5 else { return }
        cardHeightCap?.constant = height
    }

    /// The consent page needs the room its disclosure takes, so its picture gives way whenever
    /// the window is shorter than a compact phone, whichever display or orientation it is on.
    private func hideCardWhenWindowIsShort() {
        guard page.showsConsent, let windowHeight = view.window?.bounds.height else { return }
        card?.isHidden = windowHeight < Self.minimumHeightForConsentCard
    }

    private static let minimumHeightForConsentCard: CGFloat = 700
    private static let maxCardWidth: CGFloat = 320
    private static let cardAspect: CGFloat = 0.8
    private static let maxCardHeight: CGFloat = maxCardWidth / cardAspect
    private static let minCardHeight: CGFloat = 180
    private static let cardHeightShare: CGFloat = 0.38

    /// The same third-party disclosure the consent sheet shows, so tapping the primary
    /// button on this page is an informed, explicit agreement.
    private func makeConsentCard() -> UIView {
        let card = GlassMaterial.cardView(cornerRadius: 20)

        let icon = UIImageView(image: UIImage(systemName: "cloud.fill"))
        icon.tintColor = .brandText
        icon.hideFromAccessibility()
        icon.setContentHuggingPriority(.required, for: .horizontal)
        icon.setContentCompressionResistancePriority(.required, for: .horizontal)

        let label = UILabel()
        label.text = CloudAIConsent.disclosure
        label.useScaledFont(.footnote, size: 13)
        label.textColor = .label
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
        card.describe(CloudAIConsent.disclosure)
        return card
    }
}
