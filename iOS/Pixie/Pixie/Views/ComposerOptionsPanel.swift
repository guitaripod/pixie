import UIKit

final class FlowLayoutView: UIView {
    private struct Placement {
        let view: UIView
        let x: NSLayoutConstraint
        let y: NSLayoutConstraint
    }

    private var placements: [Placement] = []
    private let spacing: CGFloat

    init(spacing: CGFloat = Theme.Space.sm) {
        self.spacing = spacing
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private lazy var ownHeight: NSLayoutConstraint = {
        let constraint = heightAnchor.constraint(equalToConstant: 44)
        constraint.isActive = true
        return constraint
    }()

    func setItems(_ views: [UIView]) {
        placements.forEach { $0.view.removeFromSuperview() }
        placements = views.map { view in
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
            let x = view.leadingAnchor.constraint(equalTo: leadingAnchor)
            let y = view.topAnchor.constraint(equalTo: topAnchor)
            NSLayoutConstraint.activate([x, y])
            return Placement(view: view, x: x, y: y)
        }
        _ = ownHeight
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0 else { return }
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var changed = false
        for placement in placements where !placement.view.isHidden {
            let size = placement.view.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
            if x > 0, x + size.width > bounds.width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            if abs(placement.x.constant - x) > 0.5 { placement.x.constant = x; changed = true }
            if abs(placement.y.constant - y) > 0.5 { placement.y.constant = y; changed = true }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        let total = max(y + rowHeight, 1)
        if abs(ownHeight.constant - total) > 0.5 {
            ownHeight.constant = total
            changed = true
        }
        if changed { super.layoutSubviews() }
    }
}

final class ChoiceGroup: UIView {
    enum Layout {
        case equalRow
        case flow
    }

    private let layout: Layout
    private let titleView: SectionLabelView
    private let row = UIStackView()
    private let flow = FlowLayoutView()
    private(set) var items: [UIControl]

    var onSelect: ((Int) -> Void)?

    var selectedIndex: Int = -1 {
        didSet { applySelection() }
    }

    init(title: String, items: [UIControl], layout: Layout) {
        self.layout = layout
        self.items = items
        titleView = SectionLabelView(title: title)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        titleView.accessibilityElementsHidden = true

        let content: UIView
        switch layout {
        case .equalRow:
            row.axis = .horizontal
            row.distribution = .fillEqually
            row.spacing = Theme.Space.sm
            items.forEach(row.addArrangedSubview)
            content = row
        case .flow:
            flow.setItems(items)
            content = flow
        }
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleView)
        addSubview(content)
        NSLayoutConstraint.activate([
            titleView.topAnchor.constraint(equalTo: topAnchor),
            titleView.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleView.trailingAnchor.constraint(equalTo: trailingAnchor),
            content.topAnchor.constraint(equalTo: titleView.bottomAnchor, constant: Theme.Space.sm),
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
            content.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        for (index, item) in items.enumerated() {
            item.isAccessibilityElement = true
            item.addAction(UIAction { [weak self] _ in self?.choose(index) }, for: .touchUpInside)
        }
        accessibilityContainerType = .semanticGroup
        accessibilityLabel = title
        applyAxis()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyAxis()
    }

    private func applyAxis() {
        guard layout == .equalRow else { return }
        let stacked = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        row.axis = stacked ? .vertical : .horizontal
    }

    private func choose(_ index: Int) {
        guard index != selectedIndex else { return }
        if !(items[index] is ChipView) { HapticsManager.shared.selection() }
        selectedIndex = index
        onSelect?(index)
    }

    private func applySelection() {
        for (index, item) in items.enumerated() {
            item.isSelected = index == selectedIndex
        }
    }
}

private class SelectableCard: UIControl {
    private let cornerRadius: CGFloat

    init(cornerRadius: CGFloat) {
        self.cornerRadius = cornerRadius
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = cornerRadius
        layer.cornerCurve = .continuous
        layer.borderWidth = 1.5
        applyState()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var isSelected: Bool {
        didSet { applyState() }
    }

    override var isHighlighted: Bool {
        didSet {
            guard oldValue != isHighlighted, !Motion.isReduced else { return }
            Motion.animate(0.12, options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
            }
        }
    }

    var wrappingLabels: [(label: UILabel, inset: CGFloat, lines: Int)] = [] {
        didSet { applyLineLimits() }
    }

    private func applyLineLimits() {
        let unlimited = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        for (label, _, lines) in wrappingLabels {
            label.numberOfLines = unlimited ? 0 : lines
        }
    }

    /// A label measured before its card has a width reports a height for a sliver-wide column, which
    /// is what made a card or pill balloon when the panel showed or a model changed. Each label is told
    /// the width it will really have and is capped to the lines it needs; accessibility text sizes
    /// lift the cap so nothing is cut.
    override func layoutSubviews() {
        applyLineLimits()
        for (label, inset, _) in wrappingLabels {
            label.preferredMaxLayoutWidth = max(0, bounds.width - inset)
        }
        super.layoutSubviews()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyState()
    }

    func selectionDidChange() {}

    /// A card has no intrinsic height, so without a stated preference a spare point of panel height
    /// would be shared out among the cards. Sitting just under a label's compression resistance, it
    /// pulls the card down to its natural size yet never squeezes its text.
    func prefersHeight(_ height: CGFloat) {
        let preferred = heightAnchor.constraint(equalToConstant: height)
        preferred.priority = UILayoutPriority(740)
        preferred.isActive = true
    }

    private func applyState() {
        backgroundColor = isSelected ? Theme.Color.accentSoft : Theme.Color.fill
        layer.borderColor = (isSelected ? Theme.Color.accent : UIColor.clear).resolvedColor(with: traitCollection).cgColor
        accessibilityTraits = isSelected ? [.button, .selected] : .button
        selectionDidChange()
    }
}

private final class ModelCardView: SelectableCard {
    private let nameLabel = UILabel()
    private let blurbLabel = UILabel()
    private let costLabel = UILabel()
    private let markView = UIImageView()

    init(model: ImageModel) {
        super.init(cornerRadius: Theme.Radius.lg)
        nameLabel.font = .scaled(.subheadline, size: 14, weight: .semibold)
        nameLabel.textColor = Theme.Color.ink
        nameLabel.text = model.displayName
        blurbLabel.apply(.footnote)
        blurbLabel.text = model.composerBlurb
        costLabel.font = .scaled(.footnote, size: 13, weight: .heavy, rounded: true)
        costLabel.textColor = Theme.Color.accentText
        costLabel.text = model.composerCostText
        [nameLabel, costLabel].forEach {
            $0.adjustsFontForContentSizeCategory = true
            $0.numberOfLines = 0
        }

        markView.translatesAutoresizingMaskIntoConstraints = false
        markView.contentMode = .scaleAspectFit
        markView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        markView.layer.shadowColor = UIColor.black.cgColor
        markView.layer.shadowOpacity = 0.12
        markView.layer.shadowRadius = 2
        markView.layer.shadowOffset = CGSize(width: 0, height: 1)
        addSubview(markView)

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        let stack = UIStackView(arrangedSubviews: [nameLabel, blurbLabel, spacer, costLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.setCustomSpacing(8, after: blurbLabel)
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 112),
            markView.centerXAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            markView.centerYAnchor.constraint(equalTo: topAnchor, constant: 6),
        ])
        prefersHeight(112)
        wrappingLabels = [(nameLabel, 20, 2), (blurbLabel, 20, 3), (costLabel, 20, 1)]
        accessibilityLabel = model.displayName
        accessibilityValue = "\(model.composerBlurb), \(model.composerCostText)"
        selectionDidChange()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func selectionDidChange() {
        markView.image = UIImage(systemName: "checkmark.circle.fill")
        markView.tintColor = Theme.Color.accent
        markView.isHidden = !isSelected
    }
}

private final class QualityPillView: SelectableCard {
    private let titleLabel = UILabel()
    private let costLabel = UILabel()
    private let title: String

    init(title: String) {
        self.title = title
        super.init(cornerRadius: Theme.Radius.md)
        titleLabel.apply(.subhead, color: Theme.Color.ink)
        titleLabel.text = title
        titleLabel.textAlignment = .center
        costLabel.font = .scaled(.footnote, size: 13, weight: .heavy, rounded: true)
        costLabel.adjustsFontForContentSizeCategory = true
        costLabel.textAlignment = .center
        costLabel.numberOfLines = 0
        let stack = UIStackView(arrangedSubviews: [titleLabel, costLabel])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 2
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 56),
        ])
        prefersHeight(56)
        wrappingLabels = [(titleLabel, 8, 1), (costLabel, 8, 1)]
        accessibilityLabel = title
        selectionDidChange()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func setCost(_ range: ClosedRange<Int>) {
        let figure = range.lowerBound == range.upperBound ? "\(range.lowerBound)" : "\(range.lowerBound)–\(range.upperBound)"
        costLabel.text = figure
        accessibilityValue = range.lowerBound == range.upperBound
            ? String(localized: "\(range.lowerBound) credits")
            : String(localized: "\(range.lowerBound)-\(range.upperBound) credits")
    }

    override func selectionDidChange() {
        costLabel.textColor = isSelected ? Theme.Color.accentText : Theme.Color.inkSecondary
    }
}

private final class AspectGlyphView: UIView {
    private let shape = CAShapeLayer()
    private let ratio: CGSize?

    var color: UIColor = Theme.Color.inkSecondary {
        didSet { applyColor() }
    }

    init(ratio: CGSize?) {
        self.ratio = ratio
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = false
        shape.fillColor = UIColor.clear.cgColor
        shape.lineWidth = 2
        if ratio == nil { shape.lineDashPattern = [3.5, 3] }
        layer.addSublayer(shape)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 30),
            heightAnchor.constraint(equalToConstant: 30),
        ])
        applyColor()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let side = min(bounds.width, bounds.height)
        let unit = ratio ?? CGSize(width: 1, height: 1)
        let scale = side / max(unit.width, unit.height)
        let size = CGSize(width: unit.width * scale, height: unit.height * scale)
        let rect = CGRect(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2, width: size.width, height: size.height).insetBy(dx: 1, dy: 1)
        shape.path = UIBezierPath(roundedRect: rect, cornerRadius: 5).cgPath
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyColor()
    }

    private func applyColor() {
        shape.strokeColor = color.resolvedColor(with: traitCollection).cgColor
    }
}

