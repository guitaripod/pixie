import UIKit

private enum FirstResponderProbe {
    static weak var responder: UIResponder?
}

private extension UIResponder {
    @objc func probeFirstResponder() {
        FirstResponderProbe.responder = self
    }
}

final class ImageDetailViewController: UIViewController {

    weak var delegate: ImageDetailViewControllerDelegate?

    private let image: ImageMetadata
    private let backdropView = InkBackdropView()
    private let stageScrollView = UIScrollView()
    private let imageView = UIImageView()
    private let loadingShimmer = ShimmerView()
    private let sheetScrollView = PassthroughScrollView()
    private let sheetSpacer = UIView()
    private let sheetCard = UIView()
    private let sheetExtension = UIView()
    private let contentStack = UIStackView()
    private let actionsStackView = UIStackView()
    private let tilesStackView = UIStackView()
    private let factsStackView = UIStackView()
    private let closeButton = UIButton(type: .system)
    private let closeGlass = GlassMaterial.cardView(cornerRadius: 22, interactive: true)
    private var moreTile: ActionTile!
    private var actionTiles: [ActionTile] = []
    private var facts: [(title: String, value: String)] = []
    private var loadFailureView: StateView!
    private var loadedImage: UIImage?
    private var stageHeightConstraint: NSLayoutConstraint!
    private var spacerHeightConstraint: NSLayoutConstraint!
    private var cardMinHeightConstraint: NSLayoutConstraint!
    private var lastLayoutSize: CGSize = .zero
    private var sheetTop: CGFloat = 0
    private var isSideBySide = false
    private var stageTrailingConstraint: NSLayoutConstraint!
    private var sheetLeadingConstraint: NSLayoutConstraint!
    private var closeTrailingConstraint: NSLayoutConstraint!
    private var closeLeadingConstraint: NSLayoutConstraint!
    private let topGrabber = UIView()
    private let sheetHandle = UIView()

    private static let stageFraction: CGFloat = 0.52
    private static let stageFractionLargeText: CGFloat = 0.34
    private static let minimumSheetTop: CGFloat = 220
    private static let sheetOverlap: CGFloat = Theme.Radius.sheet
    private static let stageTopInset: CGFloat = 60
    private static let sideBySideMinWidth: CGFloat = 560
    private static let sideBySideMinAspect: CGFloat = 0.9
    private static let sideBySideStageShare: CGFloat = 0.44
    private static let doubleTapZoomScale: CGFloat = 2.5
    private static let imageRadius: CGFloat = Theme.Radius.lg
    private static let shortcutSelectors: Set<Selector> = [
        #selector(dismissDetail),
        #selector(copyTapped),
        #selector(downloadTapped),
        #selector(shareTapped)
    ]

    init(image: ImageMetadata) {
        self.image = image
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadImage()

        preferredContentSize = CGSize(width: 800, height: 900)
        setupKeyboardCommands()
    }

    private var usesLargeText: Bool {
        traitCollection.preferredContentSizeCategory.isAccessibilityCategory
    }

    private var margin: CGFloat { Theme.screenMargin(for: traitCollection) }

    private func setupUI() {
        view.backgroundColor = Theme.Color.backdrop

        navigationItem.largeTitleDisplayMode = .never

        backdropView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backdropView)
        backdropView.pinEdges(to: view)

        setupStage()
        setupSheet()
        setupChrome()
        setupLoadStates()

