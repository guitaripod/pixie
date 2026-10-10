import UIKit

enum ImageAction {
    case useForEdit
    case copyPrompt
    case download
    case share
    case delete
}

extension Notification.Name {
    static let galleryNeedsRefresh = Notification.Name("GalleryNeedsRefresh")
}

final class GalleryViewController: UIViewController {

    private let galleryPageVC = GalleryPageViewController()
    private var toast: GalleryToastView?
    private var pendingDeletion: PendingDeletion?
    private var hasImages = false
    private var isBusy = false
    private var isSelecting = false

    private static let undoWindow: TimeInterval = 5
    private static let batchConfirmationThreshold = 5

    private lazy var selectButton = UIBarButtonItem(title: String(localized: "Select"), primaryAction: UIAction { [weak self] _ in
        guard let self else { return }
        self.setSelecting(!self.isSelecting)
    })

    private lazy var saveItem = UIBarButtonItem(title: String(localized: "Save"), primaryAction: UIAction { [weak self] _ in
        guard let self else { return }
        self.saveImages(self.galleryPageVC.selectedImages)
    })

    private lazy var shareItem = UIBarButtonItem(title: String(localized: "Share"), primaryAction: UIAction { [weak self] _ in
        guard let self else { return }
        self.shareImages(self.galleryPageVC.selectedImages)
    })

    private lazy var deleteItem: UIBarButtonItem = {
        let item = UIBarButtonItem(title: String(localized: "Delete"), primaryAction: UIAction { [weak self] _ in
            guard let self else { return }
            self.deleteSelectedImages()
        })
        item.tintColor = .systemRed
        return item
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        setupToolbar()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        commitPendingDeletion()
        setSelecting(false)
        navigationController?.setToolbarHidden(true, animated: animated)
    }