private final class SizeTileView: SelectableCard {
    private let glyph: AspectGlyphView
    private let label = UILabel()

    init(title: String, ratio: CGSize?) {
        glyph = AspectGlyphView(ratio: ratio)
        super.init(cornerRadius: Theme.Radius.md)
        label.apply(.footnote, color: Theme.Color.ink)
        label.textAlignment = .center
        label.text = title
        label.numberOfLines = 0
        let stack = UIStackView(arrangedSubviews: [glyph, label])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 6
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 76),
        ])
        prefersHeight(76)
        wrappingLabels = [(label, 4, 2)]
        accessibilityLabel = title
        selectionDidChange()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func selectionDidChange() {
        glyph.color = isSelected ? Theme.Color.accentText : Theme.Color.inkSecondary
    }
}

private final class DisclosureRow: UIControl {
    private let titleLabel = UILabel()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.down"))

    var isOpen = false {
        didSet {
            Motion.animate(0.25) {
                self.chevron.transform = self.isOpen ? CGAffineTransform(rotationAngle: .pi) : .identity
            }
            accessibilityValue = isOpen ? String(localized: "Expanded") : String(localized: "Collapsed")
        }
    }

    init(title: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = Theme.Color.fill
        layer.cornerRadius = Theme.Radius.md
        layer.cornerCurve = .continuous
        titleLabel.apply(.subhead, color: Theme.Color.ink)
        titleLabel.text = title
        chevron.tintColor = Theme.Color.inkSecondary
        chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        chevron.setContentCompressionResistancePriority(.required, for: .horizontal)
        let stack = UIStackView(arrangedSubviews: [titleLabel, chevron])
        stack.alignment = .center
        stack.spacing = Theme.Space.sm
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 48),
        ])
        isAccessibilityElement = true
        accessibilityLabel = title
        accessibilityTraits = .button
        accessibilityValue = String(localized: "Collapsed")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.7 : 1 }
    }
}

