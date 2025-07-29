import UIKit

final class ImageDetailViewController: UIViewController {
    
    weak var delegate: ImageDetailViewControllerDelegate?
    
    private let image: ImageMetadata
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let imageView = UIImageView()
    private let actionsStackView = UIStackView()
    private let detailsStackView = UIStackView()
    
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
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.backgroundColor = .secondarySystemBackground
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)
        
        setupActionButtons()
        contentView.addSubview(actionsStackView)
        
        setupDetailsSection()
        contentView.addSubview(detailsStackView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            imageView.heightAnchor.constraint(lessThanOrEqualToConstant: 400),
            
            actionsStackView.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 16),
            actionsStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            actionsStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            detailsStackView.topAnchor.constraint(equalTo: actionsStackView.bottomAnchor, constant: 24),
            detailsStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            detailsStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            detailsStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
        
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch))
        imageView.isUserInteractionEnabled = true
        imageView.addGestureRecognizer(pinchGesture)
    }
    
    private func setupActionButtons() {
        actionsStackView.axis = .horizontal
        actionsStackView.distribution = .fillEqually
        actionsStackView.spacing = 12
        actionsStackView.translatesAutoresizingMaskIntoConstraints = false
        
        let editButton = createActionButton(
            title: "Edit",
            image: UIImage(systemName: "pencil"),
            action: #selector(editTapped)
        )
        
        let copyButton = createActionButton(
            title: "Copy",
            image: UIImage(systemName: "doc.on.doc"),
            action: #selector(copyTapped)
        )
        
        let downloadButton = createActionButton(
            title: "Save",
            image: UIImage(systemName: "arrow.down.to.line"),
            action: #selector(downloadTapped)
        )
        
        let shareButton = createActionButton(
            title: "Share",
            image: UIImage(systemName: "square.and.arrow.up"),
            action: #selector(shareTapped)
        )
        
        actionsStackView.addArrangedSubview(editButton)
        actionsStackView.addArrangedSubview(copyButton)
        actionsStackView.addArrangedSubview(downloadButton)
        actionsStackView.addArrangedSubview(shareButton)
    }
    
    private func createActionButton(title: String, image: UIImage?, action: Selector) -> UIButton {
        var config = UIButton.Configuration.tinted()
        config.title = title
        config.image = image
        config.imagePlacement = .top
        config.imagePadding = 4
        config.baseForegroundColor = UIColor(red: 103/255, green: 80/255, blue: 164/255, alpha: 1.0)
        config.baseBackgroundColor = UIColor(red: 103/255, green: 80/255, blue: 164/255, alpha: 0.1)
        config.cornerStyle = .medium
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 12, weight: .medium)
            return outgoing
        }
        
        let button = UIButton(configuration: config)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 60).isActive = true
        
        button.configurationUpdateHandler = { button in
            switch button.state {
            case .highlighted:
                button.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            default:
                button.transform = .identity
            }
        }
        
        return button
    }
    
    private func setupDetailsSection() {
        detailsStackView.axis = .vertical
        detailsStackView.spacing = 16
        detailsStackView.translatesAutoresizingMaskIntoConstraints = false
        
        addDetailRow(title: "Prompt", value: image.prompt)
        addDetailRow(title: "Created", value: formatDate(image.createdAt))
        
        if let metadata = image.metadata {
            if let model = metadata.model {
                addDetailRow(title: "Model", value: model)
            }
            addDetailRow(title: "Size", value: "\(metadata.width)x\(metadata.height)")
            if let quality = metadata.quality {
                addDetailRow(title: "Quality", value: quality.capitalized)
            }
            addDetailRow(title: "Credits Used", value: "\(metadata.creditsUsed)")
            addDetailRow(title: "Format", value: metadata.format.uppercased())
        }
    }
    
    private func addDetailRow(title: String, value: String) {
        let containerView = UIView()
        containerView.backgroundColor = .secondarySystemBackground
        containerView.layer.cornerRadius = 12
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = .secondaryLabel
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 16)
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
        
        detailsStackView.addArrangedSubview(containerView)
    }
    
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let view = gesture.view else { return }
        
        switch gesture.state {
        case .changed:
            let scale = gesture.scale
            view.transform = CGAffineTransform(scaleX: scale, y: scale)
        case .ended, .cancelled:
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
                view.transform = .identity
            }
        default:
            break
        }
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
        guard let url = URL(string: image.url) else { return }
        
        if let cachedImage = ImageCache.shared.image(for: image.url) {
            imageView.image = cachedImage
            updateImageViewHeight(for: cachedImage)
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self,
                  let data = data,
                  let loadedImage = UIImage(data: data),
                  error == nil else { return }
            
            ImageCache.shared.setImage(loadedImage, for: self.image.url)
            
            DispatchQueue.main.async {
                self.imageView.image = loadedImage
                self.updateImageViewHeight(for: loadedImage)
            }
        }.resume()
    }
    
    private func updateImageViewHeight(for image: UIImage) {
        let aspectRatio = image.size.height / image.size.width
        let width = view.bounds.width - 32
        let height = min(width * aspectRatio, 400)
        
        imageView.constraints.first { $0.firstAttribute == .height }?.constant = height
        view.layoutIfNeeded()
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
    
}