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
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let imageScrollView = UIScrollView()
    private let imageView = UIImageView()
    private let actionsStackView = UIStackView()
    private let detailsStackView = UIStackView()
    private var imageHeightConstraint: NSLayoutConstraint!
    private var loadedImage: UIImage?
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private let loadFailureView = UIStackView()
    private var lastLaidOutHeight: CGFloat = 0
    
    private static let imageHeightFraction: CGFloat = 0.6
    private static let minimumImageHeight: CGFloat = 200
    private static let doubleTapZoomScale: CGFloat = 2.5
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadImage()
        
        preferredContentSize = CGSize(width: 800, height: 900)
        setupKeyboardCommands()
    }
    
    /// The tallest the image may be: a share of the room the screen actually has, so a short
    /// landscape window gets a short image and a tall iPad sheet a tall one.
    private var maxImageHeight: CGFloat {
        let available = view.safeAreaLayoutGuide.layoutFrame.height
        return max(Self.minimumImageHeight, available * Self.imageHeightFraction)
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        navigationItem.largeTitleDisplayMode = .never
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        imageScrollView.delegate = self
        imageScrollView.minimumZoomScale = 1.0
        imageScrollView.maximumZoomScale = 4.0
        imageScrollView.showsVerticalScrollIndicator = false
        imageScrollView.showsHorizontalScrollIndicator = false
        imageScrollView.layer.cornerRadius = 12
        imageScrollView.clipsToBounds = true
        imageScrollView.backgroundColor = .secondarySystemBackground
        imageScrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageScrollView)
        
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageScrollView.addSubview(imageView)
        
        setupActionButtons()
        contentView.addSubview(actionsStackView)
        
        setupDetailsSection()
        contentView.addSubview(detailsStackView)
        
        let layout = AdaptiveLayout(traitCollection: traitCollection)
        let insets = layout.contentInsets
        
        imageHeightConstraint = imageScrollView.heightAnchor.constraint(equalToConstant: Self.minimumImageHeight)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            imageScrollView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16 + insets.top),
            imageScrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16 + insets.left),
            imageScrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16 - insets.right),
            imageHeightConstraint,
            
            imageView.topAnchor.constraint(equalTo: imageScrollView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: imageScrollView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: imageScrollView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: imageScrollView.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: imageScrollView.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: imageScrollView.heightAnchor),
            
            actionsStackView.topAnchor.constraint(equalTo: imageScrollView.bottomAnchor, constant: 16),
            actionsStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16 + insets.left),
            actionsStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16 - insets.right),
            
            detailsStackView.topAnchor.constraint(equalTo: actionsStackView.bottomAnchor, constant: 24),
            detailsStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16 + insets.left),
            detailsStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16 - insets.right),
            detailsStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
        
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        imageScrollView.addGestureRecognizer(doubleTap)
        
        imageView.describe(String(localized: "Generated image"), value: image.prompt, traits: .image)
        setupLoadStates()
    }
    
    private func setupLoadStates() {
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hideFromAccessibility()
        contentView.addSubview(loadingIndicator)
        
        let failureLabel = UILabel()
        failureLabel.useScaledFont(.body, size: 16)
        failureLabel.text = String(localized: "Couldn't load image.")
        failureLabel.textColor = .secondaryLabel
        failureLabel.textAlignment = .center
        failureLabel.numberOfLines = 0
        
        var retryConfig = UIButton.Configuration.tinted()
        retryConfig.title = String(localized: "Retry")
        retryConfig.baseForegroundColor = .brandText
        retryConfig.baseBackgroundColor = .brand
        retryConfig.cornerStyle = .capsule
        retryConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .scaled(.body, size: 16, weight: .semibold)
            return outgoing
        }
        let retryButton = UIButton(configuration: retryConfig)
        retryButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        retryButton.addAction(UIAction { [weak self] _ in self?.loadImage() }, for: .touchUpInside)
        retryButton.setupPointerInteraction()
        
        loadFailureView.axis = .vertical
        loadFailureView.alignment = .center
        loadFailureView.spacing = 12
        loadFailureView.isHidden = true
        loadFailureView.translatesAutoresizingMaskIntoConstraints = false
        loadFailureView.addArrangedSubview(failureLabel)
        loadFailureView.addArrangedSubview(retryButton)
        contentView.addSubview(loadFailureView)
        
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: imageScrollView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: imageScrollView.centerYAnchor),
            loadFailureView.centerXAnchor.constraint(equalTo: imageScrollView.centerXAnchor),
            loadFailureView.centerYAnchor.constraint(equalTo: imageScrollView.centerYAnchor),
            loadFailureView.leadingAnchor.constraint(greaterThanOrEqualTo: imageScrollView.leadingAnchor, constant: 16),
            loadFailureView.trailingAnchor.constraint(lessThanOrEqualTo: imageScrollView.trailingAnchor, constant: -16)
        ])
    }
    
    private func setupActionButtons() {
        actionsStackView.axis = .horizontal
        actionsStackView.distribution = .fillEqually
        actionsStackView.spacing = 12
        actionsStackView.translatesAutoresizingMaskIntoConstraints = false
        
        let editButton = createActionButton(
            title: String(localized: "Edit"),
            accessibilityLabel: String(localized: "Edit this image"),
            image: UIImage(systemName: "pencil"),
            action: #selector(editTapped)
        )
        
        let copyButton = createActionButton(
            title: String(localized: "Copy"),
            accessibilityLabel: String(localized: "Copy Prompt"),
            image: UIImage(systemName: "doc.on.doc"),
            action: #selector(copyTapped)
        )
        
        let downloadButton = createActionButton(
            title: String(localized: "Save"),
            accessibilityLabel: String(localized: "Save to Photos"),
            image: UIImage(systemName: "arrow.down.to.line"),
            action: #selector(downloadTapped)
        )
        
        let shareButton = createActionButton(
            title: String(localized: "Share"),
            accessibilityLabel: String(localized: "Share"),
            image: UIImage(systemName: "square.and.arrow.up"),
            action: #selector(shareTapped)
        )

        let moreButton = createMenuButton(
            title: String(localized: "More"),
            image: UIImage(systemName: "ellipsis")
        )
        moreButton.menu = makeMoreMenu()
        moreButton.showsMenuAsPrimaryAction = true

        actionsStackView.addArrangedSubview(editButton)
        actionsStackView.addArrangedSubview(copyButton)
        actionsStackView.addArrangedSubview(downloadButton)
        actionsStackView.addArrangedSubview(shareButton)
        actionsStackView.addArrangedSubview(moreButton)
        updateActionsLayout()
    }

    /// Lays the five actions in a row, or stacks them with the icon beside the title when the
    /// text size is large enough that a row would clip the titles.
    private func updateActionsLayout() {
        let stacked = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        actionsStackView.axis = stacked ? .vertical : .horizontal
        actionsStackView.distribution = stacked ? .fill : .fillEqually
        for case let button as UIButton in actionsStackView.arrangedSubviews {
            button.configuration?.imagePlacement = stacked ? .leading : .top
        }
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
    
    private func makeActionConfiguration(title: String, image: UIImage?) -> UIButton.Configuration {
        var config = UIButton.Configuration.tinted()
        config.title = title
        config.image = image
        config.imagePlacement = .top
        config.imagePadding = 4
        config.baseForegroundColor = .brandText
        config.baseBackgroundColor = .brand
        config.cornerStyle = .medium
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .scaled(.caption1, size: 12, weight: .medium)
            return outgoing
        }
        return config
    }
    
    private func createActionButton(title: String, accessibilityLabel: String, image: UIImage?, action: Selector) -> UIButton {
        let button = UIButton(configuration: makeActionConfiguration(title: title, image: image))
        button.accessibilityLabel = accessibilityLabel
        button.addTarget(self, action: action, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 60).isActive = true
        
        button.setupPointerInteraction()
        
        button.configurationUpdateHandler = { button in
            switch button.state {
            case .highlighted:
                button.transform = Motion.isReduced ? .identity : CGAffineTransform(scaleX: 0.95, y: 0.95)
            default:
                button.transform = .identity
            }
        }

        return button
    }

    private func createMenuButton(title: String, image: UIImage?) -> UIButton {
        let button = UIButton(configuration: makeActionConfiguration(title: title, image: image))
        button.accessibilityLabel = String(localized: "More")
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 60).isActive = true

        button.setupPointerInteraction()

        return button
    }

    private func setupDetailsSection() {
        detailsStackView.axis = .vertical
        detailsStackView.spacing = 16
        detailsStackView.translatesAutoresizingMaskIntoConstraints = false
        
        addDetailRow(title: String(localized: "Prompt"), value: image.prompt)
        addDetailRow(title: String(localized: "Created"), value: formatDate(image.createdAt))
        
        if let metadata = image.metadata {
            if let model = metadata.model {
                addDetailRow(title: String(localized: "Model"), value: model)
            }
            addDetailRow(title: String(localized: "Size"), value: "\(metadata.width)x\(metadata.height)")
            if let quality = metadata.quality {
                addDetailRow(title: String(localized: "Quality"), value: quality.capitalized)
            }
            addDetailRow(title: String(localized: "Credits Used"), value: "\(metadata.creditsUsed)")
            addDetailRow(title: String(localized: "Format"), value: metadata.format.uppercased())
        }
    }
    
    private func addDetailRow(title: String, value: String) {
        let containerView = UIView()
        containerView.backgroundColor = .secondarySystemBackground
        containerView.layer.cornerRadius = 12
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.useScaledFont(.subheadline, size: 14, weight: .medium)
        titleLabel.textColor = .secondaryLabel
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.useScaledFont(.body, size: 16)
        valueLabel.textColor = .label
        valueLabel.numberOfLines = 0
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(titleLabel)
        containerView.addSubview(valueLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            valueLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            valueLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            valueLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12)
        ])
        
        containerView.describe(title, value: value, traits: .staticText)
        detailsStackView.addArrangedSubview(containerView)
    }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        let animated = !Motion.isReduced
        if imageScrollView.zoomScale > imageScrollView.minimumZoomScale + 0.01 {
            imageScrollView.setZoomScale(imageScrollView.minimumZoomScale, animated: animated)
            return
        }
        let point = gesture.location(in: imageView)
        let size = CGSize(
            width: imageScrollView.bounds.width / Self.doubleTapZoomScale,
            height: imageScrollView.bounds.height / Self.doubleTapZoomScale
        )
        let rect = CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height)
        imageScrollView.zoom(to: rect, animated: animated)
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
        
        loadingIndicator.startAnimating()
        Task { @MainActor [weak self] in
            guard let self else { return }
            let loaded = await ImageCache.shared.loadImage(from: self.image.url)
            self.loadingIndicator.stopAnimating()
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
        updateImageHeight()
    }
    
    private func showLoadFailure() {
        loadFailureView.isHidden = false
        Announce.say(String(localized: "Couldn't load image."))
    }
    
    /// Sizes the image area to the picture's own proportions, up to the tallest the screen
    /// allows, so neither a wide nor a tall picture leaves a band of empty space.
    private func updateImageHeight() {
        let width = imageScrollView.bounds.width > 0 ? imageScrollView.bounds.width : view.bounds.width - 32
        let aspectRatio = loadedImage.map { $0.size.height / max($0.size.width, 1) } ?? 1
        let height = min(width * aspectRatio, maxImageHeight)
        if abs(imageHeightConstraint.constant - height) > 0.5 {
            imageHeightConstraint.constant = height
        }
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
        if abs(view.bounds.height - lastLaidOutHeight) > 0.5 || loadedImage == nil {
            lastLaidOutHeight = view.bounds.height
            updateImageHeight()
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
            updateActionsLayout()
        }
        if traitCollection.horizontalSizeClass != previousTraitCollection?.horizontalSizeClass {
            updateImageHeight()
        }
    }
}

extension ImageDetailViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return scrollView == imageScrollView ? imageView : nil
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        if scrollView == imageScrollView {
            centerImageInScrollView()
        }
    }
    
    private func centerImageInScrollView() {
        let scrollViewSize = imageScrollView.bounds.size
        let imageViewSize = imageView.frame.size
        
        let horizontalPadding = max(0, (scrollViewSize.width - imageViewSize.width) / 2)
        let verticalPadding = max(0, (scrollViewSize.height - imageViewSize.height) / 2)
        
        imageScrollView.contentInset = UIEdgeInsets(
            top: verticalPadding,
            left: horizontalPadding,
            bottom: verticalPadding,
            right: horizontalPadding
        )
    }
}