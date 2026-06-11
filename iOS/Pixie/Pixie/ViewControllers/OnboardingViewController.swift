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
}

final class OnboardingViewController: UIViewController {
    var onFinished: (() -> Void)?

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            symbol: "bubble.left.and.text.bubble.right.fill",
            tint: .systemPurple,
            title: "Chat your way\nto the image",
            body: "Describe what you want in plain words. Refine it message by message and watch your image evolve — powered by Google Nano Banana and OpenAI."
        ),
        OnboardingPage(
            symbol: "wand.and.stars",
            tint: .systemPink,
            title: "Edit photos\nby talking",
            body: "Attach any photo and change it with a sentence: swap the background, restyle it, remove objects, make it transparent. No layers, no tools."
        ),
        OnboardingPage(
            symbol: "sparkles",
            tint: .systemOrange,
            title: "25 free credits\nto start",
            body: "You can create right now — no sign-up. Pay only for what you make with credit packs that never expire. No subscription, ever."
        ),
    ]

    private var pageIndex = 0

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
        config.title = "Skip"
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

        setPage(0, direction: .forward, animated: false)
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
        primaryButton.configuration?.title = isLast ? "Start Creating" : "Continue"
        skipButton.isHidden = isLast
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

        let stack = UIStackView(arrangedSubviews: [iconContainer, titleLabel, bodyLabel])
        stack.axis = .vertical
        stack.spacing = 24
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 36),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -36),
        ])
    }
}
