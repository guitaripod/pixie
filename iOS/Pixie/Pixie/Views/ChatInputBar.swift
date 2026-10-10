import UIKit

class ChatInputBar: UIView {
    var selectedSuggestionsManager: SelectedSuggestionsManager?
    var onSend: ((String) -> Void)?
    var onClearEditImage: (() -> Void)?
    var onCostInputsChanged: (() -> Void)?
    var onExpandedChanged: ((Bool) -> Void)?
    var onAddPhoto: (() -> Void)?
    var onStop: (() -> Void)?
    var onGetCredits: (() -> Void)?
    var onLayoutChanged: (() -> Void)?

    let composerGuide = UILayoutGuide()
    private(set) var isExpanded = false
    private(set) var costAnnouncement = ""
    private(set) var isGenerating = false

    private var isEditMode = false
    private var selectedImage: UIImage?
    private var costRange: ClosedRange<Int> = 4...4
    private var availableBalance: Int?
    private var pendingCostAnnouncement: DispatchWorkItem?
    private var costAnnouncementBaseline: String?
    private var lastGuideFrame = CGRect.zero

    private let column = UIStackView()
    private let panel = ComposerOptionsPanel()
    private let capsule = GlassSurface(tintAlpha: 0.62, maximumCornerRadius: ChatInputBar.capsuleCornerRadius)
    private let photoSlot = ComposerPhotoSlot()
    private let promptTextView = PromptTextView()
    private let placeholderLabel = UILabel()
    private let optionsButton = ComposerOptionsButton()
    private let sendButton = ComposerSendButton()
    private let footnoteRow = UIStackView()
    private let costLabel = UILabel()
    private let getCreditsButton = FootnoteLinkButton(title: String(localized: "Get credits"))
    private let indicatorStackView = UIStackView()
    private var textHeightConstraint: NSLayoutConstraint!

    private static let capsuleCornerRadius: CGFloat = 28
    private static let grownCornerRadius: CGFloat = 24
    private static let maximumPromptLines: CGFloat = 4
    private static let minimumTextHeight: CGFloat = 44
    private static let textInsets = UIEdgeInsets(top: 12, left: 4, bottom: 12, right: 4)
    private static let sideMargin: CGFloat = 12
    private static let costAnnouncementDelay: TimeInterval = 0.9
    private static let panelHeightShare: CGFloat = 0.6
    private static let topBarClearance: CGFloat = 76
    private static let maximumPromptPointSize: CGFloat = 30

