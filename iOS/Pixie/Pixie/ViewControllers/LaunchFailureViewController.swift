import UIKit

final class LaunchFailureViewController: UIViewController {
    private let onRetry: () async -> Bool
    private let onSignIn: () -> Void
    private var isRetrying = false

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
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 30, weight: .bold).rounded()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.adjustsFontForContentSizeCategory = true
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

    private lazy var retryButton: UIButton = {
        var config: UIButton.Configuration
        if #available(iOS 26.0, *) {
            config = .prominentGlass()
        } else {
            config = .borderedProminent()
        }
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

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, bodyLabel, retryButton, signInButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.setCustomSpacing(28, after: bodyLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false

        CenteredScrollContent.make(containing: stack, in: view, horizontalInset: 32)
        retryButton.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        NotificationCenter.default.addObserver(
            self, selector: #selector(networkStatusChanged), name: .networkStatusChanged, object: nil)
        applyConnectionState()
    }

    /// Picks the offline wording while the device has no route out and the generic one
    /// when it is online but the setup call still failed.
    private func applyConnectionState() {
        let offline = !NetworkMonitor.shared.isConnected
        let config = UIImage.SymbolConfiguration(pointSize: 56, weight: .semibold)
        iconView.image = UIImage(systemName: offline ? "wifi.slash" : "exclamationmark.icloud", withConfiguration: config)
        titleLabel.text = offline ? String(localized: "You're offline") : String(localized: "Couldn't get set up")
    }

    @objc private func networkStatusChanged() {
        applyConnectionState()
        guard NetworkMonitor.shared.isConnected else { return }
        AppLogger.info("Connectivity returned on the launch failure screen, retrying setup", category: .launch)
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
                HapticsManager.shared.notification(.error)
            }
        }
    }

    private func setRetrying(_ retrying: Bool) {
        isRetrying = retrying
        retryButton.configuration?.showsActivityIndicator = retrying
        retryButton.isEnabled = !retrying
    }
}