    @objc private func appDidEnterBackground() {
        commitPendingDeletion()
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground

        addChild(galleryPageVC)
        view.addSubview(galleryPageVC.view)
        galleryPageVC.view.translatesAutoresizingMaskIntoConstraints = false
        galleryPageVC.didMove(toParent: self)
        galleryPageVC.delegate = self

        NSLayoutConstraint.activate([
            galleryPageVC.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            galleryPageVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            galleryPageVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            galleryPageVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupNavigationBar() {
        navigationController?.navigationBar.isHidden = false
        navigationItem.largeTitleDisplayMode = .never
        title = String(localized: "My Images")
        selectButton.isEnabled = false
        selectButton.accessibilityHint = String(localized: "Choose several images to save, share or delete")
        navigationItem.rightBarButtonItem = selectButton
    }

    private func setupToolbar() {
        saveItem.accessibilityLabel = String(localized: "Save to Photos")
        toolbarItems = [saveItem, UIBarButtonItem(systemItem: .flexibleSpace), shareItem, UIBarButtonItem(systemItem: .flexibleSpace), deleteItem]
        updateSelectionUI(count: 0)
    }

    private func setSelecting(_ selecting: Bool) {
        guard selecting != isSelecting else { return }
        isSelecting = selecting
        galleryPageVC.setSelecting(selecting)
        navigationController?.setToolbarHidden(!selecting, animated: !Motion.isReduced)
        updateSelectionUI(count: 0)
        Announce.layoutChanged()
    }

    /// Keeps the title, the Select/Done button and the toolbar in step with how many
    /// images are chosen, so the count is always in the title and actions only light up
    /// when there is something to act on.
    private func updateSelectionUI(count: Int) {
        selectButton.title = isSelecting ? String(localized: "Done") : String(localized: "Select")
        selectButton.isEnabled = isSelecting || hasImages
        if isSelecting {
            title = count == 0 ? String(localized: "Select Items") : String(localized: "\(count) selected")
        } else {
            title = String(localized: "My Images")
        }
        let canAct = isSelecting && count > 0 && !isBusy
        [saveItem, shareItem, deleteItem].forEach { $0.isEnabled = canAct }
    }

    private func setBusy(_ busy: Bool) {
        isBusy = busy
        updateSelectionUI(count: galleryPageVC.selectedImages.count)
    }
}

extension GalleryViewController: GalleryPageViewControllerDelegate {
    func galleryPageDidSelectImage(_ viewController: GalleryPageViewController, image: ImageMetadata) {
        presentDetail(for: image)
    }

    func presentDetail(for image: ImageMetadata) {
        let previewVC = ImageDetailViewController(image: image)
        previewVC.delegate = self

        if #available(iOS 15.0, *) {
            if let sheet = previewVC.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberVisible = true
                sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            }
        }

        present(previewVC, animated: true)
    }

    func galleryPageDidPerformAction(_ viewController: GalleryPageViewController, action: ImageAction, on image: ImageMetadata) {
        handleImageAction(action, for: image)
    }

    func galleryPageDidChangeSelection(_ viewController: GalleryPageViewController, count: Int) {
        updateSelectionUI(count: count)
    }

    func galleryPageDidChangeContent(_ viewController: GalleryPageViewController, hasImages: Bool) {
        self.hasImages = hasImages
        if !hasImages {
            setSelecting(false)
        }
        updateSelectionUI(count: galleryPageVC.selectedImages.count)
    }

    func galleryPageDidRequestCreate(_ viewController: GalleryPageViewController) {
        returnToChat()
    }
}

extension GalleryViewController: ImageDetailViewControllerDelegate {
    func imageDetailDidSelectAction(_ viewController: ImageDetailViewController, action: ImageAction, image: ImageMetadata) {
        viewController.dismiss(animated: true) {
            self.handleImageAction(action, for: image)
        }
    }
}

private struct PendingDeletion {
    let images: [ImageMetadata]
    let timer: Task<Void, Never>
}

private extension GalleryViewController {
    /// Back to the chat that edits the picked image: the chat column beside the sidebar when
    /// there are two columns, a pop of the single column otherwise.
    func returnToChat() {
        if let split = splitViewController as? MainSplitViewController, !split.isCollapsed {
            split.navigateToSection(.chat)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

    func handleImageAction(_ action: ImageAction, for image: ImageMetadata) {
        switch action {
        case .useForEdit:
            HapticsManager.shared.impact(.light)
            NotificationCenter.default.post(
                name: Notification.Name("ImageSelectedForEdit"),
                object: nil,
                userInfo: ["image": image]
            )
            returnToChat()

        case .copyPrompt:
            HapticsManager.shared.notification(.success)
            UIPasteboard.general.string = image.prompt
            showToast(String(localized: "Prompt copied to clipboard"))

        case .download:
            HapticsManager.shared.impact(.light)
            saveImages([image])

        case .share:
            HapticsManager.shared.impact(.light)
            shareImages([image])

        case .delete:
            deleteImages([image])
        }
    }

    func deleteSelectedImages() {
        let selected = galleryPageVC.selectedImages
        guard !selected.isEmpty else { return }
        guard selected.count >= Self.batchConfirmationThreshold else {
            deleteImages(selected)
            return
        }
        let alert = UIAlertController(
            title: String(localized: "Delete \(selected.count) images?"),
            message: String(localized: "This permanently deletes the selected images."),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: String(localized: "Cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: String(localized: "Delete"), style: .destructive) { [weak self] _ in
            self?.deleteImages(selected)
        })
        present(alert, animated: true)
    }

    /// Hides the images at once and gives the person a few seconds to take it back; the
    /// server only hears about the deletion once that window has passed.
    func deleteImages(_ images: [ImageMetadata]) {
        guard !images.isEmpty else { return }
        commitPendingDeletion()

        let ids = Set(images.map(\.id))
        galleryPageVC.hide(ids: ids)
        setSelecting(false)
        HapticsManager.shared.impact(.medium)

        let window = undoDuration
        let timer = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(window * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.commitPendingDeletion() }
        }
        pendingDeletion = PendingDeletion(images: images, timer: timer)

        let message = images.count == 1
            ? String(localized: "Image deleted")
            : String(localized: "Deleted \(images.count) images")
        showToast(message, actionTitle: String(localized: "Undo"), duration: window, isUndo: true) { [weak self] in
            self?.undoPendingDeletion()
        }
    }

    /// Longer than the usual window when VoiceOver is on, since reaching the Undo button
    /// takes longer than a tap.
    var undoDuration: TimeInterval {
        UIAccessibility.isVoiceOverRunning ? Self.undoWindow * 3 : Self.undoWindow
    }

    func undoPendingDeletion() {
        guard let pending = pendingDeletion else { return }
        pending.timer.cancel()
        pendingDeletion = nil
        galleryPageVC.unhide(ids: Set(pending.images.map(\.id)))
        HapticsManager.shared.selection()
        dismissToast()
        Announce.say(String(localized: "Restored"))
    }

    func commitPendingDeletion() {
        guard let pending = pendingDeletion else { return }
        pending.timer.cancel()
        pendingDeletion = nil
        if toast?.isUndo == true {
            dismissToast()
        }
        Task { @MainActor [self] in
            await self.performDeletion(of: pending.images)
        }
    }

    func performDeletion(of images: [ImageMetadata]) async {
        var failed: [ImageMetadata] = []
        for image in images {
            do {
                try await APIService.shared.deleteImage(id: image.id)
            } catch {
                failed.append(image)
            }
        }
        let failedIDs = Set(failed.map(\.id))
        galleryPageVC.purge(ids: Set(images.map(\.id)).subtracting(failedIDs))
        GalleryCache.shared.clearCache()
        guard !failed.isEmpty else { return }
        galleryPageVC.unhide(ids: failedIDs)
        HapticsManager.shared.notification(.error)
        showToast(failed.count == 1
            ? String(localized: "Could not delete image. Try again later.")
            : String(localized: "Couldn't delete \(failed.count) images. Try again later."))
    }

    func saveImages(_ images: [ImageMetadata]) {
        guard !isBusy, !images.isEmpty else { return }
        setBusy(true)
        Task { @MainActor [self] in
            let outcome = await saveToPhotos(images)
            setBusy(false)
            presentSaveOutcome(outcome, of: images)
        }
    }

    func saveToPhotos(_ images: [ImageMetadata]) async -> SaveOutcome {
        var outcome = SaveOutcome()
        for (index, image) in images.enumerated() {
            if images.count > 1 {
                showProgress(String(localized: "Saving \(index + 1) of \(images.count)…"))
            }
            guard let uiImage = await ImageCache.shared.loadImage(from: image.url) else {
                outcome.remaining.append(image)
                continue
            }
            let result = await withCheckedContinuation { continuation in
                PhotoSavingService.shared.saveToLibrary([uiImage]) { continuation.resume(returning: $0) }
            }
            switch result {
            case .success:
                outcome.saved += 1
            case .failure(let error):
                outcome.error = error
                if case .permissionDenied = error {
                    outcome.remaining.append(contentsOf: images[index...])
                    return outcome
                }
                outcome.remaining.append(image)
            }
        }
        return outcome
    }

    func presentSaveOutcome(_ outcome: SaveOutcome, of images: [ImageMetadata]) {
        if outcome.remaining.isEmpty {
            HapticsManager.shared.notification(.success)
            setSelecting(false)
            showToast(images.count == 1
                ? String(localized: "Image saved to Photos")
                : String(localized: "Saved \(images.count) images to Photos"))
            return
        }

        HapticsManager.shared.notification(.error)
        let retry: () -> Void = { [weak self] in self?.saveImages(outcome.remaining) }
        if outcome.saved > 0 {
            showToast(String(localized: "Saved \(outcome.saved) of \(images.count) images"), actionTitle: String(localized: "Retry"), action: retry)
        } else if case .permissionDenied? = outcome.error {
            showToast(String(localized: "Photo library access denied. Please enable access in Settings."), actionTitle: String(localized: "Open Settings")) {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
        } else if let error = outcome.error {
            showToast(error.localizedDescription, actionTitle: String(localized: "Retry"), action: retry)
        } else {
            showToast(String(localized: "Couldn't load image."), actionTitle: String(localized: "Retry"), action: retry)
        }
    }

    func shareImages(_ images: [ImageMetadata]) {
        guard !isBusy, !images.isEmpty else { return }
        setBusy(true)
        Task { @MainActor [self] in
            if images.count > 1 {
                showProgress(String(localized: "Preparing to share…"))
            }
            var loaded: [UIImage] = []
            for image in images {
                guard let uiImage = await ImageCache.shared.loadImage(from: image.url) else {
                    setBusy(false)
                    HapticsManager.shared.notification(.error)
                    showToast(String(localized: "Couldn't load image."), actionTitle: String(localized: "Retry")) { [weak self] in
                        self?.shareImages(images)
                    }
                    return
                }
                loaded.append(uiImage)
            }
            setBusy(false)
            dismissToast()
            if loaded.count == 1 {
                ImageSharingService.shared.shareImage(loaded[0], from: self)
            } else {
                ImageSharingService.shared.shareImages(loaded, from: self)
            }
        }
    }

    func showProgress(_ message: String) {
        if let toast, toast.isProgress {
            toast.setMessage(message)
            return
        }
        showToast(message, isProgress: true)
    }

    func dismissToast() {
        toast?.dismiss()
        toast = nil
    }

    func showToast(
        _ message: String,
        actionTitle: String? = nil,
        duration: TimeInterval? = nil,
        isUndo: Bool = false,
        isProgress: Bool = false,
        action: (() -> Void)? = nil
    ) {
        if toast?.isUndo == true && !isUndo {
            commitPendingDeletion()
        }
        toast?.dismiss()

        let lifetime: TimeInterval? = isProgress ? nil : (duration ?? defaultToastDuration(for: message, hasAction: actionTitle != nil))
        let newToast = GalleryToastView(message: message, actionTitle: actionTitle, isUndo: isUndo, isProgress: isProgress)
        newToast.onAction = { [weak self, weak newToast] in
            action?()
            if self?.toast === newToast {
                self?.dismissToast()
            }
        }
        view.addSubview(newToast)
        NSLayoutConstraint.activate([
            newToast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            newToast.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            newToast.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            newToast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
        toast = newToast
        newToast.present(lifetime: lifetime)
        Announce.say(message)
    }

    /// Reading time for a toast: longer for longer text and when there is a button to reach,
    /// and longer again with VoiceOver, which reads the text out before the person can act.
    func defaultToastDuration(for message: String, hasAction: Bool) -> TimeInterval {
        let base = max(3, 1.5 + Double(message.count) * 0.05) + (hasAction ? 2 : 0)
        return UIAccessibility.isVoiceOverRunning ? base * 2 : base
    }
}

private struct SaveOutcome {
    var saved = 0
    var remaining: [ImageMetadata] = []
    var error: PhotoSavingError?
}

private final class GalleryToastView: UIView {

    let isUndo: Bool
    let isProgress: Bool
    var onAction: (() -> Void)?

    private let label = UILabel()
    private let actionButton = UIButton(type: .system)
    private var expiry: Task<Void, Never>?
    private var isDismissing = false

    private static let maxWidth: CGFloat = 560

    init(message: String, actionTitle: String?, isUndo: Bool, isProgress: Bool) {
        self.isUndo = isUndo
        self.isProgress = isProgress
        super.init(frame: .zero)
        setupUI(message: message, actionTitle: actionTitle)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static let actionTint = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? .brand
            : UIColor.brandText.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
    }

    private func setupUI(message: String, actionTitle: String?) {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .label
        layer.cornerRadius = 16
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 2)

        label.useScaledFont(.subheadline, size: 14, weight: .medium)
        label.textColor = .systemBackground
        label.numberOfLines = 0
        label.text = message
        label.setContentCompressionResistancePriority(.required, for: .vertical)

        let stack = UIStackView(arrangedSubviews: [label])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        if let actionTitle {
            var config = UIButton.Configuration.plain()
            config.title = actionTitle
            config.baseForegroundColor = Self.actionTint
            config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = .scaled(.subheadline, size: 14, weight: .bold)
                return outgoing
            }
            actionButton.configuration = config
            actionButton.setContentHuggingPriority(.required, for: .horizontal)
            actionButton.setContentCompressionResistancePriority(.required, for: .horizontal)
            actionButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            actionButton.addAction(UIAction { [weak self] _ in self?.onAction?() }, for: .touchUpInside)
            actionButton.setupPointerInteraction()
            stack.addArrangedSubview(actionButton)
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: actionTitle == nil ? -16 : -4),
            widthAnchor.constraint(lessThanOrEqualToConstant: Self.maxWidth),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])

        accessibilityViewIsModal = false
        label.isAccessibilityElement = true
    }

