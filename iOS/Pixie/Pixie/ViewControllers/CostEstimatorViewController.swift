import UIKit
import Combine

class CostEstimatorViewController: UIViewController {
    private let viewModel: CreditsViewModel
    private var cancellables = Set<AnyCancellable>()

    private let scrollView = ColumnScrollView()

    private let resultCard = SurfaceView(style: .card, cornerRadius: Theme.Radius.xl)
    private let resultSummary = UIStackView()
    private let amountRow = UIStackView()
    private let estimatedCostLabel = UILabel()
    private let creditsUnitLabel = UILabel()
    private let estimatedUSDLabel = UILabel()
    private let noteLabel = UILabel()

    private let balanceBlock = UIStackView()
    private let divider = UIView()
    private let amountSpacer = UIView()
    private let balanceLabel = UILabel()
    private let balanceAmountLabel = UILabel()
    private let balanceBar = UsageBarView()
    private let balanceStatusLabel = UILabel()
    private let balanceStatusIcon = UIImageView()
    private let balanceHeaderRow = UIStackView()
    private var currentBalance: Int?
    private var pendingAnnouncement: DispatchWorkItem?
    private var announcementBaseline: String?
    private var lastResultSummary = ""

    private let qualitySelector = PillSelector(items: [String(localized: "Low"), String(localized: "Medium"), String(localized: "High")], selected: 1)
    private let sizeSelector = PillSelector(items: ["1024×1024", "1536×1024", "1024×1536"], selected: 0)
    private let editSwitch = UISwitch()
    private let imagesStepper = CapsuleStepper()

    init(viewModel: CreditsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindViewModel()
        updateCalculation()
        if viewModel.balance == nil {
            Task { await viewModel.loadBalance() }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyContentSizeLayout()
    }

    private func setupUI() {
        title = String(localized: "Cost Estimator")
        view.backgroundColor = Theme.Color.canvas
        navigationItem.largeTitleDisplayMode = .never

        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        setupResultCard()
        setupControls()
    }

    private func setupResultCard() {
        let captionLabel = UILabel()
        captionLabel.setStyledText(String(localized: "Estimate"), .caption)
        captionLabel.hideFromAccessibility()

        estimatedCostLabel.apply(.numeral(44), color: Theme.Color.accentText)
        estimatedCostLabel.numberOfLines = 1
        estimatedCostLabel.adjustsFontSizeToFitWidth = true
        estimatedCostLabel.minimumScaleFactor = 0.5
        estimatedCostLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        creditsUnitLabel.apply(.title2, color: Theme.Color.inkSecondary)
        creditsUnitLabel.text = String(localized: "credits")
        creditsUnitLabel.numberOfLines = 1
        creditsUnitLabel.setContentHuggingPriority(.required, for: .horizontal)

        amountRow.axis = .horizontal
        amountRow.alignment = .lastBaseline
        amountRow.spacing = Theme.Space.sm
        estimatedCostLabel.setContentHuggingPriority(.required, for: .horizontal)
        amountRow.addArrangedSubview(estimatedCostLabel)
        amountRow.addArrangedSubview(creditsUnitLabel)
        amountRow.addArrangedSubview(amountSpacer)

        estimatedUSDLabel.apply(.callout)
        noteLabel.apply(.footnote, color: Theme.Color.inkTertiary)

        resultSummary.axis = .vertical
        resultSummary.spacing = Theme.Space.xs
        [captionLabel, amountRow, estimatedUSDLabel, noteLabel].forEach { resultSummary.addArrangedSubview($0) }
        resultSummary.setCustomSpacing(Theme.Space.sm, after: captionLabel)
        resultSummary.setCustomSpacing(Theme.Space.sm, after: estimatedUSDLabel)
        resultSummary.isAccessibilityElement = true
        resultSummary.accessibilityTraits = .staticText

        setupBalanceBlock()

        divider.backgroundColor = Theme.Color.line
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true

        let content = UIStackView(arrangedSubviews: [resultSummary, divider, balanceBlock])
        content.axis = .vertical
        content.spacing = Theme.Space.lg
        content.translatesAutoresizingMaskIntoConstraints = false
        resultCard.contentView.addSubview(content)
        content.pinEdges(to: resultCard.contentView, insets: UIEdgeInsets(top: Theme.Space.xl, left: Theme.Space.xl, bottom: Theme.Space.xl, right: Theme.Space.xl))

        scrollView.column.addArrangedSubview(resultCard)
    }

    private func setupBalanceBlock() {
        balanceLabel.apply(.footnote)
        balanceLabel.text = String(localized: "Current Balance")
        balanceAmountLabel.apply(.numeral(17))
        balanceAmountLabel.numberOfLines = 1
        balanceAmountLabel.setContentHuggingPriority(.required, for: .horizontal)
        balanceAmountLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        balanceHeaderRow.axis = .horizontal
        balanceHeaderRow.alignment = .firstBaseline
        balanceHeaderRow.spacing = Theme.Space.md
        balanceHeaderRow.addArrangedSubview(balanceLabel)
        balanceHeaderRow.addArrangedSubview(balanceAmountLabel)

        balanceStatusIcon.contentMode = .scaleAspectFit
        balanceStatusIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .subheadline, scale: .medium)
        balanceStatusIcon.setContentHuggingPriority(.required, for: .horizontal)
        balanceStatusIcon.setContentCompressionResistancePriority(.required, for: .horizontal)
        balanceStatusLabel.apply(.subhead)
        let statusRow = UIStackView(arrangedSubviews: [balanceStatusIcon, balanceStatusLabel])
        statusRow.axis = .horizontal
        statusRow.spacing = 6
        statusRow.alignment = .center

        balanceBlock.axis = .vertical
        balanceBlock.spacing = Theme.Space.md
        [balanceHeaderRow, balanceBar, statusRow].forEach { balanceBlock.addArrangedSubview($0) }
        balanceBlock.isHidden = true
        divider.isHidden = true
        balanceBlock.isAccessibilityElement = true
        balanceBlock.accessibilityTraits = .staticText
    }

