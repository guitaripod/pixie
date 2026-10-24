import UIKit

class GenerationOptionsViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let promptTextView = UITextView()
    private let quantityControl = LabelledSegmentedControl(items: ["1", "2", "3", "4"])
    private let sizeControl = LabelledSegmentedControl(items: [String(localized: "Auto"), String(localized: "Square"), String(localized: "Landscape"), String(localized: "Portrait")])
    private let qualityControl = LabelledSegmentedControl(items: [String(localized: "Low"), String(localized: "Medium"), String(localized: "High")])
    
    private let advancedToggle = UISwitch()
    private var advancedStack: UIStackView!
    
    private let backgroundControl = LabelledSegmentedControl(items: [String(localized: "Transparent"), String(localized: "White"), String(localized: "Black")])
    private let formatControl = LabelledSegmentedControl(items: ["PNG", "JPEG", "WEBP"])
    private let compressionSlider = PercentSlider()
    private let compressionLabel = UILabel()
    private let moderationToggle = UISwitch()
    
    private let creditsLabel = UILabel()
    private let generateButton = UIButton(type: .system)
    private var pendingCostAnnouncement: DispatchWorkItem?
    private var costAnnouncementBaseline: String?
    
    var onGenerate: ((GenerationOptions) -> Void)?
    
    private var initialPrompt: String
    
    init(initialPrompt: String) {
        self.initialPrompt = initialPrompt
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        updateCreditsEstimate()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = String(localized: "Generation Options")
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        promptTextView.translatesAutoresizingMaskIntoConstraints = false
        promptTextView.text = initialPrompt
        promptTextView.font = .scaled(.body, size: 16)
        promptTextView.adjustsFontForContentSizeCategory = true
        promptTextView.accessibilityLabel = String(localized: "Prompt")
        promptTextView.layer.cornerRadius = 12
        promptTextView.layer.borderWidth = 1
        promptTextView.layer.borderColor = UIColor.separator.cgColor
        promptTextView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        promptTextView.isScrollEnabled = false
        quantityControl.selectedSegmentIndex = 0
        quantityControl.accessibilityLabel = String(localized: "Quantity")
        quantityControl.addTarget(self, action: #selector(controlChanged), for: .valueChanged)
        
        sizeControl.selectedSegmentIndex = 0
        sizeControl.accessibilityLabel = String(localized: "Size")
        sizeControl.addTarget(self, action: #selector(controlChanged), for: .valueChanged)
        
        qualityControl.selectedSegmentIndex = 0
        qualityControl.accessibilityLabel = String(localized: "Quality")
        qualityControl.addTarget(self, action: #selector(controlChanged), for: .valueChanged)
        advancedToggle.accessibilityLabel = String(localized: "Advanced Options")
        advancedToggle.addTarget(self, action: #selector(advancedToggled), for: .valueChanged)
        backgroundControl.selectedSegmentIndex = 0
        backgroundControl.accessibilityLabel = String(localized: "Background")
        backgroundControl.addTarget(self, action: #selector(controlChanged), for: .valueChanged)
        
        formatControl.selectedSegmentIndex = 0
        formatControl.accessibilityLabel = String(localized: "Format")
        formatControl.addTarget(self, action: #selector(controlChanged), for: .valueChanged)
        
        compressionSlider.minimumValue = 0
        compressionSlider.maximumValue = 100
        compressionSlider.value = 90
        compressionSlider.accessibilityLabel = String(localized: "Compression")
        compressionSlider.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        compressionSlider.addTarget(self, action: #selector(compressionChanged), for: .valueChanged)
        
        compressionLabel.text = String(localized: "90%")
        compressionLabel.textAlignment = .right
        compressionLabel.useScaledFont(.subheadline, size: 14)
        compressionLabel.accessibilityElementsHidden = true
        
        moderationToggle.isOn = true
        moderationToggle.accessibilityLabel = String(localized: "Content Moderation")
        creditsLabel.useScaledFont(.subheadline, size: 14, weight: .medium)
        creditsLabel.textColor = .secondaryLabel
        creditsLabel.textAlignment = .center
        creditsLabel.numberOfLines = 0
        generateButton.setTitle(String(localized: "Generate"), for: .normal)
        generateButton.titleLabel?.useScaledFont(.title3, size: 18, weight: .semibold)
        generateButton.titleLabel?.numberOfLines = 0
        generateButton.titleLabel?.textAlignment = .center
        generateButton.backgroundColor = .brand
        generateButton.setTitleColor(.white, for: .normal)
        generateButton.layer.cornerRadius = 12
        generateButton.addTarget(self, action: #selector(generateTapped), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [
            createSection(title: String(localized: "Prompt"), content: promptTextView),
            createSection(title: String(localized: "Quantity"), content: quantityControl),
            createSection(title: String(localized: "Size"), content: sizeControl),
            createSection(title: String(localized: "Quality"), content: qualityControl),
            createAdvancedSection(),
            creditsLabel,
            generateButton
        ])
        
        stack.axis = .vertical
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            
            promptTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100),
            generateButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 56)
        ])
    }
    
    private func setupConstraints() {
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
    
    private func createSection(title: String, content: UIView) -> UIView {
        let container = UIView()
        
        let label = UILabel()
        label.text = title
        label.useScaledFont(.subheadline, size: 14, weight: .medium)
        label.numberOfLines = 0
        label.textColor = .secondaryLabel
        label.accessibilityElementsHidden = true
        
        let stack = UIStackView(arrangedSubviews: [label, content])
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
    
    private func createAdvancedSection() -> UIView {
        let container = UIView()
        
        let headerStack = UIStackView()
        headerStack.axis = .horizontal
        
        let label = UILabel()
        label.text = String(localized: "Advanced Options")
        label.useScaledFont(.subheadline, size: 14, weight: .medium)
        label.numberOfLines = 0
        label.textColor = .secondaryLabel
        label.accessibilityElementsHidden = true
        headerStack.alignment = .center
        headerStack.spacing = 12
        
        headerStack.addArrangedSubview(label)
        headerStack.addArrangedSubview(advancedToggle)
        
        let compressionStack = UIStackView(arrangedSubviews: [compressionSlider, compressionLabel])
        compressionStack.axis = .horizontal
        compressionStack.spacing = 12
        compressionLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
        compressionLabel.setContentHuggingPriority(.required, for: .horizontal)
        compressionLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        let moderationStack = UIStackView()
        moderationStack.axis = .horizontal
        let moderationLabel = UILabel()
        moderationLabel.text = String(localized: "Content Moderation")
        moderationLabel.useScaledFont(.body, size: 16)
        moderationLabel.numberOfLines = 0
        moderationLabel.accessibilityElementsHidden = true
        moderationStack.alignment = .center
        moderationStack.spacing = 12
        moderationStack.addArrangedSubview(moderationLabel)
        moderationStack.addArrangedSubview(moderationToggle)
        
        advancedStack = UIStackView(arrangedSubviews: [
            createSection(title: String(localized: "Background"), content: backgroundControl),
            createSection(title: String(localized: "Format"), content: formatControl),
            createSection(title: String(localized: "Compression"), content: compressionStack),
            moderationStack
        ])
        
        advancedStack.axis = .vertical
        advancedStack.spacing = 16
        advancedStack.isHidden = true
        
        let mainStack = UIStackView(arrangedSubviews: [headerStack, advancedStack])
        mainStack.axis = .vertical
        mainStack.spacing = 16
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(mainStack)
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: container.topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            mainStack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    @objc private func controlChanged() {
        let previousCost = creditsLabel.text ?? ""
        updateCreditsEstimate()
        scheduleCostAnnouncement(previous: previousCost)
    }
    
    @objc private func compressionChanged() {
        compressionLabel.text = String(localized: "\(Int(compressionSlider.value))%")
        updateCreditsEstimate()
    }
    
    @objc private func advancedToggled() {
        Motion.animate(0.3) {
            self.advancedStack.isHidden = !self.advancedToggle.isOn
        }
    }

    /// Speaks the new estimate once the person stops changing options, and only when the
    /// figure differs from the one they heard last.
    private func scheduleCostAnnouncement(previous: String) {
        if costAnnouncementBaseline == nil { costAnnouncementBaseline = previous }
        pendingCostAnnouncement?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let baseline = self.costAnnouncementBaseline
            self.costAnnouncementBaseline = nil
            guard let text = self.creditsLabel.text, text != baseline else { return }
            Announce.say(text)
        }
        pendingCostAnnouncement = item
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.costAnnouncementDelay, execute: item)
    }

    private static let costAnnouncementDelay: TimeInterval = 0.9
    
    private func updateCreditsEstimate() {
        let quality = ["low", "medium", "high"][qualityControl.selectedSegmentIndex]
        let quantity = quantityControl.selectedSegmentIndex + 1
        
        let creditsPerImage: Int
        switch quality {
        case "low": creditsPerImage = 5
        case "medium": creditsPerImage = 15
        case "high": creditsPerImage = 50
        default: creditsPerImage = 15
        }
        
        let totalCredits = creditsPerImage * quantity
        creditsLabel.text = String(localized: "Estimated cost: \(totalCredits) credits")
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    @objc private func generateTapped() {
        let sizes = ["auto", "1024x1024", "1536x1024", "1024x1536"]
        let sizeDisplays = [String(localized: "Auto"), String(localized: "Square"), String(localized: "Landscape"), String(localized: "Portrait")]
        let qualities = ["low", "medium", "high"]
        
        var options = GenerationOptions.default
        options.prompt = promptTextView.text ?? ""
        options.quantity = quantityControl.selectedSegmentIndex + 1
        options.size = sizes[sizeControl.selectedSegmentIndex]
        options.sizeDisplay = sizeDisplays[sizeControl.selectedSegmentIndex]
        options.quality = qualities[qualityControl.selectedSegmentIndex]
        
        dismiss(animated: true) { [weak self] in
            self?.onGenerate?(options)
        }
    }
}