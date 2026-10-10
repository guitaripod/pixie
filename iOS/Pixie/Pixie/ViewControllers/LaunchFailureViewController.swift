import UIKit

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

    private lazy var iconView: UIImageView = {
        let imageView = UIImageView()
        imageView.tintColor = .systemOrange
        imageView.contentMode = .center
        imageView.hideFromAccessibility()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.useScaledFont(.title1, size: 30, weight: .bold, rounded: true)
        label.numberOfLines = 0
        label.textAlignment = .center
        label.accessibilityTraits = .header
        return label
    }()

    private lazy var bodyLabel: UILabel = {
        let label = UILabel()
        label.text = String(localized: "Pixie needs the internet once to set up your free images. Check your connection and try again.")
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.textAlignment = .center
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    private lazy var stillFailingLabel: UILabel = {
        let label = UILabel()
        label.text = String(localized: "Still can't reach Pixie. Check your connection or try again in a minute.")
        label.font = .preferredFont(forTextStyle: .callout)
        label.textColor = .label
        label.numberOfLines = 0
        label.textAlignment = .center
        label.adjustsFontForContentSizeCategory = true
        label.isHidden = true
        return label
    }()

    private lazy var retryButton: UIButton = {
        var config: UIButton.Configuration
        if #available(iOS 26.0, *) {
            config = .prominentGlass()
        } else {
            config = .borderedProminent()
        }
        config.baseBackgroundColor = .brand
        config.baseForegroundColor = .white
        config.title = String(localized: "Try Again")
        config.cornerStyle = .capsule
        config.buttonSize = .large
        config.imagePadding = 8
        return UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in
            self?.retry()
        })
    }()

    private lazy var signInButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.title = String(localized: "Sign in instead")
        config.baseForegroundColor = .secondaryLabel
        return UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in
            self?.onSignIn()
        })
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, bodyLabel, stillFailingLabel, retryButton, signInButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.setCustomSpacing(28, after: bodyLabel)
        stack.setCustomSpacing(28, after: stillFailingLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false

        CenteredScrollContent.make(containing: stack, in: view, horizontalInset: 32)
        retryButton.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        NotificationCenter.default.addObserver(
            self, selector: #selector(networkStatusChanged), name: .networkStatusChanged, object: nil)
        applyConnectionState(announcingChange: false)
    }

    /// Picks the offline wording while the device has no route out and the generic one
    /// when it is online but the setup call still failed.
    private func applyConnectionState(announcingChange: Bool) {
        let offline = !NetworkMonitor.shared.isConnected
        defer { lastShownOffline = offline }
        let config = UIImage.SymbolConfiguration(pointSize: 56, weight: .semibold)
        iconView.image = UIImage(systemName: offline ? "wifi.slash" : "exclamationmark.icloud", withConfiguration: config)
        titleLabel.text = offline ? String(localized: "You're offline") : String(localized: "Couldn't get set up")
        if announcingChange, lastShownOffline != offline, let text = titleLabel.text {
            Announce.screenChanged(text)
        }
    }

    @objc private func networkStatusChanged() {
        let connected = NetworkMonitor.shared.isConnected
        applyConnectionState(announcingChange: !connected)
        guard connected else { return }
        AppLogger.info("Connectivity returned on the launch failure screen, retrying setup", category: .launch)
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
        retryButton.configuration?.showsActivityIndicator = retrying
        retryButton.configuration?.title = retrying ? String(localized: "Retrying…") : String(localized: "Try Again")
        retryButton.isEnabled = !retrying
    }
}
