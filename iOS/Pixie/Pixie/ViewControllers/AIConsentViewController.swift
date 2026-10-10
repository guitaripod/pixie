import UIKit

enum CloudAIConsent {
    private static let key = "cloudAIConsentGranted"

    static var isGranted: Bool {
        UserDefaults.standard.bool(forKey: key)
    }

    static func grant() {
        UserDefaults.standard.set(true, forKey: key)
    }

    static var disclosure: String {
        String(localized: "Pixie sends your prompts and any photos you attach to Google Gemini and OpenAI to create your images. Automated moderation checks every request. Nothing is used to identify you, and you can withdraw consent anytime in Settings.")
    }

    static func withdraw() {
        UserDefaults.standard.set(false, forKey: key)
    }
}

final class AIConsentViewController: UIViewController {
    var onContinue: (() -> Void)?
    var onDeclined: (() -> Void)?

    static func presentIfNeeded(from presenter: UIViewController, onContinue: @escaping () -> Void, onDeclined: (() -> Void)? = nil) -> Bool {
        guard !CloudAIConsent.isGranted else { return false }
        let consent = AIConsentViewController()
        consent.onContinue = onContinue
        consent.onDeclined = onDeclined
        consent.modalPresentationStyle = .pageSheet
        if let sheet = consent.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        presenter.present(consent, animated: true)
        return true
    }

    private lazy var iconView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 40, weight: .semibold)
        let imageView = UIImageView(image: UIImage(systemName: "cloud.fill", withConfiguration: config))
        imageView.tintColor = .brandText
        imageView.hideFromAccessibility()
        return imageView
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = String(localized: "Made with cloud AI")
        label.font = UIFont.preferredFont(forTextStyle: .title2).rounded()
        label.adjustsFontForContentSizeCategory = true
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var bodyLabel: UILabel = {
        let label = UILabel()
        label.text = CloudAIConsent.disclosure
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }()

    private lazy var continueButton: UIButton = {
        var config: UIButton.Configuration
        if #available(iOS 26.0, *) {
            config = .prominentGlass()
        } else {
            config = .borderedProminent()
        }
        config.baseBackgroundColor = .brand
        config.baseForegroundColor = .white
        config.title = String(localized: "Continue")
        config.cornerStyle = .capsule
        config.buttonSize = .large
        return UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in
            CloudAIConsent.grant()
            HapticsManager.shared.notification(.success)
            self?.dismiss(animated: true) {
                self?.onContinue?()
            }
        })
    }()

    private lazy var cancelButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.title = String(localized: "Not now")
        config.baseForegroundColor = .secondaryLabel
        return UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
    }()

    /// The icon, title and disclosure read as one card, so VoiceOver speaks the whole
    /// disclosure in one go instead of stopping at each piece.
    private lazy var disclosureCard: UIStackView = {
        let card = UIStackView(arrangedSubviews: [iconView, titleLabel, bodyLabel])
        card.axis = .vertical
        card.alignment = .fill
        card.spacing = 14
        iconView.contentMode = .center
        let title = titleLabel.text ?? ""
        card.describe("\(title). \(CloudAIConsent.disclosure)")
        return card
    }()

    private lazy var cancelFootnote: UILabel = {
        let label = UILabel()
        label.text = String(localized: "Pixie asks again before your first image.")
        label.font = .preferredFont(forTextStyle: .footnote)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed, !CloudAIConsent.isGranted {
            onDeclined?()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let stack = UIStackView(arrangedSubviews: [disclosureCard, continueButton, cancelButton, cancelFootnote])
        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .center
        stack.setCustomSpacing(0, after: cancelButton)
        stack.translatesAutoresizingMaskIntoConstraints = false

        CenteredScrollContent.make(containing: stack, in: view, horizontalInset: 28)
        continueButton.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        disclosureCard.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        cancelFootnote.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }
}
