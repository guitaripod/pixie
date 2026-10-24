import UIKit

class ImagePreviewViewController: UIViewController {
    private let imageView = UIImageView()
    private let scrollView = UIScrollView()
    private let scrimView = GradientView(colors: [UIColor.black.withAlphaComponent(0), UIColor.black.withAlphaComponent(0.7)], start: CGPoint(x: 0.5, y: 0), end: CGPoint(x: 0.5, y: 1))
    private lazy var editButton = PixieButton(style: .primary, size: .large, title: String(localized: "Edit Image"), symbol: "wand.and.stars") { [weak self] in
        self?.editButtonTapped()
    }
    private var image: UIImage
    var onEditConfirmed: (() -> Void)?
    init(image: UIImage) {
        self.image = image
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupGestures()
        setupModalPresentation()
    }
    private func setupUI() {
        view.backgroundColor = .black
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.describe(String(localized: "Generated image"), hint: String(localized: "Double tap to zoom"), traits: .image)
        scrollView.addSubview(imageView)
        if onEditConfirmed != nil {
            setupEditButton()
        }
    }
    private func setupEditButton() {
        scrimView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrimView)
        editButton.accessibilityLabel = String(localized: "Edit this image")
        editButton.setupPointerInteraction()
        view.addSubview(editButton)
    }
    private func setupConstraints() {
        var constraints = [
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ]
        if onEditConfirmed != nil {
            constraints.append(contentsOf: [
                editButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Theme.Space.xl),
                editButton.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
                editButton.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: Theme.Space.xl),
                editButton.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -Theme.Space.xl),
                editButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
                editButton.widthAnchor.constraint(lessThanOrEqualToConstant: Theme.Width.button),
                scrimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                scrimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                scrimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                scrimView.topAnchor.constraint(equalTo: editButton.topAnchor, constant: -Theme.Space.xxxl)
            ])
        }
        NSLayoutConstraint.activate(constraints)
    }
    private func setupGestures() {
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)
    }
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if scrollView.zoomScale > 1.0 {
            scrollView.setZoomScale(1.0, animated: true)
        } else {
            let point = gesture.location(in: imageView)
            let rect = CGRect(x: point.x, y: point.y, width: 1, height: 1)
            scrollView.zoom(to: rect, animated: true)
        }
    }
    @objc private func editButtonTapped() {
        HapticManager.shared.impact(.click)
        onEditConfirmed?()
    }
    override func accessibilityPerformEscape() -> Bool {
        dismiss(animated: true)
        return true
    }
    private func setupModalPresentation() {
        if #available(iOS 15.0, *) {
            if let sheet = sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
                sheet.preferredCornerRadius = Theme.Radius.sheet
                sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            }
        }
    }
}

extension ImagePreviewViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
}