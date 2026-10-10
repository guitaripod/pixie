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

private final class OnboardingPageIndicator: UIView {
    private static let dotSize: CGFloat = 8
    private static let activeWidth: CGFloat = 24

    var onIncrement: (() -> Void)?
    var onDecrement: (() -> Void)?

    private var widths: [NSLayoutConstraint] = []
    private var highlights: [GradientView] = []

    var currentPage = 0 {
        didSet { applyPage(animated: oldValue != currentPage) }
    }

    init(pageCount: Int) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = Theme.Space.sm - 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        stack.pinEdges(to: self)

        for _ in 0..<pageCount {
            let pill = UIView()
            pill.translatesAutoresizingMaskIntoConstraints = false
            pill.backgroundColor = UIColor(white: 1, alpha: 0.24)
            pill.layer.cornerRadius = Self.dotSize / 2
            pill.clipsToBounds = true
            let highlight = GradientView()
            highlight.translatesAutoresizingMaskIntoConstraints = false
            pill.addSubview(highlight)
            highlight.pinEdges(to: pill)
            let width = pill.widthAnchor.constraint(equalToConstant: Self.dotSize)
            NSLayoutConstraint.activate([width, pill.heightAnchor.constraint(equalToConstant: Self.dotSize)])
            stack.addArrangedSubview(pill)
            widths.append(width)
            highlights.append(highlight)
        }
        applyPage(animated: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func applyPage(animated: Bool) {
        let changes = {
            for index in self.widths.indices {
                let active = index == self.currentPage
                self.widths[index].constant = active ? Self.activeWidth : Self.dotSize
                self.highlights[index].alpha = active ? 1 : 0
            }
            self.layoutIfNeeded()
        }
        if animated {
            Motion.spring(0.4, damping: 0.82, options: [.beginFromCurrentState], animations: changes)
        } else {
            changes()
        }
    }

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

    private lazy var pageIndicator: OnboardingPageIndicator = {
        let indicator = OnboardingPageIndicator(pageCount: pages.count)
        indicator.onIncrement = { [weak self] in self?.step(by: 1) }
        indicator.onDecrement = { [weak self] in self?.step(by: -1) }
        return indicator
    }()

    private lazy var primaryButton = PixieButton(style: .primary, size: .large, title: primaryButtonTitle) { [weak self] in
        self?.advance()
    }

    private lazy var skipButton = BackdropTextButton(title: String(localized: "Skip")) { [weak self] in
        self?.finish()
    }

    private lazy var notNowButton = BackdropTextButton(title: String(localized: "Not Now")) { [weak self] in
        self?.finish()
    }

    init() {
        super.init(nibName: nil, bundle: nil)
        overrideUserInterfaceStyle = .dark
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.backdrop
        view.overrideUserInterfaceStyle = .dark
        isModalInPresentation = true
        applyMargins()

        let backdrop = InkBackdropView()
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backdrop)
        backdrop.pinEdges(to: view)

        addChild(pageController)
        pageController.view.translatesAutoresizingMaskIntoConstraints = false
        pageController.view.backgroundColor = .clear
        view.addSubview(pageController.view)
        pageController.didMove(toParent: self)

        view.addSubview(pageIndicator)
        view.addSubview(skipButton)

        let bottomStack = UIStackView(arrangedSubviews: [primaryButton, notNowButton])
        bottomStack.axis = .vertical
        bottomStack.alignment = .center
        bottomStack.spacing = Theme.Space.xs
        bottomStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomStack)

        let buttonFillWidth = bottomStack.widthAnchor.constraint(equalTo: view.layoutMarginsGuide.widthAnchor)
        buttonFillWidth.priority = .defaultHigh

        NSLayoutConstraint.activate([
            pageIndicator.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            pageIndicator.centerYAnchor.constraint(equalTo: skipButton.centerYAnchor),

            skipButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Theme.Space.sm),
            skipButton.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor, constant: Theme.Space.lg),

            pageController.view.topAnchor.constraint(equalTo: skipButton.bottomAnchor),
            pageController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageController.view.bottomAnchor.constraint(equalTo: bottomStack.topAnchor, constant: -Theme.Space.sm),

