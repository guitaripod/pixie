import UIKit
import PhotosUI
import UniformTypeIdentifiers

extension ChatGenerationViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view is UIButton || touch.view is UICollectionViewCell {
            return false
        }
        return true
    }
}



extension ChatGenerationViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let result = results.first else {
            pendingPreset = nil
            return
        }
        result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
            DispatchQueue.main.async {
                guard let image = image as? UIImage else {
                    self?.pendingPreset = nil
                    AppLogger.error("Picked photo could not be loaded: \(error?.localizedDescription ?? "no image")", category: .ui)
                    return
                }
                self?.photoPicked(image)
            }
        }
    }
}



extension ChatGenerationViewController: ChatTableViewDelegate {
    func chatTableView(_ chatTableView: ChatTableView, didTapImageAt index: Int, in message: ChatMessage) {
        haptics.impact(.click)
        guard let images = message.images,
              index < images.count else { return }
        let image = images[index]
        let previewVC = ImagePreviewViewController(image: image)
        previewVC.modalPresentationStyle = .pageSheet
        present(previewVC, animated: true)
    }
    func chatTableView(_ chatTableView: ChatTableView, didLongPressImageAt index: Int, in message: ChatMessage) {
    }
    func chatTableView(_ chatTableView: ChatTableView, didSelectImageForEdit index: Int, in message: ChatMessage) {
        haptics.impact(.click)
        guard let images = message.images,
              index < images.count else { return }
        let image = images[index]
        switchToEditMode(with: image, url: nil)
    }
    func chatTableView(_ chatTableView: ChatTableView, didRequest action: ResultAction, imageIndex: Int?, for message: ChatMessage, from sourceView: UIView) {
        guard let images = message.images, let first = images.first else { return }
        let targets = imageIndex.flatMap { images.indices.contains($0) ? [images[$0]] : nil } ?? images
        switch action {
        case .save:
            PhotoSavingService.shared.saveToLibrary(targets) { [weak self] result in
                switch result {
                case .success:
                    self?.showBatchSaveSuccess(count: targets.count)
                    self?.chatView.showActionSucceeded(.save, for: message)
                case .failure(let error):
                    self?.showBatchSaveError(error)
                }
            }
        case .share:
            ImageSharingService.shared.shareImages(targets, from: self, sourceView: sourceView) { [weak self] completed, _ in
                if completed { self?.chatView.showActionSucceeded(.share, for: message) }
            }
        case .beforeAfter:
            guard let source = message.sourceImage else { return }
            let composite = BeforeAfterComposer.compose(before: source, after: targets.first ?? first)
            ImageSharingService.shared.shareImage(composite, from: self, sourceView: sourceView)
        }
    }
    private func showBatchSaveSuccess(count: Int) {
        haptics.impact(.success)
        Announce.say(String(localized: "Saved to Photos"))
    }
    private func showBatchSaveError(_ error: PhotoSavingError) {
        haptics.impact(.error)
        let alert = UIAlertController(
            title: String(localized: "Save Failed"),
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: String(localized: "OK"), style: .default))
        if case .permissionDenied = error {
            alert.addAction(UIAlertAction(title: String(localized: "Open Settings"), style: .default) { _ in
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            })
        }
        present(alert, animated: true)
    }
}

extension ChatGenerationViewController: UIDropInteractionDelegate {
    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        return session.hasItemsConforming(toTypeIdentifiers: [UTType.image.identifier])
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        return UIDropProposal(operation: .copy)
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        session.loadObjects(ofClass: UIImage.self) { [weak self] items in
            guard let images = items as? [UIImage], let image = images.first else { return }
            DispatchQueue.main.async {
                self?.presentImagePreviewForEdit(image)
            }
        }
    }
}

extension ChatGenerationViewController: UIDragInteractionDelegate {
    func dragInteraction(_ interaction: UIDragInteraction, itemsForBeginning session: UIDragSession) -> [UIDragItem] {
        guard let lastMessage = viewModel.messages.last,
              !lastMessage.isUser,
              let images = lastMessage.images,
              let image = images.first else { return [] }
        
        let provider = NSItemProvider(object: image)
        let dragItem = UIDragItem(itemProvider: provider)
        dragItem.localObject = image
        return [dragItem]
    }
}
