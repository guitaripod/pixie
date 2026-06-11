import UIKit
import Combine
import RevenueCat

struct StorePackDisplay {
    let id: String
    let name: String
    let baseCredits: Int
    let bonusCredits: Int
    let price: String
    let rcPackage: Package?

    var totalCredits: Int { baseCredits + bonusCredits }
    var bonusPercent: Int { baseCredits > 0 ? Int((Double(bonusCredits) / Double(baseCredits) * 100).rounded()) : 0 }
    var imageEstimate: Int { max(1, totalCredits / 21) }
}

final class CreditStoreViewController: UIViewController {
    static let nanoBananaCreditCost = 21

    private let viewModel = CreditsViewModel()
    private let shortfall: Int?
    private let purchaseManager = CreditPurchaseManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var packs: [StorePackDisplay] = []
    private var selectedPackId = "popular"
    private var isPurchasing = false

    init(shortfall: Int? = nil) {
        self.shortfall = shortfall
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    static func present(from presenter: UIViewController, shortfall: Int? = nil) {
        let store = CreditStoreViewController(shortfall: shortfall)
        let navigation = UINavigationController(rootViewController: store)
        navigation.modalPresentationStyle = .pageSheet
        if let sheet = navigation.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        presenter.present(navigation, animated: true)
    }

    private lazy var scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.alwaysBounceVertical = true
        return scroll
    }()