    func setMessage(_ message: String) {
        label.text = message
    }

    func present(lifetime: TimeInterval?) {
        alpha = 0
        transform = Motion.isReduced ? .identity : CGAffineTransform(translationX: 0, y: 20)
        Motion.spring(0.3) {
            self.alpha = 1
            self.transform = .identity
        }
        guard let lifetime else { return }
        expiry = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(lifetime * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.dismiss() }
        }
    }

    func dismiss() {
        guard !isDismissing else { return }
        isDismissing = true
        expiry?.cancel()
        Motion.animate(0.25) {
            self.alpha = 0
            self.transform = Motion.isReduced ? .identity : CGAffineTransform(translationX: 0, y: 20)
        } completion: { _ in
            self.removeFromSuperview()
        }
    }
}

protocol GalleryPageViewControllerDelegate: AnyObject {
    func galleryPageDidSelectImage(_ viewController: GalleryPageViewController, image: ImageMetadata)
    func galleryPageDidPerformAction(_ viewController: GalleryPageViewController, action: ImageAction, on image: ImageMetadata)
    func galleryPageDidChangeSelection(_ viewController: GalleryPageViewController, count: Int)
    func galleryPageDidChangeContent(_ viewController: GalleryPageViewController, hasImages: Bool)
    func galleryPageDidRequestCreate(_ viewController: GalleryPageViewController)
}

protocol ImageDetailViewControllerDelegate: AnyObject {
    func imageDetailDidSelectAction(_ viewController: ImageDetailViewController, action: ImageAction, image: ImageMetadata)
}