            bottomStack.centerXAnchor.constraint(equalTo: view.layoutMarginsGuide.centerXAnchor),
            bottomStack.widthAnchor.constraint(lessThanOrEqualToConstant: Theme.Width.button),
            buttonFillWidth,
            bottomStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Theme.Space.sm),

            primaryButton.widthAnchor.constraint(equalTo: bottomStack.widthAnchor),
        ])

        setPage(initialPage, direction: .forward, animated: false)
        updateChrome()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyMargins()
    }

    private func applyMargins() {
        let margin = Theme.screenMargin(for: traitCollection)
        view.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: margin, bottom: 0, trailing: margin)
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
        pageIndicator.currentPage = pageIndex
        pageIndicator.describe(
            String(localized: "Page"),
            value: String(localized: "\(pageIndex + 1) of \(pages.count)"),
            traits: .adjustable
        )
        primaryButton.title = isWaiting ? String(localized: "Getting ready…") : primaryButtonTitle
        primaryButton.isLoading = isWaiting
        setVisible(skipButton, !isOnLastPage)
        setVisible(notNowButton, isOnLastPage && needsConsent)
    }

    /// Fades a button instead of hiding it, so the stack keeps its height and the page content
    /// does not jump when the button comes and goes.
    private func setVisible(_ button: UIView, _ visible: Bool) {
        button.alpha = visible ? 1 : 0
        button.isUserInteractionEnabled = visible
        button.accessibilityElementsHidden = !visible
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

private final class ConsentDetailsViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = Theme.Color.surfaceRaised

        let badge = IconBadge(symbol: "cloud.fill", size: 64, symbolScale: 0.46)

        let titleLabel = UILabel()
        titleLabel.setStyledText(String(localized: "Made with cloud AI"), .title, alignment: .center)
        titleLabel.accessibilityTraits = .header

        let bodyLabel = UILabel()
        bodyLabel.setStyledText(CloudAIConsent.disclosure, .body, color: Theme.Color.inkSecondary, alignment: .center)

        let doneButton = PixieButton(style: .secondary, size: .large, title: String(localized: "Got it")) { [weak self] in
            self?.dismiss(animated: true)
        }

        let stack = UIStackView(arrangedSubviews: [badge, titleLabel, bodyLabel, doneButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = Theme.Space.md
        stack.setCustomSpacing(Theme.Space.lg, after: badge)
        stack.setCustomSpacing(Theme.Space.xxl, after: bodyLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false

        CenteredScrollContent.make(containing: stack, in: view, horizontalInset: Theme.Space.xxl)
        for wide in [titleLabel, bodyLabel, doneButton] {
            wide.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
    }
}

private final class PillLabel: UILabel {
    private static let insets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
    private static let pillFont = UIFontMetrics(forTextStyle: .caption1).scaledFont(for: .systemFont(ofSize: 12, weight: .semibold), maximumPointSize: 16)

    override init(frame: CGRect) {
        super.init(frame: frame)
        font = Self.pillFont
        adjustsFontForContentSizeCategory = true
        textColor = .white
        backgroundColor = UIColor.black.withAlphaComponent(0.55)
        clipsToBounds = true
        textAlignment = .center
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var text: String? {
        didSet {
            guard let text else { return }
            attributedText = NSAttributedString(string: text.uppercased(), attributes: [.font: Self.pillFont, .foregroundColor: UIColor.white, .kern: 0.6])
        }
    }

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

/// A tray with the original photo on the left and Pixie's result on the right, split
/// by a handle. The result wipes in from the right edge once when the card appears.
private final class BeforeAfterCardView: UIView {
    private static let trayRadius = Theme.Radius.xl
    private static let inset = Theme.Space.sm
    private static let pillMargin = Theme.Space.md
    private static let handleSize: CGFloat = 32
    private static let dividerWidth: CGFloat = 2
    private static let restingFraction: CGFloat = 0.5

    private let tray = UIView()
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

        layer.shadowColor = UIColor(hex: 0x6C47FF).cgColor
        layer.shadowOpacity = 0.4
        layer.shadowRadius = 40
        layer.shadowOffset = CGSize(width: 0, height: 20)

        tray.backgroundColor = UIColor(white: 1, alpha: 0.08)
        tray.layer.cornerRadius = Self.trayRadius
        tray.layer.cornerCurve = .continuous
        tray.layer.borderWidth = 1
        tray.layer.borderColor = Theme.Color.onBackdropLine.cgColor
        addSubview(tray)
        tray.addSubview(content)

        content.clipsToBounds = true
        content.layer.cornerRadius = Theme.Radius.lg
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
        handleIcon.tintColor = Theme.Color.backdrop
        handleIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 13, weight: .bold)
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
        tray.frame = bounds
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: Self.trayRadius).cgPath
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
        view.backgroundColor = .clear

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
        titleLabel.setStyledText(page.title, .display, color: Theme.Color.onBackdrop, alignment: .center)
        titleLabel.accessibilityTraits = .header

        let bodyLabel = UILabel()
        bodyLabel.setStyledText(page.body, .callout, color: Theme.Color.onBackdropSecondary, alignment: .center)

        var arranged: [UIView] = [card, titleLabel, bodyLabel]
        self.card = card
        let consentRow = page.showsConsent ? makeConsentRow() : nil
        if let consentRow { arranged.append(consentRow) }

        let stack = UIStackView(arrangedSubviews: arranged)
        stack.axis = .vertical
        stack.spacing = Theme.Space.md
        stack.alignment = .center
        stack.setCustomSpacing(Theme.Space.xxl, after: card)
        stack.setCustomSpacing(Theme.Space.xl, after: bodyLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        bodyLabel.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        consentRow?.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        CenteredScrollContent.make(containing: stack, in: view, horizontalInset: Theme.screenMargin(for: traitCollection))
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

    /// The consent page needs the room its summary takes, so its picture gives way whenever
    /// the window is shorter than a compact phone, whichever display or orientation it is on.
    private func hideCardWhenWindowIsShort() {
        guard page.showsConsent, let windowHeight = view.window?.bounds.height else { return }
        card?.isHidden = windowHeight < Self.minimumHeightForConsentCard || traitCollection.preferredContentSizeCategory.isAccessibilityCategory
    }

    private static let minimumHeightForConsentCard: CGFloat = 700
    private static let maxCardWidth: CGFloat = 400
    private static let cardAspect: CGFloat = 0.8
    private static let maxCardHeight: CGFloat = maxCardWidth / cardAspect
    private static let minCardHeight: CGFloat = 180
    private static let cardHeightShare: CGFloat = 0.4

    /// A one-sentence summary with a Details link. The full third-party disclosure stays one
    /// tap away and is what VoiceOver reads, so the primary button is still an informed agreement.
    private func makeConsentRow() -> UIView {
        let row = UIView()
        row.backgroundColor = Theme.Color.onBackdropFill
        row.layer.cornerRadius = Theme.Radius.lg
        row.layer.cornerCurve = .continuous
        row.layer.borderWidth = 1
        row.layer.borderColor = Theme.Color.onBackdropLine.cgColor

        let badge = IconBadge(symbol: "cloud.fill", size: 40, symbolScale: 0.5)
        badge.setContentHuggingPriority(.required, for: .horizontal)
        badge.setContentCompressionResistancePriority(.required, for: .horizontal)

        let summary = UILabel()
        summary.setStyledText(
            String(localized: "Your prompts and photos are sent to Google Gemini and OpenAI to make your images."),
            .footnote,
            color: Theme.Color.onBackdrop
        )
        summary.accessibilityLabel = CloudAIConsent.disclosure

        let detailsButton = makeDetailsButton()

        let text = UIStackView(arrangedSubviews: [summary, detailsButton])
        text.axis = .vertical
        text.alignment = .leading
        text.spacing = 0

        let content = UIStackView(arrangedSubviews: [badge, text])
        content.axis = .horizontal
        content.alignment = .top
        content.spacing = Theme.Space.md
        content.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: row.topAnchor, constant: Theme.Space.md),
            content.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -Theme.Space.xs),
            content.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: Theme.Space.md),
            content.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -Theme.Space.md),
        ])
        return row
    }

    private func makeDetailsButton() -> UIButton {
        var config = UIButton.Configuration.plain()
        config.title = String(localized: "Details")
        config.baseForegroundColor = Theme.Color.accentText
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 16)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = Theme.TextStyle.subhead.font
            return outgoing
        }
        let button = UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in
            self?.showDetails()
        })
        button.accessibilityHint = String(localized: "Shows the full cloud AI disclosure")
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        return button
    }

    private func showDetails() {
        HapticsManager.shared.selection()
        let details = ConsentDetailsViewController()
        details.modalPresentationStyle = .pageSheet
        if let sheet = details.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = Theme.Radius.sheet
        }
        present(details, animated: true)
    }
}
