import UIKit

final class GalleryImageCell: UICollectionViewCell {
    
    static let identifier = "GalleryImageCell"
    
    
    private let imageView = UIImageView()
    private let gradientView = UIView()
    private let promptLabel = UILabel()
    private let timeLabel = UILabel()
    private let creditsStackView = UIStackView()
    private let creditsIcon = UIImageView()
    private let creditsLabel = UILabel()
    private let gradientLayer = CAGradientLayer()
    
    private var currentImageMetadata: ImageMetadata?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        promptLabel.text = nil
        timeLabel.text = nil
        creditsLabel.text = nil
        currentImageMetadata = nil
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = gradientView.bounds
    }
    
    private func setupUI() {
        contentView.backgroundColor = .black
        contentView.clipsToBounds = true
        
        if UIDevice.isPad {
            setupPointerInteraction()
        }
        
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .systemGray6
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)
        
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(gradientView)
        
        gradientLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.7).cgColor
        ]
        gradientLayer.locations = [0.0, 1.0]
        gradientView.layer.addSublayer(gradientLayer)
        
        promptLabel.font = .systemFont(ofSize: 10, weight: .medium)
        promptLabel.textColor = .white
        promptLabel.numberOfLines = 2
        promptLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(promptLabel)
        
        timeLabel.font = .systemFont(ofSize: 9)
        timeLabel.textColor = .white.withAlphaComponent(0.7)
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(timeLabel)
        
        creditsStackView.axis = .horizontal
        creditsStackView.spacing = 4
        creditsStackView.alignment = .center
        creditsStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(creditsStackView)
        
        creditsIcon.image = UIImage(systemName: "star.fill")
        creditsIcon.tintColor = .white.withAlphaComponent(0.7)
        creditsIcon.contentMode = .scaleAspectFit
        creditsIcon.translatesAutoresizingMaskIntoConstraints = false
        
        creditsLabel.font = .systemFont(ofSize: 9)
        creditsLabel.textColor = .white.withAlphaComponent(0.7)
        
        creditsStackView.addArrangedSubview(creditsIcon)
        creditsStackView.addArrangedSubview(creditsLabel)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            gradientView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            gradientView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            gradientView.heightAnchor.constraint(equalToConstant: 60),
            
            promptLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            promptLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            promptLabel.bottomAnchor.constraint(equalTo: timeLabel.topAnchor, constant: -2),
            
            timeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            timeLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            creditsStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            creditsStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            creditsIcon.widthAnchor.constraint(equalToConstant: 10),
            creditsIcon.heightAnchor.constraint(equalToConstant: 10)
        ])
    }
    
    
    func configure(with metadata: ImageMetadata) {
        currentImageMetadata = metadata
        promptLabel.text = metadata.prompt
        timeLabel.text = formatTimeAgo(metadata.createdAt)
        
        if let creditsUsed = metadata.metadata?.creditsUsed {
            creditsLabel.text = "\(creditsUsed)"
            creditsStackView.isHidden = false
        } else {
            creditsStackView.isHidden = true
        }
        
        loadImage(from: metadata.thumbnailUrl ?? metadata.url)
    }
    
    private func loadImage(from urlString: String) {
        Task { @MainActor in
            if let image = await ImageCache.shared.loadImage(from: urlString) {
                if self.currentImageMetadata?.url == urlString || self.currentImageMetadata?.thumbnailUrl == urlString {
                    self.imageView.image = image
                }
            }
        }
    }
    
    
    private func formatTimeAgo(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = formatter.date(from: dateString) else { return dateString }
        
        let now = Date()
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date, to: now)
        
        if let years = components.year, years > 0 {
            return "\(years)y ago"
        } else if let months = components.month, months > 0 {
            return "\(months)mo ago"
        } else if let days = components.day, days > 0 {
            return "\(days)d ago"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)h ago"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)m ago"
        } else {
            return "Just now"
        }
    }
    
    private func calculateCredits(for quality: String, size: String) -> Int {
        let isHighQuality = quality.lowercased() == "high"
        let isLargeSize = size.contains("1792") || size.contains("1024")
        
        if isHighQuality {
            return isLargeSize ? 80 : 50
        } else {
            return isLargeSize ? 8 : 4
        }
    }
}