import UIKit

class ChatInputBar: UIView {
    var selectedSuggestionsManager: SelectedSuggestionsManager?
    private var showAdvancedOptions = false
    private var isEditMode = false
    private var selectedImage: UIImage?
    private let containerView = UIView()
    private let collapsedView = UIView()
    private let expandedView = UIView()
    private let openPromptButton = UIButton(type: .custom)
    private let collapsedPromptLabel = UILabel()
    private let dragHandleContainer = ActivatableView()
    private var costRange: ClosedRange<Int> = 4...4
    private var availableBalance: Int?
    private(set) var costAnnouncement = ""
    private var pendingCostAnnouncement: DispatchWorkItem?
    private var costAnnouncementBaseline: String?
    
    private var contentPadding: CGFloat {
        return traitCollection.isRegularWidth ? 60 : 20
    }
    private var paddedConstraints: [(constraint: NSLayoutConstraint, sign: CGFloat)] = []

    private func padded(_ constraint: NSLayoutConstraint, sign: CGFloat) -> NSLayoutConstraint {
        paddedConstraints.append((constraint, sign))
        return constraint
    }

    private func updatePadding() {
        for entry in paddedConstraints {
            entry.constraint.constant = entry.sign * contentPadding
        }
    }
    private let indicatorStackView = UIStackView()
    private let promptTextView = UITextView()
    private static let selectableModels: [ImageModel] = [.gemini, .geminiPro, .openai]
    private let modelSelector = LabelledSegmentedControl(items: ChatInputBar.selectableModels.map(\.displayName))
    private let sizeSelector = LabelledSegmentedControl(items: [String(localized: "Auto"), String(localized: "Square"), String(localized: "Landscape"), String(localized: "Portrait")])
    private let qualitySelector = LabelledSegmentedControl(items: [String(localized: "Auto"), String(localized: "Low"), String(localized: "Medium"), String(localized: "High")])
    private let advancedOptionsButton = UIButton(type: .system)
    private let advancedOptionsContainer = UIView()
    private let backgroundSelector = LabelledSegmentedControl(items: [String(localized: "Auto"), String(localized: "Transparent"), String(localized: "Opaque"), String(localized: "None")])
    private let formatSelector = LabelledSegmentedControl(items: ["PNG", "JPG", "WebP"])
    private let compressionSlider = PercentSlider()
    private let compressionLabel = UILabel()
    private let moderationSelector = LabelledSegmentedControl(items: [String(localized: "Default"), String(localized: "Auto"), String(localized: "Low")])
    private let generateButton = UIButton(type: .system)
    private let creditsLabel = UILabel()
    private let expandedImageContainer = UIView()
    private let expandedSelectedImageView = UIImageView()
    private let selectedImageView = UIImageView()
    private lazy var clearImageButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "xmark.circle.fill")
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        config.baseForegroundColor = .secondaryLabel
        config.contentInsets = .zero
        let button = UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in
            HapticManager.shared.impact(.click)
            self?.onClearEditImage?()
        })
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityLabel = String(localized: "Remove photo")
        let disc = UIView()
        disc.translatesAutoresizingMaskIntoConstraints = false
        disc.isUserInteractionEnabled = false
        disc.backgroundColor = .systemBackground
        disc.layer.cornerRadius = 11
        button.insertSubview(disc, at: 0)
        NSLayoutConstraint.activate([
            disc.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            disc.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            disc.widthAnchor.constraint(equalToConstant: 22),
            disc.heightAnchor.constraint(equalToConstant: 22)
        ])
        return button
    }()
    private let editPromptLabel = UILabel()
    private let fidelitySelector = LabelledSegmentedControl(items: [String(localized: "Low"), String(localized: "High")])
    private(set) var isExpanded = false
    private var heightConstraint: NSLayoutConstraint!
    private var creditsLabelTopToAdvancedConstraint: NSLayoutConstraint!
    private var creditsLabelTopToButtonConstraint: NSLayoutConstraint!
    private var creditsLabelTopToModelConstraint: NSLayoutConstraint!
    private var openAIConstraints: [NSLayoutConstraint] = []
    private var promptTextViewTopToHandleConstraint: NSLayoutConstraint!
    private var promptTextViewTopToImageConstraint: NSLayoutConstraint!
    var onSend: ((String) -> Void)?
    var onClearEditImage: (() -> Void)?
    var onCostInputsChanged: (() -> Void)?
    var onExpandedChanged: ((Bool) -> Void)?
    var currentPrompt: String? {
        let basePrompt = promptTextView.text
        return selectedSuggestionsManager?.composePrompt(basePrompt: basePrompt ?? "") ?? basePrompt
    }
    var selectedModel: ImageModel {
        let models = ChatInputBar.selectableModels
        let index = modelSelector.selectedSegmentIndex
        guard index >= 0 && index < models.count else { return .gemini }
        return models[index]
    }
    var selectedSize: ImageSize {
        let sizes: [ImageSize] = [.auto, .square, .landscape, .portrait]
        let index = sizeSelector.selectedSegmentIndex
        guard index >= 0 && index < sizes.count else { return .auto }
        return sizes[index]
    }
    var selectedQuality: ImageQuality {
        let qualities: [ImageQuality] = [.auto, .low, .medium, .high]
        let index = qualitySelector.selectedSegmentIndex
        guard index >= 0 && index < qualities.count else { return .low }
        return qualities[index]
    }
    var selectedBackground: String? {
        let backgrounds = ["auto", "transparent", "opaque", nil]
        let index = backgroundSelector.selectedSegmentIndex
        guard index >= 0 && index < backgrounds.count else { return "auto" }
        return backgrounds[index]
    }
    var selectedFormat: String {
        let formats = ["png", "jpeg", "webp"]
        let index = formatSelector.selectedSegmentIndex
        guard index >= 0 && index < formats.count else { return "webp" }
        return formats[index]
    }
    var compressionLevel: Int {
        return Int(compressionSlider.value)
    }
    var selectedModeration: String? {
        let moderations = [nil, "auto", "low"]
        let index = moderationSelector.selectedSegmentIndex
        guard index >= 0 && index < moderations.count else { return "auto" }
        return moderations[index]
    }
    func collapse() {
        setExpanded(false, animated: true)
    }

    /// Credits the person can spend, so the cost line can say in words when the estimate is
    /// more than they have.
    func setAvailableBalance(_ balance: Int?) {
        availableBalance = balance
        refreshCostLabel()
    }
    func expand() {
        setExpanded(true, animated: false)
    }
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
        applyDefaults()
        updateCredits()
        setupAccessibility()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(configurationChanged),
            name: ConfigurationManager.configurationDidChangeNotification,
            object: nil
        )
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    private func setupUI() {
        backgroundColor = .systemBackground
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: -2)
        layer.shadowOpacity = 0.1
        layer.shadowRadius = 12
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = .systemBackground
        containerView.clipsToBounds = true
        addSubview(containerView)
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
        dragHandleContainer.onActivate = { [weak self] in self?.toggleExpanded() }
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
        let promptLabel = collapsedPromptLabel
        promptLabel.text = String(localized: "What do you want to create?")
        promptLabel.useScaledFont(.callout, size: 16)
        promptLabel.textColor = .secondaryLabel
        promptLabel.numberOfLines = 0
        promptLabel.textAlignment = .center
        promptLabel.translatesAutoresizingMaskIntoConstraints = false
        let tapLabel = UILabel()
        tapLabel.text = String(localized: "Tap to customize")
        tapLabel.useScaledFont(.footnote, size: 13)
        tapLabel.textColor = .secondaryLabel
        tapLabel.numberOfLines = 0
        tapLabel.textAlignment = .center
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
        openPromptButton.translatesAutoresizingMaskIntoConstraints = false
        openPromptButton.addAction(UIAction { [weak self] _ in self?.toggleExpanded() }, for: .touchUpInside)
        collapsedView.insertSubview(openPromptButton, at: 0)
        collapsedView.isUserInteractionEnabled = true
        [stackView, tapLabel, indicatorStackView].forEach { $0.accessibilityElementsHidden = true }
        NSLayoutConstraint.activate([
            openPromptButton.topAnchor.constraint(equalTo: collapsedView.topAnchor),
            openPromptButton.leadingAnchor.constraint(equalTo: collapsedView.leadingAnchor),
            openPromptButton.trailingAnchor.constraint(equalTo: collapsedView.trailingAnchor),
            openPromptButton.bottomAnchor.constraint(equalTo: collapsedView.bottomAnchor),
            stackView.centerXAnchor.constraint(equalTo: collapsedView.centerXAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: collapsedView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: collapsedView.trailingAnchor, constant: -16),
            stackView.centerYAnchor.constraint(equalTo: collapsedView.centerYAnchor, constant: -17),
            tapLabel.topAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 4),
            tapLabel.centerXAnchor.constraint(equalTo: collapsedView.centerXAnchor),
            tapLabel.leadingAnchor.constraint(greaterThanOrEqualTo: collapsedView.leadingAnchor, constant: 16),
            tapLabel.trailingAnchor.constraint(lessThanOrEqualTo: collapsedView.trailingAnchor, constant: -16),
            padded(indicatorStackView.trailingAnchor.constraint(equalTo: collapsedView.trailingAnchor, constant: -contentPadding), sign: -1),
            indicatorStackView.centerYAnchor.constraint(equalTo: collapsedView.centerYAnchor, constant: -12)
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
        expandedDragHandleArea.accessibilityElementsHidden = true
        NSLayoutConstraint.activate([
            expandedDragHandleArea.topAnchor.constraint(equalTo: contentView.topAnchor),
            expandedDragHandleArea.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            expandedDragHandleArea.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            expandedDragHandleArea.heightAnchor.constraint(equalToConstant: 36)
        ])
        expandedImageContainer.translatesAutoresizingMaskIntoConstraints = false
        expandedImageContainer.backgroundColor = .secondarySystemBackground
        expandedImageContainer.layer.cornerRadius = 12
        expandedImageContainer.clipsToBounds = true
        expandedImageContainer.isHidden = true
        contentView.addSubview(expandedImageContainer)
        expandedSelectedImageView.translatesAutoresizingMaskIntoConstraints = false
        expandedSelectedImageView.contentMode = .scaleAspectFit
        expandedSelectedImageView.backgroundColor = .clear
        expandedSelectedImageView.describe(String(localized: "Photo to edit"), traits: .image)
        expandedSelectedImageView.accessibilityIgnoresInvertColors = true
        expandedImageContainer.addSubview(expandedSelectedImageView)
        promptTextView.translatesAutoresizingMaskIntoConstraints = false
        promptTextView.font = .scaled(.body, size: 16)
        promptTextView.adjustsFontForContentSizeCategory = true
        promptTextView.accessibilityLabel = String(localized: "Prompt")
        promptTextView.layer.cornerRadius = 12
        promptTextView.layer.borderWidth = 1
        promptTextView.layer.borderColor = UIColor.separator.cgColor
        updateBorderColors()
        promptTextView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        promptTextView.isScrollEnabled = false
        promptTextView.delegate = self
        contentView.addSubview(promptTextView)
        let modelLabel = createLabel(String(localized: "AI Model"))
        modelLabel.tag = 900
        contentView.addSubview(modelLabel)
        modelSelector.translatesAutoresizingMaskIntoConstraints = false
        modelSelector.addTarget(self, action: #selector(modelChanged), for: .valueChanged)
        modelSelector.tag = 901
        contentView.addSubview(modelSelector)
        let sizeLabel = createLabel(String(localized: "Size"))
        sizeLabel.tag = 902
        contentView.addSubview(sizeLabel)
        sizeSelector.translatesAutoresizingMaskIntoConstraints = false
        sizeSelector.addTarget(self, action: #selector(costInputChangedByPerson), for: .valueChanged)
        sizeSelector.tag = 903
        contentView.addSubview(sizeSelector)
        let qualityLabel = createLabel(String(localized: "Quality"))
        qualityLabel.tag = 904
        contentView.addSubview(qualityLabel)
        qualitySelector.translatesAutoresizingMaskIntoConstraints = false
        qualitySelector.addTarget(self, action: #selector(costInputChangedByPerson), for: .valueChanged)
        qualitySelector.tag = 905
        contentView.addSubview(qualitySelector)
        advancedOptionsButton.translatesAutoresizingMaskIntoConstraints = false
        advancedOptionsButton.tag = 906
        advancedOptionsButton.backgroundColor = .secondarySystemFill
        advancedOptionsButton.layer.cornerRadius = 12
        advancedOptionsButton.contentHorizontalAlignment = .left
        var advancedConfig = UIButton.Configuration.plain()
        advancedConfig.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        advancedOptionsButton.configuration = advancedConfig
        advancedOptionsButton.addTarget(self, action: #selector(toggleAdvancedOptions), for: .touchUpInside)
        contentView.addSubview(advancedOptionsButton)
        let advancedButtonContent = UIStackView()
        advancedButtonContent.translatesAutoresizingMaskIntoConstraints = false
        advancedButtonContent.axis = .horizontal
        advancedButtonContent.alignment = .center
        advancedButtonContent.isUserInteractionEnabled = false
        let advancedLabel = UILabel()
        advancedLabel.text = String(localized: "Advanced Options")
        advancedLabel.useScaledFont(.callout, size: 16, weight: .medium)
        advancedLabel.numberOfLines = 0
        let chevronImageView = UIImageView(image: UIImage(systemName: "chevron.down"))
        chevronImageView.tintColor = .secondaryLabel
        chevronImageView.tag = 100
        chevronImageView.setContentHuggingPriority(.required, for: .horizontal)
        chevronImageView.setContentCompressionResistancePriority(.required, for: .horizontal)
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
        creditsLabel.useScaledFont(.subheadline, size: 14, weight: .medium)
        creditsLabel.textColor = .secondaryLabel
        creditsLabel.textAlignment = .center
        creditsLabel.numberOfLines = 0
        contentView.addSubview(creditsLabel)
        generateButton.translatesAutoresizingMaskIntoConstraints = false
        var config = UIButton.Configuration.filled()
        config.title = String(localized: "Generate")
        config.image = UIImage(systemName: "sparkles")
        config.imagePadding = 8
        config.cornerStyle = .medium
        config.titleLineBreakMode = .byWordWrapping
        generateButton.configuration = config
        generateButton.addTarget(self, action: #selector(generateTapped), for: .touchUpInside)
        contentView.addSubview(generateButton)
        promptTextViewTopToHandleConstraint = promptTextView.topAnchor.constraint(equalTo: expandedDragHandleArea.bottomAnchor, constant: 8)
        promptTextViewTopToImageConstraint = promptTextView.topAnchor.constraint(equalTo: expandedImageContainer.bottomAnchor, constant: 12)
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
            expandedImageContainer.topAnchor.constraint(equalTo: expandedDragHandleArea.bottomAnchor, constant: 8),
            padded(expandedImageContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: contentPadding), sign: 1),
            padded(expandedImageContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -contentPadding), sign: -1),
            expandedImageContainer.heightAnchor.constraint(equalToConstant: 180),
            expandedSelectedImageView.topAnchor.constraint(equalTo: expandedImageContainer.topAnchor, constant: 8),
            expandedSelectedImageView.leadingAnchor.constraint(equalTo: expandedImageContainer.leadingAnchor, constant: 8),
            expandedSelectedImageView.trailingAnchor.constraint(equalTo: expandedImageContainer.trailingAnchor, constant: -8),
            expandedSelectedImageView.bottomAnchor.constraint(equalTo: expandedImageContainer.bottomAnchor, constant: -8),
            padded(promptTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: contentPadding), sign: 1),
            padded(promptTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -contentPadding), sign: -1),
            promptTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100),
            modelLabel.topAnchor.constraint(equalTo: promptTextView.bottomAnchor, constant: 16),
            padded(modelLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: contentPadding), sign: 1),
            modelSelector.topAnchor.constraint(equalTo: modelLabel.bottomAnchor, constant: 8),
            padded(modelSelector.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: contentPadding), sign: 1),
            padded(modelSelector.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -contentPadding), sign: -1),
            sizeLabel.topAnchor.constraint(equalTo: modelSelector.bottomAnchor, constant: 16),
            padded(sizeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: contentPadding), sign: 1),
            sizeSelector.topAnchor.constraint(equalTo: sizeLabel.bottomAnchor, constant: 8),
            padded(sizeSelector.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: contentPadding), sign: 1),
            padded(sizeSelector.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -contentPadding), sign: -1),
            qualityLabel.topAnchor.constraint(equalTo: sizeSelector.bottomAnchor, constant: 16),
            padded(qualityLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: contentPadding), sign: 1),
            qualitySelector.topAnchor.constraint(equalTo: qualityLabel.bottomAnchor, constant: 8),
            padded(qualitySelector.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: contentPadding), sign: 1),
            padded(qualitySelector.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -contentPadding), sign: -1),
            advancedOptionsButton.topAnchor.constraint(equalTo: qualitySelector.bottomAnchor, constant: 16),
            padded(advancedOptionsButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: contentPadding), sign: 1),
            padded(advancedOptionsButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -contentPadding), sign: -1),
            advancedOptionsContainer.topAnchor.constraint(equalTo: advancedOptionsButton.bottomAnchor, constant: 12),
            padded(advancedOptionsContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: contentPadding), sign: 1),
            padded(advancedOptionsContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -contentPadding), sign: -1),
            padded(creditsLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: contentPadding), sign: 1),
            padded(creditsLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -contentPadding), sign: -1),
            generateButton.topAnchor.constraint(equalTo: creditsLabel.bottomAnchor, constant: 12),
            padded(generateButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: contentPadding), sign: 1),
            padded(generateButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -contentPadding), sign: -1),
            generateButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 56),
            generateButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -contentPadding)
        ])
        updateCredits()

        openAIConstraints = [
            modelLabel.topAnchor.constraint(equalTo: promptTextView.bottomAnchor, constant: 16),
            modelSelector.topAnchor.constraint(equalTo: modelLabel.bottomAnchor, constant: 8),
            sizeLabel.topAnchor.constraint(equalTo: modelSelector.bottomAnchor, constant: 16),
            sizeSelector.topAnchor.constraint(equalTo: sizeLabel.bottomAnchor, constant: 8),
            qualityLabel.topAnchor.constraint(equalTo: sizeSelector.bottomAnchor, constant: 16),
            qualitySelector.topAnchor.constraint(equalTo: qualityLabel.bottomAnchor, constant: 8),
            advancedOptionsButton.topAnchor.constraint(equalTo: qualitySelector.bottomAnchor, constant: 16)
        ]

        creditsLabelTopToAdvancedConstraint = creditsLabel.topAnchor.constraint(equalTo: advancedOptionsContainer.bottomAnchor, constant: 12)
        creditsLabelTopToButtonConstraint = creditsLabel.topAnchor.constraint(equalTo: advancedOptionsButton.bottomAnchor, constant: 12)
        creditsLabelTopToModelConstraint = creditsLabel.topAnchor.constraint(equalTo: modelSelector.bottomAnchor, constant: 16)

        creditsLabelTopToButtonConstraint.isActive = true
        creditsLabelTopToAdvancedConstraint.isActive = false
        creditsLabelTopToModelConstraint.isActive = false
        promptTextViewTopToHandleConstraint.isActive = true
        promptTextViewTopToImageConstraint.isActive = false
    }
    private func createLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.useScaledFont(.subheadline, size: 14, weight: .medium)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.accessibilityElementsHidden = true
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
        let backgroundLabel = createLabel(String(localized: "Background"))
        stackView.addArrangedSubview(backgroundLabel)
        backgroundSelector.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(backgroundSelector)
        let formatLabel = createLabel(String(localized: "Output Format"))
        stackView.addArrangedSubview(formatLabel)
        formatSelector.translatesAutoresizingMaskIntoConstraints = false
        formatSelector.addTarget(self, action: #selector(formatChanged), for: .valueChanged)
        stackView.addArrangedSubview(formatSelector)
        compressionLabel.text = String(localized: "Compression: \(ConfigurationManager.shared.defaultCompression)%")
        compressionLabel.useScaledFont(.subheadline, size: 14, weight: .medium)
        compressionLabel.textColor = .secondaryLabel
        compressionLabel.numberOfLines = 0
        compressionLabel.accessibilityElementsHidden = true
        compressionLabel.isHidden = true
        stackView.addArrangedSubview(compressionLabel)
        compressionSlider.translatesAutoresizingMaskIntoConstraints = false
        compressionSlider.minimumValue = 1
        compressionSlider.maximumValue = 100
        compressionSlider.accessibilityLabel = String(localized: "Compression")
        compressionSlider.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        compressionSlider.isHidden = true
        compressionSlider.addTarget(self, action: #selector(compressionChanged), for: .valueChanged)
        stackView.addArrangedSubview(compressionSlider)
        let moderationLabel = createLabel(String(localized: "Moderation"))
        stackView.addArrangedSubview(moderationLabel)
        moderationSelector.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(moderationSelector)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: advancedOptionsContainer.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: advancedOptionsContainer.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: advancedOptionsContainer.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: advancedOptionsContainer.bottomAnchor)
        ])
    }
    private func setupConstraints() {
        heightConstraint = containerView.heightAnchor.constraint(equalToConstant: collapsedHeight)
        heightConstraint.priority = UILayoutPriority(999)
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightConstraint,
            collapsedView.topAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.topAnchor, constant: 20),
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
            heightConstraint.constant = max(collapsedHeight, min(maxHeight, newHeight))
            gesture.setTranslation(.zero, in: self)
        case .ended, .cancelled:
            let shouldExpand = velocity.y < -50 || heightConstraint.constant > 300
            setExpanded(shouldExpand, animated: true)
        default:
            break
        }
    }
    private static let baseCollapsedHeight: CGFloat = 80
    private static let maximumCollapsedHeight: CGFloat = 220

    /// The resting height of the bar, grown with the text size so the prompt and its hint
    /// never clip.
    private var collapsedHeight: CGFloat {
        let scaled = UIFontMetrics(forTextStyle: .callout).scaledValue(for: Self.baseCollapsedHeight, compatibleWith: traitCollection)
        return min(scaled, Self.maximumCollapsedHeight)
    }

    private func calculateExpandedHeight() -> CGFloat {
        guard let window = window else { return 460 }
        let safeAreaTop = window.safeAreaInsets.top
        let screenHeight = window.bounds.height
        let expandedHeight = screenHeight - safeAreaTop
        guard let fold = FoldGeometry.activeFold(in: window), fold.orientation == .horizontal else { return expandedHeight }
        return min(expandedHeight, screenHeight - fold.frame.maxY)
    }

    /// Keeps an open panel inside the stable bottom region when the device is folded like a
    /// laptop, and lets it grow back when it is opened flat again.
    func refitExpandedHeight() {
        guard isExpanded else { return }
        let height = calculateExpandedHeight()
        guard abs(heightConstraint.constant - height) > 0.5 else { return }
        heightConstraint.constant = height
    }
    private func setExpanded(_ expanded: Bool, animated: Bool, movesFocus: Bool = true) {
        let changed = isExpanded != expanded
        isExpanded = expanded
        if !expanded {
            updateSendButton()
            promptTextView.resignFirstResponder()
        }
        let expandedHeight = calculateExpandedHeight()
        let restingHeight = collapsedHeight
        let animator = UIViewPropertyAnimator(duration: animated && !Motion.isReduced ? 0.4 : 0, dampingRatio: 0.8) {
            self.heightConstraint.constant = expanded ? expandedHeight : restingHeight
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
        refreshExpansionAccessibility()
        if changed && movesFocus { moveAccessibilityFocus(afterExpanding: expanded) }
        onExpandedChanged?(expanded)
    }
    @objc private func generateTapped() {
        guard let text = promptTextView.text, !text.isEmpty else { return }
        HapticManager.shared.impact(.click)
        if isEditMode {
            onSend?("EDIT_MODE")
        } else {
            onSend?(text)
        }
        setExpanded(false, animated: true, movesFocus: false)
        if !isEditMode {
            clear()
        }
    }
    @objc private func modelChanged() {
        HapticManager.shared.impact(.click)
        let previousCost = costAnnouncement
        updateUIForModel()
        updateCredits()
        scheduleCostAnnouncement(previous: previousCost)
    }

    @objc private func costInputChangedByPerson() {
        let previousCost = costAnnouncement
        updateCredits()
        scheduleCostAnnouncement(previous: previousCost)
    }

    /// Speaks the new cost once the person stops changing options, and only when the figure
    /// actually differs from what they last heard.
    private func scheduleCostAnnouncement(previous: String) {
        if costAnnouncementBaseline == nil { costAnnouncementBaseline = previous }
        pendingCostAnnouncement?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let baseline = self.costAnnouncementBaseline
            self.costAnnouncementBaseline = nil
            guard self.costAnnouncement != baseline else { return }
            Announce.say(self.costAnnouncement)
        }
        pendingCostAnnouncement = item
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.costAnnouncementDelay, execute: item)
    }

    private static let costAnnouncementDelay: TimeInterval = 0.9

    private func updateUIForModel() {
        let isOpenAI = selectedModel == .openai

        if isOpenAI {
            creditsLabelTopToModelConstraint.isActive = false
            creditsLabelTopToButtonConstraint.isActive = !showAdvancedOptions
            creditsLabelTopToAdvancedConstraint.isActive = showAdvancedOptions
        } else {
            creditsLabelTopToButtonConstraint.isActive = false
            creditsLabelTopToAdvancedConstraint.isActive = false
            creditsLabelTopToModelConstraint.isActive = true
        }

        Motion.animate(0.3) { [weak self] in
            guard let self = self else { return }
            self.expandedView.viewWithTag(902)?.isHidden = !isOpenAI
            self.expandedView.viewWithTag(902)?.alpha = isOpenAI ? 1.0 : 0.0
            self.expandedView.viewWithTag(903)?.isHidden = !isOpenAI
            self.expandedView.viewWithTag(903)?.alpha = isOpenAI ? 1.0 : 0.0
            self.expandedView.viewWithTag(904)?.isHidden = !isOpenAI
            self.expandedView.viewWithTag(904)?.alpha = isOpenAI ? 1.0 : 0.0
            self.expandedView.viewWithTag(905)?.isHidden = !isOpenAI
            self.expandedView.viewWithTag(905)?.alpha = isOpenAI ? 1.0 : 0.0
            self.expandedView.viewWithTag(906)?.isHidden = !isOpenAI
            self.expandedView.viewWithTag(906)?.alpha = isOpenAI ? 1.0 : 0.0
            self.expandedView.layoutIfNeeded()
        }
    }

    @objc private func updateCredits() {
        defer { onCostInputsChanged?() }
        costRange = estimatedCostRange()
        refreshCostLabel()
    }

    private func estimatedCostRange() -> ClosedRange<Int> {
        if let fixedCost = selectedModel.fixedCost {
            return fixedCost...fixedCost
        }
        let quality = selectedQuality.value
        let size = selectedSize.value
        switch quality {
        case "low":
            switch size {
            case "1024x1024": return 4...4
            case "1536x1024", "1024x1536": return 6...6
            default: return 4...6
            }
        case "medium":
            switch size {
            case "1024x1024": return 16...16
            case "1536x1024", "1024x1536": return 24...24
            default: return 16...24
            }
        case "high":
            switch size {
            case "1024x1024": return 62...62
            case "1536x1024", "1024x1536": return 94...94
            default: return 62...94
            }
        case "auto":
            return 50...75
        default:
            return 4...6
        }
    }

    private var costSummary: String {
        if costRange.lowerBound == costRange.upperBound {
            return String(localized: "\(costRange.lowerBound) credits")
        }
        return String(localized: "\(costRange.lowerBound)-\(costRange.upperBound) credits")
    }

    private var exceedsBalance: Bool {
        guard let availableBalance else { return false }
        return availableBalance < costRange.lowerBound
    }

    /// Shows the estimate, and when it is more than the balance covers adds the words "Not enough
    /// credits" with a warning symbol so the state never rests on colour alone.
    private func refreshCostLabel() {
        let summary = costSummary
        let font = creditsLabel.font ?? UIFont.preferredFont(forTextStyle: .subheadline)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let text = NSMutableAttributedString(string: summary, attributes: [.font: font, .foregroundColor: UIColor.secondaryLabel, .paragraphStyle: paragraph])
        var announcement = summary
        if exceedsBalance {
            let warning = String(localized: "Not enough credits")
            let attachment = NSTextAttachment()
            attachment.image = UIImage(systemName: "exclamationmark.circle.fill")?.withTintColor(.systemOrange, renderingMode: .alwaysOriginal)
            text.append(NSAttributedString(string: "\n", attributes: [.font: font, .paragraphStyle: paragraph]))
            text.append(NSAttributedString(attachment: attachment))
            text.append(NSAttributedString(string: " \(warning)", attributes: [.font: font, .foregroundColor: UIColor.label, .paragraphStyle: paragraph]))
            announcement = "\(summary), \(warning)"
        }
        creditsLabel.attributedText = text
        creditsLabel.accessibilityLabel = announcement
        costAnnouncement = announcement
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
        generateButton.accessibilityHint = hasText ? nil : String(localized: "Enter a prompt first")
        refreshCollapsedAccessibility()
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
        refreshAdvancedToggleAccessibility()
        Motion.animate(0.3, options: .curveEaseInOut, animations: {
            self.advancedOptionsContainer.alpha = self.showAdvancedOptions ? 1 : 0
            chevron?.transform = self.showAdvancedOptions ? CGAffineTransform(rotationAngle: .pi) : .identity
            self.layoutIfNeeded()
        }, completion: { _ in
            if !self.showAdvancedOptions {
                self.advancedOptionsContainer.isHidden = true
            }
        })
        Announce.layoutChanged(advancedOptionsButton)
    }
    @objc private func formatChanged() {
        let isPNG = formatSelector.selectedSegmentIndex == 0
        compressionLabel.isHidden = isPNG
        compressionSlider.isHidden = isPNG
        updateCredits()
    }
    @objc private func compressionChanged() {
        let value = Int(compressionSlider.value)
        compressionLabel.text = String(localized: "Compression: \(value)%")
    }
    func updateIndicators() {
        indicatorStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        defer { refreshCollapsedAccessibility() }
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
    func setEditMode(_ editMode: Bool, selectedImage: UIImage?) {
        isEditMode = editMode
        self.selectedImage = selectedImage
        if editMode {
            if let stackView = collapsedView.subviews.first(where: { $0 is UIStackView }) as? UIStackView {
                if let imageView = stackView.arrangedSubviews.first as? UIImageView {
                    imageView.image = UIImage(systemName: "wand.and.stars")
                }
                if stackView.arrangedSubviews.count > 1,
                   let label = stackView.arrangedSubviews[1] as? UILabel {
                    label.text = String(localized: "Describe your edits...")
                }
            }
            generateButton.setTitle(String(localized: "Edit Image"), for: .normal)
            if !advancedOptionsContainer.subviews.contains(fidelitySelector) {
                addFidelitySection()
            }
            setupEditModeCollapsedView()
            if let image = selectedImage {
                expandedSelectedImageView.image = image
                expandedImageContainer.isHidden = false
                promptTextViewTopToHandleConstraint.isActive = false
                promptTextViewTopToImageConstraint.isActive = true
            }
        } else {
            if let stackView = collapsedView.subviews.first(where: { $0 is UIStackView }) as? UIStackView {
                if let imageView = stackView.arrangedSubviews.first as? UIImageView {
                    imageView.image = UIImage(systemName: "sparkles")
                }
                if stackView.arrangedSubviews.count > 1,
                   let label = stackView.arrangedSubviews[1] as? UILabel {
                    label.text = String(localized: "What do you want to create?")
                }
            }
            generateButton.setTitle(String(localized: "Generate"), for: .normal)
            selectedImageView.removeFromSuperview()
            clearImageButton.removeFromSuperview()
            expandedImageContainer.isHidden = true
            expandedSelectedImageView.image = nil
            promptTextViewTopToImageConstraint.isActive = false
            promptTextViewTopToHandleConstraint.isActive = true
        }
        refreshCollapsedAccessibility()
        updateCredits()
    }
    private func setupEditModeCollapsedView() {
        guard let image = selectedImage else { return }
        selectedImageView.image = image
        guard selectedImageView.superview == nil else { return }
        selectedImageView.translatesAutoresizingMaskIntoConstraints = false
        selectedImageView.contentMode = .scaleAspectFill
        selectedImageView.clipsToBounds = true
        selectedImageView.layer.cornerRadius = 8
        collapsedView.addSubview(selectedImageView)
        collapsedView.addSubview(clearImageButton)
        NSLayoutConstraint.activate([
            selectedImageView.leadingAnchor.constraint(equalTo: collapsedView.leadingAnchor, constant: 16),
            selectedImageView.centerYAnchor.constraint(equalTo: collapsedView.centerYAnchor),
            selectedImageView.widthAnchor.constraint(equalToConstant: 56),
            selectedImageView.heightAnchor.constraint(equalToConstant: 56),
            clearImageButton.centerXAnchor.constraint(equalTo: selectedImageView.trailingAnchor, constant: -2),
            clearImageButton.centerYAnchor.constraint(equalTo: selectedImageView.topAnchor, constant: 2),
            clearImageButton.widthAnchor.constraint(equalToConstant: 44),
            clearImageButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    private func addFidelitySection() {
        let fidelityLabel = createLabel(String(localized: "Fidelity"))
        advancedOptionsContainer.addSubview(fidelityLabel)
        fidelitySelector.translatesAutoresizingMaskIntoConstraints = false
        fidelitySelector.selectedSegmentIndex = 0
        advancedOptionsContainer.addSubview(fidelitySelector)
        NSLayoutConstraint.activate([
            fidelityLabel.topAnchor.constraint(equalTo: moderationSelector.bottomAnchor, constant: 16),
            fidelityLabel.leadingAnchor.constraint(equalTo: advancedOptionsContainer.leadingAnchor),
            fidelitySelector.topAnchor.constraint(equalTo: fidelityLabel.bottomAnchor, constant: 8),
            fidelitySelector.leadingAnchor.constraint(equalTo: advancedOptionsContainer.leadingAnchor),
            fidelitySelector.trailingAnchor.constraint(equalTo: advancedOptionsContainer.trailingAnchor)
        ])
    }
    func getEditOptions() -> EditOptions {
        let size = [ImageSize.auto, .square, .landscape, .portrait][sizeSelector.selectedSegmentIndex]
        let quality = [ImageQuality.auto, .low, .medium, .high][qualitySelector.selectedSegmentIndex]
        let fidelity = [FidelityLevel.low, .high][fidelitySelector.selectedSegmentIndex]
        return EditOptions(
            prompt: promptTextView.text ?? "",
            model: selectedModel.value,
            variations: 1,
            size: size,
            quality: quality,
            fidelity: fidelity,
            background: selectedBackground,
            outputFormat: selectedFormat,
            compression: selectedFormat != "png" ? compressionLevel : nil
        )
    }
    
    func applyDefaults() {
        let config = ConfigurationManager.shared

        let defaultModel = ImageModel(rawValue: config.defaultModel) ?? .gemini
        modelSelector.selectedSegmentIndex = ChatInputBar.selectableModels.firstIndex(of: defaultModel) ?? 0

        updateUIForModel()

        switch config.defaultSize {
        case "auto": sizeSelector.selectedSegmentIndex = 0
        case "1024x1024": sizeSelector.selectedSegmentIndex = 1
        case "1792x1024": sizeSelector.selectedSegmentIndex = 2
        case "1024x1792": sizeSelector.selectedSegmentIndex = 3
        default: sizeSelector.selectedSegmentIndex = 0
        }
        
        switch config.defaultQuality {
        case "auto": qualitySelector.selectedSegmentIndex = 0
        case "low": qualitySelector.selectedSegmentIndex = 1
        case "medium": qualitySelector.selectedSegmentIndex = 2
        case "high": qualitySelector.selectedSegmentIndex = 3
        default: qualitySelector.selectedSegmentIndex = 1
        }
        
        switch config.defaultOutputFormat {
        case "png": formatSelector.selectedSegmentIndex = 0
        case "jpeg": formatSelector.selectedSegmentIndex = 1
        case "webp": formatSelector.selectedSegmentIndex = 2
        default: formatSelector.selectedSegmentIndex = 0
        }
        
        compressionSlider.value = Float(config.defaultCompression)
        compressionChanged()
        
        switch config.defaultBackground {
        case "auto": backgroundSelector.selectedSegmentIndex = 0
        case "transparent": backgroundSelector.selectedSegmentIndex = 1
        case "opaque": backgroundSelector.selectedSegmentIndex = 2
        case "none": backgroundSelector.selectedSegmentIndex = 3
        default: backgroundSelector.selectedSegmentIndex = 0
        }
        
        switch config.defaultModeration {
        case "default": moderationSelector.selectedSegmentIndex = 0
        case "auto": moderationSelector.selectedSegmentIndex = 1
        case "low": moderationSelector.selectedSegmentIndex = 2
        default: moderationSelector.selectedSegmentIndex = 1
        }
        
        updateCredits()
    }
    
    @objc private func configurationChanged() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.promptTextView.text.isEmpty {
                self.applyDefaults()
            }
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateBorderColors()
        if traitCollection.horizontalSizeClass != previousTraitCollection?.horizontalSizeClass {
            updatePadding()
        }
        if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
            refreshCostLabel()
            if !isExpanded { heightConstraint.constant = collapsedHeight }
        }
    }

    override func accessibilityPerformEscape() -> Bool {
        guard isExpanded else { return false }
        collapse()
        return true
    }

    private func setupAccessibility() {
        openPromptButton.accessibilityTraits = .button
        dragHandleContainer.accessibilityLabel = String(localized: "Prompt and options")
        dragHandleContainer.accessibilityTraits = .button
        advancedOptionsButton.accessibilityLabel = String(localized: "Advanced Options")
        advancedOptionsButton.accessibilityTraits = .button
        nameControl(modelSelector, String(localized: "AI Model"))
        nameControl(sizeSelector, String(localized: "Size"))
        nameControl(qualitySelector, String(localized: "Quality"))
        nameControl(backgroundSelector, String(localized: "Background"))
        nameControl(formatSelector, String(localized: "Output Format"))
        nameControl(moderationSelector, String(localized: "Moderation"))
        nameControl(fidelitySelector, String(localized: "Fidelity"))
        refreshExpansionAccessibility()
        refreshAdvancedToggleAccessibility()
        refreshCollapsedAccessibility()
    }

    private func nameControl(_ control: UIView, _ text: String) {
        control.accessibilityLabel = text
    }

    private var expansionStateText: String {
        isExpanded ? String(localized: "Expanded") : String(localized: "Collapsed")
    }

    private func refreshExpansionAccessibility() {
        collapsedView.accessibilityElementsHidden = isExpanded
        dragHandleContainer.isAccessibilityElement = isExpanded
        dragHandleContainer.accessibilityValue = expansionStateText
        accessibilityViewIsModal = isExpanded
        refreshCollapsedAccessibility()
    }

    private func refreshAdvancedToggleAccessibility() {
        advancedOptionsButton.accessibilityValue = showAdvancedOptions ? String(localized: "Expanded") : String(localized: "Collapsed")
    }

    /// The collapsed bar reads as one button: its prompt, its state, what has been typed and
    /// which ideas are picked, since the coloured dots alone say nothing to VoiceOver.
    private func refreshCollapsedAccessibility() {
        openPromptButton.accessibilityLabel = collapsedPromptLabel.text
        openPromptButton.accessibilityHint = String(localized: "Tap to customize")
        var parts = [expansionStateText]
        if let typed = promptTextView.text, !typed.isEmpty { parts.append(typed) }
        parts.append(contentsOf: selectedIdeaTitles)
        openPromptButton.accessibilityValue = parts.joined(separator: ", ")
    }

    private var selectedIdeaTitles: [String] {
        guard let selections = selectedSuggestionsManager?.selections else { return [] }
        let order: [SuggestionType] = [.quickAction, .creativePrompt, .stylePreset, .promptModifier]
        return order.compactMap { selections[$0]?.title }
    }

    /// Moves VoiceOver to the prompt when the panel opens and back to the bar when it closes.
    private func moveAccessibilityFocus(afterExpanding expanded: Bool) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            Announce.layoutChanged(expanded ? self.promptTextView : self.openPromptButton)
        }
    }
    private func updateBorderColors() {
        promptTextView.layer.borderColor = UIColor.separator.cgColor
        expandedImageContainer.layer.borderColor = UIColor.separator.cgColor
        expandedImageContainer.layer.borderWidth = 0.5
    }
    
    func getCurrentText() -> String? {
        return promptTextView.text
    }
    
    @discardableResult
    override func becomeFirstResponder() -> Bool {
        return promptTextView.becomeFirstResponder()
    }
    
    @discardableResult
    override func resignFirstResponder() -> Bool {
        return promptTextView.resignFirstResponder()
    }
}

extension ChatInputBar: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        updateSendButton()
    }
}

final class LabelledSegmentedControl: UISegmentedControl {
    override func didMoveToWindow() {
        super.didMoveToWindow()
        accessibilityContainerType = .semanticGroup
    }
}

final class PercentSlider: UISlider {
    private static let step: Float = 5

    override var accessibilityValue: String? {
        get { String(localized: "\(Int(value)) percent") }
        set {}
    }

    override func accessibilityIncrement() {
        move(to: (floor(value / Self.step) + 1) * Self.step)
    }

    override func accessibilityDecrement() {
        move(to: (ceil(value / Self.step) - 1) * Self.step)
    }

    private func move(to target: Float) {
        value = min(max(target, minimumValue), maximumValue)
        sendActions(for: .valueChanged)
    }
}

final class ActivatableView: UIView {
    var onActivate: (() -> Void)?

    override func accessibilityActivate() -> Bool {
        guard let onActivate else { return false }
        onActivate()
        return true
    }
}
