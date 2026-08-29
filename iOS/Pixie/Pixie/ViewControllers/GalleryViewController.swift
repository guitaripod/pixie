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

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
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

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(backButtonTapped)
        )
    }

    @objc private func backButtonTapped() {
        HapticsManager.shared.impact(.light)
        navigationController?.popViewController(animated: true)
    }
}

extension GalleryViewController: GalleryPageViewControllerDelegate {
    func galleryPageDidSelectImage(_ viewController: GalleryPageViewController, image: ImageMetadata) {
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
}

extension GalleryViewController: ImageDetailViewControllerDelegate {
    func imageDetailDidSelectAction(_ viewController: ImageDetailViewController, action: ImageAction, image: ImageMetadata) {
        viewController.dismiss(animated: true) {
            self.handleImageAction(action, for: image)
        }
    }
}

private extension GalleryViewController {
    func handleImageAction(_ action: ImageAction, for image: ImageMetadata) {
        switch action {
        case .useForEdit:
            HapticsManager.shared.impact(.light)
            NotificationCenter.default.post(
                name: Notification.Name("ImageSelectedForEdit"),
                object: nil,
                userInfo: ["image": image]
            )
            navigationController?.popViewController(animated: true)
            
        case .copyPrompt:
            HapticsManager.shared.notification(.success)
            UIPasteboard.general.string = image.prompt
            showToast(String(localized: "Prompt copied to clipboard"))
            
        case .download:
            HapticsManager.shared.impact(.light)
            downloadImage(from: image.url)
            
        case .share:
            HapticsManager.shared.impact(.light)
            shareImage(from: image.url)

        case .delete:
            HapticsManager.shared.impact(.light)
            confirmDelete(image)
        }
    }


    func confirmDelete(_ image: ImageMetadata) {
        let alert = UIAlertController(
            title: String(localized: "Delete Image?"),
            message: String(localized: "This permanently deletes the image. This can't be undone."),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: String(localized: "Cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: String(localized: "Delete"), style: .destructive) { [weak self] _ in
            self?.deleteImage(image)
        })
        present(alert, animated: true)
    }

    func deleteImage(_ image: ImageMetadata) {
        Task {
            do {
                try await APIService.shared.deleteImage(id: image.id)
                await MainActor.run {
                    HapticsManager.shared.notification(.success)
                    self.galleryPageVC.removeImage(id: image.id)
                    GalleryCache.shared.clearCache()
                    self.showToast(String(localized: "Image deleted"))
                }
            } catch {
                await MainActor.run {
                    HapticsManager.shared.notification(.error)
                    self.showToast(String(localized: "Could not delete image. Try again later."))
                }
            }
        }
    }


    
    func showToast(_ message: String) {
        let toast = UIView()
        toast.backgroundColor = .systemGray
        toast.layer.cornerRadius = 12
        toast.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        toast.addSubview(label)
        view.addSubview(toast)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: toast.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: toast.trailingAnchor, constant: -16),
            label.topAnchor.constraint(equalTo: toast.topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: toast.bottomAnchor, constant: -12),
            
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -50)
        ])
        
        toast.alpha = 0
        toast.transform = CGAffineTransform(translationX: 0, y: 20)
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            toast.alpha = 1
            toast.transform = .identity
        } completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 2.0) {
                toast.alpha = 0
                toast.transform = CGAffineTransform(translationX: 0, y: 20)
            } completion: { _ in
                toast.removeFromSuperview()
            }
        }
    }
    
    func downloadImage(from urlString: String) {
        Task {
            if let image = await ImageCache.shared.loadImage(from: urlString) {
                UIImageWriteToSavedPhotosAlbum(image, self, #selector(self.image(_:didFinishSavingWithError:contextInfo:)), nil)
            } else {
                await MainActor.run {
                    self.showToast(String(localized: "Failed to download image"))
                }
            }
        }
    }
    
    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if error != nil {
            HapticsManager.shared.notification(.error)
            showToast(String(localized: "Failed to save image"))
        } else {
            HapticsManager.shared.notification(.success)
            showToast(String(localized: "Image saved to Photos"))
        }
    }
    
    func shareImage(from urlString: String) {
        Task {
            if let image = await ImageCache.shared.loadImage(from: urlString) {
                await MainActor.run {
                    let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
                    if let popover = activityVC.popoverPresentationController {
                        popover.sourceView = self.view
                        popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
                        popover.permittedArrowDirections = []
                    }
                    self.present(activityVC, animated: true)
                }
            } else {
                await MainActor.run {
                    self.showToast(String(localized: "Failed to load image for sharing"))
                }
            }
        }
    }
}

protocol GalleryPageViewControllerDelegate: AnyObject {
    func galleryPageDidSelectImage(_ viewController: GalleryPageViewController, image: ImageMetadata)
    func galleryPageDidPerformAction(_ viewController: GalleryPageViewController, action: ImageAction, on image: ImageMetadata)
}

protocol ImageDetailViewControllerDelegate: AnyObject {
    func imageDetailDidSelectAction(_ viewController: ImageDetailViewController, action: ImageAction, image: ImageMetadata)
}