    private func setupControls() {
        qualitySelector.accessibilityLabel = String(localized: "Quality")
        qualitySelector.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        sizeSelector.accessibilityLabel = String(localized: "Size")
        sizeSelector.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)

        let qualityHeader = CreditsSectionHeader(title: String(localized: "Quality"))
        qualityHeader.accessibilityElementsHidden = true
        let sizeHeader = CreditsSectionHeader(title: String(localized: "Size"))
        sizeHeader.accessibilityElementsHidden = true

        editSwitch.isOn = false
        editSwitch.accessibilityLabel = String(localized: "Edit Mode")
        editSwitch.addTarget(self, action: #selector(switchChanged), for: .valueChanged)

        imagesStepper.accessibilityLabel = String(localized: "Number of Images")
        imagesStepper.addTarget(self, action: #selector(stepperChanged), for: .valueChanged)

        let options = RowCard.make([
            settingRow(title: String(localized: "Edit Mode"), control: editSwitch),
            settingRow(title: String(localized: "Number of Images"), control: imagesStepper),
        ], dividerInset: Theme.Space.lg)

        scrollView.column.addArrangedSubview(group(qualityHeader, qualitySelector))
        scrollView.column.addArrangedSubview(group(sizeHeader, sizeSelector))
        scrollView.column.addArrangedSubview(options)
    }

    private func group(_ header: UIView, _ control: UIView) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: [header, control])
        stack.axis = .vertical
        stack.spacing = Theme.Space.sm
        return stack
    }

    private func settingRow(title: String, control: UIView) -> UIView {
        let label = UILabel()
        label.apply(.headline)
        label.text = title
        label.accessibilityElementsHidden = true
        control.setContentHuggingPriority(.required, for: .horizontal)
        control.setContentCompressionResistancePriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [label, control])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = Theme.Space.md
        row.translatesAutoresizingMaskIntoConstraints = false
        row.tag = Self.settingRowTag

        let host = UIView()
        host.addSubview(row)
        row.pinEdges(to: host, insets: UIEdgeInsets(top: Theme.Space.md, left: Theme.Space.lg, bottom: Theme.Space.md, right: Theme.Space.lg))
        host.heightAnchor.constraint(greaterThanOrEqualToConstant: 60).isActive = true
        return host
    }

    private static let settingRowTag = 7002

    /// Stacks amounts and rows vertically at accessibility text sizes so nothing is squeezed or clipped.
    private func applyContentSizeLayout() {
        let isAccessibilitySize = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        let axis: NSLayoutConstraint.Axis = isAccessibilitySize ? .vertical : .horizontal
        if amountRow.axis != axis {
            amountRow.axis = axis
            amountRow.alignment = isAccessibilitySize ? .leading : .lastBaseline
            amountSpacer.isHidden = isAccessibilitySize
        }
        if balanceHeaderRow.axis != axis {
            balanceHeaderRow.axis = axis
            balanceHeaderRow.alignment = isAccessibilitySize ? .leading : .firstBaseline
        }
        for case let row as UIStackView in scrollView.column.allDescendants(withTag: Self.settingRowTag) where row.axis != axis {
            row.axis = axis
            row.alignment = isAccessibilitySize ? .leading : .center
        }
    }

    private func bindViewModel() {
        viewModel.$balance
            .receive(on: DispatchQueue.main)
            .sink { [weak self] balance in
                self?.updateBalance(balance)
            }
            .store(in: &cancellables)
    }

    private func updateBalance(_ balance: CreditBalance?) {
        guard let balance = balance else { return }
        currentBalance = balance.balance
        balanceAmountLabel.text = String(localized: "\(balance.balance) credits")
        refreshBalanceStatus()
    }

    /// Says in words and with a symbol whether the balance covers the current estimate, so the
    /// green or orange tint is never the only signal.
    private func refreshBalanceStatus() {
        guard let balance = currentBalance else { return }
        let total = estimatedTotal
        let isEnough = balance >= total
        let status = isEnough ? String(localized: "Enough") : String(localized: "Low")
        let tint = isEnough ? Theme.Color.success : Theme.Color.warning
        balanceStatusLabel.text = status
        balanceStatusLabel.textColor = tint
        balanceStatusIcon.image = UIImage(systemName: isEnough ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
        balanceStatusIcon.tintColor = tint
        balanceBar.setUsage(balance > 0 ? Double(total) / Double(balance) : 1, isOver: !isEnough)
        balanceBlock.isHidden = false
        divider.isHidden = false
        balanceBlock.accessibilityLabel = String(localized: "Current Balance")
        balanceBlock.accessibilityValue = "\(String(localized: "\(balance) credits")), \(status)"
    }

    @objc private func segmentChanged() {
        HapticsManager.shared.selection()
        updateCalculation(announcing: true)
    }

    @objc private func switchChanged() {
        HapticsManager.shared.selection()
        updateCalculation(announcing: true)
    }

    @objc private func stepperChanged() {
        HapticsManager.shared.selection()
        updateCalculation(announcing: true)
    }

    private var selectedQuality: String {
        ["low", "medium", "high"][qualitySelector.selectedSegmentIndex]
    }

    private var selectedSize: String {
        ["1024x1024", "1536x1024", "1024x1536"][sizeSelector.selectedSegmentIndex]
    }

    private var estimatedTotal: Int {
        let editCost = editSwitch.isOn ? getEditCost(quality: selectedQuality) : 0
        return (getBaseCost(quality: selectedQuality, size: selectedSize) + editCost) * imagesStepper.value
    }

    /// One USD figure in the person's own number format. It stays dollars: the symbol is used
    /// only where their region's currency is also dollars, otherwise the ISO code is shown.
    private func formattedUSD(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.currencyCode = "USD"
        formatter.numberStyle = Locale.current.currency?.identifier == "USD" ? .currency : .currencyISOCode
        return formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.2f USD", amount)
    }

    /// Speaks the new estimate once the person stops adjusting, and only when it changed.
    private func scheduleAnnouncement(previous: String) {
        if announcementBaseline == nil { announcementBaseline = previous }
        pendingAnnouncement?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let baseline = self.announcementBaseline
            self.announcementBaseline = nil
            guard self.lastResultSummary != baseline else { return }
            Announce.say(self.lastResultSummary)
        }
        pendingAnnouncement = item
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.announcementDelay, execute: item)
    }

    private static let announcementDelay: TimeInterval = 0.9

    private func updateCalculation(announcing: Bool = false) {
        let previousSummary = lastResultSummary
        let numberOfImages = imagesStepper.value
        let totalCost = estimatedTotal

        estimatedCostLabel.text = NumberFormatter.localizedString(from: NSNumber(value: totalCost), number: .decimal)
        estimatedUSDLabel.text = String(localized: "≈ \(formattedUSD(Double(totalCost) * 0.01))")
        noteLabel.text = String(localized: "Estimate based on \(numberOfImages) image\(numberOfImages > 1 ? "s" : "")")
        lastResultSummary = [String(localized: "\(totalCost) credits"), estimatedUSDLabel.text].compactMap { $0 }.joined(separator: ", ")
        resultSummary.accessibilityLabel = String(localized: "Cost Estimator")
        resultSummary.accessibilityValue = [lastResultSummary, noteLabel.text].compactMap { $0 }.joined(separator: ", ")
        refreshBalanceStatus()
        if announcing { scheduleAnnouncement(previous: previousSummary) }
    }

    private func getBaseCost(quality: String, size: String) -> Int {
        switch quality {
        case "low":
            switch size {
            case "1024x1024": return 4
            case "1536x1024", "1024x1536": return 6
            default: return 5
            }
        case "medium":
            switch size {
            case "1024x1024": return 16
            case "1536x1024", "1024x1536": return 24
            default: return 20
            }
        case "high":
            switch size {
            case "1024x1024": return 62
            case "1536x1024", "1024x1536": return 94
            default: return 78
            }
        default:
            return 50
        }
    }

    private func getEditCost(quality: String) -> Int {
        switch quality {
        case "low", "medium": return 3
        case "high": return 20
        default: return 10
        }
    }
}

