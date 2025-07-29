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
            items.append("Generated with Pixie: \(prompt)")
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
        let items: [Any] = images + ["Generated with Pixie"]
        
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
        
        alertController.addAction(UIAlertAction(title: "Save to Photos", style: .default) { _ in
            PhotoSavingService.shared.saveImage(image) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self.showSaveSuccess(in: viewController)
                    case .failure(let error):
                        self.showSaveError(error, in: viewController)
                    }
                }
            }
        })
        
        alertController.addAction(UIAlertAction(title: "Share", style: .default) { _ in
            self.shareImage(image, prompt: prompt, from: viewController, sourceView: sourceView)
        })
        
        alertController.addAction(UIAlertAction(title: "Copy Image", style: .default) { _ in
            UIPasteboard.general.image = image
            self.showCopySuccess(in: viewController)
        })
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
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
        let haptics = HapticManager.shared
        haptics.impact(.success)
        
        let alert = UIAlertController(
            title: "Saved!",
            message: "Image saved to your Pixie album",
            preferredStyle: .alert
        )
        
        viewController.present(alert, animated: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            alert.dismiss(animated: true)
        }
    }
    
    private func showSaveError(_ error: PhotoSavingError, in viewController: UIViewController) {
        let haptics = HapticManager.shared
        haptics.impact(.error)
        
        let alert = UIAlertController(
            title: "Save Failed",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        if case .permissionDenied = error {
            alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            })
        }
        
        viewController.present(alert, animated: true)
    }
    
    private func showCopySuccess(in viewController: UIViewController) {
        let haptics = HapticManager.shared
        haptics.impact(.success)
        
        let alert = UIAlertController(
            title: "Copied!",
            message: "Image copied to clipboard",
            preferredStyle: .alert
        )
        
        viewController.present(alert, animated: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            alert.dismiss(animated: true)
        }
    }
    
    private func showPromptCopySuccess(in viewController: UIViewController) {
        let haptics = HapticManager.shared
        haptics.impact(.success)
        
        let alert = UIAlertController(
            title: "Copied!",
            message: "Prompt copied to clipboard",
            preferredStyle: .alert
        )
        
        viewController.present(alert, animated: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            alert.dismiss(animated: true)
        }
    }
}