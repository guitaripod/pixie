import UIKit

class GenerationToolbar: UIView {
    
    private let promptTextField = UITextField()
    private let generateButton = UIButton()
    private let expandButton = UIButton()
    private let collapsedContent = UIView()
    private let expandedContent = UIScrollView()
    private let expandedStackView = UIStackView()
    
    private var isExpanded = false
    
    var onExpandedChange: ((Bool) -> Void)?
    var onGenerate: ((GenerationOptions) -> Void)?
    
    private var selectedSize = ImageSize.auto
    private var selectedQuality = ImageQuality.low
    private var selectedBackground: BackgroundStyle?
    private var selectedFormat: OutputFormat?
    private var compressionLevel: Int = 80
    private var selectedModeration: ModerationLevel?
    private var showAdvancedOptions = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        setupCollapsedContent()
        setupExpandedContent()
        
        setExpanded(false)
    }
    
    private func setupCollapsedContent() {
        collapsedContent.translatesAutoresizingMaskIntoConstraints = false
        addSubview(collapsedContent)
        
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 12
        stackView.alignment = .center
        collapsedContent.addSubview(stackView)
        
        promptTextField.translatesAutoresizingMaskIntoConstraints = false
        promptTextField.placeholder = "Describe what you want to create..."
        promptTextField.borderStyle = .none
        promptTextField.font = .systemFont(ofSize: 16)
        promptTextField.returnKeyType = .go
        promptTextField.delegate = self
        
        let textFieldContainer = UIView()
        textFieldContainer.translatesAutoresizingMaskIntoConstraints = false
        textFieldContainer.backgroundColor = .secondarySystemFill
        textFieldContainer.layer.cornerRadius = 20
        textFieldContainer.addSubview(promptTextField)
        
        expandButton.translatesAutoresizingMaskIntoConstraints = false
        expandButton.setImage(UIImage(systemName: "chevron.up.circle.fill"), for: .normal)
        expandButton.tintColor = .systemBlue
        expandButton.addTarget(self, action: #selector(expandButtonTapped), for: .touchUpInside)
        
        generateButton.translatesAutoresizingMaskIntoConstraints = false
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: "sparkles")
        config.cornerStyle = .capsule
        config.baseBackgroundColor = UIColor(red: 0.404, green: 0.314, blue: 0.643, alpha: 1.0)
        generateButton.configuration = config
        generateButton.addTarget(self, action: #selector(generateTapped), for: .touchUpInside)
        
        stackView.addArrangedSubview(textFieldContainer)
        stackView.addArrangedSubview(expandButton)
        stackView.addArrangedSubview(generateButton)
        
        NSLayoutConstraint.activate([
            collapsedContent.topAnchor.constraint(equalTo: topAnchor),
            collapsedContent.leadingAnchor.constraint(equalTo: leadingAnchor),
            collapsedContent.trailingAnchor.constraint(equalTo: trailingAnchor),
            collapsedContent.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: collapsedContent.topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: collapsedContent.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: collapsedContent.trailingAnchor, constant: -16),
            
            textFieldContainer.heightAnchor.constraint(equalToConstant: 40),
            
            promptTextField.leadingAnchor.constraint(equalTo: textFieldContainer.leadingAnchor, constant: 16),
            promptTextField.trailingAnchor.constraint(equalTo: textFieldContainer.trailingAnchor, constant: -16),
            promptTextField.centerYAnchor.constraint(equalTo: textFieldContainer.centerYAnchor),
            
            expandButton.widthAnchor.constraint(equalToConstant: 32),
            expandButton.heightAnchor.constraint(equalToConstant: 32),
            
            generateButton.widthAnchor.constraint(equalToConstant: 44),
            generateButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func setupExpandedContent() {
        expandedContent.translatesAutoresizingMaskIntoConstraints = false
        expandedContent.showsVerticalScrollIndicator = false
        addSubview(expandedContent)
        
        expandedStackView.translatesAutoresizingMaskIntoConstraints = false
        expandedStackView.axis = .vertical
        expandedStackView.spacing = 20
        expandedStackView.alignment = .fill
        expandedContent.addSubview(expandedStackView)
        let dragHandle = UIView()
        dragHandle.translatesAutoresizingMaskIntoConstraints = false
        dragHandle.backgroundColor = UIColor.tertiaryLabel
        dragHandle.layer.cornerRadius = 2
        expandedContent.addSubview(dragHandle)
        
        NSLayoutConstraint.activate([
            dragHandle.topAnchor.constraint(equalTo: expandedContent.topAnchor, constant: 8),
            dragHandle.centerXAnchor.constraint(equalTo: expandedContent.centerXAnchor),
            dragHandle.widthAnchor.constraint(equalToConstant: 40),
            dragHandle.heightAnchor.constraint(equalToConstant: 4)
        ])
        
        let headerView = UIView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        
        let iconView = UIImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = UIImage(systemName: "sparkles")
        iconView.tintColor = .systemBlue
        iconView.contentMode = .scaleAspectFit
        headerView.addSubview(iconView)
        
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Create Image"
        titleLabel.font = .systemFont(ofSize: 24, weight: .semibold)
        headerView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            iconView.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            
            headerView.heightAnchor.constraint(equalToConstant: 32)
        ])
        
        let promptSection = createPromptSection()
        let sizeSection = createSizeSection()
        let qualitySection = createQualitySection()
        let advancedSection = createAdvancedSection()
        let generateSection = createGenerateSection()
        
        expandedStackView.addArrangedSubview(headerView)
        expandedStackView.addArrangedSubview(promptSection)
        expandedStackView.addArrangedSubview(sizeSection)
        expandedStackView.addArrangedSubview(qualitySection)
        expandedStackView.addArrangedSubview(advancedSection)
        expandedStackView.addArrangedSubview(generateSection)
        
        NSLayoutConstraint.activate([
            expandedContent.topAnchor.constraint(equalTo: topAnchor, constant: 40),
            expandedContent.leadingAnchor.constraint(equalTo: leadingAnchor),
            expandedContent.trailingAnchor.constraint(equalTo: trailingAnchor),
            expandedContent.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            expandedStackView.topAnchor.constraint(equalTo: expandedContent.topAnchor),
            expandedStackView.leadingAnchor.constraint(equalTo: expandedContent.leadingAnchor, constant: 20),
            expandedStackView.trailingAnchor.constraint(equalTo: expandedContent.trailingAnchor, constant: -20),
            expandedStackView.bottomAnchor.constraint(equalTo: expandedContent.bottomAnchor, constant: -20),
            expandedStackView.widthAnchor.constraint(equalTo: expandedContent.widthAnchor, constant: -40)
        ])
    }
    
    private func createPromptSection() -> UIView {
        let section = UIView()
        
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Describe what you want to create..."
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        section.addSubview(label)
        
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.font = .systemFont(ofSize: 16)
        textView.backgroundColor = .secondarySystemFill
        textView.layer.cornerRadius = 12
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.text = promptTextField.text
        textView.delegate = self
        section.addSubview(textView)
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: section.topAnchor),
            label.leadingAnchor.constraint(equalTo: section.leadingAnchor),
            
            textView.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
            textView.leadingAnchor.constraint(equalTo: section.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: section.trailingAnchor),
            textView.heightAnchor.constraint(equalToConstant: 80),
            textView.bottomAnchor.constraint(equalTo: section.bottomAnchor)
        ])
        
        return section
    }
    
    private func createSizeSection() -> UIView {
        let section = UIView()
        
        let headerStack = UIStackView()
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerStack.axis = .horizontal
        headerStack.spacing = 6
        headerStack.alignment = .center
        section.addSubview(headerStack)
        
        let iconView = UIImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = UIImage(systemName: "aspectratio")
        iconView.tintColor = .systemBlue
        iconView.contentMode = .scaleAspectFit
        
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Size"
        label.font = .systemFont(ofSize: 16, weight: .medium)
        
        headerStack.addArrangedSubview(iconView)
        headerStack.addArrangedSubview(label)
        
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        section.addSubview(scrollView)
        
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 8
        scrollView.addSubview(stackView)
        
        for (index, size) in ImageSize.allCases.enumerated() {
            let button = createSizeButton(size: size)
            button.tag = 4000 + index
            button.addAction(UIAction { [weak self] _ in
                HapticManager.shared.impact(.click)
                stackView.arrangedSubviews.forEach { view in
                    if let btn = view as? UIButton {
                        btn.isSelected = btn == button
                    }
                }
                self?.selectedSize = size
            }, for: .touchUpInside)
            
            if size == selectedSize {
                button.isSelected = true
            }
            
            stackView.addArrangedSubview(button)
        }
        
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: section.topAnchor),
            headerStack.leadingAnchor.constraint(equalTo: section.leadingAnchor),
            
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),
            
            scrollView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: section.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: section.trailingAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: 60),
            scrollView.bottomAnchor.constraint(equalTo: section.bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
        
        return section
    }
    
    private func createSizeButton(size: ImageSize) -> UIButton {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 2
        stackView.alignment = .center
        stackView.isUserInteractionEnabled = false
        
        let titleLabel = UILabel()
        titleLabel.text = size.displayName
        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.textAlignment = .center
        
        let dimensionsLabel = UILabel()
        dimensionsLabel.text = size.dimensions
        dimensionsLabel.font = .systemFont(ofSize: 11)
        dimensionsLabel.textAlignment = .center
        dimensionsLabel.alpha = 0.7
        
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(dimensionsLabel)
        
        button.addSubview(stackView)
        
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor.clear.cgColor
        button.backgroundColor = .secondarySystemFill
        
        button.configurationUpdateHandler = { button in
            UIView.animate(withDuration: 0.2) {
                if button.isSelected {
                    button.layer.borderColor = UIColor.systemBlue.cgColor
                    button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
                    titleLabel.textColor = .systemBlue
                    dimensionsLabel.textColor = .systemBlue
                } else {
                    button.layer.borderColor = UIColor.clear.cgColor
                    button.backgroundColor = .secondarySystemFill
                    titleLabel.textColor = .label
                    dimensionsLabel.textColor = .secondaryLabel
                }
            }
        }
        
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 90),
            button.heightAnchor.constraint(equalToConstant: 60),
            stackView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
        
        return button
    }
    
    private func createQualitySection() -> UIView {
        let section = UIView()
        
        let headerStack = UIStackView()
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerStack.axis = .horizontal
        headerStack.spacing = 6
        headerStack.alignment = .center
        section.addSubview(headerStack)
        
        let iconView = UIImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = UIImage(systemName: "sparkles")
        iconView.tintColor = .systemBlue
        iconView.contentMode = .scaleAspectFit
        
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Quality"
        label.font = .systemFont(ofSize: 16, weight: .medium)
        
        let creditsLabel = UILabel()
        creditsLabel.translatesAutoresizingMaskIntoConstraints = false
        creditsLabel.text = selectedQuality.creditRange
        creditsLabel.font = .systemFont(ofSize: 12)
        creditsLabel.textColor = .secondaryLabel
        creditsLabel.tag = 5001
        
        headerStack.addArrangedSubview(iconView)
        headerStack.addArrangedSubview(label)
        headerStack.addArrangedSubview(UIView())
        headerStack.addArrangedSubview(creditsLabel)
        
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        section.addSubview(scrollView)
        
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 8
        scrollView.addSubview(stackView)
        
        for (index, quality) in ImageQuality.allCases.enumerated() {
            let button = createQualityButton(quality: quality)
            button.tag = 5000 + index
            button.addAction(UIAction { [weak self] _ in
                HapticManager.shared.impact(.click)
                stackView.arrangedSubviews.forEach { view in
                    if let btn = view as? UIButton {
                        btn.isSelected = btn == button
                    }
                }
                self?.selectedQuality = quality
                creditsLabel.text = quality.creditRange
            }, for: .touchUpInside)
            
            if quality == selectedQuality {
                button.isSelected = true
            }
            
            stackView.addArrangedSubview(button)
        }
        
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: section.topAnchor),
            headerStack.leadingAnchor.constraint(equalTo: section.leadingAnchor),
            headerStack.trailingAnchor.constraint(equalTo: section.trailingAnchor),
            
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),
            
            scrollView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: section.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: section.trailingAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: 40),
            scrollView.bottomAnchor.constraint(equalTo: section.bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
        
        return section
    }
    
    private func createQualityButton(quality: ImageQuality) -> UIButton {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 6
        stackView.alignment = .center
        stackView.isUserInteractionEnabled = false
        
        let iconView = UIImageView()
        iconView.image = UIImage(systemName: quality == .high ? "sparkles.rectangle.stack" : "sparkles")
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .label
        
        let label = UILabel()
        label.text = quality.displayName
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .label
        
        stackView.addArrangedSubview(iconView)
        stackView.addArrangedSubview(label)
        
        button.addSubview(stackView)
        
        button.layer.cornerRadius = 12
        button.backgroundColor = .secondarySystemFill
        
        button.configurationUpdateHandler = { button in
            UIView.animate(withDuration: 0.2) {
                if button.isSelected {
                    button.backgroundColor = .systemBlue
                    iconView.tintColor = .white
                    label.textColor = .white
                } else {
                    button.backgroundColor = .secondarySystemFill
                    iconView.tintColor = .label
                    label.textColor = .label
                }
            }
        }
        
        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(equalToConstant: 40),
            stackView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -16),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18)
        ])
        
        return button
    }
    
    private func createAdvancedSection() -> UIView {
        let section = UIView()
        let toggleView = UIView()
        toggleView.translatesAutoresizingMaskIntoConstraints = false
        toggleView.backgroundColor = UIColor.secondarySystemFill.withAlphaComponent(0.5)
        toggleView.layer.cornerRadius = 16
        section.addSubview(toggleView)
        
        let toggleLabel = UILabel()
        toggleLabel.translatesAutoresizingMaskIntoConstraints = false
        toggleLabel.text = "Advanced Options"
        toggleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        toggleView.addSubview(toggleLabel)
        
        let toggleIcon = UIImageView()
        toggleIcon.translatesAutoresizingMaskIntoConstraints = false
        toggleIcon.image = UIImage(systemName: "chevron.down")
        toggleIcon.tintColor = .label
        toggleIcon.tag = 1001
        toggleView.addSubview(toggleIcon)
        
        let toggleTapGesture = UITapGestureRecognizer(target: self, action: #selector(toggleAdvancedOptions))
        toggleView.addGestureRecognizer(toggleTapGesture)
        let optionsContainer = UIView()
        optionsContainer.translatesAutoresizingMaskIntoConstraints = false
        optionsContainer.isHidden = true
        optionsContainer.alpha = 0
        optionsContainer.tag = 1002
        section.addSubview(optionsContainer)
        
        let optionsStack = UIStackView()
        optionsStack.translatesAutoresizingMaskIntoConstraints = false
        optionsStack.axis = .vertical
        optionsStack.spacing = 20
        optionsContainer.addSubview(optionsStack)
        
        let backgroundSection = createBackgroundSection()
        let formatSection = createFormatSection()
        let moderationSection = createModerationSection()
        
        optionsStack.addArrangedSubview(backgroundSection)
        optionsStack.addArrangedSubview(formatSection)
        optionsStack.addArrangedSubview(moderationSection)
        
        NSLayoutConstraint.activate([
            toggleView.topAnchor.constraint(equalTo: section.topAnchor),
            toggleView.leadingAnchor.constraint(equalTo: section.leadingAnchor),
            toggleView.trailingAnchor.constraint(equalTo: section.trailingAnchor),
            toggleView.heightAnchor.constraint(equalToConstant: 48),
            
            toggleLabel.leadingAnchor.constraint(equalTo: toggleView.leadingAnchor, constant: 16),
            toggleLabel.centerYAnchor.constraint(equalTo: toggleView.centerYAnchor),
            
            toggleIcon.trailingAnchor.constraint(equalTo: toggleView.trailingAnchor, constant: -16),
            toggleIcon.centerYAnchor.constraint(equalTo: toggleView.centerYAnchor),
            toggleIcon.widthAnchor.constraint(equalToConstant: 20),
            toggleIcon.heightAnchor.constraint(equalToConstant: 20),
            
            optionsContainer.topAnchor.constraint(equalTo: toggleView.bottomAnchor, constant: 12),
            optionsContainer.leadingAnchor.constraint(equalTo: section.leadingAnchor),
            optionsContainer.trailingAnchor.constraint(equalTo: section.trailingAnchor),
            optionsContainer.bottomAnchor.constraint(equalTo: section.bottomAnchor),
            
            optionsStack.topAnchor.constraint(equalTo: optionsContainer.topAnchor),
            optionsStack.leadingAnchor.constraint(equalTo: optionsContainer.leadingAnchor),
            optionsStack.trailingAnchor.constraint(equalTo: optionsContainer.trailingAnchor),
            optionsStack.bottomAnchor.constraint(equalTo: optionsContainer.bottomAnchor)
        ])
        
        return section
    }
    
    private func createBackgroundSection() -> UIView {
        let section = createMultipleChoiceSection(
            title: "Background",
            icon: "person.crop.circle",
            options: [("Default", nil)] + BackgroundStyle.allCases.map { ($0.displayName, $0) },
            onSelect: { [weak self] option in
                self?.selectedBackground = option as? BackgroundStyle
            }
        )
        return section
    }
    
    private func createFormatSection() -> UIView {
        let section = UIView()
        
        let formatSection = createMultipleChoiceSection(
            title: "Output format",
            icon: "photo",
            options: [("Default", nil)] + OutputFormat.allCases.map { ($0.displayName, $0) },
            onSelect: { [weak self] option in
                self?.selectedFormat = option as? OutputFormat
                self?.updateCompressionVisibility()
            }
        )
        section.addSubview(formatSection)
        let compressionContainer = UIView()
        compressionContainer.translatesAutoresizingMaskIntoConstraints = false
        compressionContainer.isHidden = true
        compressionContainer.alpha = 0
        compressionContainer.tag = 2001
        section.addSubview(compressionContainer)
        
        let compressionStack = UIStackView()
        compressionStack.translatesAutoresizingMaskIntoConstraints = false
        compressionStack.axis = .vertical
        compressionStack.spacing = 4
        compressionContainer.addSubview(compressionStack)
        
        let compressionHeader = UIView()
        let compressionLabel = UILabel()
        compressionLabel.translatesAutoresizingMaskIntoConstraints = false
        compressionLabel.text = "Compression"
        compressionLabel.font = .systemFont(ofSize: 14, weight: .medium)
        compressionHeader.addSubview(compressionLabel)
        
        let compressionValue = UILabel()
        compressionValue.translatesAutoresizingMaskIntoConstraints = false
        compressionValue.text = "\(compressionLevel)%"
        compressionValue.font = .systemFont(ofSize: 14, weight: .medium)
        compressionValue.textColor = .systemBlue
        compressionValue.tag = 2002
        compressionHeader.addSubview(compressionValue)
        
        let slider = UISlider()
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.minimumValue = 0
        slider.maximumValue = 100
        slider.value = Float(compressionLevel)
        slider.isContinuous = true
        slider.addTarget(self, action: #selector(compressionSliderChanged(_:)), for: .valueChanged)
        
        compressionStack.addArrangedSubview(compressionHeader)
        compressionStack.addArrangedSubview(slider)
        
        NSLayoutConstraint.activate([
            formatSection.topAnchor.constraint(equalTo: section.topAnchor),
            formatSection.leadingAnchor.constraint(equalTo: section.leadingAnchor),
            formatSection.trailingAnchor.constraint(equalTo: section.trailingAnchor),
            
            compressionContainer.topAnchor.constraint(equalTo: formatSection.bottomAnchor, constant: 8),
            compressionContainer.leadingAnchor.constraint(equalTo: section.leadingAnchor, constant: 16),
            compressionContainer.trailingAnchor.constraint(equalTo: section.trailingAnchor, constant: -16),
            compressionContainer.bottomAnchor.constraint(equalTo: section.bottomAnchor),
            
            compressionStack.topAnchor.constraint(equalTo: compressionContainer.topAnchor),
            compressionStack.leadingAnchor.constraint(equalTo: compressionContainer.leadingAnchor),
            compressionStack.trailingAnchor.constraint(equalTo: compressionContainer.trailingAnchor),
            compressionStack.bottomAnchor.constraint(equalTo: compressionContainer.bottomAnchor),
            
            compressionLabel.leadingAnchor.constraint(equalTo: compressionHeader.leadingAnchor),
            compressionLabel.centerYAnchor.constraint(equalTo: compressionHeader.centerYAnchor),
            
            compressionValue.trailingAnchor.constraint(equalTo: compressionHeader.trailingAnchor),
            compressionValue.centerYAnchor.constraint(equalTo: compressionHeader.centerYAnchor),
            
            compressionHeader.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        return section
    }
    
    private func createModerationSection() -> UIView {
        let section = createMultipleChoiceSection(
            title: "Moderation",
            icon: "lock",
            options: [("Default", nil)] + ModerationLevel.allCases.map { ($0.displayName, $0) },
            onSelect: { [weak self] option in
                self?.selectedModeration = option as? ModerationLevel
            }
        )
        return section
    }
    
    private func createMultipleChoiceSection(title: String, icon: String, options: [(String, Any?)], onSelect: @escaping (Any?) -> Void) -> UIView {
        let section = UIView()
        
        let headerStack = UIStackView()
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerStack.axis = .horizontal
        headerStack.spacing = 6
        headerStack.alignment = .center
        section.addSubview(headerStack)
        
        let iconView = UIImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = UIImage(systemName: icon)
        iconView.tintColor = .systemBlue
        iconView.contentMode = .scaleAspectFit
        
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = title
        label.font = .systemFont(ofSize: 16, weight: .medium)
        
        headerStack.addArrangedSubview(iconView)
        headerStack.addArrangedSubview(label)
        
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        section.addSubview(scrollView)
        
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center
        scrollView.addSubview(stackView)
        
        for (index, (optionTitle, optionValue)) in options.enumerated() {
            let button = createSelectionChip(title: optionTitle)
            button.tag = 3000 + section.tag + index
            button.addAction(UIAction { _ in
                HapticManager.shared.impact(.click)
                stackView.arrangedSubviews.forEach { view in
                    if let btn = view as? UIButton {
                        btn.isSelected = btn == button
                    }
                }
                onSelect(optionValue)
            }, for: .touchUpInside)
            
            if index == 0 {
                button.isSelected = true
            }
            
            stackView.addArrangedSubview(button)
        }
        
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: section.topAnchor),
            headerStack.leadingAnchor.constraint(equalTo: section.leadingAnchor),
            
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),
            
            scrollView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: section.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: section.trailingAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: 36),
            scrollView.bottomAnchor.constraint(equalTo: section.bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
        
        section.tag = Int.random(in: 100...999)
        return section
    }
    
    private func createSelectionChip(title: String) -> UIButton {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        button.layer.cornerRadius = 12
        
        button.setTitleColor(.label, for: .normal)
        button.setTitleColor(.white, for: .selected)
        button.backgroundColor = .secondarySystemFill
        
        button.configurationUpdateHandler = { button in
            UIView.animate(withDuration: 0.2) {
                button.backgroundColor = button.isSelected ? .systemBlue : .secondarySystemFill
            }
        }
        
        return button
    }
    
    @objc private func toggleAdvancedOptions() {
        HapticManager.shared.impact(.click)
        showAdvancedOptions.toggle()
        
        if let toggleIcon = viewWithTag(1001) as? UIImageView,
           let optionsContainer = viewWithTag(1002) {
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
                toggleIcon.transform = self.showAdvancedOptions ? CGAffineTransform(rotationAngle: .pi) : .identity
                optionsContainer.isHidden = !self.showAdvancedOptions
                optionsContainer.alpha = self.showAdvancedOptions ? 1 : 0
            }
        }
    }
    
    @objc private func compressionSliderChanged(_ slider: UISlider) {
        let roundedValue = Int(slider.value / 5) * 5
        compressionLevel = roundedValue
        slider.value = Float(roundedValue)
        
        if let label = viewWithTag(2002) as? UILabel {
            label.text = "\(roundedValue)%"
        }
        
        if roundedValue % 5 == 0 {
            HapticManager.shared.selectionChanged()
        }
    }
    
    private func updateCompressionVisibility() {
        if let compressionContainer = viewWithTag(2001) {
            let shouldShow = selectedFormat?.supportsCompression ?? false
            UIView.animate(withDuration: 0.3) {
                compressionContainer.isHidden = !shouldShow
                compressionContainer.alpha = shouldShow ? 1 : 0
            }
        }
    }
    
    private func createGenerateSection() -> UIView {
        let section = UIView()
        
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: "sparkles")
        config.imagePlacement = .leading
        config.imagePadding = 8
        config.cornerStyle = .large
        config.baseBackgroundColor = .systemBlue
        button.configuration = config
        button.configurationUpdateHandler = { [weak self] button in
            guard let self = self else { return }
            var config = button.configuration
            let credits = self.estimateCredits()
            config?.title = "Generate (\(credits.lowerBound)-\(credits.upperBound) credits)"
            button.configuration = config
        }
        button.addTarget(self, action: #selector(generateTapped), for: .touchUpInside)
        section.addSubview(button)
        
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: section.topAnchor),
            button.leadingAnchor.constraint(equalTo: section.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: section.trailingAnchor),
            button.heightAnchor.constraint(equalToConstant: 56),
            button.bottomAnchor.constraint(equalTo: section.bottomAnchor)
        ])
        
        return section
    }
    
    private func estimateCredits() -> ClosedRange<Int> {
        let baseCredits: ClosedRange<Int>
        switch selectedQuality {
        case .low:
            switch selectedSize {
            case .square: baseCredits = 4...4
            case .landscape, .portrait: baseCredits = 6...6
            case .auto: baseCredits = 4...6
            }
        case .medium:
            switch selectedSize {
            case .square: baseCredits = 16...16
            case .landscape, .portrait: baseCredits = 24...24
            case .auto: baseCredits = 16...24
            }
        case .high:
            switch selectedSize {
            case .square: baseCredits = 62...62
            case .landscape, .portrait: baseCredits = 94...94
            case .auto: baseCredits = 62...94
            }
        case .auto:
            baseCredits = 50...75
        }
        
        return baseCredits
    }
    
    private func createSection<T>(title: String, options: [(String, T)]) -> UIView {
        let section = UIView()
        
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = title
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .label
        section.addSubview(label)
        
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        section.addSubview(scrollView)
        
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 8
        scrollView.addSubview(stackView)
        
        for (optionTitle, _) in options {
            let button = createOptionButton(title: optionTitle)
            stackView.addArrangedSubview(button)
        }
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: section.topAnchor),
            label.leadingAnchor.constraint(equalTo: section.leadingAnchor),
            
            scrollView.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: section.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: section.trailingAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: 36),
            scrollView.bottomAnchor.constraint(equalTo: section.bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
        
        if let firstButton = stackView.arrangedSubviews.first as? UIButton {
            firstButton.isSelected = true
        }
        
        return section
    }
    
    private func createOptionButton(title: String) -> UIButton {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        
        var config = UIButton.Configuration.tinted()
        config.title = title
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        
        button.configuration = config
        button.configurationUpdateHandler = { button in
            var config = button.configuration
            config?.baseBackgroundColor = button.isSelected ? UIColor(red: 0.404, green: 0.314, blue: 0.643, alpha: 1.0) : .secondarySystemFill
            config?.baseForegroundColor = button.isSelected ? .white : .label
            button.configuration = config
        }
        
        button.addTarget(self, action: #selector(optionButtonTapped(_:)), for: .touchUpInside)
        
        return button
    }
    
    func setExpanded(_ expanded: Bool) {
        isExpanded = expanded
        collapsedContent.isHidden = expanded
        expandedContent.isHidden = !expanded
        expandButton.setImage(UIImage(systemName: expanded ? "chevron.down.circle.fill" : "chevron.up.circle.fill"), for: .normal)
    }
    
    func setPrompt(_ prompt: String) {
        promptTextField.text = prompt
    }
    
    @objc private func expandButtonTapped() {
        HapticManager.shared.impact(.click)
        onExpandedChange?(!isExpanded)
    }
    
    @objc private func generateTapped() {
        HapticManager.shared.impact(.click)
        
        let prompt = isExpanded ? 
            (expandedStackView.arrangedSubviews.first?.subviews.compactMap { $0 as? UITextView }.first?.text ?? "") :
            (promptTextField.text ?? "")
        
        guard !prompt.isEmpty else { return }
        
        var options = GenerationOptions.default
        options.prompt = prompt
        options.quantity = 1
        options.size = selectedSize.value
        options.sizeDisplay = selectedSize.displayName
        options.quality = selectedQuality.value
        
        onGenerate?(options)
    }
    
    @objc private func optionButtonTapped(_ sender: UIButton) {
        HapticManager.shared.impact(.click)
        
        if let stackView = sender.superview as? UIStackView {
            stackView.arrangedSubviews.forEach { view in
                if let button = view as? UIButton {
                    button.isSelected = button == sender
                }
            }
        }
    }
}