private extension UIView {
    func allDescendants(withTag tag: Int) -> [UIView] {
        subviews.flatMap { ($0.tag == tag ? [$0] : []) + $0.allDescendants(withTag: tag) }
    }
}

private final class UsageBarView: UIView {
    private let fill = GradientView()
    private var fraction: CGFloat = 0
    private var isOver = false

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = Theme.Color.fill
        layer.cornerCurve = .continuous
        fill.cornerRadius = 5
        addSubview(fill)
        heightAnchor.constraint(equalToConstant: 10).isActive = true
        hideFromAccessibility()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
        fill.cornerRadius = bounds.height / 2
        fill.frame = CGRect(x: 0, y: 0, width: max(bounds.height, bounds.width * fraction), height: bounds.height)
    }

    func setUsage(_ value: Double, isOver over: Bool) {
        let clamped = CGFloat(min(max(value, 0), 1))
        guard clamped != fraction || over != isOver else { return }
        fraction = clamped
        isOver = over
        fill.colors = over ? [Theme.Color.warning, Theme.Color.danger] : Theme.Color.gradient
        Motion.animate(0.3, options: [.beginFromCurrentState]) {
            self.setNeedsLayout()
            self.layoutIfNeeded()
        }
    }
}

private final class PillSelector: UIControl {
    private let stack = UIStackView()
    private var buttons: [UIButton] = []

