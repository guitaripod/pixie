import UIKit

class HelpViewController: UIViewController {
    private static let supportURL = URL(string: "https://x.com/guitaripod")

    private let column = SettingsColumnView(spacing: Theme.Space.xxl)
    private let haptics = HapticManager.shared

    private struct Point {
        let heading: String?
        let text: String
        let marker: String?
        let alignsWithMarkers: Bool

        init(_ heading: String? = nil, _ text: String, marker: String? = nil, alignsWithMarkers: Bool = false) {
            self.heading = heading
            self.text = text
            self.marker = marker
            self.alignsWithMarkers = alignsWithMarkers
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = String(localized: "Help")
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = Theme.Color.canvas

        column.install(in: view, top: Theme.Space.lg)
        buildContent()
    }

    private func buildContent() {
        let topics = UIStackView(arrangedSubviews: [
            topicCard(
                title: String(localized: "Get Started"),
                symbol: "sparkles",
                expanded: true,
                points: [
                    Point(String(localized: "Pick a photo"), String(localized: "Choose one from your library, or try the sample photo first."), marker: "1"),
                    Point(String(localized: "Tap an edit"), String(localized: "A pro headshot, a restored old photo, a 3D figurine and more: one tap each."), marker: "2"),
                    Point(String(localized: "Refine by chat"), String(localized: "Ask for changes in plain words and each message edits your latest image."), marker: "3"),
                    Point(String(localized: "3 free images"), String(localized: "They're included, and there's nothing to sign up for."), alignsWithMarkers: true),
                ]
            ),
            topicCard(
                title: String(localized: "Credits"),
                symbol: "creditcard.fill",
                expanded: false,
                points: [
                    Point(String(localized: "What a credit is"), String(localized: "Credits pay for the images you make. The cost is shown before you generate.")),
                    Point(String(localized: "Packs never expire"), String(localized: "Buy a pack once and use it whenever you like. There is no subscription.")),
                    Point(String(localized: "See where they went"), String(localized: "Tap your balance to see every credit you've spent or received.")),
                ]
            ),
            topicCard(
                title: String(localized: "Your data"),
                symbol: "lock.shield.fill",
                expanded: false,
                points: [
                    Point(String(localized: "Private by default"), String(localized: "Your images are only visible to you. There is no public feed.")),
                    Point(String(localized: "Cloud AI"), String(localized: "With your consent, photos and prompts are sent to Google Gemini and OpenAI to make your images.")),
                    Point(String(localized: "You're in control"), String(localized: "Delete your account and everything in it from Settings.")),
                ]
            ),
        ])
        topics.axis = .vertical
        topics.spacing = Theme.Space.md
        column.stack.addArrangedSubview(topics)

        column.stack.addArrangedSubview(SettingsLayout.section(title: String(localized: "FAQ"), content: [faqCard()]))
        column.stack.addArrangedSubview(contactCard())
    }

    private func topicCard(title: String, symbol: String, expanded: Bool, points: [Point]) -> UIView {
        let card = SurfaceView(style: .card)
        let accordion = makeAccordion(title: title, symbol: symbol, expanded: expanded, points: points)
        card.contentView.addSubview(accordion)
        accordion.pinEdges(to: card.contentView)
        return card
    }

    private func faqCard() -> UIView {
        let faqs: [(String, String)] = [
            (String(localized: "Can I use Pixie offline?"),
             String(localized: "Making an image needs an internet connection. Images you've already saved to Photos stay available offline.")),
            (String(localized: "What if a request is declined?"),
             String(localized: "Nothing is charged. Try rewording your request, since safety filters sometimes block photos of people.")),
            (String(localized: "Do I need to sign in?"),
             String(localized: "No. Pixie starts right away on this device. Sign in with Apple in Settings to back up your images and credits and use them on other devices.")),
            (String(localized: "How do I delete my account?"),
             String(localized: "Open Settings and tap Delete Account at the bottom. Your credits, including any you bought, and every image you've made are permanently deleted from our servers. This can't be undone.")),
            (String(localized: "How do I report issues?"),
             String(localized: "Message @guitaripod on X (x.com/guitaripod) and we'll help you out.")),
        ]
        var views: [UIView] = []
        for (index, entry) in faqs.enumerated() {
            if index > 0 { views.append(RowDivider(inset: Theme.Space.lg)) }
            views.append(makeAccordion(title: entry.0, symbol: nil, expanded: false, points: [Point(nil, entry.1)]))
        }
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .vertical
        let card = SurfaceView(style: .card)
        card.contentView.addSubview(stack)
        stack.pinEdges(to: card.contentView)
        return card
    }

    private func contactCard() -> UIView {
        let contact = ListRowView(title: String(localized: "Contact"), subtitle: String(localized: "@guitaripod on X"), symbol: "bubble.left.fill", showsChevron: true)
        contact.onTap = { [weak self] in self?.openSupport() }
        return SettingsLayout.card(rows: [contact])
    }

    private func makeAccordion(title: String, symbol: String?, expanded: Bool, points: [Point]) -> HelpAccordionView {
        let body = UIStackView(arrangedSubviews: points.map(makePointView))
        body.axis = .vertical
        body.spacing = Theme.Space.lg
        let spoken = points.map { [$0.heading, $0.text].compactMap { $0 }.joined(separator: ". ") }.joined(separator: " ")
        let accordion = HelpAccordionView(title: title, symbol: symbol, body: body, spokenBody: spoken, expanded: expanded)
        accordion.onToggle = { [weak self] in self?.haptics.impact(.click) }
        return accordion
    }

