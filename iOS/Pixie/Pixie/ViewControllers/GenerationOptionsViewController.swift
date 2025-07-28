import UIKit

class GenerationOptionsViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let promptTextView = UITextView()
    private let quantityControl = UISegmentedControl(items: ["1", "2", "3", "4"])
    private let sizeControl = UISegmentedControl(items: ["Auto", "Square", "Landscape", "Portrait"])
    private let qualityControl = UISegmentedControl(items: ["Low", "Medium", "High"])
    
    private let advancedToggle = UISwitch()
    private var advancedStack: UIStackView!
    
    private let backgroundControl = UISegmentedControl(items: ["Transparent", "White", "Black"])
    private let formatControl = UISegmentedControl(items: ["PNG", "JPEG", "WEBP"])
    private let compressionSlider = UISlider()
    private let compressionLabel = UILabel()
    private let moderationToggle = UISwitch()
    
    private let creditsLabel = UILabel()
    private let generateButton = UIButton(type: .system)
    
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
        title = "Generation Options"
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        promptTextView.translatesAutoresizingMaskIntoConstraints = false
        promptTextView.text = initialPrompt
        promptTextView.font = .systemFont(ofSize: 16)
        promptTextView.layer.cornerRadius = 12
        promptTextView.layer.borderWidth = 1
        promptTextView.layer.borderColor = UIColor.separator.cgColor
        promptTextView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        promptTextView.isScrollEnabled = false
        quantityControl.selectedSegmentIndex = 0
        quantityControl.addTarget(self, action: #selector(controlChanged), for: .valueChanged)
        
        sizeControl.selectedSegmentIndex = 0
        sizeControl.addTarget(self, action: #selector(controlChanged), for: .valueChanged)
        
        qualityControl.selectedSegmentIndex = 1
        qualityControl.addTarget(self, action: #selector(controlChanged), for: .valueChanged)
        advancedToggle.addTarget(self, action: #selector(advancedToggled), for: .valueChanged)
        backgroundControl.selectedSegmentIndex = 0
        backgroundControl.addTarget(self, action: #selector(controlChanged), for: .valueChanged)
        
        formatControl.selectedSegmentIndex = 0
        formatControl.addTarget(self, action: #selector(controlChanged), for: .valueChanged)
        
        compressionSlider.minimumValue = 0
        compressionSlider.maximumValue = 100
        compressionSlider.value = 90
        compressionSlider.addTarget(self, action: #selector(compressionChanged), for: .valueChanged)
        
        compressionLabel.text = "90%"
        compressionLabel.textAlignment = .right
        compressionLabel.font = .systemFont(ofSize: 14)
        
        moderationToggle.isOn = true
        creditsLabel.font = .systemFont(ofSize: 14, weight: .medium)
        creditsLabel.textColor = .secondaryLabel
        creditsLabel.textAlignment = .center
        generateButton.setTitle("Generate", for: .normal)
        generateButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        generateButton.backgroundColor = .systemBlue
        generateButton.setTitleColor(.white, for: .normal)
        generateButton.layer.cornerRadius = 12
        generateButton.addTarget(self, action: #selector(generateTapped), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [
            createSection(title: "Prompt", content: promptTextView),
            createSection(title: "Quantity", content: quantityControl),
            createSection(title: "Size", content: sizeControl),
            createSection(title: "Quality", content: qualityControl),
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
            generateButton.heightAnchor.constraint(equalToConstant: 56)
        ])
    }
    
    private func setupConstraints() {
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
    
    private func createSection(title: String, content: UIView) -> UIView {
        let container = UIView()
        
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        
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
        label.text = "Advanced Options"
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        
        headerStack.addArrangedSubview(label)
        headerStack.addArrangedSubview(advancedToggle)
        
        let compressionStack = UIStackView(arrangedSubviews: [compressionSlider, compressionLabel])
        compressionStack.axis = .horizontal
        compressionStack.spacing = 12
        compressionLabel.widthAnchor.constraint(equalToConstant: 40).isActive = true
        
        let moderationStack = UIStackView()
        moderationStack.axis = .horizontal
        let moderationLabel = UILabel()
        moderationLabel.text = "Content Moderation"
        moderationLabel.font = .systemFont(ofSize: 16)
        moderationStack.addArrangedSubview(moderationLabel)
        moderationStack.addArrangedSubview(moderationToggle)
        
        advancedStack = UIStackView(arrangedSubviews: [
            createSection(title: "Background", content: backgroundControl),
            createSection(title: "Format", content: formatControl),
            createSection(title: "Compression", content: compressionStack),
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
        updateCreditsEstimate()
    }
    
    @objc private func compressionChanged() {
        compressionLabel.text = "\(Int(compressionSlider.value))%"
        updateCreditsEstimate()
    }
    
    @objc private func advancedToggled() {
        UIView.animate(withDuration: 0.3) {
            self.advancedStack.isHidden = !self.advancedToggle.isOn
        }
    }
    
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
        creditsLabel.text = "Estimated cost: \(totalCredits) credits"
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    @objc private func generateTapped() {
        let sizes = ["auto", "1024x1024", "1024x768", "768x1024"]
        let sizeDisplays = ["Auto", "Square", "Landscape", "Portrait"]
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