extension GenerationToolbar: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        generateTapped()
        return true
    }
}

extension GenerationToolbar: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        promptTextField.text = textView.text
    }
}

enum ImageSize: CaseIterable {
    case auto, square, landscape, portrait
    
    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .square: return "Square"
        case .landscape: return "Landscape"
        case .portrait: return "Portrait"
        }
    }
    
    var dimensions: String {
        switch self {
        case .auto: return "Optimal"
        case .square: return "1024×1024"
        case .landscape: return "1536×1024"
        case .portrait: return "1024×1536"
        }
    }
    
    var value: String {
        switch self {
        case .auto: return "auto"
        case .square: return "1024x1024"
        case .landscape: return "1536x1024"
        case .portrait: return "1024x1536"
        }
    }
}

enum ImageQuality: CaseIterable {
    case low, medium, high, auto
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .auto: return "Auto"
        }
    }
    
    var creditRange: String {
        switch self {
        case .low: return "4-6 credits"
        case .medium: return "16-24 credits"
        case .high: return "62-94 credits"
        case .auto: return "50-75 credits"
        }
    }
    
    var value: String {
        switch self {
        case .low: return "low"
        case .medium: return "medium"
        case .high: return "high"
        case .auto: return "auto"
        }
    }
}

enum BackgroundStyle: CaseIterable {
    case auto, transparent, white, black
    
    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .transparent: return "Transparent"
        case .white: return "White"
        case .black: return "Black"
        }
    }
    
    var value: String {
        switch self {
        case .auto: return "auto"
        case .transparent: return "transparent"
        case .white: return "white"
        case .black: return "black"
        }
    }
}

enum OutputFormat: CaseIterable {
    case png, jpeg, webp
    
    var displayName: String {
        switch self {
        case .png: return "PNG"
        case .jpeg: return "JPEG"
        case .webp: return "WebP"
        }
    }
    
    var value: String {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpeg"
        case .webp: return "webp"
        }
    }
    
    var supportsCompression: Bool {
        switch self {
        case .png: return false
        case .jpeg, .webp: return true
        }
    }
}

enum ModerationLevel: CaseIterable {
    case auto, low
    
    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .low: return "Low"
        }
    }
    
    var description: String {
        switch self {
        case .auto: return "Default moderation"
        case .low: return "Less restrictive"
        }
    }
    
    var value: String {
        switch self {
        case .auto: return "auto"
        case .low: return "low"
        }
    }
}