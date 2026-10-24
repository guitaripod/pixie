import UIKit
import Photos

class ImageSharingService {
    
    static let shared = ImageSharingService()
    
    private init() {}
    
    func shareImage(
        _ image: UIImage,
        prompt: String? = nil,
        from viewController: UIViewController,
        sourceView: UIView? = nil,
        completion: ((Bool, UIActivity.ActivityType?) -> Void)? = nil
    ) {
        var items: [Any] = [image]
        
        if let prompt = prompt {
            items.append(String(localized: "Generated with Pixie: \(prompt)"))
        }
        
        presentActivityViewController(
            with: items,
            from: viewController,
            sourceView: sourceView,
            completion: completion
        )
    }
    
    func shareImages(
        _ images: [UIImage],
        from viewController: UIViewController,
        sourceView: UIView? = nil,
        completion: ((Bool, UIActivity.ActivityType?) -> Void)? = nil
    ) {
        let items: [Any] = images + [String(localized: "Generated with Pixie")]
        
        presentActivityViewController(
            with: items,
            from: viewController,
            sourceView: sourceView,
            completion: completion
        )
    }
    
    func shareAndSaveImage(
        _ image: UIImage,
        prompt: String? = nil,
        from viewController: UIViewController,
        sourceView: UIView? = nil
    ) {
        let alertController = UIAlertController(
            title: nil,
            message: nil,
            preferredStyle: .actionSheet
        )
        
        alertController.addAction(UIAlertAction(title: String(localized: "Save to Photos"), style: .default) { _ in
            PhotoSavingService.shared.saveToLibrary([image]) { result in
                switch result {
                case .success:
                    self.showSaveSuccess(in: viewController)
                case .failure(let error):
                    self.showSaveError(error, in: viewController)
                }
            }
        })
        
        alertController.addAction(UIAlertAction(title: String(localized: "Share"), style: .default) { _ in
            self.shareImage(image, prompt: prompt, from: viewController, sourceView: sourceView)
        })
        
        alertController.addAction(UIAlertAction(title: String(localized: "Copy Image"), style: .default) { _ in
            UIPasteboard.general.image = image
            self.showCopySuccess(in: viewController)
        })
        
        alertController.addAction(UIAlertAction(title: String(localized: "Cancel"), style: .cancel))
        
        if let popover = alertController.popoverPresentationController {
            if let sourceView = sourceView {
                popover.sourceView = sourceView
                popover.sourceRect = sourceView.bounds
            } else {
                popover.sourceView = viewController.view
                popover.sourceRect = CGRect(
                    x: viewController.view.bounds.midX,
                    y: viewController.view.bounds.midY,
                    width: 0,
                    height: 0
                )
            }
        }
        
        viewController.present(alertController, animated: true)
    }
    
    private func presentActivityViewController(
        with items: [Any],
        from viewController: UIViewController,
        sourceView: UIView?,
        completion: ((Bool, UIActivity.ActivityType?) -> Void)?
    ) {
        let activityViewController = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        
        activityViewController.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList,
            .openInIBooks
        ]
        
        if let popover = activityViewController.popoverPresentationController {
            if let sourceView = sourceView {
                popover.sourceView = sourceView
                popover.sourceRect = sourceView.bounds
            } else {
                popover.sourceView = viewController.view
                popover.sourceRect = CGRect(
                    x: viewController.view.bounds.midX,
                    y: viewController.view.bounds.midY,
                    width: 0,
                    height: 0
                )
            }
        }
        
        activityViewController.completionWithItemsHandler = { activityType, completed, _, _ in
            completion?(completed, activityType)
        }
        
        viewController.present(activityViewController, animated: true)
    }
    
    private func showSaveSuccess(in viewController: UIViewController) {
        HapticManager.shared.impact(.success)
        presentTransientAlert(
            title: String(localized: "Saved!"),
            message: String(localized: "Saved to Photos"),
            in: viewController
        )
    }
    
    private func showSaveError(_ error: PhotoSavingError, in viewController: UIViewController) {
        HapticManager.shared.impact(.error)
        
        let alert = UIAlertController(
            title: String(localized: "Save Failed"),
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: String(localized: "OK"), style: .cancel))
        
        if case .permissionDenied = error {
            let openSettings = UIAlertAction(title: String(localized: "Open Settings"), style: .default) { _ in
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            alert.addAction(openSettings)
            alert.preferredAction = openSettings
        }
        
        viewController.present(alert, animated: true)
    }
    
    private func showCopySuccess(in viewController: UIViewController) {
        HapticManager.shared.impact(.success)
        presentTransientAlert(
            title: String(localized: "Copied!"),
            message: String(localized: "Image copied to clipboard"),
            in: viewController
        )
    }

    /// How long a self-dismissing alert stays up: never under two seconds, and longer for
    /// longer text so the whole message can be read.
    private func readingTime(title: String, message: String) -> TimeInterval {
        let characters = title.count + message.count
        return min(8, max(2, 1 + Double(characters) * 0.06))
    }

    /// Shows an alert that closes itself after the reading time. The dismissal is a task the
    /// OK button cancels, so a person who closes the alert first never has a later timer
    /// dismiss whatever is on screen by then.
    private func presentTransientAlert(title: String, message: String, in viewController: UIViewController) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let timer = DismissalTimer()
        alert.addAction(UIAlertAction(title: String(localized: "OK"), style: .cancel) { _ in
            timer.task?.cancel()
        })
        viewController.present(alert, animated: true)

        let delay = readingTime(title: title, message: message)
        timer.task = Task { @MainActor [weak alert] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let alert, alert.presentingViewController != nil else { return }
            alert.dismiss(animated: true)
        }
    }
}

private final class DismissalTimer {
    var task: Task<Void, Never>?
}