    private static var promptFont: UIFont {
        UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: 17), maximumPointSize: maximumPromptPointSize)
    }

    var currentPrompt: String? {
        let basePrompt = promptTextView.text
        return selectedSuggestionsManager?.composePrompt(basePrompt: basePrompt ?? "") ?? basePrompt
    }

    var selectedModel: ImageModel {
        let models = ComposerOptionsPanel.models
        let index = panel.modelIndex
        guard index >= 0 && index < models.count else { return .gemini }
        return models[index]
    }

    var selectedSize: ImageSize {
        let sizes: [ImageSize] = [.auto, .square, .landscape, .portrait]
        let index = panel.sizeIndex
        guard index >= 0 && index < sizes.count else { return .auto }
        return sizes[index]
    }

    var selectedQuality: ImageQuality {
        let qualities: [ImageQuality] = [.auto, .low, .medium, .high]
        let index = panel.qualityIndex
        guard index >= 0 && index < qualities.count else { return .low }
        return qualities[index]
    }

    var selectedBackground: String? {
        let backgrounds = ["auto", "transparent", "opaque", nil]
        let index = panel.backgroundIndex
        guard index >= 0 && index < backgrounds.count else { return "auto" }
        return backgrounds[index]
    }

    var selectedFormat: String {
        let formats = ["png", "jpeg", "webp"]
        let index = panel.formatIndex
        guard index >= 0 && index < formats.count else { return "webp" }
        return formats[index]
    }

    var compressionLevel: Int {
        Int(panel.compression)
    }

    var selectedModeration: String? {
        let moderations = [nil, "auto", "low"]
        let index = panel.moderationIndex
        guard index >= 0 && index < moderations.count else { return "auto" }
        return moderations[index]
    }

    func collapse() {
        setExpanded(false, animated: true)
    }

    func expand() {
        setExpanded(true, animated: false)
    }

    /// Credits the person can spend, so the cost line can say in words when the estimate is
    /// more than they have.
    func setAvailableBalance(_ balance: Int?) {
        availableBalance = balance
        refreshCostLabel()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildLayout()
        wirePanel()
        wireControls()
        applyDefaults()
        updateCredits()
        setupAccessibility()
        updateSendButton()
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

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self || hit === column ? nil : hit
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateTextHeight(animated: false)
        refitExpandedHeight()
        let guideFrame = composerGuide.layoutFrame
        guard guideFrame != lastGuideFrame else { return }
        lastGuideFrame = guideFrame
        onLayoutChanged?()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
            refreshCostLabel()
            updateTextHeight(animated: false)
        }
        if traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle {
            refreshCostLabel()
        }
    }

    override func accessibilityPerformEscape() -> Bool {
        guard isExpanded else { return false }
        collapse()
        return true
    }

    @discardableResult
    override func becomeFirstResponder() -> Bool {
        promptTextView.becomeFirstResponder()
    }

    @discardableResult
    override func resignFirstResponder() -> Bool {
        promptTextView.resignFirstResponder()
    }

    var isEditingText: Bool {
        promptTextView.isFirstResponder
    }

    var capsuleFrame: CGRect {
        capsule.frame
    }

    func getCurrentText() -> String? {
        promptTextView.text
    }

    func setText(_ text: String) {
        promptTextView.text = text
        textDidChange()
    }

    func clear() {
        promptTextView.text = ""
        textDidChange()
    }

    func setGenerating(_ generating: Bool) {
        guard generating != isGenerating else { return }
        isGenerating = generating
        promptTextView.isEditable = !generating
        UIView.performWithoutAnimation { self.promptTextView.alpha = generating ? 0.5 : 1 }
        photoSlot.isActionEnabled = !generating
        optionsButton.isEnabled = !generating
        if generating {
            setExpanded(false, animated: true, movesFocus: false)
            promptTextView.resignFirstResponder()
        }
        updateSendButton()
    }

    /// Keeps an open panel inside the stable bottom region when the device is folded like a
    /// laptop, and lets it grow back when it is opened flat again.
    func refitExpandedHeight() {
        guard let host = superview else { return }
        let resting = capsule.bounds.height + footnoteRow.bounds.height + Self.sideMargin + Theme.Space.md + host.safeAreaInsets.bottom
        let clearance = host.safeAreaInsets.top + Self.topBarClearance
        var limit = min(host.bounds.height * Self.panelHeightShare, host.bounds.height - resting - clearance)
        if let window, let fold = FoldGeometry.activeFold(in: window), fold.orientation == .horizontal {
            let region = window.bounds.height - fold.frame.maxY
            limit = min(limit, region - resting - Theme.Space.sm)
        }
        panel.setMaximumHeight(max(limit, 160))
    }

    func updateIndicators() {
        indicatorStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let colors = selectedSuggestionsManager?.getIndicatorColors() ?? []
        for color in colors {
            let dot = UIView()
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.backgroundColor = color
            dot.layer.cornerRadius = 3
            indicatorStackView.addArrangedSubview(dot)
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 6),
                dot.heightAnchor.constraint(equalToConstant: 6),
            ])
        }
        indicatorStackView.isHidden = colors.isEmpty
        indicatorStackView.isAccessibilityElement = !colors.isEmpty
        indicatorStackView.accessibilityLabel = selectedIdeaTitles.joined(separator: ", ")
    }

    func setEditMode(_ editMode: Bool, selectedImage: UIImage?) {
        isEditMode = editMode
        self.selectedImage = selectedImage
        photoSlot.image = editMode ? selectedImage : nil
        panel.setEditMode(editMode)
        placeholderLabel.text = editMode ? String(localized: "Describe your edits...") : String(localized: "What do you want to create?")
        promptTextView.accessibilityHint = placeholderLabel.text
        updateSendButton()
        updateTextHeight(animated: false)
        updateCredits()
    }

    func getEditOptions() -> EditOptions {
        let size = [ImageSize.auto, .square, .landscape, .portrait][panel.sizeIndex]
        let quality = [ImageQuality.auto, .low, .medium, .high][panel.qualityIndex]
        let fidelity = [FidelityLevel.low, .high][panel.fidelityIndex]
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
        let defaults = Choices.defaults()
        panel.modelIndex = defaults.model
        updateUIForModel(animated: false)
        panel.sizeIndex = defaults.size
        panel.qualityIndex = defaults.quality
        panel.formatIndex = defaults.format
        panel.compression = Float(defaults.compression)
        panel.backgroundIndex = defaults.background
        panel.moderationIndex = defaults.moderation
        panel.fidelityIndex = 0
        updateCredits()
    }

    private struct Choices: Equatable {
        var model: Int
        var size: Int
        var quality: Int
        var format: Int
        var background: Int
        var moderation: Int
        var compression: Int

        static func defaults() -> Choices {
            let config = ConfigurationManager.shared
            let model = ImageModel(rawValue: config.defaultModel) ?? .gemini
            return Choices(
                model: ComposerOptionsPanel.models.firstIndex(of: model) ?? 0,
                size: ["auto": 0, "1024x1024": 1, "1792x1024": 2, "1024x1792": 3][config.defaultSize] ?? 0,
                quality: ["auto": 0, "low": 1, "medium": 2, "high": 3][config.defaultQuality] ?? 1,
                format: ["png": 0, "jpeg": 1, "webp": 2][config.defaultOutputFormat] ?? 0,
                background: ["auto": 0, "transparent": 1, "opaque": 2, "none": 3][config.defaultBackground] ?? 0,
                moderation: ["default": 0, "auto": 1, "low": 2][config.defaultModeration] ?? 1,
                compression: config.defaultCompression
            )
        }
    }

    private var hasNonDefaultOptions: Bool {
        let defaults = Choices.defaults()
        if panel.modelIndex != defaults.model { return true }
        guard selectedModel == .openai else { return false }
        if panel.sizeIndex != defaults.size || panel.qualityIndex != defaults.quality { return true }
        if panel.formatIndex != defaults.format || panel.backgroundIndex != defaults.background { return true }
        if panel.moderationIndex != defaults.moderation { return true }
        if panel.formatIndex != 0 && Int(panel.compression) != defaults.compression { return true }
        return isEditMode && panel.fidelityIndex != 0
    }

    private func buildLayout() {
        backgroundColor = .clear
        addLayoutGuide(composerGuide)
        buildCapsule()
        buildFootnote()

        column.axis = .vertical
        column.alignment = .fill
        column.spacing = Theme.Space.sm
        column.translatesAutoresizingMaskIntoConstraints = false
        panel.isHidden = true
        panel.alpha = 0
        column.addArrangedSubview(panel)
        column.addArrangedSubview(capsule)
        column.addArrangedSubview(footnoteRow)
        column.setCustomSpacing(Theme.Space.xs, after: capsule)
        addSubview(column)

        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: topAnchor),
            column.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.sideMargin),
            column.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.sideMargin),
            column.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.sideMargin),
            composerGuide.topAnchor.constraint(equalTo: capsule.topAnchor),
            composerGuide.bottomAnchor.constraint(equalTo: footnoteRow.bottomAnchor),
            composerGuide.leadingAnchor.constraint(equalTo: leadingAnchor),
            composerGuide.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    private func buildCapsule() {
        promptTextView.translatesAutoresizingMaskIntoConstraints = false
        promptTextView.backgroundColor = .clear
        promptTextView.font = Self.promptFont
        promptTextView.adjustsFontForContentSizeCategory = true
        promptTextView.textColor = Theme.Color.ink
        promptTextView.tintColor = Theme.Color.accent
        promptTextView.textContainerInset = Self.textInsets
        promptTextView.textContainer.lineFragmentPadding = 0
        promptTextView.isScrollEnabled = false
        promptTextView.delegate = self
        promptTextView.onWidthChange = { [weak self] in self?.updateTextHeight(animated: false) }
        promptTextView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        promptTextView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textHeightConstraint = promptTextView.heightAnchor.constraint(equalToConstant: Self.minimumTextHeight)
        textHeightConstraint.isActive = true

        placeholderLabel.apply(.body, color: Theme.Color.inkTertiary)
        placeholderLabel.font = Self.promptFont
        placeholderLabel.numberOfLines = 1
        placeholderLabel.lineBreakMode = .byTruncatingTail
        placeholderLabel.adjustsFontSizeToFitWidth = true
        placeholderLabel.minimumScaleFactor = 0.75
        placeholderLabel.text = String(localized: "What do you want to create?")
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.isUserInteractionEnabled = false
        placeholderLabel.accessibilityElementsHidden = true
        promptTextView.addSubview(placeholderLabel)
        NSLayoutConstraint.activate([
            placeholderLabel.topAnchor.constraint(equalTo: promptTextView.topAnchor, constant: Self.textInsets.top),
            placeholderLabel.leadingAnchor.constraint(equalTo: promptTextView.leadingAnchor, constant: Self.textInsets.left),
            placeholderLabel.widthAnchor.constraint(equalTo: promptTextView.widthAnchor, constant: -(Self.textInsets.left + Self.textInsets.right)),
        ])

        let row = UIStackView(arrangedSubviews: [photoSlot, promptTextView, optionsButton, sendButton])
        row.axis = .horizontal
        row.alignment = .bottom
        row.spacing = 0
        row.isLayoutMarginsRelativeArrangement = true
        row.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)
        row.translatesAutoresizingMaskIntoConstraints = false
        capsule.contentView.addSubview(row)
        row.pinEdges(to: capsule.contentView)

        let focusTap = UITapGestureRecognizer(target: self, action: #selector(focusPrompt))
        focusTap.cancelsTouchesInView = false
        focusTap.delegate = self
        capsule.addGestureRecognizer(focusTap)
    }

    private func buildFootnote() {
        costLabel.apply(.footnote)
        costLabel.setContentHuggingPriority(.required, for: .horizontal)
        costLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        indicatorStackView.axis = .horizontal
        indicatorStackView.spacing = Theme.Space.xs
        indicatorStackView.alignment = .center
        indicatorStackView.isHidden = true
        indicatorStackView.setContentHuggingPriority(.required, for: .horizontal)
        getCreditsButton.isHidden = true

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        footnoteRow.axis = .horizontal
        footnoteRow.alignment = .center
        footnoteRow.spacing = Theme.Space.sm
        footnoteRow.isLayoutMarginsRelativeArrangement = true
        footnoteRow.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: Theme.Space.lg, bottom: 0, trailing: Theme.Space.lg)
        [costLabel, getCreditsButton, spacer, indicatorStackView].forEach(footnoteRow.addArrangedSubview)
        footnoteRow.heightAnchor.constraint(greaterThanOrEqualToConstant: 20).isActive = true
    }

    private func wirePanel() {
        panel.onChange = { [weak self] change in self?.panelChanged(change) }
        panel.onCollapse = { [weak self] in
            HapticManager.shared.impact(.click)
            self?.collapse()
        }
        panel.onAdvancedToggled = { target in Announce.layoutChanged(target) }
    }

    private func wireControls() {
        photoSlot.onAdd = { [weak self] in self?.onAddPhoto?() }
        photoSlot.onRemove = { [weak self] in self?.onClearEditImage?() }
        optionsButton.addAction(UIAction { [weak self] _ in self?.toggleExpanded() }, for: .touchUpInside)
        sendButton.addAction(UIAction { [weak self] _ in self?.sendTapped() }, for: .touchUpInside)
        getCreditsButton.addAction(UIAction { [weak self] _ in self?.onGetCredits?() }, for: .touchUpInside)
    }

    private func panelChanged(_ change: ComposerOptionsPanel.Change) {
        let previousCost = costAnnouncement
        switch change {
        case .model:
            updateUIForModel(animated: true)
            updateCredits()
            scheduleCostAnnouncement(previous: previousCost)
        case .size, .quality:
            updateCredits()
            scheduleCostAnnouncement(previous: previousCost)
        case .format:
            updateCredits()
        case .other:
            refreshOptionsIndicator()
        }
    }

    private func updateUIForModel(animated: Bool) {
        panel.setOpenAIVisible(selectedModel == .openai, animated: animated)
    }

    @objc private func focusPrompt() {
        guard !isGenerating else { return }
        promptTextView.becomeFirstResponder()
    }

    @objc private func configurationChanged() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.promptTextView.text.isEmpty {
                self.applyDefaults()
            }
        }
    }

    private func toggleExpanded() {
        HapticManager.shared.impact(.click)
        setExpanded(!isExpanded, animated: true)
    }

    private func sendTapped() {
        if isGenerating {
            HapticManager.shared.impact(.click)
            onStop?()
            return
        }
        guard let text = promptTextView.text, !text.isEmpty else { return }
        HapticManager.shared.impact(.click)
        if isEditMode {
            onSend?("EDIT_MODE")
        } else {
            onSend?(text)
        }
        setExpanded(false, animated: true, movesFocus: false)
        promptTextView.resignFirstResponder()
        if !isEditMode {
            clear()
        }
    }

    private func setExpanded(_ expanded: Bool, animated: Bool, movesFocus: Bool = true) {
        let changed = isExpanded != expanded
        isExpanded = expanded
        if expanded { promptTextView.resignFirstResponder() }
        refitExpandedHeight()
        optionsButton.isSelected = expanded
        refreshExpansionAccessibility()

        let hiddenTransform = CGAffineTransform(translationX: 0, y: 18)
        if expanded, changed {
            panel.alpha = 0
            panel.transform = hiddenTransform
            panel.isHidden = false
        }
        let apply = {
            self.panel.alpha = expanded ? 1 : 0
            self.panel.transform = expanded ? .identity : hiddenTransform
            if !expanded { self.panel.isHidden = true }
            self.layoutFromTopOfHierarchy()
        }
        if animated {
            Motion.spring(0.4, damping: 0.82, options: [.beginFromCurrentState], animations: apply) { _ in
                if !self.isExpanded { self.panel.transform = .identity }
            }
        } else {
            if expanded { panel.isHidden = false }
            apply()
            if !expanded { panel.transform = .identity }
        }
        if changed && movesFocus { moveAccessibilityFocus(afterExpanding: expanded) }
        if changed { onExpandedChanged?(expanded) }
    }

    private func textDidChange() {
        updatePlaceholder()
        updateSendButton()
        updateTextHeight(animated: true)
    }

    private func updatePlaceholder() {
        placeholderLabel.isHidden = !(promptTextView.text?.isEmpty ?? true)
    }

    /// Grows the field with its text up to four lines and then scrolls it, and rounds the
    /// capsule less once it is tall enough that a full pill would eat the corners of the text.
    private func updateTextHeight(animated: Bool) {
        let width = promptTextView.bounds.width
        guard width > 0 else { return }
        let insets = Self.textInsets.top + Self.textInsets.bottom
        let lineHeight = promptTextView.font?.lineHeight ?? 20
        let minimum = max(Self.minimumTextHeight, ceil(lineHeight + insets))
        let maximum = ceil(lineHeight * Self.maximumPromptLines + insets)
        let measured: CGFloat
        if promptTextView.text?.isEmpty ?? true {
            let fitting = placeholderLabel.sizeThatFits(CGSize(width: width - Self.textInsets.left - Self.textInsets.right, height: .greatestFiniteMagnitude))
            measured = ceil(fitting.height) + insets
        } else {
            measured = ceil(promptTextView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height)
        }
        let height = min(max(measured, minimum), maximum)
        let needsScroll = measured > maximum + 0.5
        if promptTextView.isScrollEnabled != needsScroll {
            promptTextView.isScrollEnabled = needsScroll
            if needsScroll, let range = promptTextView.selectedTextRange {
                promptTextView.scrollRectToVisible(promptTextView.caretRect(for: range.end), animated: false)
            }
        }
        capsule.maximumCornerRadius = height > minimum + 0.5 ? Self.grownCornerRadius : Self.capsuleCornerRadius
        guard abs(textHeightConstraint.constant - height) > 0.5 else { return }
        textHeightConstraint.constant = height
        if animated && window != nil {
            Motion.spring(0.3, damping: 0.85, options: [.beginFromCurrentState, .allowUserInteraction]) {
                self.layoutFromTopOfHierarchy()
            }
        }
    }

    private func updateSendButton() {
        let hasText = !(promptTextView.text?.isEmpty ?? true)
        updatePlaceholder()
        if isGenerating {
            sendButton.apply(.stop, animated: true)
            sendButton.accessibilityLabel = String(localized: "Cancel")
            sendButton.accessibilityHint = nil
        } else {
            sendButton.apply(hasText ? .ready : .disabled, animated: true)
            sendButton.accessibilityLabel = isEditMode ? String(localized: "Edit Image") : String(localized: "Generate")
            sendButton.accessibilityHint = hasText ? nil : String(localized: "Enter a prompt first")
        }
        refreshOptionsIndicator()
    }

    private func refreshOptionsIndicator() {
        optionsButton.showsChangeDot = hasNonDefaultOptions
    }

    @objc private func updateCredits() {
        defer { onCostInputsChanged?() }
        costRange = estimatedCostRange()
        panel.setQualityCosts([ImageQuality.auto, .low, .medium, .high].map {
            Self.costRange(model: .openai, quality: $0, size: selectedSize)
        })
        refreshCostLabel()
        refreshOptionsIndicator()
    }

    private func estimatedCostRange() -> ClosedRange<Int> {
        Self.costRange(model: selectedModel, quality: selectedQuality, size: selectedSize)
    }

    private static func costRange(model: ImageModel, quality: ImageQuality, size: ImageSize) -> ClosedRange<Int> {
        if let fixedCost = model.fixedCost {
            return fixedCost...fixedCost
        }
        let size = size.value
        switch quality.value {
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

    private var freeImagesLeft: Int? {
        guard let availableBalance, WelcomeCredits().isOnWelcomeGrant(balance: availableBalance) else { return nil }
        return WelcomeCredits.freeImages(balance: availableBalance, imageCost: costRange.lowerBound)
    }

    /// Shows the estimate and the free images left; when the estimate is more than the balance
    /// covers it adds the words "Not enough credits" with a warning symbol and the link to the
    /// store, so the state never rests on colour alone.
    private func refreshCostLabel() {
        let summary = costSummary
        let font = Theme.TextStyle.footnote.font
        let secondary = Theme.Color.inkSecondary
        let text = NSMutableAttributedString(string: String(localized: "≈ \(summary)"), attributes: [.font: font, .foregroundColor: secondary])
        var announcement = summary
        var spoken = summary
        if exceedsBalance {
            let warning = String(localized: "Not enough credits")
            let danger = Theme.Color.danger.resolvedColor(with: traitCollection)
            let attachment = NSTextAttachment()
            attachment.image = UIImage(systemName: "exclamationmark.circle.fill", withConfiguration: UIImage.SymbolConfiguration(font: font))?
                .withTintColor(danger, renderingMode: .alwaysOriginal)
            text.append(NSAttributedString(string: "  ·  ", attributes: [.font: font, .foregroundColor: secondary]))
            text.append(NSAttributedString(attachment: attachment))
            text.append(NSAttributedString(string: " \(warning)", attributes: [.font: font, .foregroundColor: danger]))
            announcement = "\(summary), \(warning)"
            spoken = announcement
        } else if let free = freeImagesLeft {
            let left = String(localized: "\(free) free left")
            text.append(NSAttributedString(string: "  ·  \(left)", attributes: [.font: font, .foregroundColor: secondary]))
            spoken = "\(summary), \(left)"
        }
        costLabel.attributedText = text
        costLabel.accessibilityLabel = spoken
        costAnnouncement = announcement
        getCreditsButton.isHidden = !exceedsBalance
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

    private func setupAccessibility() {
        promptTextView.accessibilityLabel = String(localized: "Prompt")
        promptTextView.accessibilityHint = placeholderLabel.text
        optionsButton.accessibilityLabel = String(localized: "Prompt and options")
        costLabel.isAccessibilityElement = true
        getCreditsButton.accessibilityLabel = String(localized: "Get credits")
        refreshExpansionAccessibility()
    }

    private var expansionStateText: String {
        isExpanded ? String(localized: "Expanded") : String(localized: "Collapsed")
    }

    private func refreshExpansionAccessibility() {
        optionsButton.accessibilityValue = expansionStateText
    }

    private var selectedIdeaTitles: [String] {
        guard let selections = selectedSuggestionsManager?.selections else { return [] }
        let order: [SuggestionType] = [.quickAction, .creativePrompt, .stylePreset, .promptModifier]
        return order.compactMap { selections[$0]?.title }
    }

    /// Moves VoiceOver into the panel when it opens and back to the options button when it closes.
    private func moveAccessibilityFocus(afterExpanding expanded: Bool) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            Announce.layoutChanged(expanded ? self.panel.firstFocusTarget : self.optionsButton)
        }
    }
}

extension ChatInputBar: UIGestureRecognizerDelegate {
    /// A tap on the options, attach or send button must only run that button: focusing the prompt as
    /// well collapsed the options panel in the same tap that was meant to close or open it.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var view = touch.view
        while let current = view, current !== capsule {
            if current is UIControl { return false }
            view = current.superview
        }
        return true
    }
}

extension ChatInputBar: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        textDidChange()
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        if isExpanded { setExpanded(false, animated: true, movesFocus: false) }
    }
}

private final class PromptTextView: UITextView {
    var onWidthChange: (() -> Void)?
    private var laidOutWidth: CGFloat = 0

    override func layoutSubviews() {
        super.layoutSubviews()
        guard abs(bounds.width - laidOutWidth) > 0.5 else { return }
        laidOutWidth = bounds.width
        onWidthChange?()
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
