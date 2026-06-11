import UIKit

enum CloudAIConsent {
    private static let key = "cloudAIConsentGranted"

    static var isGranted: Bool {
        UserDefaults.standard.bool(forKey: key)
    }

    static func grant() {
        UserDefaults.standard.set(true, forKey: key)
    }

    static func withdraw() {
        UserDefaults.standard.set(false, forKey: key)
    }
}

final class AIConsentViewController: UIViewController {
    var onContinue: (() -> Void)?

    static func presentIfNeeded(from presenter: UIViewController, onContinue: @escaping () -> Void) -> Bool {
        guard !CloudAIConsent.isGranted else { return false }
        let consent = AIConsentViewController()
        consent.onContinue = onContinue
        consent.modalPresentationStyle = .pageSheet
        if let sheet = consent.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
        presenter.present(consent, animated: true)
        return true
    }

    private lazy var iconView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 40, weight: .semibold)
        let imageView = UIImageView(image: UIImage(systemName: "cloud.fill", withConfiguration: config))
        imageView.tintColor = .systemPurple
        return imageView
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Made with cloud AI"
        label.font = UIFont.preferredFont(forTextStyle: .title2).rounded()
        label.textAlignment = .center
        return label
    }()

    private lazy var bodyLabel: UILabel = {
        let label = UILabel()
        label.text = "Pixie sends your prompts and any photos you attach to Google Gemini and OpenAI to create your images. Automated moderation checks every request. Nothing is used to identify you, and you can withdraw consent anytime in Settings."
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var continueButton: UIButton = {
        var config: UIButton.Configuration
        if #available(iOS 26.0, *) {
            config = .prominentGlass()
        } else {
            config = .borderedProminent()
        }
        config.title = "Continue"
        config.cornerStyle = .capsule
        config.buttonSize = .large
        return UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in
            CloudAIConsent.grant()
            self?.dismiss(animated: true) {
                self?.onContinue?()
            }
        })
    }()

    private lazy var cancelButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.title = "Not Now"
        config.baseForegroundColor = .secondaryLabel
        return UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, bodyLabel, continueButton, cancelButton])
        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            continueButton.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }
}