    var selectedSegmentIndex: Int {
        didSet {
            guard oldValue != selectedSegmentIndex else { return }
            buttons.enumerated().forEach { $0.element.isSelected = $0.offset == selectedSegmentIndex }
        }
    }

    init(items: [String], selected: Int) {
        selectedSegmentIndex = selected
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = Theme.Color.fill
        layer.cornerCurve = .continuous
        accessibilityContainerType = .semanticGroup

        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        stack.pinEdges(to: self, insets: UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4))

        for (index, item) in items.enumerated() {
            let button = makeButton(title: item, index: index)
            buttons.append(button)
            stack.addArrangedSubview(button)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let isAccessibilitySize = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        let axis: NSLayoutConstraint.Axis = isAccessibilitySize ? .vertical : .horizontal
        if stack.axis != axis { stack.axis = axis }
        layer.cornerRadius = isAccessibilitySize ? Theme.Radius.lg : bounds.height / 2
    }

    private func makeButton(title: String, index: Int) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.title = title
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 6, bottom: 10, trailing: 6)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = Theme.TextStyle.subhead.font
            return outgoing
        }
        let button = UIButton(configuration: config)
        button.isSelected = index == selectedSegmentIndex
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        button.configurationUpdateHandler = { button in
            var updated = button.configuration
            updated?.baseForegroundColor = button.isSelected ? .white : Theme.Color.ink
            updated?.background.backgroundColor = button.isSelected ? Theme.Color.accent : .clear
            button.configuration = updated
        }
        button.addAction(UIAction { [weak self] _ in
            guard let self, self.selectedSegmentIndex != index else { return }
            self.selectedSegmentIndex = index
            self.sendActions(for: .valueChanged)
        }, for: .touchUpInside)
        return button
    }
}

