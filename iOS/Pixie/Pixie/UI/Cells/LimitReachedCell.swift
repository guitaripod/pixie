import UIKit

final class LimitReachedCell: UICollectionViewCell {
    
    static let identifier = "LimitReachedCell"
    
    private let cardView = SurfaceView(style: .sunken, cornerRadius: Theme.Radius.lg)
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.backgroundColor = .clear
        
        contentView.addSubview(cardView)
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = Theme.Space.sm
        stackView.translatesAutoresizingMaskIntoConstraints = false
        cardView.contentView.addSubview(stackView)
        
        iconImageView.image = UIImage(systemName: "info.circle.fill")
        iconImageView.tintColor = Theme.Color.inkTertiary
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.hideFromAccessibility()
        
        titleLabel.apply(.headline)
        titleLabel.textAlignment = .center
        
        subtitleLabel.apply(.footnote)
        subtitleLabel.text = String(localized: "Refresh to see more recent images")
        subtitleLabel.textAlignment = .center
        
        stackView.addArrangedSubview(iconImageView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)
        
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Theme.Space.sm),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Theme.Space.sm),
            
            stackView.topAnchor.constraint(equalTo: cardView.contentView.topAnchor, constant: Theme.Space.lg),
            stackView.leadingAnchor.constraint(equalTo: cardView.contentView.leadingAnchor, constant: Theme.Space.lg),
            stackView.trailingAnchor.constraint(equalTo: cardView.contentView.trailingAnchor, constant: -Theme.Space.lg),
            stackView.bottomAnchor.constraint(equalTo: cardView.contentView.bottomAnchor, constant: -Theme.Space.lg),
            
            iconImageView.widthAnchor.constraint(equalToConstant: 40),
            iconImageView.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        isAccessibilityElement = true
        accessibilityTraits = .staticText
    }
    
    /// Shows the number of images the pager lets the person page through before this cell
    /// appears, taken from the pager's own limit rather than written into the text.
    func configure(limit: Int) {
        titleLabel.text = String(localized: "Reached viewing limit (\(limit) images)")
        accessibilityLabel = [titleLabel.text, subtitleLabel.text].compactMap { $0 }.joined(separator: ". ")
    }
}