    private lazy var contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var heroIconView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 44, weight: .semibold)
        let imageView = UIImageView(image: UIImage(systemName: "sparkles", withConfiguration: config))
        imageView.tintColor = .systemPurple
        imageView.contentMode = .scaleAspectFit
        if #available(iOS 18.0, *) {
            imageView.addSymbolEffect(.pulse, options: .repeat(.continuous))
        }
        return imageView
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Pixie Credits"
        label.font = UIFont.systemFont(ofSize: 30, weight: .bold).rounded()
        label.textAlignment = .center
        return label
    }()

    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Pay for what you create.\nNo subscription — ever."
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var balanceLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        return label
    }()

    private lazy var packsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        return stack
    }()

    private lazy var perksLabel: UILabel = {
        let label = UILabel()
        label.text = "Credits never expire  ·  Every quality tier  ·  No account required"
        label.font = .preferredFont(forTextStyle: .caption1)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var ctaButton: UIButton = {
        var config = ctaConfiguration()
        config.title = "Loading…"
        let button = UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in
            self?.purchaseSelectedPack()
        })
        button.isEnabled = false
        return button
    }()

    private lazy var footerStack: UIStackView = {
        let restore = UIButton(configuration: plainFooterConfiguration(title: "Restore Purchases"), primaryAction: UIAction { [weak self] _ in
            self?.restorePurchases()
        })
        let privacy = UIButton(configuration: plainFooterConfiguration(title: "Privacy"), primaryAction: UIAction { [weak self] _ in
            self?.open(url: "https://mako.midgarcorp.cc/privacy/pixie")
        })
        let terms = UIButton(configuration: plainFooterConfiguration(title: "Terms"), primaryAction: UIAction { [weak self] _ in
            self?.open(url: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
        })
        let stack = UIStackView(arrangedSubviews: [restore, privacy, terms])
        stack.axis = .horizontal
        stack.spacing = 18
        stack.distribution = .equalCentering
        return stack
    }()

    private lazy var bottomBar: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [ctaButton, footerStack])
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "clock.arrow.circlepath"),
            primaryAction: UIAction { [weak self] _ in
                self?.navigationController?.pushViewController(CreditsMainViewController(), animated: true)
            }
        )
        layoutUI()
        buildHeader()
        #if DEBUG
        if DemoMode.isActive {
            applyDemoPacks()
            return
        }
        #endif
        bind()
        viewModel.refresh()
        Task { await purchaseManager.fetchCreditPacks() }
    }

    private func layoutUI() {
        view.addSubview(scrollView)
        view.addSubview(bottomBar)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -4),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40),

            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            bottomBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            ctaButton.widthAnchor.constraint(equalTo: bottomBar.widthAnchor),
        ])
    }

    private func buildHeader() {
        let headerStack = UIStackView(arrangedSubviews: [heroIconView, titleLabel, subtitleLabel, balanceLabel])
        headerStack.axis = .vertical
        headerStack.spacing = 6
        headerStack.alignment = .center
        contentStack.addArrangedSubview(headerStack)
        contentStack.setCustomSpacing(18, after: headerStack)

        if let shortfall, shortfall > 0 {
            contentStack.addArrangedSubview(makeShortfallBanner(shortfall))
        }

        contentStack.addArrangedSubview(packsStack)
        contentStack.addArrangedSubview(perksLabel)
    }

    private func makeShortfallBanner(_ shortfall: Int) -> UIView {
        let card = GlassMaterial.cardView(cornerRadius: 16)
        let icon = UIImageView(image: UIImage(systemName: "exclamationmark.circle.fill"))
        icon.tintColor = .systemOrange
        icon.setContentHuggingPriority(.required, for: .horizontal)
        let label = UILabel()
        label.text = "You need \(shortfall) more credits to finish this image."
        label.font = .preferredFont(forTextStyle: .footnote)
        label.numberOfLines = 0
        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.axis = .horizontal
        stack.spacing = 10
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -12),
        ])
        return card
    }

    private func bind() {
        viewModel.$balance
            .receive(on: DispatchQueue.main)
            .sink { [weak self] balance in
                guard let balance else { return }
                self?.balanceLabel.text = "Current balance: \(balance.balance) credits"
            }
            .store(in: &cancellables)

        purchaseManager.getCreditPacksWithPricing()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] packsWithPricing in
                guard !packsWithPricing.isEmpty else { return }
                self?.packs = packsWithPricing.map {
                    StorePackDisplay(
                        id: $0.creditPack.id,
                        name: $0.creditPack.name,
                        baseCredits: $0.creditPack.credits,
                        bonusCredits: $0.creditPack.bonusCredits,
                        price: $0.localizedPrice,
                        rcPackage: $0.rcPackage
                    )
                }
                self?.reloadPacks()
            }
            .store(in: &cancellables)
    }

    private func reloadPacks() {
        packsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if packs.first(where: { $0.id == selectedPackId }) == nil {
            selectedPackId = packs.first?.id ?? selectedPackId
        }
        for pack in packs {
            let card = PackCardView(pack: pack, badge: badge(for: pack.id))
            card.isSelectedPack = pack.id == selectedPackId
            card.onTap = { [weak self] in self?.select(packId: pack.id) }
            packsStack.addArrangedSubview(card)
        }
        updateCTA()
    }

    private func badge(for packId: String) -> String? {
        switch packId {
        case "popular": return "MOST POPULAR"
        case "enterprise": return "BEST VALUE"
        default: return nil
        }
    }

    private func select(packId: String) {
        guard !isPurchasing else { return }
        HapticsManager.shared.impact(.light)
        selectedPackId = packId
        for case let card as PackCardView in packsStack.arrangedSubviews {
            card.isSelectedPack = card.packId == packId
        }
        updateCTA()
    }

    private func updateCTA() {
        guard let pack = packs.first(where: { $0.id == selectedPackId }) else { return }
        var config = ctaButton.configuration ?? ctaConfiguration()
        config.title = "Get \(formatted(pack.totalCredits)) credits · \(pack.price)"
        config.subtitle = "One-time purchase · ≈ \(pack.imageEstimate) images"
        ctaButton.configuration = config
        ctaButton.isEnabled = true
    }

    private func ctaConfiguration() -> UIButton.Configuration {
        var config: UIButton.Configuration
        if #available(iOS 26.0, *) {
            config = .prominentGlass()
        } else {
            config = .borderedProminent()
        }
        config.cornerStyle = .capsule
        config.buttonSize = .large
        config.titleAlignment = .center
        return config
    }

    private func plainFooterConfiguration(title: String) -> UIButton.Configuration {
        var config = UIButton.Configuration.plain()
        config.title = title
        config.baseForegroundColor = .secondaryLabel
        config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)
        var container = AttributeContainer()
        container.font = UIFont.preferredFont(forTextStyle: .caption1)
        config.attributedTitle = AttributedString(title, attributes: container)
        return config
    }

    private func formatted(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func purchaseSelectedPack() {
        guard let pack = packs.first(where: { $0.id == selectedPackId }), let package = pack.rcPackage, !isPurchasing else { return }
        HapticsManager.shared.impact(.medium)
        isPurchasing = true
        ctaButton.configuration?.showsActivityIndicator = true
        ctaButton.isEnabled = false

        Task {
            let result = await purchaseManager.purchaseCreditPack(package: package)
            await MainActor.run {
                self.isPurchasing = false
                self.ctaButton.configuration?.showsActivityIndicator = false
                switch result {
                case .success(let purchase):
                    HapticsManager.shared.notification(.success)
                    self.ctaButton.configuration?.title = "Added \(self.formatted(purchase.credits)) credits"
                    self.ctaButton.configuration?.subtitle = "New balance: \(self.formatted(purchase.newBalance))"
                    Task { await self.viewModel.loadBalance() }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak self] in
                        self?.dismiss(animated: true)
                    }
                case .failure(let error):
                    self.updateCTA()
                    if error is PurchaseCancelledException { return }
                    HapticsManager.shared.notification(.error)
                    let alert = UIAlertController(title: "Purchase Failed", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }

    private func restorePurchases() {
        HapticsManager.shared.impact(.light)
        Task {
            let result = await purchaseManager.restorePurchases()
            await MainActor.run {
                let message: String
                switch result {
                case .success(let restored):
                    message = restored.isEmpty ? "No purchases found to restore." : "Restored \(restored.count) purchase(s)."
                case .failure(let error):
                    message = error.localizedDescription
                }
                let alert = UIAlertController(title: "Restore Purchases", message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        }
    }

    private func open(url: String) {
        guard let url = URL(string: url) else { return }
        UIApplication.shared.open(url)
    }

    #if DEBUG
    private func applyDemoPacks() {
        balanceLabel.text = "Current balance: 132 credits"
        packs = [
            StorePackDisplay(id: "starter", name: "Starter", baseCredits: 150, bonusCredits: 0, price: "$2.99", rcPackage: nil),
            StorePackDisplay(id: "basic", name: "Basic", baseCredits: 475, bonusCredits: 75, price: "$9.99", rcPackage: nil),
            StorePackDisplay(id: "popular", name: "Popular", baseCredits: 1136, bonusCredits: 364, price: "$24.99", rcPackage: nil),
            StorePackDisplay(id: "business", name: "Business", baseCredits: 2174, bonusCredits: 1076, price: "$49.99", rcPackage: nil),
            StorePackDisplay(id: "enterprise", name: "Enterprise", baseCredits: 4167, bonusCredits: 2833, price: "$99.99", rcPackage: nil),
        ]
        reloadPacks()
    }
    #endif
}

final class PackCardView: UIControl {
    let packId: String
    var onTap: (() -> Void)?

    var isSelectedPack: Bool = false {
        didSet { updateSelection() }
    }

    private let glassCard: UIVisualEffectView
    private let checkmarkView: UIImageView

    init(pack: StorePackDisplay, badge: String?) {
        self.packId = pack.id
        self.glassCard = GlassMaterial.cardView(cornerRadius: 18)
        let checkConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        self.checkmarkView = UIImageView(image: UIImage(systemName: "circle", withConfiguration: checkConfig))
        super.init(frame: .zero)
        build(pack: pack, badge: badge)
        addAction(UIAction { [weak self] _ in self?.onTap?() }, for: .touchUpInside)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func build(pack: StorePackDisplay, badge: String?) {
        glassCard.isUserInteractionEnabled = false
        addSubview(glassCard)

        let nameLabel = UILabel()
        nameLabel.text = pack.name
        nameLabel.font = UIFont.preferredFont(forTextStyle: .headline).rounded()

        let creditsLabel = UILabel()
        creditsLabel.font = .preferredFont(forTextStyle: .subheadline)
        creditsLabel.textColor = .secondaryLabel
        let total = NumberFormatter.localizedString(from: NSNumber(value: pack.totalCredits), number: .decimal)
        creditsLabel.text = pack.bonusCredits > 0
            ? "\(total) credits · +\(pack.bonusPercent)% bonus"
            : "\(total) credits"

        let imagesLabel = UILabel()
        imagesLabel.font = .preferredFont(forTextStyle: .caption1)
        imagesLabel.textColor = .tertiaryLabel
        imagesLabel.text = "≈ \(pack.imageEstimate) Nano Banana images"

        let leftStack = UIStackView(arrangedSubviews: [nameLabel, creditsLabel, imagesLabel])
        leftStack.axis = .vertical
        leftStack.spacing = 2

        let priceLabel = UILabel()
        priceLabel.text = pack.price
        priceLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold).rounded()
        priceLabel.setContentHuggingPriority(.required, for: .horizontal)
        priceLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        checkmarkView.tintColor = .tertiaryLabel
        checkmarkView.setContentHuggingPriority(.required, for: .horizontal)

        let rowStack = UIStackView(arrangedSubviews: [checkmarkView, leftStack, UIView(), priceLabel])
        rowStack.axis = .horizontal
        rowStack.spacing = 12
        rowStack.alignment = .center
        rowStack.isUserInteractionEnabled = false
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        glassCard.contentView.addSubview(rowStack)

        var constraints = [
            glassCard.topAnchor.constraint(equalTo: topAnchor),
            glassCard.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassCard.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassCard.bottomAnchor.constraint(equalTo: bottomAnchor),
            rowStack.topAnchor.constraint(equalTo: glassCard.contentView.topAnchor, constant: 14),
            rowStack.leadingAnchor.constraint(equalTo: glassCard.contentView.leadingAnchor, constant: 14),
            rowStack.trailingAnchor.constraint(equalTo: glassCard.contentView.trailingAnchor, constant: -16),
            rowStack.bottomAnchor.constraint(equalTo: glassCard.contentView.bottomAnchor, constant: -14),
        ]

        if let badge {
            let badgeLabel = PaddedLabel()
            badgeLabel.text = badge
            badgeLabel.font = .systemFont(ofSize: 10, weight: .bold)
            badgeLabel.textColor = .white
            badgeLabel.backgroundColor = packId == "popular" ? .systemPurple : .systemGreen
            badgeLabel.layer.cornerRadius = 8
            badgeLabel.layer.cornerCurve = .continuous
            badgeLabel.clipsToBounds = true
            badgeLabel.translatesAutoresizingMaskIntoConstraints = false
            badgeLabel.isUserInteractionEnabled = false
            addSubview(badgeLabel)
            constraints.append(contentsOf: [
                badgeLabel.centerYAnchor.constraint(equalTo: topAnchor),
                badgeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            ])
        }

        NSLayoutConstraint.activate(constraints)
        layer.cornerRadius = 18
        layer.cornerCurve = .continuous
        updateSelection()
    }

    private func updateSelection() {
        let checkConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        if isSelectedPack {
            checkmarkView.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: checkConfig)
            checkmarkView.tintColor = .systemPurple
            glassCard.layer.borderWidth = 2
            glassCard.layer.borderColor = UIColor.systemPurple.cgColor
        } else {
            checkmarkView.image = UIImage(systemName: "circle", withConfiguration: checkConfig)
            checkmarkView.tintColor = .tertiaryLabel
            glassCard.layer.borderWidth = 0.5
            glassCard.layer.borderColor = UIColor.separator.cgColor
        }
    }
}

final class PaddedLabel: UILabel {
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + 16, height: size.height + 8)
    }
}
