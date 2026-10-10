import UIKit

class HelpViewController: UIViewController {

    private let segmentedControl = UISegmentedControl(items: [String(localized: "Getting Started"), String(localized: "Features"), String(localized: "FAQ")])
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stackView = UIStackView()

    private var currentTab = 0
    private let haptics = HapticManager.shared

    override func viewDidLoad() {
        super.viewDidLoad()

        title = String(localized: "Help")
        view.backgroundColor = .systemBackground

        setupViews()
        setupConstraints()

        segmentedControl.selectedSegmentIndex = 0
        updateContent()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory else { return }
        let offset = scrollView.contentOffset
        updateContent()
        scrollView.setContentOffset(offset, animated: false)
    }

    private func setupViews() {
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(segmentedControl)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        stackView.axis = .vertical
        stackView.spacing = 24
        stackView.alignment = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            segmentedControl.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),

            scrollView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
    }

    @objc private func segmentChanged() {
        haptics.impact(.click)
        currentTab = segmentedControl.selectedSegmentIndex
        updateContent()
    }

    private func updateContent() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        switch currentTab {
        case 0:
            showGettingStartedContent()
        case 1:
            showFeaturesContent()
        case 2:
            showFAQContent()
        default:
            break
        }

        scrollView.setContentOffset(.zero, animated: false)
    }

    private func showGettingStartedContent() {
        stackView.addArrangedSubview(createSection(
            title: String(localized: "Welcome to Pixie"),
            content: String(localized: "Pixie is a powerful AI image generation app powered by gpt-image-1. Create stunning images from text descriptions, edit existing images, and browse your own private gallery.")
        ))

        stackView.addArrangedSubview(createSection(
            title: String(localized: "Quick Start"),
            content: String(localized: """
                1. **Generate Images**: Tap the bottom toolbar and enter a description
                2. **Edit Images**: Select an image from gallery or your device
                3. **Browse Gallery**: View and manage your creations
                4. **Manage Credits**: Check your balance and purchase more credits
                """)
        ))

        stackView.addArrangedSubview(createSection(
            title: String(localized: "Authentication"),
            content: String(localized: """
                Sign in with your preferred provider:
                • GitHub (recommended)
                • Google
                • Apple

                Your account syncs across all devices and with the CLI tool.
                """)
        ))
    }

    private func showFeaturesContent() {
        stackView.addArrangedSubview(createSection(
            title: String(localized: "Image Generation"),
            content: String(localized: """
                **Quality Options:**
                • Low: ~4-6 credits per image
                • Medium: ~16-24 credits per image
                • High: ~62-94 credits per image
                • Auto: ~50-75 credits (AI selects)

                **Size Options:**
                • Square (1024×1024)
                • Landscape (1536×1024)
                • Portrait (1024×1536)
                • Auto (AI selects optimal)

                **Advanced Options:**
                • Background: Auto, transparent, white, black
                • Format: PNG, JPEG, WebP
                • Compression: 0-100 (JPEG/WebP only)
                • Moderation: Auto (default), Low (less restrictive)
                """)
        ))

        stackView.addArrangedSubview(createSection(
            title: String(localized: "Image Editing"),
            content: String(localized: """
                Transform existing images with AI:

                **Edit Options:**
                • Change styles (cyberpunk, oil painting, etc.)
                • Add or remove elements
                • Enhance details
                • Create variations

                **Quality & Fidelity:**
                • Low fidelity: More creative freedom
                • High fidelity: Preserves faces/logos better

                **Credit Costs:**
                Base edit cost + quality cost:
                • Low: ~7 credits
                • Medium: ~16 credits
                • High: ~72-110 credits
                """)
        ))

        stackView.addArrangedSubview(createSection(
            title: String(localized: "Gallery Features"),
            content: String(localized: """
                **My Images:**
                • View your generated images
                • View image details and prompts
                • Copy prompts for inspiration
                • Download or share images
                • Edit from gallery
                • Manage your creations
                • Track image metadata
                """)
        ))

        stackView.addArrangedSubview(createSection(
            title: String(localized: "Credits System"),
            content: String(localized: """
                **Understanding Credits:**
                • Credits never expire
                • Shared across all platforms
                • Used for image generation and editing

                **Usage Tracking:**
                • View daily/weekly/monthly usage
                • Export usage data as CSV
                • Monitor credit consumption
                • Set up low balance alerts
                """)
        ))
    }

    private func showFAQContent() {
        let faqs = [
            (String(localized: "How do credits work?"),
             String(localized: "Credits are the currency used to generate and edit images. Each operation costs a different amount based on quality and size.")),

            (String(localized: "Can I use my own OpenAI API key?"),
             String(localized: "Yes! The backend supports using your own OpenAI API key. Contact support to set this up for your account.")),

            (String(localized: "What's the difference between quality levels?"),
             String(localized: "Higher quality produces more detailed images but costs more credits. Low quality is great for drafts and experiments, while high quality is best for final artwork.")),

            (String(localized: "How do I get transparent backgrounds?"),
             String(localized: "Select 'Transparent' in the background options when generating images. This works best with isolated subjects like logos or products.")),

            (String(localized: "Can I edit images from my gallery?"),
             String(localized: "Yes! Long-press any image in the gallery and select 'Edit' to modify it with AI.")),

            (String(localized: "Is my data private?"),
             String(localized: "Your API keys are stored securely on your device. The images you generate are private to your account and only you can see them. You can save images locally or share them to other apps.")),

            (String(localized: "How do I delete my account?"),
             String(localized: "Open Settings, find the Account section and tap Delete Account. Your credits, including any you bought, and every image you've made are permanently deleted from our servers. This can't be undone.")),

            (String(localized: "How do I report issues?"),
             String(localized: "Message @guitaripod on X (x.com/guitaripod) and we'll help you out.")),

            (String(localized: "Can I use Pixie offline?"),
             String(localized: "No, Pixie requires an internet connection to communicate with the AI servers for image generation."))
        ]

        for (question, answer) in faqs {
            let item = FAQItemView(question: question, answer: answer)
            item.onToggle = { [weak self] in
                self?.haptics.impact(.click)
            }
            stackView.addArrangedSubview(item)
        }
    }

    private func createSection(title: String, content: String) -> UIView {
        let container = UIView()

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.useScaledFont(.title3, size: 20, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0
        titleLabel.accessibilityTraits = .header

        let contentLabel = UILabel()
        contentLabel.attributedText = parseMarkdown(content)
        contentLabel.adjustsFontForContentSizeCategory = true
        contentLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [titleLabel, contentLabel])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    private func parseMarkdown(_ text: String) -> NSAttributedString {
        let attributedString = NSMutableAttributedString()
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4

        let lines = text.components(separatedBy: "\n")

        for (index, line) in lines.enumerated() {
            var processedLine = line
            var attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.scaled(.subheadline, size: 15),
                .foregroundColor: UIColor.label,
                .paragraphStyle: paragraphStyle
            ]

            let boldPattern = #"\*\*(.*?)\*\*"#
            if let regex = try? NSRegularExpression(pattern: boldPattern, options: []) {
                let matches = regex.matches(in: processedLine, options: [], range: NSRange(location: 0, length: processedLine.count))

                for match in matches.reversed() {
                    if let range = Range(match.range, in: processedLine) {
                        let boldText = String(processedLine[range]).replacingOccurrences(of: "**", with: "")
                        processedLine.replaceSubrange(range, with: boldText)
                    }
                }

                if !matches.isEmpty {
                    attributes[.font] = UIFont.scaled(.subheadline, size: 15, weight: .semibold)
                }
            }

            if processedLine.trimmingCharacters(in: .whitespaces).hasPrefix("•") {
                processedLine = "  " + processedLine
            }

            attributedString.append(NSAttributedString(string: processedLine, attributes: attributes))

            if index < lines.count - 1 {
                attributedString.append(NSAttributedString(string: "\n", attributes: attributes))
            }
        }

        return attributedString
    }
}

