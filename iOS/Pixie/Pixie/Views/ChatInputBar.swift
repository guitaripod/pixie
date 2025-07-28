import UIKit

class ChatInputBar: UIView {
    
    // MARK: - Properties
    var selectedSuggestionsManager: SelectedSuggestionsManager?
    private var showAdvancedOptions = false
    
    private let containerView = UIView()
    private let collapsedView = UIView()
    private let expandedView = UIView()
    private let indicatorStackView = UIStackView()
    private let promptTextView = UITextView()
    private let sizeSelector = UISegmentedControl(items: ["Auto", "Square", "Landscape", "Portrait"])
    private let qualitySelector = UISegmentedControl(items: ["Low", "Medium", "High"])
    private let advancedOptionsButton = UIButton(type: .system)
    private let advancedOptionsContainer = UIView()
    private let backgroundSelector = UISegmentedControl(items: ["None", "Transparent", "White", "Black"])
    private let formatSelector = UISegmentedControl(items: ["PNG", "JPG", "WebP"])
    private let compressionSlider = UISlider()
    private let compressionLabel = UILabel()
    private let moderationSelector = UISegmentedControl(items: ["Safe", "Balanced", "Creative"])
    private let generateButton = UIButton(type: .system)
    private let creditsLabel = UILabel()
    
    private(set) var isExpanded = false
    private var heightConstraint: NSLayoutConstraint!
    private var creditsLabelTopToAdvancedConstraint: NSLayoutConstraint!
    private var creditsLabelTopToButtonConstraint: NSLayoutConstraint!
    
    var onSend: ((String) -> Void)?
    var onExpandedChanged: ((Bool) -> Void)?
    
    var currentPrompt: String? {
        let basePrompt = promptTextView.text
        return selectedSuggestionsManager?.composePrompt(basePrompt: basePrompt ?? "") ?? basePrompt
    }
    
    var selectedSize: ImageSize {
        let sizes: [ImageSize] = [.auto, .square, .landscape, .portrait]
        return sizes[sizeSelector.selectedSegmentIndex]
    }
    
    var selectedQuality: ImageQuality {
        let qualities: [ImageQuality] = [.low, .medium, .high]
        return qualities[qualitySelector.selectedSegmentIndex]
    }
    
    func collapse() {
        setExpanded(false, animated: true)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .systemBackground
        
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: -2)
        layer.shadowOpacity = 0.1
        layer.shadowRadius = 12
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 28
        containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        containerView.clipsToBounds = true
        addSubview(containerView)
        let dragHandleContainer = UIView()
        dragHandleContainer.translatesAutoresizingMaskIntoConstraints = false
        dragHandleContainer.backgroundColor = .clear
        containerView.addSubview(dragHandleContainer)
        