extension ImageModel {
    fileprivate var composerBlurb: String {
        switch self {
        case .gemini: return String(localized: "Fast and affordable")
        case .geminiPro: return String(localized: "Sharper detail and text")
        case .openai: return String(localized: "Fine control")
        }
    }

    fileprivate var composerCostText: String {
        if let fixedCost { return String(localized: "\(fixedCost) credits") }
        return String(localized: "\(5)-\(94) credits")
    }
}

/// Reports each layout pass, which is the moment its content has changed size: the panel itself
/// is not laid out when only a group inside it appears or collapses.
private final class LayoutReportingScrollView: UIScrollView {
    var onLayout: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }
}

final class ComposerOptionsPanel: UIView {
    enum Change {
        case model
        case size
        case quality
        case format
        case other
    }

    static let models: [ImageModel] = [.gemini, .geminiPro, .openai]

    var onChange: ((Change) -> Void)?
    var onCollapse: (() -> Void)?
    var onAdvancedToggled: ((UIView) -> Void)?

    private let surface = SurfaceView(style: .raised, cornerRadius: Theme.Radius.xl)
    private let grabberArea = UIView()
    private let grabber = UIView()
    private let scrollView = LayoutReportingScrollView()
    private let content = UIStackView()
    private let qualityPills: [QualityPillView]
    private let modelGroup: ChoiceGroup
    private let qualityGroup: ChoiceGroup
    private let sizeGroup: ChoiceGroup
    private let advancedRow = DisclosureRow(title: String(localized: "Advanced Options"))
    private let advancedContainer = UIStackView()
    private var advancedStack = UIStackView()
    private let formatGroup: ChoiceGroup
    private let backgroundGroup: ChoiceGroup
    private let moderationGroup: ChoiceGroup
    private let fidelityGroup: ChoiceGroup
    private let compressionBlock = UIStackView()
    private let compressionLabel = UILabel()
    private let compressionNote = UILabel()
    private let compressionSlider = PercentSlider()
    private var maxHeightConstraint: NSLayoutConstraint!
    private lazy var fittedHeight = heightAnchor.constraint(equalToConstant: Self.grabberHeight)
    private static let grabberHeight: CGFloat = 36
    private static let contentTopInset = Theme.Space.xs
    private static let contentBottomInset = Theme.Space.xl
    private var showsAdvanced = false
    private var isOpenAIVisible = false
    private var isEditMode = false

