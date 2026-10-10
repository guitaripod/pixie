import UIKit
import Combine

class CostEstimatorViewController: UIViewController {
    private let viewModel: CreditsViewModel
    private var cancellables = Set<AnyCancellable>()
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let balanceCard = UIView()
    private let balanceLabel = UILabel()
    private let balanceAmountLabel = UILabel()
    private let balanceStatusLabel = UILabel()
    private let balanceStatusIcon = UIImageView()
    private var currentBalance: Int?
    private var pendingAnnouncement: DispatchWorkItem?
    private var announcementBaseline: String?
    private var lastResultSummary = ""
    
    private let qualitySection = UIView()
    private let qualityLabel = UILabel()
    private let qualitySegmentedControl = LabelledSegmentedControl(items: [String(localized: "Low"), String(localized: "Medium"), String(localized: "High")])
    
    private let sizeSection = UIView()
    private let sizeLabel = UILabel()
    private let sizeSegmentedControl = LabelledSegmentedControl(items: ["1024×1024", "1536×1024", "1024×1536"])
    
    private let editSection = UIView()
    private let editLabel = UILabel()
    private let editSwitch = UISwitch()
    
    private let numberOfImagesSection = UIView()
    private let numberOfImagesLabel = UILabel()
    private let numberOfImagesStepper = UIStepper()
    private let numberOfImagesValueLabel = UILabel()
    
