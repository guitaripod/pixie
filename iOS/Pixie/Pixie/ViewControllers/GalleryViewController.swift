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
    private var isHeaderTitleHidden = true

    private let selectionBar = GallerySelectionBar()
    private let navTitleLabel = UILabel()

    private static let undoWindow: TimeInterval = 5
    private static let batchConfirmationThreshold = 5

    private lazy var selectButton: UIBarButtonItem = {
        let item = UIBarButtonItem(title: String(localized: "Select"), primaryAction: UIAction { [weak self] _ in
            guard let self else { return }
            self.setSelecting(!self.isSelecting)
        })
        if #available(iOS 26.0, *) {
            item.hidesSharedBackground = true
        }
        item.tintColor = Theme.Color.accentText
        return item
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        setupSelectionBar()

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

    /// The navigation bar resets its title view to fully opaque whenever it puts it in place,
    /// so the intended opacity is applied again after each layout.
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        navTitleLabel.alpha = navTitleTargetAlpha
    }

    private var navTitleTargetAlpha: CGFloat {
        isSelecting || !isHeaderTitleHidden ? 1 : 0
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        commitPendingDeletion()
        setSelecting(false)
    }

    @objc private func appDidEnterBackground() {
        commitPendingDeletion()
    }

    private func setupUI() {
        view.backgroundColor = Theme.Color.canvas

        addChild(galleryPageVC)
        view.addSubview(galleryPageVC.view)
        galleryPageVC.view.translatesAutoresizingMaskIntoConstraints = false
        galleryPageVC.didMove(toParent: self)
        galleryPageVC.delegate = self
        galleryPageVC.view.pinEdges(to: view)
    }

    private func setupNavigationBar() {
        navigationController?.navigationBar.isHidden = false
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.title = String(localized: "Gallery")

        navTitleLabel.apply(.headline)
        navTitleLabel.numberOfLines = 1
        navTitleLabel.accessibilityTraits = .header
        navTitleLabel.text = String(localized: "Gallery")
        navTitleLabel.alpha = 0
        navigationItem.titleView = navTitleLabel

        selectButton.isEnabled = false
        selectButton.accessibilityHint = String(localized: "Choose several images to save, share or delete")
        navigationItem.rightBarButtonItem = selectButton
    }

    private func setupSelectionBar() {
        selectionBar.isHidden = true
        selectionBar.alpha = 0
        selectionBar.onSave = { [weak self] in
            guard let self else { return }
            self.saveImages(self.galleryPageVC.selectedImages)
        }
        selectionBar.onShare = { [weak self] in
            guard let self else { return }
            self.shareImages(self.galleryPageVC.selectedImages)
        }
        selectionBar.onDelete = { [weak self] in self?.deleteSelectedImages() }
        view.addSubview(selectionBar)
        let width = selectionBar.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor, constant: -2 * Theme.Space.lg)
        width.priority = .defaultHigh
        NSLayoutConstraint.activate([
            selectionBar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            selectionBar.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: Theme.Space.lg),
            selectionBar.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -Theme.Space.lg),
            selectionBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Theme.Space.md),
            selectionBar.widthAnchor.constraint(lessThanOrEqualToConstant: Self.selectionBarMaxWidth),
            width,
        ])
        updateSelectionUI(count: 0)
    }

    private static let selectionBarMaxWidth: CGFloat = 520

    private func setSelecting(_ selecting: Bool) {
        guard selecting != isSelecting else { return }
        isSelecting = selecting
        galleryPageVC.setSelecting(selecting)
        setSelectionBarVisible(selecting)
        updateSelectionUI(count: 0)
        Announce.layoutChanged()
    }

    private func setSelectionBarVisible(_ visible: Bool) {
        if visible {
            selectionBar.isHidden = false
            selectionBar.transform = Motion.isReduced ? .identity : CGAffineTransform(translationX: 0, y: 40)
            Motion.spring(0.4, damping: 0.82) {
                self.selectionBar.alpha = 1
                self.selectionBar.transform = .identity
            }
        } else {
            Motion.animate(0.2, options: .curveEaseIn) {
                self.selectionBar.alpha = 0
                self.selectionBar.transform = Motion.isReduced ? .identity : CGAffineTransform(translationX: 0, y: 40)
            } completion: { _ in
                if !self.isSelecting { self.selectionBar.isHidden = true }
            }
        }
    }

    /// Keeps the title, the Select/Done button and the action bar in step with how many
    /// images are chosen, so the count is always in the title and actions only light up
    /// when there is something to act on.
    private func updateSelectionUI(count: Int) {
        selectButton.title = isSelecting ? String(localized: "Done") : String(localized: "Select")
        selectButton.isEnabled = isSelecting || hasImages
        updateNavigationTitle(count: count)
        selectionBar.actionsEnabled = isSelecting && count > 0 && !isBusy
    }

    private func updateNavigationTitle(count: Int) {
        if isSelecting {
            navTitleLabel.text = count == 0 ? String(localized: "Select Items") : String(localized: "\(count) selected")
        } else {
            navTitleLabel.text = String(localized: "Gallery")
        }
        navTitleLabel.alpha = navTitleTargetAlpha
        navTitleLabel.sizeToFit()
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

        if let sheet = previewVC.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = false
            sheet.preferredCornerRadius = Theme.Radius.sheet
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
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

    func galleryPageDidChangeHeaderVisibility(_ viewController: GalleryPageViewController, isTitleHidden: Bool) {
        isHeaderTitleHidden = isTitleHidden
        guard !isSelecting else { return }
        Motion.animate(0.2) { self.updateNavigationTitle(count: 0) }
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
            showToast(String(localized: "Prompt copied to clipboard"), kind: .success)

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
        showToast(message, actionTitle: String(localized: "Undo"), duration: window, kind: .undo) { [weak self] in
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
            : String(localized: "Couldn't delete \(failed.count) images. Try again later."), kind: .error)
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
                : String(localized: "Saved \(images.count) images to Photos"), kind: .success)
            return
        }

        HapticsManager.shared.notification(.error)
        let retry: () -> Void = { [weak self] in self?.saveImages(outcome.remaining) }
        if outcome.saved > 0 {
            showToast(String(localized: "Saved \(outcome.saved) of \(images.count) images"), actionTitle: String(localized: "Retry"), kind: .error, action: retry)
        } else if case .permissionDenied? = outcome.error {
            showToast(String(localized: "Photo library access denied. Please enable access in Settings."), actionTitle: String(localized: "Open Settings"), kind: .error) {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
        } else if let error = outcome.error {
            showToast(error.localizedDescription, actionTitle: String(localized: "Retry"), kind: .error, action: retry)
        } else {
            showToast(String(localized: "Couldn't load image."), actionTitle: String(localized: "Retry"), kind: .error, action: retry)
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
                    showToast(String(localized: "Couldn't load image."), actionTitle: String(localized: "Retry"), kind: .error) { [weak self] in
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
        showToast(message, kind: .progress)
    }

    func dismissToast() {
        toast?.dismiss()
        toast = nil
    }

    func showToast(
        _ message: String,
        actionTitle: String? = nil,
        duration: TimeInterval? = nil,
        kind: GalleryToastKind,
        action: (() -> Void)? = nil
    ) {
        if toast?.isUndo == true && kind != .undo {
            commitPendingDeletion()
        }
        toast?.dismiss()

        let lifetime: TimeInterval? = kind == .progress ? nil : (duration ?? defaultToastDuration(for: message, hasAction: actionTitle != nil))
        let newToast = GalleryToastView(message: message, actionTitle: actionTitle, kind: kind)
        newToast.onAction = { [weak self, weak newToast] in
            action?()
            if self?.toast === newToast {
                self?.dismissToast()
            }
        }
        view.addSubview(newToast)
        let bottom = isSelecting
            ? newToast.bottomAnchor.constraint(equalTo: selectionBar.topAnchor, constant: -Theme.Space.md)
            : newToast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Theme.Space.xxl)
        NSLayoutConstraint.activate([
            newToast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            newToast.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: Theme.Space.lg),
            newToast.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -Theme.Space.lg),
            bottom,
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

protocol GalleryPageViewControllerDelegate: AnyObject {
    func galleryPageDidSelectImage(_ viewController: GalleryPageViewController, image: ImageMetadata)
    func galleryPageDidPerformAction(_ viewController: GalleryPageViewController, action: ImageAction, on image: ImageMetadata)
    func galleryPageDidChangeSelection(_ viewController: GalleryPageViewController, count: Int)
    func galleryPageDidChangeContent(_ viewController: GalleryPageViewController, hasImages: Bool)
    func galleryPageDidRequestCreate(_ viewController: GalleryPageViewController)
    func galleryPageDidChangeHeaderVisibility(_ viewController: GalleryPageViewController, isTitleHidden: Bool)
}

protocol ImageDetailViewControllerDelegate: AnyObject {
    func imageDetailDidSelectAction(_ viewController: ImageDetailViewController, action: ImageAction, image: ImageMetadata)
}
