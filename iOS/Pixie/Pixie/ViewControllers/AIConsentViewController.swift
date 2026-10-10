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
            sheet.preferredCornerRadius = Theme.Radius.sheet
        }
        presenter.present(consent, animated: true)
        return true
    }

    private lazy var iconBadge = IconBadge(symbol: "cloud.fill", size: 64, symbolScale: 0.46)

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.setStyledText(String(localized: "Made with cloud AI"), .title, alignment: .center)
        label.accessibilityTraits = .header
        return label
    }()

    private lazy var bodyLabel: UILabel = {
        let label = UILabel()
        label.setStyledText(CloudAIConsent.disclosure, .body, color: Theme.Color.inkSecondary, alignment: .center)
        label.lineBreakMode = .byWordWrapping
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }()

    private lazy var continueButton = PixieButton(style: .primary, size: .large, title: String(localized: "Continue")) { [weak self] in
        CloudAIConsent.grant()
        HapticsManager.shared.notification(.success)
        self?.dismiss(animated: true) {
            self?.onContinue?()
        }
    }

    private lazy var cancelButton = PixieButton(style: .plain, size: .medium, title: String(localized: "Not now")) { [weak self] in
        self?.dismiss(animated: true)
    }

    /// The icon, title and disclosure read as one card, so VoiceOver speaks the whole
    /// disclosure in one go instead of stopping at each piece.
    private lazy var disclosureCard: UIStackView = {
        let card = UIStackView(arrangedSubviews: [iconBadge, titleLabel, bodyLabel])
        card.axis = .vertical
        card.alignment = .center
        card.spacing = Theme.Space.md
        card.setCustomSpacing(Theme.Space.lg, after: iconBadge)
        let title = titleLabel.text ?? ""
        card.describe("\(title). \(CloudAIConsent.disclosure)")
        return card
    }()

    private lazy var cancelFootnote: UILabel = {
        let label = UILabel()
        label.setStyledText(String(localized: "Pixie asks again before your first image."), .footnote, color: Theme.Color.inkTertiary, alignment: .center)
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
        view.backgroundColor = Theme.Color.surfaceRaised

        let stack = UIStackView(arrangedSubviews: [disclosureCard, continueButton, cancelButton, cancelFootnote])
        stack.axis = .vertical
        stack.spacing = Theme.Space.sm
        stack.alignment = .center
        stack.setCustomSpacing(Theme.Space.xxl, after: disclosureCard)
        stack.setCustomSpacing(0, after: cancelButton)
        stack.translatesAutoresizingMaskIntoConstraints = false

        CenteredScrollContent.make(containing: stack, in: view, horizontalInset: Theme.Space.xxl)
        continueButton.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        disclosureCard.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        cancelFootnote.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }
}