        refreshLayoutForTextSize()
    }

    private func setupStage() {
        stageScrollView.delegate = self
        stageScrollView.minimumZoomScale = 1.0
        stageScrollView.maximumZoomScale = 4.0
        stageScrollView.showsVerticalScrollIndicator = false
        stageScrollView.showsHorizontalScrollIndicator = false
        stageScrollView.contentInsetAdjustmentBehavior = .never
        stageScrollView.clipsToBounds = true
        stageScrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stageScrollView)

        imageView.contentMode = .scaleAspectFill
        imageView.isUserInteractionEnabled = true
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = Self.imageRadius
        imageView.layer.cornerCurve = .continuous
        stageScrollView.addSubview(imageView)

        loadingShimmer.overrideUserInterfaceStyle = .dark
        loadingShimmer.backgroundColor = Theme.Color.onBackdropFill
        loadingShimmer.translatesAutoresizingMaskIntoConstraints = false
        imageView.addSubview(loadingShimmer)
        loadingShimmer.pinEdges(to: imageView)

        stageHeightConstraint = stageScrollView.heightAnchor.constraint(equalToConstant: Self.minimumSheetTop)
        stageTrailingConstraint = stageScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        NSLayoutConstraint.activate([
            stageScrollView.topAnchor.constraint(equalTo: view.topAnchor),
            stageScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stageTrailingConstraint,
            stageHeightConstraint
        ])

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        stageScrollView.addGestureRecognizer(doubleTap)

        imageView.describe(String(localized: "Generated image"), value: image.prompt, traits: .image)
    }

    private func setupSheet() {
        sheetScrollView.alwaysBounceVertical = true
        sheetScrollView.showsVerticalScrollIndicator = false
        sheetScrollView.contentInsetAdjustmentBehavior = .never
        sheetScrollView.delegate = self
        sheetScrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sheetScrollView)
        sheetLeadingConstraint = sheetScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        NSLayoutConstraint.activate([
            sheetScrollView.topAnchor.constraint(equalTo: view.topAnchor),
            sheetScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sheetScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sheetLeadingConstraint,
        ])

        sheetSpacer.translatesAutoresizingMaskIntoConstraints = false
        sheetSpacer.isAccessibilityElement = false
        sheetScrollView.addSubview(sheetSpacer)

        sheetCard.backgroundColor = Theme.Color.surface
        sheetCard.layer.cornerRadius = Theme.Radius.sheet
        sheetCard.layer.cornerCurve = .continuous
        sheetCard.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        sheetCard.layer.borderWidth = 1
        sheetCard.layer.borderColor = Theme.Color.line.resolvedColor(with: traitCollection).cgColor
        sheetCard.translatesAutoresizingMaskIntoConstraints = false
        sheetScrollView.addSubview(sheetCard)

        sheetExtension.backgroundColor = Theme.Color.surface
        sheetExtension.translatesAutoresizingMaskIntoConstraints = false
        sheetScrollView.insertSubview(sheetExtension, belowSubview: sheetCard)

        let handle = sheetHandle
        handle.backgroundColor = Theme.Color.line
        handle.layer.cornerRadius = 2.5
        handle.translatesAutoresizingMaskIntoConstraints = false
        handle.isAccessibilityElement = false
        sheetCard.addSubview(handle)

        contentStack.axis = .vertical
        contentStack.spacing = Theme.Space.xxl
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        sheetCard.addSubview(contentStack)

        setupActionRow()
        contentStack.addArrangedSubview(actionsStackView)
        contentStack.addArrangedSubview(makePromptCard())
        buildFacts()
        if !facts.isEmpty {
            factsStackView.axis = .vertical
            factsStackView.spacing = Theme.Space.xl
            contentStack.addArrangedSubview(factsStackView)
        }

        spacerHeightConstraint = sheetSpacer.heightAnchor.constraint(equalToConstant: Self.minimumSheetTop)
        cardMinHeightConstraint = sheetCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 0)
        let leading = contentStack.leadingAnchor.constraint(equalTo: sheetCard.leadingAnchor, constant: margin)
        let trailing = contentStack.trailingAnchor.constraint(equalTo: sheetCard.trailingAnchor, constant: -margin)
        leading.priority = .defaultHigh
        trailing.priority = .defaultHigh
        NSLayoutConstraint.activate([
            sheetSpacer.topAnchor.constraint(equalTo: sheetScrollView.contentLayoutGuide.topAnchor),
            sheetSpacer.leadingAnchor.constraint(equalTo: sheetScrollView.contentLayoutGuide.leadingAnchor),
            sheetSpacer.trailingAnchor.constraint(equalTo: sheetScrollView.contentLayoutGuide.trailingAnchor),
            sheetSpacer.widthAnchor.constraint(equalTo: sheetScrollView.frameLayoutGuide.widthAnchor),
            spacerHeightConstraint,

            sheetCard.topAnchor.constraint(equalTo: sheetSpacer.bottomAnchor),
            sheetCard.leadingAnchor.constraint(equalTo: sheetScrollView.contentLayoutGuide.leadingAnchor),
            sheetCard.trailingAnchor.constraint(equalTo: sheetScrollView.contentLayoutGuide.trailingAnchor),
            sheetCard.bottomAnchor.constraint(equalTo: sheetScrollView.contentLayoutGuide.bottomAnchor),
            cardMinHeightConstraint,

            sheetExtension.topAnchor.constraint(equalTo: sheetCard.bottomAnchor, constant: -Theme.Radius.sheet),
            sheetExtension.leadingAnchor.constraint(equalTo: sheetCard.leadingAnchor),
            sheetExtension.trailingAnchor.constraint(equalTo: sheetCard.trailingAnchor),
            sheetExtension.heightAnchor.constraint(equalToConstant: 2000),

            handle.topAnchor.constraint(equalTo: sheetCard.topAnchor, constant: Theme.Space.sm),
            handle.centerXAnchor.constraint(equalTo: sheetCard.centerXAnchor),
            handle.widthAnchor.constraint(equalToConstant: 36),
            handle.heightAnchor.constraint(equalToConstant: 5),

            contentStack.topAnchor.constraint(equalTo: sheetCard.topAnchor, constant: Theme.Space.xxl),
            contentStack.bottomAnchor.constraint(equalTo: sheetCard.bottomAnchor, constant: -Theme.Space.xxxl),
            contentStack.centerXAnchor.constraint(equalTo: sheetCard.centerXAnchor),
            contentStack.widthAnchor.constraint(lessThanOrEqualToConstant: Theme.Width.form),
            contentStack.leadingAnchor.constraint(greaterThanOrEqualTo: sheetCard.leadingAnchor, constant: margin),
            contentStack.trailingAnchor.constraint(lessThanOrEqualTo: sheetCard.trailingAnchor, constant: -margin),
            leading,
            trailing
        ])
    }

    private func setupChrome() {
        let grabber = topGrabber
        grabber.backgroundColor = UIColor(white: 1, alpha: 0.35)
        grabber.layer.cornerRadius = 2.5
        grabber.translatesAutoresizingMaskIntoConstraints = false
        grabber.isAccessibilityElement = false
        view.addSubview(grabber)

        closeGlass.isUserInteractionEnabled = false
        view.addSubview(closeGlass)

        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .bold))
        config.baseForegroundColor = .white
        closeButton.configuration = config
        closeButton.accessibilityLabel = String(localized: "Close")
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addAction(UIAction { [weak self] _ in self?.dismissDetail() }, for: .touchUpInside)
        closeButton.setupPointerInteraction()
        view.addSubview(closeButton)

        closeTrailingConstraint = closeButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -Theme.Space.lg)
        closeLeadingConstraint = closeButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: Theme.Space.lg)
        NSLayoutConstraint.activate([
            closeTrailingConstraint,
            grabber.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Theme.Space.sm),
            grabber.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            grabber.widthAnchor.constraint(equalToConstant: 36),
            grabber.heightAnchor.constraint(equalToConstant: 5),

            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Theme.Space.md),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),

            closeGlass.centerXAnchor.constraint(equalTo: closeButton.centerXAnchor),
            closeGlass.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            closeGlass.widthAnchor.constraint(equalToConstant: 40),
            closeGlass.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    private func setupLoadStates() {
        loadFailureView = StateView(
            symbol: "exclamationmark.triangle",
            title: String(localized: "Couldn't load image."),
            actionTitle: String(localized: "Retry"),
            onBackdrop: true
        ) { [weak self] in self?.loadImage() }
        loadFailureView.isHidden = true
        view.addSubview(loadFailureView)
        NSLayoutConstraint.activate([
            loadFailureView.centerXAnchor.constraint(equalTo: stageScrollView.centerXAnchor),
            loadFailureView.centerYAnchor.constraint(equalTo: stageScrollView.centerYAnchor, constant: Theme.Space.xl),
            loadFailureView.leadingAnchor.constraint(greaterThanOrEqualTo: stageScrollView.leadingAnchor, constant: Theme.Space.lg),
            loadFailureView.trailingAnchor.constraint(lessThanOrEqualTo: stageScrollView.trailingAnchor, constant: -Theme.Space.lg)
        ])
    }

    private func setupActionRow() {
        let editTile = ActionTile(
            title: String(localized: "Edit"),
            accessibilityLabel: String(localized: "Edit this image"),
            symbol: "pencil",
            isPrimary: true
        )
        editTile.addTarget(self, action: #selector(editTapped), for: .touchUpInside)

        let copyTile = ActionTile(
            title: String(localized: "Copy"),
            accessibilityLabel: String(localized: "Copy Prompt"),
            symbol: "doc.on.doc"
        )
        copyTile.addTarget(self, action: #selector(copyTapped), for: .touchUpInside)

        let saveTile = ActionTile(
            title: String(localized: "Save"),
            accessibilityLabel: String(localized: "Save to Photos"),
            symbol: "arrow.down.to.line"
        )
        saveTile.addTarget(self, action: #selector(downloadTapped), for: .touchUpInside)

        let shareTile = ActionTile(
            title: String(localized: "Share"),
            accessibilityLabel: String(localized: "Share"),
            symbol: "square.and.arrow.up"
        )
        shareTile.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)

        moreTile = ActionTile(
            title: String(localized: "More"),
            accessibilityLabel: String(localized: "More"),
            symbol: "ellipsis",
            isCircle: true
        )
        moreTile.menu = makeMoreMenu()
        moreTile.showsMenuAsPrimaryAction = true

        actionTiles = [editTile, copyTile, saveTile, shareTile]
        tilesStackView.axis = .horizontal
        tilesStackView.distribution = .fillEqually
        tilesStackView.spacing = Theme.Space.sm
        actionTiles.forEach { tilesStackView.addArrangedSubview($0) }

        actionsStackView.axis = .horizontal
        actionsStackView.alignment = .center
        actionsStackView.spacing = Theme.Space.sm
        actionsStackView.addArrangedSubview(tilesStackView)
        actionsStackView.addArrangedSubview(moreTile)
    }

    /// Lays the actions in one row, or stacks them with the icon beside the title when the
    /// text size is large enough that a row would clip the titles.
    private func refreshLayoutForTextSize() {
        let stacked = usesLargeText
        actionsStackView.axis = stacked ? .vertical : .horizontal
        actionsStackView.alignment = stacked ? .fill : .center
        tilesStackView.axis = stacked ? .vertical : .horizontal
        tilesStackView.distribution = stacked ? .fill : .fillEqually
        (actionTiles + [moreTile]).forEach { $0.setStacked(stacked) }
        rebuildFacts()
    }

    private func makeMoreMenu() -> UIMenu {
        let delete = UIAction(
            title: String(localized: "Delete"),
            image: UIImage(systemName: "trash"),
            attributes: .destructive
        ) { [weak self] _ in
            guard let self = self else { return }
            HapticsManager.shared.impact(.light)
            self.delegate?.imageDetailDidSelectAction(self, action: .delete, image: self.image)
        }
        return UIMenu(title: "", children: [delete])
    }

    private func makePromptCard() -> UIView {
        let card = SurfaceView(style: .sunken, cornerRadius: Theme.Radius.lg)

        let titleLabel = UILabel()
        titleLabel.setStyledText(String(localized: "Prompt"), .caption)
        titleLabel.numberOfLines = 1
        titleLabel.accessibilityTraits = .header

        let copyButton = PixieButton(style: .plain, size: .small, title: String(localized: "Copy")) { [weak self] in
            self?.copyTapped()
        }
        copyButton.accessibilityLabel = String(localized: "Copy Prompt")
        copyButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        copyButton.setContentHuggingPriority(.required, for: .horizontal)
        copyButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        copyButton.setupPointerInteraction()

        let header = UIStackView(arrangedSubviews: [titleLabel, UIView(), copyButton])
        header.axis = .horizontal
        header.alignment = .center

        let promptLabel = UILabel()
        promptLabel.apply(.body)
        promptLabel.text = image.prompt
        promptLabel.describe(String(localized: "Prompt"), value: image.prompt, traits: .staticText)

        let stack = UIStackView(arrangedSubviews: [header, promptLabel])
        stack.axis = .vertical
        stack.spacing = Theme.Space.xs
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: Theme.Space.sm),
            stack.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: Theme.Space.lg),
            stack.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -Theme.Space.sm),
            stack.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -Theme.Space.lg)
        ])
        return card
    }

    private func buildFacts() {
        facts = []
        if let metadata = image.metadata {
            if let model = metadata.model {
                facts.append((String(localized: "Model"), ImageModel(rawValue: model)?.displayName ?? model))
            }
            facts.append((String(localized: "Size"), "\(metadata.width) × \(metadata.height)"))
            if let quality = metadata.quality {
                facts.append((String(localized: "Quality"), quality.capitalized))
            }
            facts.append((String(localized: "Format"), metadata.format.uppercased()))
            facts.append((String(localized: "Credits"), "\(metadata.creditsUsed)"))
        }
        facts.append((String(localized: "Created"), formatDate(image.createdAt)))
    }

    /// Two facts to a row, or one per row at accessibility text sizes where two columns
    /// would force the values to wrap letter by letter.
    private func rebuildFacts() {
        factsStackView.arrangedSubviews.forEach {
            factsStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        let perRow = usesLargeText ? 1 : 2
        var index = 0
        while index < facts.count {
            let row = UIStackView()
            row.axis = .horizontal
            row.distribution = .fillEqually
            row.alignment = .top
            row.spacing = Theme.Space.lg
            for offset in 0..<perRow {
                if index + offset < facts.count {
                    let fact = facts[index + offset]
                    row.addArrangedSubview(makeFactView(title: fact.title, value: fact.value))
                } else {
                    row.addArrangedSubview(UIView())
                }
            }
            factsStackView.addArrangedSubview(row)
            index += perRow
        }
    }

    private func makeFactView(title: String, value: String) -> UIView {
        let titleLabel = UILabel()
        titleLabel.setStyledText(title, .caption)
        let valueLabel = UILabel()
        valueLabel.apply(.subhead, color: Theme.Color.ink)
        valueLabel.text = value
        let stack = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        stack.axis = .vertical
        stack.spacing = Theme.Space.xs
        stack.describe(title, value: value, traits: .staticText)
        return stack
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        let animated = !Motion.isReduced
        if stageScrollView.zoomScale > stageScrollView.minimumZoomScale + 0.01 {
            stageScrollView.setZoomScale(stageScrollView.minimumZoomScale, animated: animated)
            return
        }
        let point = gesture.location(in: imageView)
        let size = CGSize(
            width: imageView.bounds.width / Self.doubleTapZoomScale,
            height: imageView.bounds.height / Self.doubleTapZoomScale
        )
        let rect = CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height)
        stageScrollView.zoom(to: rect, animated: animated)
    }

    @objc private func editTapped() {
        HapticsManager.shared.impact(.light)
        delegate?.imageDetailDidSelectAction(self, action: .useForEdit, image: image)
    }

    @objc private func copyTapped() {
        HapticsManager.shared.impact(.light)
        delegate?.imageDetailDidSelectAction(self, action: .copyPrompt, image: image)
    }

    @objc private func downloadTapped() {
        HapticsManager.shared.impact(.light)
        delegate?.imageDetailDidSelectAction(self, action: .download, image: image)
    }

    @objc private func shareTapped() {
        HapticsManager.shared.impact(.light)
        delegate?.imageDetailDidSelectAction(self, action: .share, image: image)
    }

    private func loadImage() {
        loadFailureView.isHidden = true

        if let cachedImage = ImageCache.shared.image(for: image.url) {
            show(cachedImage)
            return
        }

        loadingShimmer.isHidden = false
        Task { @MainActor [weak self] in
            guard let self else { return }
            let loaded = await ImageCache.shared.loadImage(from: self.image.url)
            if let loaded {
                self.show(loaded)
            } else {
                self.showLoadFailure()
            }
        }
    }

    private func show(_ loadedImage: UIImage) {
        self.loadedImage = loadedImage
        imageView.image = loadedImage
        loadingShimmer.isHidden = true
        layoutStage()
    }

    private func showLoadFailure() {
        loadingShimmer.isHidden = true
        imageView.isHidden = true
        loadFailureView.isHidden = false
        Announce.say(String(localized: "Couldn't load image."))
    }

    /// The picture's own proportions: from the decoded image when it is there, from the saved
    /// size while it loads, square when neither is known, so the placeholder matches the result.
    private var imageAspectRatio: CGFloat {
        if let loadedImage, loadedImage.size.height > 0 {
            return loadedImage.size.width / loadedImage.size.height
        }
        if let metadata = image.metadata, metadata.height > 0 {
            return CGFloat(metadata.width) / CGFloat(metadata.height)
        }
        return 1
    }

    /// The box in the stage the picture may fill: below the grabber and close button, clear of
    /// the sheet's rounded top edge.
    private var imageArea: CGRect {
        let bounds = stageScrollView.bounds
        let top = view.safeAreaInsets.top + Self.stageTopInset
        let bottom = isSideBySide ? view.safeAreaInsets.bottom + Theme.Space.xl : Self.sheetOverlap + Theme.Space.lg
        let side = margin
        return CGRect(
            x: side,
            y: top,
            width: max(bounds.width - 2 * side, 1),
            height: max(bounds.height - top - bottom, 1)
        )
    }

    /// Fits the picture inside the image area without cropping and centres it by inset, so
    /// zooming keeps working through the scroll view's own gestures.
    private func layoutStage() {
        guard stageScrollView.bounds.width > 0, stageScrollView.zoomScale == 1 else { return }
        let area = imageArea
        let ratio = imageAspectRatio
        var size = CGSize(width: area.width, height: area.width / ratio)
        if size.height > area.height {
            size = CGSize(width: area.height * ratio, height: area.height)
        }
        imageView.frame = CGRect(origin: .zero, size: size)
        stageScrollView.contentSize = size
        centerImageInStage()
        stageScrollView.contentOffset = CGPoint(x: -stageScrollView.contentInset.left, y: -stageScrollView.contentInset.top)
    }

    private func centerImageInStage() {
        let bounds = stageScrollView.bounds.size
        let area = imageArea
        let content = imageView.frame.size
        stageScrollView.contentInset = UIEdgeInsets(
            top: max(0, area.midY - content.height / 2),
            left: max(0, area.midX - content.width / 2),
            bottom: max(0, bounds.height - area.midY - content.height / 2),
            right: max(0, bounds.width - area.midX - content.width / 2)
        )
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let date = formatter.date(from: dateString) else { return dateString }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short

        return displayFormatter.string(from: date)
    }

    private func setupKeyboardCommands() {
        addKeyCommand(UIKeyCommand(title: String(localized: "Close"),
                                  action: #selector(dismissDetail),
                                  input: UIKeyCommand.inputEscape))

        addKeyCommand(UIKeyCommand(title: String(localized: "Copy Prompt"),
                                  action: #selector(copyTapped),
                                  input: "C",
                                  modifierFlags: .command))

        addKeyCommand(UIKeyCommand(title: String(localized: "Save Image"),
                                  action: #selector(downloadTapped),
                                  input: "S",
                                  modifierFlags: .command))

        addKeyCommand(UIKeyCommand(title: String(localized: "Share"),
                                  action: #selector(shareTapped),
                                  input: "S",
                                  modifierFlags: [.command, .shift]))
    }

    /// Shortcuts belong to this screen only while it is the one in front and nobody is typing
    /// somewhere else, so command-C still copies selected text instead of the prompt.
    private var shortcutsAreActive: Bool {
        guard isViewLoaded, view.window != nil, presentedViewController == nil, !isBeingDismissed else { return false }
        FirstResponderProbe.responder = nil
        UIApplication.shared.sendAction(#selector(UIResponder.probeFirstResponder), to: nil, from: nil, for: nil)
        return !(FirstResponderProbe.responder is UITextInput)
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if Self.shortcutSelectors.contains(action) && !shortcutsAreActive {
            return false
        }
        return super.canPerformAction(action, withSender: sender)
    }

    @objc private func dismissDetail() {
        dismiss(animated: true)
    }

    override func accessibilityPerformEscape() -> Bool {
        dismiss(animated: true)
        return true
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard view.bounds.size != lastLayoutSize else { return }
        lastLayoutSize = view.bounds.size
        updateSheetMetrics()
    }

    /// A wide window that is not much taller than it is wide, such as a landscape phone or the
    /// inner Duo display, puts the picture beside the details instead of above them.
    private var prefersSideBySide: Bool {
        let size = view.bounds.size
        return size.width >= Self.sideBySideMinWidth && size.width >= size.height * Self.sideBySideMinAspect
    }

    /// Places the sheet's top edge: a share of the height, less when the text is large so the
    /// controls get the room, and never so low that the sheet loses its first row. Side by
    /// side, the picture takes the leading share of the width and the sheet fills the rest.
    private func updateSheetMetrics() {
        isSideBySide = prefersSideBySide
        applySideBySideChrome()
        if isSideBySide {
            let size = view.bounds.size
            let stageWidth = (size.width * Self.sideBySideStageShare).rounded()
            sheetTop = 0
            spacerHeightConstraint.constant = 0
            cardMinHeightConstraint.constant = size.height
            stageHeightConstraint.constant = size.height
            stageTrailingConstraint.constant = stageWidth - size.width
            sheetLeadingConstraint.constant = stageWidth
            stageScrollView.alpha = 1
        } else {
            let fraction = usesLargeText ? Self.stageFractionLargeText : Self.stageFraction
            sheetTop = max(Self.minimumSheetTop, (view.bounds.height * fraction).rounded())
            spacerHeightConstraint.constant = sheetTop
            cardMinHeightConstraint.constant = max(0, view.bounds.height - sheetTop)
            stageHeightConstraint.constant = sheetTop + Self.sheetOverlap
            stageTrailingConstraint.constant = 0
            sheetLeadingConstraint.constant = 0
        }
        sheetScrollView.passthroughHeight = sheetTop
        view.layoutIfNeeded()
        layoutStage()
    }

    private func applySideBySideChrome() {
        topGrabber.isHidden = isSideBySide
        sheetHandle.isHidden = isSideBySide
        sheetCard.layer.maskedCorners = isSideBySide
            ? [.layerMinXMinYCorner, .layerMinXMaxYCorner]
            : [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        closeTrailingConstraint.isActive = !isSideBySide
        closeLeadingConstraint.isActive = isSideBySide
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        layoutStage()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        sheetCard.layer.borderColor = Theme.Color.line.resolvedColor(with: traitCollection).cgColor
        if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
            refreshLayoutForTextSize()
            lastLayoutSize = .zero
            view.setNeedsLayout()
        }
        if traitCollection.horizontalSizeClass != previousTraitCollection?.horizontalSizeClass {
            lastLayoutSize = .zero
            view.setNeedsLayout()
        }
    }
}

