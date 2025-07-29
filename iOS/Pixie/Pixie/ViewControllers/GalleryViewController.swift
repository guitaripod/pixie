import UIKit

enum GalleryType {
    case personal
    case explore
}

enum ImageAction {
    case useForEdit
    case copyPrompt
    case download
    case share
}

final class GalleryViewController: UIViewController {
    
    private let pageViewController = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
    private let segmentedControl = UISegmentedControl(items: ["My Images", "Explore"])
    private var currentType: GalleryType = .personal
    
    private lazy var personalGalleryVC = GalleryPageViewController(type: .personal)
    private lazy var exploreGalleryVC = GalleryPageViewController(type: .explore)
    
    private var pages: [UIViewController] {
        [personalGalleryVC, exploreGalleryVC]
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupPageViewController()
        setupNavigationBar()
        setupSegmentedControl()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        addChild(pageViewController)
        view.addSubview(pageViewController.view)
        pageViewController.view.translatesAutoresizingMaskIntoConstraints = false
        pageViewController.didMove(toParent: self)
        
        NSLayoutConstraint.activate([
            pageViewController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            pageViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupPageViewController() {
        pageViewController.dataSource = self
        pageViewController.delegate = self
        pageViewController.setViewControllers([personalGalleryVC], direction: .forward, animated: false)
        
        personalGalleryVC.delegate = self
        exploreGalleryVC.delegate = self
    }
    
    private func setupNavigationBar() {
        navigationController?.navigationBar.isHidden = false
        navigationItem.largeTitleDisplayMode = .never
    }
    
    private func setupSegmentedControl() {
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        navigationItem.titleView = segmentedControl
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(backButtonTapped)
        )
    }
    
    @objc private func segmentChanged() {
        HapticsManager.shared.impact(.light)
        
        let selectedIndex = segmentedControl.selectedSegmentIndex
        let direction: UIPageViewController.NavigationDirection = selectedIndex == 0 ? .reverse : .forward
        let targetVC = pages[selectedIndex]
        
        pageViewController.setViewControllers([targetVC], direction: direction, animated: true) { [weak self] _ in
            self?.currentType = selectedIndex == 0 ? .personal : .explore
        }
    }
    
    @objc private func backButtonTapped() {
        HapticsManager.shared.impact(.light)
        navigationController?.popViewController(animated: true)
    }
}

extension GalleryViewController: UIPageViewControllerDataSource {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let index = pages.firstIndex(of: viewController), index > 0 else { return nil }
        return pages[index - 1]
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let index = pages.firstIndex(of: viewController), index < pages.count - 1 else { return nil }
        return pages[index + 1]
    }
}

extension GalleryViewController: UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        guard completed,
              let currentVC = pageViewController.viewControllers?.first,
              let index = pages.firstIndex(of: currentVC) else { return }
        
        segmentedControl.selectedSegmentIndex = index
        currentType = index == 0 ? .personal : .explore
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
            showToast("Prompt copied to clipboard")
            
        case .download:
            HapticsManager.shared.impact(.light)
            downloadImage(from: image.url)
            
        case .share:
            HapticsManager.shared.impact(.light)
            shareImage(from: image.url)
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
        guard let url = URL(string: urlString) else { return }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data = data, let image = UIImage(data: data), error == nil else {
                DispatchQueue.main.async {
                    self?.showToast("Failed to download image")
                }
                return
            }
            
            UIImageWriteToSavedPhotosAlbum(image, self, #selector(self?.image(_:didFinishSavingWithError:contextInfo:)), nil)
        }
        task.resume()
    }
    
    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if error != nil {
            HapticsManager.shared.notification(.error)
            showToast("Failed to save image")
        } else {
            HapticsManager.shared.notification(.success)
            showToast("Image saved to Photos")
        }
    }
    
    func shareImage(from urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        present(activityVC, animated: true)
    }
}

protocol GalleryPageViewControllerDelegate: AnyObject {
    func galleryPageDidSelectImage(_ viewController: GalleryPageViewController, image: ImageMetadata)
    func galleryPageDidPerformAction(_ viewController: GalleryPageViewController, action: ImageAction, on image: ImageMetadata)
}

protocol ImageDetailViewControllerDelegate: AnyObject {
    func imageDetailDidSelectAction(_ viewController: ImageDetailViewController, action: ImageAction, image: ImageMetadata)
}