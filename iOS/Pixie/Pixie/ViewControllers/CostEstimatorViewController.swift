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
    
    private let qualitySection = UIView()
    private let qualityLabel = UILabel()
    private let qualitySegmentedControl = UISegmentedControl(items: ["Low", "Medium", "High"])
    
    private let sizeSection = UIView()
    private let sizeLabel = UILabel()
    private let sizeSegmentedControl = UISegmentedControl(items: ["1024×1024", "1536×1024", "1024×1536"])
    
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
        title = "Cost Estimator"
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
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
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
        
        balanceLabel.text = "Current Balance"
        balanceLabel.font = .systemFont(ofSize: 14, weight: .medium)
        balanceLabel.textColor = .secondaryLabel
        balanceLabel.translatesAutoresizingMaskIntoConstraints = false
        
        balanceAmountLabel.font = .systemFont(ofSize: 28, weight: .bold)
        balanceAmountLabel.translatesAutoresizingMaskIntoConstraints = false
        
        balanceCard.addSubview(balanceLabel)
        balanceCard.addSubview(balanceAmountLabel)
        
        NSLayoutConstraint.activate([
            balanceLabel.topAnchor.constraint(equalTo: balanceCard.topAnchor, constant: 16),
            balanceLabel.leadingAnchor.constraint(equalTo: balanceCard.leadingAnchor, constant: 16),
            
            balanceAmountLabel.topAnchor.constraint(equalTo: balanceLabel.bottomAnchor, constant: 4),
            balanceAmountLabel.leadingAnchor.constraint(equalTo: balanceCard.leadingAnchor, constant: 16),
            balanceAmountLabel.bottomAnchor.constraint(equalTo: balanceCard.bottomAnchor, constant: -16)
        ])
    }
    
    private func setupQualitySection() {
        qualityLabel.text = "Quality"
        qualityLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        qualityLabel.translatesAutoresizingMaskIntoConstraints = false
        
        qualitySegmentedControl.selectedSegmentIndex = 1 // Medium by default
        qualitySegmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        qualitySegmentedControl.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupSizeSection() {
        sizeLabel.text = "Size"
        sizeLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        sizeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        sizeSegmentedControl.selectedSegmentIndex = 0 // 1024x1024 by default
        sizeSegmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        sizeSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupEditSection() {
        editSection.backgroundColor = .secondarySystemBackground
        editSection.layer.cornerRadius = 12
        editSection.translatesAutoresizingMaskIntoConstraints = false
        
        editLabel.text = "Edit Mode"
        editLabel.font = .systemFont(ofSize: 16, weight: .medium)
        editLabel.translatesAutoresizingMaskIntoConstraints = false
        
        editSwitch.isOn = false
        editSwitch.addTarget(self, action: #selector(switchChanged), for: .valueChanged)
        editSwitch.translatesAutoresizingMaskIntoConstraints = false
        
        editSection.addSubview(editLabel)
        editSection.addSubview(editSwitch)
        
        NSLayoutConstraint.activate([
            editLabel.leadingAnchor.constraint(equalTo: editSection.leadingAnchor, constant: 16),
            editLabel.centerYAnchor.constraint(equalTo: editSection.centerYAnchor),
            
            editSwitch.trailingAnchor.constraint(equalTo: editSection.trailingAnchor, constant: -16),
            editSwitch.centerYAnchor.constraint(equalTo: editSection.centerYAnchor),
            
            editSection.heightAnchor.constraint(equalToConstant: 56)
        ])
    }
    
    private func setupNumberOfImagesSection() {
        numberOfImagesSection.backgroundColor = .secondarySystemBackground
        numberOfImagesSection.layer.cornerRadius = 12
        numberOfImagesSection.translatesAutoresizingMaskIntoConstraints = false
        
        numberOfImagesLabel.text = "Number of Images"
        numberOfImagesLabel.font = .systemFont(ofSize: 16, weight: .medium)
        numberOfImagesLabel.translatesAutoresizingMaskIntoConstraints = false
        
        numberOfImagesStepper.minimumValue = 1
        numberOfImagesStepper.maximumValue = 4
        numberOfImagesStepper.value = 1
        numberOfImagesStepper.addTarget(self, action: #selector(stepperChanged), for: .valueChanged)
        numberOfImagesStepper.translatesAutoresizingMaskIntoConstraints = false
        
        numberOfImagesValueLabel.text = "1"
        numberOfImagesValueLabel.font = .systemFont(ofSize: 16, weight: .medium)
        numberOfImagesValueLabel.textColor = .systemPurple
        numberOfImagesValueLabel.translatesAutoresizingMaskIntoConstraints = false
        
        numberOfImagesSection.addSubview(numberOfImagesLabel)
        numberOfImagesSection.addSubview(numberOfImagesValueLabel)
        numberOfImagesSection.addSubview(numberOfImagesStepper)
        
        NSLayoutConstraint.activate([
            numberOfImagesLabel.leadingAnchor.constraint(equalTo: numberOfImagesSection.leadingAnchor, constant: 16),
            numberOfImagesLabel.centerYAnchor.constraint(equalTo: numberOfImagesSection.centerYAnchor),
            
            numberOfImagesValueLabel.trailingAnchor.constraint(equalTo: numberOfImagesStepper.leadingAnchor, constant: -16),
            numberOfImagesValueLabel.centerYAnchor.constraint(equalTo: numberOfImagesSection.centerYAnchor),
            
            numberOfImagesStepper.trailingAnchor.constraint(equalTo: numberOfImagesSection.trailingAnchor, constant: -16),
            numberOfImagesStepper.centerYAnchor.constraint(equalTo: numberOfImagesSection.centerYAnchor),
            
            numberOfImagesSection.heightAnchor.constraint(equalToConstant: 56)
        ])
    }
    
    private func setupResultCard() {
        resultCard.backgroundColor = .systemPurple.withAlphaComponent(0.1)
        resultCard.layer.cornerRadius = 16
        resultCard.layer.borderWidth = 1
        resultCard.layer.borderColor = UIColor.systemPurple.cgColor
        resultCard.translatesAutoresizingMaskIntoConstraints = false
        
        resultStackView.axis = .vertical
        resultStackView.spacing = 12
        resultStackView.alignment = .center
        resultStackView.translatesAutoresizingMaskIntoConstraints = false
        
        estimatedCostLabel.font = .systemFont(ofSize: 36, weight: .bold)
        estimatedCostLabel.textColor = .systemPurple
        estimatedCostLabel.textAlignment = .center
        
        estimatedUSDLabel.font = .systemFont(ofSize: 16, weight: .medium)
        estimatedUSDLabel.textColor = .secondaryLabel
        estimatedUSDLabel.textAlignment = .center
        
        noteLabel.font = .systemFont(ofSize: 14)
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
        balanceAmountLabel.text = "\(balance.balance) credits"
        balanceAmountLabel.textColor = balance.getBalanceColor()
    }
    
    @objc private func segmentChanged() {
        HapticsManager.shared.selection()
        updateCalculation()
    }
    
    @objc private func switchChanged() {
        HapticsManager.shared.selection()
        updateCalculation()
    }
    
    @objc private func stepperChanged() {
        HapticsManager.shared.selection()
        numberOfImagesValueLabel.text = "\(Int(numberOfImagesStepper.value))"
        updateCalculation()
    }
    
    private func updateCalculation() {
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
        estimatedCostLabel.text = "\(totalCost) credits"
        estimatedUSDLabel.text = String(format: "≈ $%.2f USD", Double(totalCost) * 0.01)
        noteLabel.text = "Estimate based on \(numberOfImages) image\(numberOfImages > 1 ? "s" : "")"
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