/// A collapsible question card that VoiceOver reads as one button whose value is "Collapsed" or "Expanded" plus the answer.
private final class FAQItemView: UIView {
    var onToggle: (() -> Void)?

    private let question: String
    private let answer: String
    private let answerLabel = UILabel()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
    private var isExpanded = false

    init(question: String, answer: String) {
        self.question = question
        self.answer = answer
        super.init(frame: .zero)
        configureViews()
        updateAccessibility()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureViews() {
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 12

        let questionLabel = UILabel()
        questionLabel.text = question
        questionLabel.useScaledFont(.body, size: 17, weight: .medium)
        questionLabel.textColor = .label
        questionLabel.numberOfLines = 0

        answerLabel.text = answer
        answerLabel.useScaledFont(.subheadline, size: 15)
        answerLabel.textColor = .secondaryLabel
        answerLabel.numberOfLines = 0
        answerLabel.isHidden = true

        chevron.tintColor = .secondaryLabel
        chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        chevron.setContentCompressionResistancePriority(.required, for: .horizontal)

        let topStack = UIStackView(arrangedSubviews: [questionLabel, chevron])
        topStack.axis = .horizontal
        topStack.alignment = .center
        topStack.spacing = 8

        let mainStack = UIStackView(arrangedSubviews: [topStack, answerLabel])
        mainStack.axis = .vertical
        mainStack.spacing = 12
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),

            chevron.widthAnchor.constraint(equalToConstant: 12),
            chevron.heightAnchor.constraint(equalToConstant: 20),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
        isUserInteractionEnabled = true
    }

    @objc private func handleTap() {
        toggle()
    }

    override func accessibilityActivate() -> Bool {
        toggle()
        return true
    }

    private func toggle() {
        onToggle?()
        isExpanded.toggle()
        updateAccessibility()

        Motion.spring(0.3, damping: 0.8) {
            self.answerLabel.isHidden = !self.isExpanded
            self.chevron.transform = self.isExpanded ? CGAffineTransform(rotationAngle: .pi / 2) : .identity
            self.window?.layoutIfNeeded()
        }

        Announce.say(accessibilityStateDescription)
    }

    private var accessibilityStateDescription: String {
        let state = isExpanded ? String(localized: "Expanded") : String(localized: "Collapsed")
        return isExpanded ? "\(state). \(answer)" : state
    }

    private func updateAccessibility() {
        describe(question, value: accessibilityStateDescription, traits: .button)
    }
}