private final class CapsuleStepper: UIControl {
    private static let minimum = 1
    private static let maximum = 4

    private let minusButton = UIButton(type: .system)
    private let plusButton = UIButton(type: .system)
    private let valueLabel = UILabel()

    private(set) var value = CapsuleStepper.minimum {
        didSet { refresh() }
    }

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = Theme.Color.fill
        layer.cornerCurve = .continuous

        configure(minusButton, symbol: "minus") { [weak self] in self?.step(-1) }
        configure(plusButton, symbol: "plus") { [weak self] in self?.step(1) }
        valueLabel.apply(.numeral(20), color: Theme.Color.accentText)
        valueLabel.numberOfLines = 1
        valueLabel.textAlignment = .center
        valueLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 28).isActive = true

        let stack = UIStackView(arrangedSubviews: [minusButton, valueLabel, plusButton])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 2
        stack.isUserInteractionEnabled = true
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        stack.pinEdges(to: self, insets: UIEdgeInsets(top: 2, left: 2, bottom: 2, right: 2))

        isAccessibilityElement = true
        accessibilityTraits = .adjustable
        refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }

    override func accessibilityIncrement() {
        step(1)
    }

    override func accessibilityDecrement() {
        step(-1)
    }

    private func configure(_ button: UIButton, symbol: String, action: @escaping () -> Void) {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(weight: .bold))
        config.baseForegroundColor = Theme.Color.accentText
        button.configuration = config
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        button.widthAnchor.constraint(equalToConstant: 44).isActive = true
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        button.hideFromAccessibility()
    }

    private func step(_ delta: Int) {
        let next = min(max(value + delta, Self.minimum), Self.maximum)
        guard next != value else { return }
        value = next
        sendActions(for: .valueChanged)
    }

    private func refresh() {
        valueLabel.text = "\(value)"
        accessibilityValue = "\(value)"
        minusButton.isEnabled = value > Self.minimum
        plusButton.isEnabled = value < Self.maximum
    }
}