    private func makePointView(_ point: Point) -> UIView {
        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 2
        if let heading = point.heading {
            let headingLabel = UILabel()
            headingLabel.apply(.subhead, color: Theme.Color.ink)
            headingLabel.text = heading
            textStack.addArrangedSubview(headingLabel)
        }
        let textLabel = UILabel()
        textLabel.apply(.callout)
        textLabel.text = point.text
        textStack.addArrangedSubview(textLabel)

        guard let marker = point.marker else {
            guard point.alignsWithMarkers else { return textStack }
            let spacer = UIView()
            spacer.translatesAutoresizingMaskIntoConstraints = false
            spacer.widthAnchor.constraint(equalToConstant: 24).isActive = true
            let row = UIStackView(arrangedSubviews: [spacer, textStack])
            row.axis = .horizontal
            row.spacing = Theme.Space.md
            return row
        }

        let markerLabel = UILabel()
        markerLabel.apply(.numeral(13), color: Theme.Color.accentText)
        markerLabel.text = marker
        markerLabel.textAlignment = .center
        markerLabel.numberOfLines = 1
        let markerView = UIView()
        markerView.backgroundColor = Theme.Color.accentSoft
        markerView.layer.cornerRadius = 12
        markerView.translatesAutoresizingMaskIntoConstraints = false
        markerView.addSubview(markerLabel)
        markerLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            markerView.widthAnchor.constraint(equalToConstant: 24),
            markerView.heightAnchor.constraint(equalToConstant: 24),
            markerLabel.centerXAnchor.constraint(equalTo: markerView.centerXAnchor),
            markerLabel.centerYAnchor.constraint(equalTo: markerView.centerYAnchor),
        ])
        let markerColumn = UIStackView(arrangedSubviews: [markerView, UIView()])
        markerColumn.axis = .vertical

        let row = UIStackView(arrangedSubviews: [markerColumn, textStack])
        row.axis = .horizontal
        row.alignment = .fill
        row.spacing = Theme.Space.md
        return row
    }

    private func openSupport() {
        guard let url = Self.supportURL else { return }
        UIApplication.shared.open(url)
    }
}

/// A collapsible card that VoiceOver reads as one button whose value is "Collapsed" or "Expanded" plus the answer.
private final class HelpAccordionView: UIView {
    var onToggle: (() -> Void)?

    private let header = UIControl()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
    private let bodyContainer = UIView()
    private let spokenBody: String
    private var isExpanded: Bool

    init(title: String, symbol: String?, body: UIView, spokenBody: String, expanded: Bool) {
        self.spokenBody = spokenBody
        self.isExpanded = expanded
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.apply(.headline)
        titleLabel.text = title

        chevron.tintColor = Theme.Color.inkTertiary
        chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        chevron.setContentCompressionResistancePriority(.required, for: .horizontal)
        chevron.transform = expanded ? CGAffineTransform(rotationAngle: .pi / 2) : .identity

        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = Theme.Space.md
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        var bodyInset = Theme.Space.lg
        if let symbol {
            row.addArrangedSubview(IconBadge(symbol: symbol, size: 40))
            bodyInset += 40 + Theme.Space.md
        }
        row.addArrangedSubview(titleLabel)
        row.addArrangedSubview(chevron)
        header.addSubview(row)
        header.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: header.topAnchor, constant: Theme.Space.md),
            row.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -Theme.Space.md),
            row.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: Theme.Space.lg),
            row.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -Theme.Space.lg),
            header.heightAnchor.constraint(greaterThanOrEqualToConstant: symbol == nil ? 56 : 64),
        ])

        body.translatesAutoresizingMaskIntoConstraints = false
        bodyContainer.addSubview(body)
        bodyContainer.translatesAutoresizingMaskIntoConstraints = false
        bodyContainer.isHidden = !expanded
        bodyContainer.accessibilityElementsHidden = true
        NSLayoutConstraint.activate([
            body.topAnchor.constraint(equalTo: bodyContainer.topAnchor),
            body.bottomAnchor.constraint(equalTo: bodyContainer.bottomAnchor, constant: -Theme.Space.lg),
            body.leadingAnchor.constraint(equalTo: bodyContainer.leadingAnchor, constant: bodyInset),
            body.trailingAnchor.constraint(equalTo: bodyContainer.trailingAnchor, constant: -Theme.Space.lg),
        ])

        let stack = UIStackView(arrangedSubviews: [header, bodyContainer])
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        stack.pinEdges(to: self)

        header.addAction(UIAction { [weak self] _ in self?.toggle() }, for: .touchUpInside)
        header.describe(title, value: stateDescription, traits: .button)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func toggle() {
        onToggle?()
        isExpanded.toggle()
        header.accessibilityValue = stateDescription

        Motion.spring(0.3, damping: 0.85) {
            self.bodyContainer.isHidden = !self.isExpanded
            self.chevron.transform = self.isExpanded ? CGAffineTransform(rotationAngle: .pi / 2) : .identity
            self.window?.layoutIfNeeded()
        }

        Announce.say(stateDescription)
    }

    private var stateDescription: String {
        let state = isExpanded ? String(localized: "Expanded") : String(localized: "Collapsed")
        return isExpanded ? "\(state). \(spokenBody)" : state
    }
}