        let dragHandle = UIView()
        dragHandle.translatesAutoresizingMaskIntoConstraints = false
        dragHandle.backgroundColor = .tertiaryLabel
        dragHandle.layer.cornerRadius = 2
        dragHandleContainer.addSubview(dragHandle)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(toggleExpanded))
        dragHandleContainer.addGestureRecognizer(tapGesture)
        dragHandleContainer.isUserInteractionEnabled = true
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        containerView.addGestureRecognizer(panGesture)
        
        NSLayoutConstraint.activate([
            dragHandleContainer.topAnchor.constraint(equalTo: containerView.topAnchor),
            dragHandleContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            dragHandleContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            dragHandleContainer.heightAnchor.constraint(equalToConstant: 24),
            
            dragHandle.centerXAnchor.constraint(equalTo: dragHandleContainer.centerXAnchor),
            dragHandle.centerYAnchor.constraint(equalTo: dragHandleContainer.centerYAnchor),
            dragHandle.widthAnchor.constraint(equalToConstant: 40),
            dragHandle.heightAnchor.constraint(equalToConstant: 4)
        ])
        
        setupCollapsedView()
        setupExpandedView()
        
        expandedView.isHidden = true
        containerView.bringSubviewToFront(dragHandleContainer)
    }
    
    private func setupCollapsedView() {
        collapsedView.translatesAutoresizingMaskIntoConstraints = false
        collapsedView.backgroundColor = .clear
        containerView.addSubview(collapsedView)
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 8
        collapsedView.addSubview(stackView)
        
        let sparkleImageView = UIImageView(image: UIImage(systemName: "sparkles"))
        sparkleImageView.tintColor = .secondaryLabel
        sparkleImageView.contentMode = .scaleAspectFit
        sparkleImageView.translatesAutoresizingMaskIntoConstraints = false
        
        let promptLabel = UILabel()
        promptLabel.text = "What do you want to create?"
        promptLabel.font = .systemFont(ofSize: 16)
        promptLabel.textColor = .secondaryLabel
        promptLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let tapLabel = UILabel()
        tapLabel.text = "Tap to customize"
        tapLabel.font = .systemFont(ofSize: 13)
        tapLabel.textColor = .tertiaryLabel
        tapLabel.translatesAutoresizingMaskIntoConstraints = false
        indicatorStackView.translatesAutoresizingMaskIntoConstraints = false
        indicatorStackView.axis = .horizontal
        indicatorStackView.spacing = 4
        indicatorStackView.alignment = .center
        collapsedView.addSubview(indicatorStackView)
        
        stackView.addArrangedSubview(sparkleImageView)
        stackView.addArrangedSubview(promptLabel)
        
        collapsedView.addSubview(tapLabel)
        
        NSLayoutConstraint.activate([
            sparkleImageView.widthAnchor.constraint(equalToConstant: 20),
            sparkleImageView.heightAnchor.constraint(equalToConstant: 20)
        ])
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(toggleExpanded))
        collapsedView.addGestureRecognizer(tapGesture)
        collapsedView.isUserInteractionEnabled = true
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: collapsedView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: collapsedView.centerYAnchor, constant: -5),
            
            tapLabel.topAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 4),
            tapLabel.centerXAnchor.constraint(equalTo: collapsedView.centerXAnchor),
            
            indicatorStackView.trailingAnchor.constraint(equalTo: collapsedView.trailingAnchor, constant: -20),
            indicatorStackView.centerYAnchor.constraint(equalTo: collapsedView.centerYAnchor)
        ])
    }
    
    private func setupExpandedView() {
        expandedView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(expandedView)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        expandedView.addGestureRecognizer(tapGesture)
        
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        expandedView.addSubview(scrollView)
        
        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        let expandedDragHandleArea = UIView()
        expandedDragHandleArea.translatesAutoresizingMaskIntoConstraints = false
        expandedDragHandleArea.backgroundColor = .clear
        contentView.addSubview(expandedDragHandleArea)
        
        let expandedTapGesture = UITapGestureRecognizer(target: self, action: #selector(toggleExpanded))
        expandedDragHandleArea.addGestureRecognizer(expandedTapGesture)
        
        NSLayoutConstraint.activate([
            expandedDragHandleArea.topAnchor.constraint(equalTo: contentView.topAnchor),
            expandedDragHandleArea.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            expandedDragHandleArea.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            expandedDragHandleArea.heightAnchor.constraint(equalToConstant: 32)
        ])
        promptTextView.translatesAutoresizingMaskIntoConstraints = false
        promptTextView.font = .systemFont(ofSize: 16)
        promptTextView.layer.cornerRadius = 12
        promptTextView.layer.borderWidth = 1
        promptTextView.layer.borderColor = UIColor.separator.cgColor
        promptTextView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        promptTextView.isScrollEnabled = false
        promptTextView.delegate = self
        contentView.addSubview(promptTextView)
        let sizeLabel = createLabel("Size")
        contentView.addSubview(sizeLabel)
        sizeSelector.translatesAutoresizingMaskIntoConstraints = false
        sizeSelector.selectedSegmentIndex = 0
        contentView.addSubview(sizeSelector)
        let qualityLabel = createLabel("Quality")
        contentView.addSubview(qualityLabel)
        qualitySelector.translatesAutoresizingMaskIntoConstraints = false
        qualitySelector.selectedSegmentIndex = 1
        qualitySelector.addTarget(self, action: #selector(updateCredits), for: .valueChanged)
        contentView.addSubview(qualitySelector)
        advancedOptionsButton.translatesAutoresizingMaskIntoConstraints = false
        advancedOptionsButton.backgroundColor = .secondarySystemFill
        advancedOptionsButton.layer.cornerRadius = 12
        advancedOptionsButton.contentHorizontalAlignment = .left
        advancedOptionsButton.contentEdgeInsets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        advancedOptionsButton.addTarget(self, action: #selector(toggleAdvancedOptions), for: .touchUpInside)
        contentView.addSubview(advancedOptionsButton)
        
        let advancedButtonContent = UIStackView()
        advancedButtonContent.translatesAutoresizingMaskIntoConstraints = false
        advancedButtonContent.axis = .horizontal
        advancedButtonContent.alignment = .center
        advancedButtonContent.isUserInteractionEnabled = false
        
        let advancedLabel = UILabel()
        advancedLabel.text = "Advanced Options"
        advancedLabel.font = .systemFont(ofSize: 16, weight: .medium)
        
        let chevronImageView = UIImageView(image: UIImage(systemName: "chevron.down"))
        chevronImageView.tintColor = .secondaryLabel
        chevronImageView.tag = 100
        
        advancedButtonContent.addArrangedSubview(advancedLabel)
        advancedButtonContent.addArrangedSubview(UIView())
        advancedButtonContent.addArrangedSubview(chevronImageView)
        
        advancedOptionsButton.addSubview(advancedButtonContent)
        
        NSLayoutConstraint.activate([
            advancedButtonContent.topAnchor.constraint(equalTo: advancedOptionsButton.topAnchor, constant: 16),
            advancedButtonContent.leadingAnchor.constraint(equalTo: advancedOptionsButton.leadingAnchor, constant: 16),
            advancedButtonContent.trailingAnchor.constraint(equalTo: advancedOptionsButton.trailingAnchor, constant: -16),
            advancedButtonContent.bottomAnchor.constraint(equalTo: advancedOptionsButton.bottomAnchor, constant: -16)
        ])
        setupAdvancedOptions()
        contentView.addSubview(advancedOptionsContainer)
        creditsLabel.translatesAutoresizingMaskIntoConstraints = false
        creditsLabel.font = .systemFont(ofSize: 14, weight: .medium)
        creditsLabel.textColor = .secondaryLabel
        creditsLabel.textAlignment = .center
        contentView.addSubview(creditsLabel)
        generateButton.translatesAutoresizingMaskIntoConstraints = false
        var config = UIButton.Configuration.filled()
        config.title = "Generate"
        config.image = UIImage(systemName: "sparkles")
        config.imagePadding = 8
        config.cornerStyle = .medium
        generateButton.configuration = config
        generateButton.addTarget(self, action: #selector(generateTapped), for: .touchUpInside)
        contentView.addSubview(generateButton)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: expandedView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: expandedView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: expandedView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: expandedView.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            promptTextView.topAnchor.constraint(equalTo: expandedDragHandleArea.bottomAnchor, constant: 8),
            promptTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            promptTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            promptTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100),
            
            sizeLabel.topAnchor.constraint(equalTo: promptTextView.bottomAnchor, constant: 16),
            sizeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            
            sizeSelector.topAnchor.constraint(equalTo: sizeLabel.bottomAnchor, constant: 8),
            sizeSelector.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            sizeSelector.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            qualityLabel.topAnchor.constraint(equalTo: sizeSelector.bottomAnchor, constant: 16),
            qualityLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            
            qualitySelector.topAnchor.constraint(equalTo: qualityLabel.bottomAnchor, constant: 8),
            qualitySelector.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            qualitySelector.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            advancedOptionsButton.topAnchor.constraint(equalTo: qualitySelector.bottomAnchor, constant: 16),
            advancedOptionsButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            advancedOptionsButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            advancedOptionsContainer.topAnchor.constraint(equalTo: advancedOptionsButton.bottomAnchor, constant: 12),
            advancedOptionsContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            advancedOptionsContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            creditsLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            creditsLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            generateButton.topAnchor.constraint(equalTo: creditsLabel.bottomAnchor, constant: 12),
            generateButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            generateButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            generateButton.heightAnchor.constraint(equalToConstant: 56),
            generateButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
        
        updateCredits()
        creditsLabelTopToAdvancedConstraint = creditsLabel.topAnchor.constraint(equalTo: advancedOptionsContainer.bottomAnchor, constant: 12)
        creditsLabelTopToButtonConstraint = creditsLabel.topAnchor.constraint(equalTo: advancedOptionsButton.bottomAnchor, constant: 12)
        creditsLabelTopToButtonConstraint.isActive = true
        creditsLabelTopToAdvancedConstraint.isActive = false
    }
    
    private func createLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        return label
    }
    
    private func setupAdvancedOptions() {
        advancedOptionsContainer.translatesAutoresizingMaskIntoConstraints = false
        advancedOptionsContainer.isHidden = true
        advancedOptionsContainer.alpha = 0
        advancedOptionsContainer.clipsToBounds = true
        
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 16
        advancedOptionsContainer.addSubview(stackView)
        let backgroundLabel = createLabel("Background")
        stackView.addArrangedSubview(backgroundLabel)
        
        backgroundSelector.translatesAutoresizingMaskIntoConstraints = false
        backgroundSelector.selectedSegmentIndex = 0
        stackView.addArrangedSubview(backgroundSelector)
        let formatLabel = createLabel("Output Format")
        stackView.addArrangedSubview(formatLabel)
        
        formatSelector.translatesAutoresizingMaskIntoConstraints = false
        formatSelector.selectedSegmentIndex = 0
        formatSelector.addTarget(self, action: #selector(formatChanged), for: .valueChanged)
        stackView.addArrangedSubview(formatSelector)
        compressionLabel.text = "Compression: 80%"
        compressionLabel.font = .systemFont(ofSize: 14, weight: .medium)
        compressionLabel.textColor = .secondaryLabel
        compressionLabel.isHidden = true
        stackView.addArrangedSubview(compressionLabel)
        
        compressionSlider.translatesAutoresizingMaskIntoConstraints = false
        compressionSlider.minimumValue = 1
        compressionSlider.maximumValue = 100
        compressionSlider.value = 80
        compressionSlider.isHidden = true
        compressionSlider.addTarget(self, action: #selector(compressionChanged), for: .valueChanged)
        stackView.addArrangedSubview(compressionSlider)
        let moderationLabel = createLabel("Moderation")
        stackView.addArrangedSubview(moderationLabel)
        
        moderationSelector.translatesAutoresizingMaskIntoConstraints = false
        moderationSelector.selectedSegmentIndex = 1
        stackView.addArrangedSubview(moderationSelector)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: advancedOptionsContainer.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: advancedOptionsContainer.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: advancedOptionsContainer.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: advancedOptionsContainer.bottomAnchor)
        ])
    }
    
    private func setupConstraints() {
        heightConstraint = containerView.heightAnchor.constraint(equalToConstant: 80)
        heightConstraint.priority = UILayoutPriority(999)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightConstraint,
            collapsedView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            collapsedView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            collapsedView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            collapsedView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            expandedView.topAnchor.constraint(equalTo: containerView.topAnchor),
            expandedView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            expandedView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            expandedView.bottomAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        updateSendButton()
    }
    
    @objc private func toggleExpanded() {
        HapticManager.shared.impact(.click)
        setExpanded(!isExpanded, animated: true)
    }
    
    @objc private func dismissKeyboard() {
        promptTextView.resignFirstResponder()
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        let velocity = gesture.velocity(in: self)
        
        switch gesture.state {
        case .changed:
            let newHeight = heightConstraint.constant - translation.y
            let maxHeight = calculateExpandedHeight()
            heightConstraint.constant = max(80, min(maxHeight, newHeight))
            gesture.setTranslation(.zero, in: self)
            
        case .ended, .cancelled:
            let shouldExpand = velocity.y < -50 || heightConstraint.constant > 300
            setExpanded(shouldExpand, animated: true)
            
        default:
            break
        }
    }
    
    private func calculateExpandedHeight() -> CGFloat {
        guard let window = window else { return 460 }
        let safeAreaTop = window.safeAreaInsets.top
        let screenHeight = window.bounds.height
        let expandedHeight = screenHeight - safeAreaTop
        return expandedHeight
    }
    
    private func setExpanded(_ expanded: Bool, animated: Bool) {
        isExpanded = expanded
        
        if !expanded {
            updateSendButton()
        }
        
        let expandedHeight = calculateExpandedHeight()
        
        let animator = UIViewPropertyAnimator(duration: animated ? 0.4 : 0, dampingRatio: 0.8) {
            self.heightConstraint.constant = expanded ? expandedHeight : 80
            self.containerView.layer.cornerRadius = expanded ? 24 : 28
            self.layer.shadowRadius = expanded ? 24 : 12
            self.collapsedView.alpha = expanded ? 0 : 1
            self.expandedView.alpha = expanded ? 1 : 0
            self.expandedView.isHidden = !expanded
            self.superview?.layoutIfNeeded()
        }
        
        if !expanded {
            animator.addCompletion { _ in
                self.expandedView.isHidden = true
            }
        } else {
            expandedView.isHidden = false
        }
        
        animator.startAnimation()
        onExpandedChanged?(expanded)
    }
    
    
    @objc private func generateTapped() {
        guard let text = promptTextView.text, !text.isEmpty else { return }
        HapticManager.shared.impact(.click)
        
        onSend?(text)
        setExpanded(false, animated: true)
        clear()
    }
    
    @objc private func updateCredits() {
        let quality = ["low", "medium", "high"][qualitySelector.selectedSegmentIndex]
        let creditsPerImage: Int
        
        switch quality {
        case "low": creditsPerImage = 5
        case "medium": creditsPerImage = 15
        case "high": creditsPerImage = 50
        default: creditsPerImage = 15
        }
        
        creditsLabel.text = "Estimated cost: \(creditsPerImage) credits"
    }
    
    func setText(_ text: String) {
        promptTextView.text = text
        updateSendButton()
    }
    
    func clear() {
        promptTextView.text = ""
        updateSendButton()
    }
    
    
    private func updateSendButton() {
        let hasText = !(promptTextView.text?.isEmpty ?? true)
        generateButton.isEnabled = hasText
    }
    
    @objc private func toggleAdvancedOptions() {
        HapticManager.shared.impact(.click)
        showAdvancedOptions.toggle()
        
        let chevron = advancedOptionsButton.viewWithTag(100) as? UIImageView
        
        if showAdvancedOptions {
            advancedOptionsContainer.isHidden = false
            creditsLabelTopToButtonConstraint.isActive = false
            creditsLabelTopToAdvancedConstraint.isActive = true
        } else {
            creditsLabelTopToAdvancedConstraint.isActive = false
            creditsLabelTopToButtonConstraint.isActive = true
        }
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
            self.advancedOptionsContainer.alpha = self.showAdvancedOptions ? 1 : 0
            chevron?.transform = self.showAdvancedOptions ? CGAffineTransform(rotationAngle: .pi) : .identity
            self.layoutIfNeeded()
        } completion: { _ in
            if !self.showAdvancedOptions {
                self.advancedOptionsContainer.isHidden = true
            }
        }
    }
    
    @objc private func formatChanged() {
        let isPNG = formatSelector.selectedSegmentIndex == 0
        compressionLabel.isHidden = isPNG
        compressionSlider.isHidden = isPNG
        updateCredits()
    }
    
    @objc private func compressionChanged() {
        let value = Int(compressionSlider.value)
        compressionLabel.text = "Compression: \(value)%"
    }
    
    func updateIndicators() {
        indicatorStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        guard let manager = selectedSuggestionsManager else { return }
        
        let colors = manager.getIndicatorColors()
        for color in colors {
            let dot = UIView()
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.backgroundColor = color
            dot.layer.cornerRadius = 3
            indicatorStackView.addArrangedSubview(dot)
            
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 6),
                dot.heightAnchor.constraint(equalToConstant: 6)
            ])
        }
        
        indicatorStackView.isHidden = colors.isEmpty
    }
}

extension ChatInputBar: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        updateSendButton()
    }
}