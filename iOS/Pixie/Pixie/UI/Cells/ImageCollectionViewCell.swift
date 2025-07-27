import UIKit

class ImageCollectionViewCell: UICollectionViewCell {
    
    struct Configuration: Hashable {
        let imageURL: String
        let prompt: String
        let creditsUsed: Int?
    }
    
    private let imageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.backgroundColor = .systemGray6
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let promptLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .caption1)
        label.textColor = .label
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let creditsLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .caption2)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.7).cgColor
        ]
        layer.locations = [0.6, 1.0]
        return layer
    }()
    
    private var currentImageURL: String?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        promptLabel.text = nil
        creditsLabel.text = nil
        currentImageURL = nil
    }
    
    private func setupViews() {
        contentView.layer.cornerRadius = 12
        contentView.clipsToBounds = true
        
        contentView.addSubview(imageView)
        contentView.layer.addSublayer(gradientLayer)
        contentView.addSubview(promptLabel)
        contentView.addSubview(creditsLabel)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            promptLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            promptLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            promptLabel.bottomAnchor.constraint(equalTo: creditsLabel.topAnchor, constant: -4),
            
            creditsLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            creditsLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            creditsLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }
    
    func configure(with configuration: Configuration) {
        promptLabel.text = configuration.prompt
        
        if let credits = configuration.creditsUsed {
            creditsLabel.text = "\(credits) credits"
            creditsLabel.isHidden = false
        } else {
            creditsLabel.isHidden = true
        }
        
        currentImageURL = configuration.imageURL
        loadImage(from: configuration.imageURL)
    }
    
    private func loadImage(from urlString: String) {
        // TODO: Implement proper image loading with caching
        imageView.backgroundColor = .systemGray5
    }
    
    static func registration() -> UICollectionView.CellRegistration<ImageCollectionViewCell, Configuration> {
        UICollectionView.CellRegistration<ImageCollectionViewCell, Configuration> { cell, indexPath, configuration in
            cell.configure(with: configuration)
        }
    }
}