    private let resultCard = UIView()
    private let resultStackView = UIStackView()
    private let estimatedCostLabel = UILabel()
    private let estimatedUSDLabel = UILabel()
    private let noteLabel = UILabel()
    
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
    }
    
    private func setupUI() {
        title = String(localized: "Cost Estimator")
        view.backgroundColor = .systemBackground
        navigationItem.largeTitleDisplayMode = .never
        
        setupScrollView()
        setupBalanceCard()
        setupQualitySection()
        setupSizeSection()
        setupEditSection()
        setupNumberOfImagesSection()
        setupResultCard()
        layoutUI()
    }
    
    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }
    
    private func setupBalanceCard() {
        balanceCard.backgroundColor = .secondarySystemBackground
        balanceCard.layer.cornerRadius = 16
        balanceCard.translatesAutoresizingMaskIntoConstraints = false
        
        balanceLabel.text = String(localized: "Current Balance")
        balanceLabel.useScaledFont(.subheadline, size: 14, weight: .medium)
        balanceLabel.textColor = .secondaryLabel
        balanceLabel.numberOfLines = 0
        balanceLabel.translatesAutoresizingMaskIntoConstraints = false
        
        balanceAmountLabel.useScaledFont(.title1, size: 28, weight: .bold)
        balanceAmountLabel.textColor = .label
        balanceAmountLabel.numberOfLines = 0
        balanceAmountLabel.translatesAutoresizingMaskIntoConstraints = false

        balanceStatusLabel.useScaledFont(.subheadline, size: 14, weight: .semibold)
        balanceStatusLabel.textColor = .label
        balanceStatusLabel.numberOfLines = 0
        balanceStatusIcon.contentMode = .scaleAspectFit
        balanceStatusIcon.setContentHuggingPriority(.required, for: .horizontal)
        balanceStatusIcon.setContentCompressionResistancePriority(.required, for: .horizontal)

        let statusStack = UIStackView(arrangedSubviews: [balanceStatusIcon, balanceStatusLabel])
        statusStack.axis = .horizontal
        statusStack.spacing = 6
        statusStack.alignment = .center
        statusStack.isHidden = true
        statusStack.tag = Self.balanceStatusTag
        statusStack.translatesAutoresizingMaskIntoConstraints = false
        
        balanceCard.addSubview(balanceLabel)
        balanceCard.addSubview(balanceAmountLabel)
        balanceCard.addSubview(statusStack)
        balanceCard.isAccessibilityElement = true
        balanceCard.accessibilityTraits = .staticText
        
        NSLayoutConstraint.activate([
            balanceLabel.topAnchor.constraint(equalTo: balanceCard.topAnchor, constant: 16),
            balanceLabel.leadingAnchor.constraint(equalTo: balanceCard.leadingAnchor, constant: 16),
            balanceLabel.trailingAnchor.constraint(equalTo: balanceCard.trailingAnchor, constant: -16),
            
            balanceAmountLabel.topAnchor.constraint(equalTo: balanceLabel.bottomAnchor, constant: 4),
            balanceAmountLabel.leadingAnchor.constraint(equalTo: balanceCard.leadingAnchor, constant: 16),
            balanceAmountLabel.trailingAnchor.constraint(equalTo: balanceCard.trailingAnchor, constant: -16),

            statusStack.topAnchor.constraint(equalTo: balanceAmountLabel.bottomAnchor, constant: 6),
            statusStack.leadingAnchor.constraint(equalTo: balanceCard.leadingAnchor, constant: 16),
            statusStack.trailingAnchor.constraint(lessThanOrEqualTo: balanceCard.trailingAnchor, constant: -16),
            statusStack.bottomAnchor.constraint(equalTo: balanceCard.bottomAnchor, constant: -16)
        ])
    }

    private static let balanceStatusTag = 7001
    
    private func setupQualitySection() {
        qualityLabel.text = String(localized: "Quality")
        qualityLabel.useScaledFont(.callout, size: 16, weight: .semibold)
        qualityLabel.numberOfLines = 0
        qualityLabel.accessibilityElementsHidden = true
        qualityLabel.translatesAutoresizingMaskIntoConstraints = false
        
        qualitySegmentedControl.selectedSegmentIndex = 1
        qualitySegmentedControl.accessibilityLabel = String(localized: "Quality")
        qualitySegmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        qualitySegmentedControl.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupSizeSection() {
        sizeLabel.text = String(localized: "Size")
        sizeLabel.useScaledFont(.callout, size: 16, weight: .semibold)
        sizeLabel.numberOfLines = 0
        sizeLabel.accessibilityElementsHidden = true
        sizeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        sizeSegmentedControl.selectedSegmentIndex = 0
        sizeSegmentedControl.accessibilityLabel = String(localized: "Size")
        sizeSegmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        sizeSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupEditSection() {
        editSection.backgroundColor = .secondarySystemBackground
        editSection.layer.cornerRadius = 12
        editSection.translatesAutoresizingMaskIntoConstraints = false
        
        editLabel.text = String(localized: "Edit Mode")
        editLabel.useScaledFont(.callout, size: 16, weight: .medium)
        editLabel.numberOfLines = 0
        editLabel.accessibilityElementsHidden = true
        editLabel.translatesAutoresizingMaskIntoConstraints = false
        
        editSwitch.isOn = false
        editSwitch.accessibilityLabel = String(localized: "Edit Mode")
        editSwitch.addTarget(self, action: #selector(switchChanged), for: .valueChanged)
        editSwitch.translatesAutoresizingMaskIntoConstraints = false
        
        editSection.addSubview(editLabel)
        editSection.addSubview(editSwitch)
        
        NSLayoutConstraint.activate([
            editLabel.leadingAnchor.constraint(equalTo: editSection.leadingAnchor, constant: 16),
            editLabel.topAnchor.constraint(equalTo: editSection.topAnchor, constant: 12),
            editLabel.bottomAnchor.constraint(equalTo: editSection.bottomAnchor, constant: -12),
            editLabel.trailingAnchor.constraint(lessThanOrEqualTo: editSwitch.leadingAnchor, constant: -12),
            
            editSwitch.trailingAnchor.constraint(equalTo: editSection.trailingAnchor, constant: -16),
            editSwitch.centerYAnchor.constraint(equalTo: editSection.centerYAnchor),
            
            editSection.heightAnchor.constraint(greaterThanOrEqualToConstant: 56)
        ])
    }
    
    private func setupNumberOfImagesSection() {
        numberOfImagesSection.backgroundColor = .secondarySystemBackground
        numberOfImagesSection.layer.cornerRadius = 12
        numberOfImagesSection.translatesAutoresizingMaskIntoConstraints = false
        
        numberOfImagesLabel.text = String(localized: "Number of Images")
        numberOfImagesLabel.useScaledFont(.callout, size: 16, weight: .medium)
        numberOfImagesLabel.numberOfLines = 0
        numberOfImagesLabel.accessibilityElementsHidden = true
        numberOfImagesLabel.translatesAutoresizingMaskIntoConstraints = false
        
        numberOfImagesStepper.minimumValue = 1
        numberOfImagesStepper.maximumValue = 4
        numberOfImagesStepper.value = 1
        numberOfImagesStepper.accessibilityLabel = String(localized: "Number of Images")
        numberOfImagesStepper.accessibilityValue = "1"
        numberOfImagesStepper.addTarget(self, action: #selector(stepperChanged), for: .valueChanged)
        numberOfImagesStepper.translatesAutoresizingMaskIntoConstraints = false
        
        numberOfImagesValueLabel.text = "1"
        numberOfImagesValueLabel.useScaledFont(.callout, size: 16, weight: .medium)
        numberOfImagesValueLabel.textColor = .brandText
        numberOfImagesValueLabel.accessibilityElementsHidden = true
        numberOfImagesValueLabel.translatesAutoresizingMaskIntoConstraints = false
        
        numberOfImagesSection.addSubview(numberOfImagesLabel)
        numberOfImagesSection.addSubview(numberOfImagesValueLabel)
        numberOfImagesSection.addSubview(numberOfImagesStepper)
        
        NSLayoutConstraint.activate([
            numberOfImagesLabel.leadingAnchor.constraint(equalTo: numberOfImagesSection.leadingAnchor, constant: 16),
            numberOfImagesLabel.topAnchor.constraint(equalTo: numberOfImagesSection.topAnchor, constant: 12),
            numberOfImagesLabel.bottomAnchor.constraint(equalTo: numberOfImagesSection.bottomAnchor, constant: -12),
            numberOfImagesLabel.trailingAnchor.constraint(lessThanOrEqualTo: numberOfImagesValueLabel.leadingAnchor, constant: -12),
            
            numberOfImagesValueLabel.trailingAnchor.constraint(equalTo: numberOfImagesStepper.leadingAnchor, constant: -16),
            numberOfImagesValueLabel.centerYAnchor.constraint(equalTo: numberOfImagesSection.centerYAnchor),
            
            numberOfImagesStepper.trailingAnchor.constraint(equalTo: numberOfImagesSection.trailingAnchor, constant: -16),
            numberOfImagesStepper.centerYAnchor.constraint(equalTo: numberOfImagesSection.centerYAnchor),
            
            numberOfImagesSection.heightAnchor.constraint(greaterThanOrEqualToConstant: 56)
        ])
        numberOfImagesValueLabel.setContentHuggingPriority(.required, for: .horizontal)
        numberOfImagesValueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    }
    
    private func setupResultCard() {
        resultCard.backgroundColor = .brandTint
        resultCard.layer.cornerRadius = 16
        resultCard.layer.borderWidth = 1
        resultCard.layer.borderColor = UIColor.brand.cgColor
        resultCard.isAccessibilityElement = true
        resultCard.accessibilityTraits = .staticText
        resultCard.translatesAutoresizingMaskIntoConstraints = false
        
        resultStackView.axis = .vertical
        resultStackView.spacing = 12
        resultStackView.alignment = .center
        resultStackView.translatesAutoresizingMaskIntoConstraints = false
        
        estimatedCostLabel.useScaledFont(.largeTitle, size: 36, weight: .bold)
        estimatedCostLabel.textColor = .brandText
        estimatedCostLabel.textAlignment = .center
        estimatedCostLabel.numberOfLines = 0
        
        estimatedUSDLabel.useScaledFont(.callout, size: 16, weight: .medium)
        estimatedUSDLabel.textColor = .secondaryLabel
        estimatedUSDLabel.textAlignment = .center
        estimatedUSDLabel.numberOfLines = 0
        
        noteLabel.useScaledFont(.subheadline, size: 14)
        noteLabel.textColor = .secondaryLabel
        noteLabel.textAlignment = .center
        noteLabel.numberOfLines = 0
        
        resultStackView.addArrangedSubview(estimatedCostLabel)
        resultStackView.addArrangedSubview(estimatedUSDLabel)
        resultStackView.addArrangedSubview(noteLabel)
        
        resultCard.addSubview(resultStackView)
        
        NSLayoutConstraint.activate([
            resultStackView.topAnchor.constraint(equalTo: resultCard.topAnchor, constant: 24),
            resultStackView.leadingAnchor.constraint(equalTo: resultCard.leadingAnchor, constant: 24),
            resultStackView.trailingAnchor.constraint(equalTo: resultCard.trailingAnchor, constant: -24),
            resultStackView.bottomAnchor.constraint(equalTo: resultCard.bottomAnchor, constant: -24)
        ])
    }
    
    private func layoutUI() {
        contentView.addSubview(balanceCard)
        contentView.addSubview(qualityLabel)
        contentView.addSubview(qualitySegmentedControl)
        contentView.addSubview(sizeLabel)
        contentView.addSubview(sizeSegmentedControl)
        contentView.addSubview(editSection)
        contentView.addSubview(numberOfImagesSection)
        contentView.addSubview(resultCard)
        
        NSLayoutConstraint.activate([
            balanceCard.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            balanceCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            balanceCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            qualityLabel.topAnchor.constraint(equalTo: balanceCard.bottomAnchor, constant: 24),
            qualityLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
            qualitySegmentedControl.topAnchor.constraint(equalTo: qualityLabel.bottomAnchor, constant: 12),
            qualitySegmentedControl.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            qualitySegmentedControl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            sizeLabel.topAnchor.constraint(equalTo: qualitySegmentedControl.bottomAnchor, constant: 24),
            sizeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
            sizeSegmentedControl.topAnchor.constraint(equalTo: sizeLabel.bottomAnchor, constant: 12),
            sizeSegmentedControl.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            sizeSegmentedControl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            editSection.topAnchor.constraint(equalTo: sizeSegmentedControl.bottomAnchor, constant: 24),
            editSection.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            editSection.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            numberOfImagesSection.topAnchor.constraint(equalTo: editSection.bottomAnchor, constant: 16),
            numberOfImagesSection.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            numberOfImagesSection.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            resultCard.topAnchor.constraint(equalTo: numberOfImagesSection.bottomAnchor, constant: 24),
            resultCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            resultCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            resultCard.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32)
        ])
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
        let isEnough = balance >= estimatedTotal
        let status = isEnough ? String(localized: "Enough") : String(localized: "Low")
        balanceStatusLabel.text = status
        balanceStatusIcon.image = UIImage(systemName: isEnough ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
        balanceStatusIcon.tintColor = isEnough ? .systemGreen : .systemOrange
        balanceCard.viewWithTag(Self.balanceStatusTag)?.isHidden = false
        balanceCard.accessibilityLabel = String(localized: "Current Balance")
        balanceCard.accessibilityValue = "\(String(localized: "\(balance) credits")), \(status)"
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
        let count = Int(numberOfImagesStepper.value)
        numberOfImagesValueLabel.text = "\(count)"
        numberOfImagesStepper.accessibilityValue = "\(count)"
        updateCalculation(announcing: true)
    }

    private var estimatedTotal: Int {
        let quality = ["low", "medium", "high"][qualitySegmentedControl.selectedSegmentIndex]
        let size = ["1024x1024", "1536x1024", "1024x1536"][sizeSegmentedControl.selectedSegmentIndex]
        let editCost = editSwitch.isOn ? getEditCost(quality: quality) : 0
        return (getBaseCost(quality: quality, size: size) + editCost) * Int(numberOfImagesStepper.value)
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
        let quality = ["low", "medium", "high"][qualitySegmentedControl.selectedSegmentIndex]
        let size = ["1024x1024", "1536x1024", "1024x1536"][sizeSegmentedControl.selectedSegmentIndex]
        let isEdit = editSwitch.isOn
        let numberOfImages = Int(numberOfImagesStepper.value)
        
        // Calculate cost locally
        let baseCost = getBaseCost(quality: quality, size: size)
        let editCost = isEdit ? getEditCost(quality: quality) : 0
        let totalCostPerImage = baseCost + editCost
        let totalCost = totalCostPerImage * numberOfImages
        
        // Update UI
        estimatedCostLabel.text = String(localized: "\(totalCost) credits")
        estimatedUSDLabel.text = String(localized: "≈ \(formattedUSD(Double(totalCost) * 0.01))")
        noteLabel.text = String(localized: "Estimate based on \(numberOfImages) image\(numberOfImages > 1 ? "s" : "")")
        lastResultSummary = [estimatedCostLabel.text, estimatedUSDLabel.text].compactMap { $0 }.joined(separator: ", ")
        resultCard.accessibilityLabel = String(localized: "Cost Estimator")
        resultCard.accessibilityValue = [lastResultSummary, noteLabel.text].compactMap { $0 }.joined(separator: ", ")
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