extension ImageDetailViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return scrollView === stageScrollView ? imageView : nil
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        if scrollView === stageScrollView {
            centerImageInStage()
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === sheetScrollView, sheetTop > 0 else { return }
        let progress = min(max(scrollView.contentOffset.y / sheetTop, 0), 1)
        stageScrollView.alpha = 1 - 0.5 * progress
    }
}

private final class PassthroughScrollView: UIScrollView {
    var passthroughHeight: CGFloat = 0

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        point.y >= passthroughHeight && super.point(inside: point, with: event)
    }
}

private final class ActionTile: UIButton {
    private let tileTitle: String
    private let symbol: String
    private let isPrimary: Bool
    private let isCircle: Bool
    private let gradient = GradientView()
    private var isStacked = false
    private var sizeConstraints: [NSLayoutConstraint] = []

    private static let circleDiameter: CGFloat = 52

    init(title: String, accessibilityLabel spoken: String, symbol: String, isPrimary: Bool = false, isCircle: Bool = false) {
        tileTitle = title
        self.symbol = symbol
        self.isPrimary = isPrimary
        self.isCircle = isCircle
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        accessibilityLabel = spoken
        setupPointerInteraction()
        configurationUpdateHandler = { button in
            guard !Motion.isReduced else { return }
            Motion.animate(0.15, options: [.allowUserInteraction, .beginFromCurrentState]) {
                button.transform = button.isHighlighted ? CGAffineTransform(scaleX: 0.95, y: 0.95) : .identity
            }
        }
        setStacked(false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.cornerRadius = isCircleShape ? bounds.height / 2 : Theme.Radius.lg
    }

    private var isCircleShape: Bool { isCircle && !isStacked }

    /// At accessibility text sizes a tile becomes a full-width row with the icon beside its
    /// title; the circular "More" button grows into the same row so its label can be read.
    func setStacked(_ stacked: Bool) {
        isStacked = stacked
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(textStyle: .headline, scale: .medium))
        config.title = isCircleShape ? nil : tileTitle
        config.imagePlacement = stacked ? .leading : .top
        config.imagePadding = stacked ? Theme.Space.md : Theme.Space.xs
        config.baseForegroundColor = isPrimary ? .white : Theme.Color.ink
        config.contentInsets = NSDirectionalEdgeInsets(top: Theme.Space.sm, leading: Theme.Space.xs, bottom: Theme.Space.sm, trailing: Theme.Space.xs)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .scaled(.footnote, size: 13, weight: .medium)
            return outgoing
        }
        config.cornerStyle = .fixed
        config.background.cornerRadius = isCircleShape ? Self.circleDiameter / 2 : Theme.Radius.lg
        if isPrimary {
            config.background.backgroundColor = .clear
            config.background.customView = gradient
        } else {
            config.background.backgroundColor = Theme.Color.fill
        }
        configuration = config

        NSLayoutConstraint.deactivate(sizeConstraints)
        if isCircleShape {
            sizeConstraints = [
                widthAnchor.constraint(equalToConstant: Self.circleDiameter),
                heightAnchor.constraint(equalToConstant: Self.circleDiameter),
            ]
        } else {
            sizeConstraints = [heightAnchor.constraint(greaterThanOrEqualToConstant: stacked ? 56 : 64)]
        }
        NSLayoutConstraint.activate(sizeConstraints)
        setNeedsLayout()
    }
}