    override init(frame: CGRect) {
        let titles = [String(localized: "Auto"), String(localized: "Low"), String(localized: "Medium"), String(localized: "High")]
        let pills = titles.map { QualityPillView(title: $0) }
        qualityPills = pills
        modelGroup = ChoiceGroup(title: String(localized: "AI Model"), items: Self.models.map { ModelCardView(model: $0) }, layout: .equalRow)
        qualityGroup = ChoiceGroup(title: String(localized: "Quality"), items: pills, layout: .equalRow)
        sizeGroup = ChoiceGroup(
            title: String(localized: "Size"),
            items: [
                SizeTileView(title: String(localized: "Auto"), ratio: nil),
                SizeTileView(title: String(localized: "Square"), ratio: CGSize(width: 1, height: 1)),
                SizeTileView(title: String(localized: "Landscape"), ratio: CGSize(width: 3, height: 2)),
                SizeTileView(title: String(localized: "Portrait"), ratio: CGSize(width: 2, height: 3)),
            ],
            layout: .equalRow
        )
        formatGroup = ChoiceGroup(title: String(localized: "Output Format"), items: ["PNG", "JPG", "WebP"].map { ChipView(title: $0) }, layout: .flow)
        backgroundGroup = ChoiceGroup(
            title: String(localized: "Background"),
            items: [String(localized: "Auto"), String(localized: "Transparent"), String(localized: "Opaque"), String(localized: "None")].map { ChipView(title: $0) },
            layout: .flow
        )
        moderationGroup = ChoiceGroup(
            title: String(localized: "Moderation"),
            items: [String(localized: "Default"), String(localized: "Auto"), String(localized: "Low")].map { ChipView(title: $0) },
            layout: .flow
        )
        fidelityGroup = ChoiceGroup(title: String(localized: "Fidelity"), items: [String(localized: "Low"), String(localized: "High")].map { ChipView(title: $0) }, layout: .flow)
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        setupSurface()
        setupContent()
        setupGestures()
        wireGroups()
        applyDefaultVisibility()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    var modelIndex: Int {
        get { modelGroup.selectedIndex }
        set { modelGroup.selectedIndex = newValue }
    }
    var sizeIndex: Int {
        get { sizeGroup.selectedIndex }
        set { sizeGroup.selectedIndex = newValue }
    }
    var qualityIndex: Int {
        get { qualityGroup.selectedIndex }
        set { qualityGroup.selectedIndex = newValue }
    }
    var formatIndex: Int {
        get { formatGroup.selectedIndex }
        set {
            formatGroup.selectedIndex = newValue
            refreshCompressionVisibility()
        }
    }
    var backgroundIndex: Int {
        get { backgroundGroup.selectedIndex }
        set { backgroundGroup.selectedIndex = newValue }
    }
    var moderationIndex: Int {
        get { moderationGroup.selectedIndex }
        set { moderationGroup.selectedIndex = newValue }
    }
    var fidelityIndex: Int {
        get { fidelityGroup.selectedIndex }
        set { fidelityGroup.selectedIndex = newValue }
    }
    var compression: Float {
        get { compressionSlider.value }
        set {
            compressionSlider.value = newValue
            refreshCompressionLabel()
        }
    }

    var firstFocusTarget: UIView {
        modelGroup.items[max(modelGroup.selectedIndex, 0)]
    }

    func setMaximumHeight(_ height: CGFloat) {
        guard abs(maxHeightConstraint.constant - height) > 0.5 else { return }
        maxHeightConstraint.constant = height
    }

    func setQualityCosts(_ ranges: [ClosedRange<Int>]) {
        for (pill, range) in zip(qualityPills, ranges) {
            pill.setCost(range)
        }
    }

    func setOpenAIVisible(_ visible: Bool, animated: Bool) {
        isOpenAIVisible = visible
        let apply = {
            self.qualityGroup.isHidden = !visible
            self.sizeGroup.isHidden = !visible
            self.advancedStack.isHidden = !visible
            self.advancedRow.isHidden = !visible
            self.advancedContainer.isHidden = !visible || !self.showsAdvanced
            self.qualityGroup.alpha = visible ? 1 : 0
            self.sizeGroup.alpha = visible ? 1 : 0
            self.advancedRow.alpha = visible ? 1 : 0
            self.layoutFromTopOfHierarchy()
        }
        if animated {
            Motion.animate(0.3, animations: apply)
        } else {
            apply()
        }
    }

    func setEditMode(_ editMode: Bool) {
        isEditMode = editMode
        fidelityGroup.isHidden = !editMode
    }

    private func setupSurface() {
        addSubview(surface)
        surface.pinEdges(to: self)
        maxHeightConstraint = heightAnchor.constraint(lessThanOrEqualToConstant: 520)
        maxHeightConstraint.isActive = true

        grabberArea.translatesAutoresizingMaskIntoConstraints = false
        grabber.translatesAutoresizingMaskIntoConstraints = false
        grabber.backgroundColor = Theme.Color.inkTertiary.withAlphaComponent(0.5)
        grabber.layer.cornerRadius = 2.5
        grabberArea.addSubview(grabber)
        grabberArea.accessibilityElementsHidden = true
        surface.contentView.addSubview(grabberArea)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = false
        scrollView.keyboardDismissMode = .interactive
        scrollView.onLayout = { [weak self] in self?.refitHeight() }
        surface.contentView.addSubview(scrollView)

        fittedHeight.priority = UILayoutPriority(999)
        fittedHeight.isActive = true

        NSLayoutConstraint.activate([
            grabberArea.topAnchor.constraint(equalTo: surface.contentView.topAnchor),
            grabberArea.leadingAnchor.constraint(equalTo: surface.contentView.leadingAnchor),
            grabberArea.trailingAnchor.constraint(equalTo: surface.contentView.trailingAnchor),
            grabberArea.heightAnchor.constraint(equalToConstant: Self.grabberHeight),
            grabber.centerXAnchor.constraint(equalTo: grabberArea.centerXAnchor),
            grabber.centerYAnchor.constraint(equalTo: grabberArea.centerYAnchor, constant: 2),
            grabber.widthAnchor.constraint(equalToConstant: 36),
            grabber.heightAnchor.constraint(equalToConstant: 5),
            scrollView.topAnchor.constraint(equalTo: grabberArea.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: surface.contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: surface.contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: surface.contentView.bottomAnchor),
        ])
    }

    private func setupContent() {
        content.axis = .vertical
        content.spacing = Theme.Space.xl
        content.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(content)

        compressionLabel.apply(.subhead, color: Theme.Color.inkSecondary)
        compressionLabel.accessibilityElementsHidden = true
        compressionNote.apply(.footnote, color: Theme.Color.inkSecondary)
        compressionSlider.minimumValue = 1
        compressionSlider.maximumValue = 100
        compressionSlider.accessibilityLabel = String(localized: "Compression")
        compressionSlider.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        compressionSlider.addTarget(self, action: #selector(compressionChanged), for: .valueChanged)
        compressionBlock.axis = .vertical
        compressionBlock.spacing = Theme.Space.xs
        [compressionLabel, compressionSlider, compressionNote].forEach(compressionBlock.addArrangedSubview)
        compressionBlock.accessibilityContainerType = .semanticGroup

        advancedContainer.axis = .vertical
        advancedContainer.spacing = Theme.Space.xl
        advancedContainer.alpha = 0
        [formatGroup, compressionBlock, backgroundGroup, moderationGroup, fidelityGroup].forEach(advancedContainer.addArrangedSubview)

        advancedStack = UIStackView(arrangedSubviews: [advancedRow, advancedContainer])
        advancedStack.axis = .vertical
        advancedStack.spacing = Theme.Space.md

        [modelGroup, qualityGroup, sizeGroup, advancedStack].forEach(content.addArrangedSubview)
        advancedRow.addAction(UIAction { [weak self] _ in self?.toggleAdvanced() }, for: .touchUpInside)

        let inset = Theme.Space.lg
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: Self.contentTopInset),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -Self.contentBottomInset),
            content.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: inset),
            content.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -inset),
            content.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -inset * 2),
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        refitHeight()
    }

    /// The panel is exactly as tall as its content, or as tall as the screen allows with the rest
    /// scrolling. Measuring the content once its cards have a width and have told their labels how
    /// wide they are keeps the height from depending on which layout pass ran first.
    private func refitHeight() {
        let width = bounds.width - Theme.Space.lg * 2
        guard width > 0 else { return }
        let fitting = content.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        let wanted = ceil(Self.grabberHeight + Self.contentTopInset + fitting + Self.contentBottomInset)
        guard abs(fittedHeight.constant - wanted) > 0.5 else { return }
        fittedHeight.constant = wanted
        superview?.setNeedsLayout()
    }

    private func setupGestures() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        grabberArea.addGestureRecognizer(pan)
        let tap = UITapGestureRecognizer(target: self, action: #selector(grabberTapped))
        grabberArea.addGestureRecognizer(tap)
    }

    private func wireGroups() {
        modelGroup.onSelect = { [weak self] _ in self?.onChange?(.model) }
        qualityGroup.onSelect = { [weak self] _ in self?.onChange?(.quality) }
        sizeGroup.onSelect = { [weak self] _ in self?.onChange?(.size) }
        formatGroup.onSelect = { [weak self] _ in
            self?.refreshCompressionVisibility()
            self?.onChange?(.format)
        }
        backgroundGroup.onSelect = { [weak self] _ in self?.onChange?(.other) }
        moderationGroup.onSelect = { [weak self] _ in self?.onChange?(.other) }
        fidelityGroup.onSelect = { [weak self] _ in self?.onChange?(.other) }
    }

    private func applyDefaultVisibility() {
        qualityGroup.isHidden = true
        sizeGroup.isHidden = true
        advancedStack.isHidden = true
        advancedRow.isHidden = true
        advancedContainer.isHidden = true
        fidelityGroup.isHidden = true
        refreshCompressionVisibility()
    }

    private func toggleAdvanced() {
        HapticManager.shared.impact(.click)
        showsAdvanced.toggle()
        advancedRow.isOpen = showsAdvanced
        if showsAdvanced { advancedContainer.isHidden = false }
        Motion.animate(0.3, options: .curveEaseInOut, animations: {
            self.advancedContainer.alpha = self.showsAdvanced ? 1 : 0
            self.advancedContainer.isHidden = !self.showsAdvanced
            self.layoutFromTopOfHierarchy()
        })
        onAdvancedToggled?(advancedRow)
    }

    private func refreshCompressionVisibility() {
        let isPNG = formatGroup.selectedIndex == 0
        compressionLabel.isHidden = isPNG
        compressionSlider.isHidden = isPNG
        compressionNote.text = isPNG ? String(localized: "Compression isn't available for PNG") : String(localized: "Compression applies to JPEG and WebP")
    }

    @objc private func compressionChanged() {
        refreshCompressionLabel()
        onChange?(.other)
    }

    private func refreshCompressionLabel() {
        compressionLabel.text = String(localized: "Compression: \(Int(compressionSlider.value))%")
    }

    @objc private func grabberTapped() {
        onCollapse?()
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let travel = max(gesture.translation(in: self).y, 0)
        switch gesture.state {
        case .changed:
            transform = CGAffineTransform(translationX: 0, y: travel * 0.9)
            alpha = max(1 - travel / 320, 0.4)
        case .ended, .cancelled:
            let fast = gesture.velocity(in: self).y > 700
            if gesture.state == .ended, travel > 56 || fast {
                onCollapse?()
            } else {
                Motion.spring(0.35, damping: 0.8) {
                    self.transform = .identity
                    self.alpha = 1
                }
            }
        default:
            break
        }
    }
}
