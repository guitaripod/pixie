import UIKit
import MidgarCore

final class LaunchFailureViewController: UIViewController {
    private let onRetry: () async -> Bool
    private let onSignIn: () -> Void
    private var isRetrying = false
    private var failedAttempts = 0
    private var lastShownOffline: Bool?
    private static let attemptsBeforeExplaining = 3

    init(onRetry: @escaping () async -> Bool, onSignIn: @escaping () -> Void) {
        self.onRetry = onRetry
        self.onSignIn = onSignIn
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private lazy var iconBadge = IconBadge(symbol: "icloud.slash", size: 88, symbolScale: 0.42)

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.apply(.title, color: Theme.Color.onBackdrop)
        label.textAlignment = .center
        label.accessibilityTraits = .header
        return label
    }()

    private lazy var bodyLabel: UILabel = {
        let label = UILabel()
        label.setStyledText(
            String(localized: "Pixie needs the internet once to set up your free images. Check your connection and try again."),
            .callout,
            color: Theme.Color.onBackdropSecondary,
            alignment: .center
        )
        return label
    }()

    private lazy var stillFailingLabel: UILabel = {
        let label = UILabel()
        label.setStyledText(
            String(localized: "Still can't reach Pixie. Check your connection or try again in a minute."),
            .callout,
            color: Theme.Color.onBackdrop,
            alignment: .center
        )
        label.isHidden = true
        return label
    }()

    private lazy var retryButton = PixieButton(style: .primary, size: .large, title: String(localized: "Try Again")) { [weak self] in
        self?.retry()
    }

    private lazy var signInButton = BackdropTextButton(title: String(localized: "Sign in instead")) { [weak self] in
        self?.onSignIn()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.overrideUserInterfaceStyle = .dark
        view.backgroundColor = Theme.Color.backdrop

        let backdrop = InkBackdropView()
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backdrop)
        backdrop.pinEdges(to: view)

        let stack = UIStackView(arrangedSubviews: [iconBadge, titleLabel, bodyLabel, stillFailingLabel, retryButton, signInButton])
        stack.axis = .vertical
        stack.spacing = Theme.Space.md
        stack.alignment = .center
        stack.setCustomSpacing(Theme.Space.xxl, after: iconBadge)
        stack.setCustomSpacing(Theme.Space.xxxl, after: bodyLabel)
        stack.setCustomSpacing(Theme.Space.xxxl, after: stillFailingLabel)
        stack.setCustomSpacing(Theme.Space.sm, after: retryButton)
        stack.translatesAutoresizingMaskIntoConstraints = false

        CenteredScrollContent.make(containing: stack, in: view, horizontalInset: Theme.Space.xxxl, maxContentWidth: Theme.Width.button + 2 * Theme.Space.xxxl)
        retryButton.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        bodyLabel.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        stillFailingLabel.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        NotificationCenter.default.addObserver(
            self, selector: #selector(networkStatusChanged), name: .networkStatusChanged, object: nil)
        applyConnectionState(announcingChange: false)
    }

    /// Picks the offline wording while the device has no route out and the generic one
    /// when it is online but the setup call still failed.
    private func applyConnectionState(announcingChange: Bool) {
        let offline = !NetworkMonitor.shared.isConnected
        defer { lastShownOffline = offline }
        iconBadge.setSymbol(offline ? "wifi.slash" : "icloud.slash")
        titleLabel.text = offline ? String(localized: "You're offline") : String(localized: "Couldn't get set up")
        if announcingChange, lastShownOffline != offline, let text = titleLabel.text {
            Announce.screenChanged(text)
        }
    }

    @objc private func networkStatusChanged() {
        let connected = NetworkMonitor.shared.isConnected
        applyConnectionState(announcingChange: !connected)
        guard connected else { return }
        MidgarLog.info("Connectivity returned on the launch failure screen, retrying setup", category: .launch)
        guard !isRetrying else { return }
        Announce.say(String(localized: "Back online, trying again"))
        retry()
    }

    private func retry() {
        guard !isRetrying else { return }
        setRetrying(true)
        Task { [weak self] in
            guard let self else { return }
            let succeeded = await onRetry()
            if !succeeded {
                setRetrying(false)
                recordFailedAttempt()
                HapticsManager.shared.notification(.error)
            }
        }
    }

    /// After a few failures in a row the screen says so plainly, so the person knows to
    /// check their connection or wait rather than keep tapping.
    private func recordFailedAttempt() {
        failedAttempts += 1
        guard failedAttempts >= Self.attemptsBeforeExplaining else {
            if let text = titleLabel.text { Announce.say(text) }
            return
        }
        let wasHidden = stillFailingLabel.isHidden
        stillFailingLabel.isHidden = false
        if wasHidden, let text = stillFailingLabel.text {
            Announce.screenChanged(text)
        }
    }

    private func setRetrying(_ retrying: Bool) {
        isRetrying = retrying
        retryButton.isLoading = retrying
        retryButton.title = retrying ? String(localized: "Retrying…") : String(localized: "Try Again")
    }
}
