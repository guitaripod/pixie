import UIKit

enum PublicGalleryConsent {
    private static let key = "publicGalleryConsentShown"

    static var hasBeenShown: Bool {
        UserDefaults.standard.bool(forKey: key)
    }

    static func markShown() {
        UserDefaults.standard.set(true, forKey: key)
    }
}

final class PublicGalleryConsentViewController: UIViewController {
    var onContinue: (() -> Void)?

    static func presentIfNeeded(from presenter: UIViewController, onContinue: @escaping () -> Void) -> Bool {
        guard !PublicGalleryConsent.hasBeenShown else { return false }
        let consent = PublicGalleryConsentViewController()
        consent.onContinue = onContinue
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
        let imageView = UIImageView(image: UIImage(systemName: "rectangle.stack.fill", withConfiguration: config))
        imageView.tintColor = .systemPurple
        return imageView
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Your creations go public"
        label.font = UIFont.preferredFont(forTextStyle: .title2).rounded()
        label.textAlignment = .center
        return label
    }()

    private lazy var bodyLabel: UILabel = {
        let label = UILabel()
        label.text = "Images you make in Pixie appear in the public Explore feed, where anyone using Pixie can see them and get inspired. You can turn this off below or anytime in Settings, and you can delete any post from your gallery."
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var shareLabel: UILabel = {
        let label = UILabel()
        label.text = "Show my creations in Explore"
        label.font = .preferredFont(forTextStyle: .body)
        label.numberOfLines = 0
        return label
    }()

    private lazy var shareToggle: UISwitch = {
        let toggle = UISwitch()
        toggle.isOn = ConfigurationManager.shared.shareToPublicGallery
        toggle.onTintColor = UIColor(red: 103 / 255, green: 80 / 255, blue: 164 / 255, alpha: 1.0)
        toggle.addTarget(self, action: #selector(shareToggled), for: .valueChanged)
        return toggle
    }()

    private lazy var shareRow: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [shareLabel, shareToggle])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 12
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        stack.backgroundColor = .secondarySystemBackground
        stack.layer.cornerRadius = 12
        return stack
    }()

    private lazy var continueButton: UIButton = {
        var config: UIButton.Configuration
        if #available(iOS 26.0, *) {
            config = .prominentGlass()
        } else {
            config = .borderedProminent()
        }
        config.title = "Got it"
        config.cornerStyle = .capsule
        config.buttonSize = .large
        return UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in
            PublicGalleryConsent.markShown()
            self?.dismiss(animated: true) {
                self?.onContinue?()
            }
        })
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        isModalInPresentation = true

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, bodyLabel, shareRow, continueButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        let content = scrollView.contentLayoutGuide
        let frame = scrollView.frameLayoutGuide

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 32),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -32),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -28),
            stack.widthAnchor.constraint(equalTo: frame.widthAnchor, constant: -56),

            shareRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            continueButton.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    @objc private func shareToggled() {
        HapticsManager.shared.impact(.light)
        ConfigurationManager.shared.shareToPublicGallery = shareToggle.isOn
    }
}
