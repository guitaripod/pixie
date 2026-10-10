import UIKit

final class GalleryHeaderView: UICollectionReusableView {

    static let kind = "GalleryHeader"
    static let identifier = "GalleryHeaderView"

    private let titleLabel = UILabel()
    private let countLabel = UILabel()
    private let stack = UIStackView()
    private var leadingConstraint: NSLayoutConstraint!
    private var trailingConstraint: NSLayoutConstraint!

    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel.setStyledText(String(localized: "Gallery"), .display)
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.5
        titleLabel.accessibilityTraits = .header
        countLabel.apply(.callout)
        countLabel.isHidden = true

        stack.axis = .vertical
        stack.spacing = Theme.Space.xs
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(countLabel)
        addSubview(stack)

        leadingConstraint = stack.leadingAnchor.constraint(equalTo: leadingAnchor)
        trailingConstraint = stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: Theme.Space.sm),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Theme.Space.lg),
            leadingConstraint,
            trailingConstraint,
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// The count line stays hidden until the first page has arrived, so the title never
    /// shows a misleading "0 images" while the grid is still loading. In a short window the
    /// count stands beside the title instead of under it, which gives a row back to the grid.
    func configure(count: Int?, horizontalPadding: CGFloat, isShort: Bool = false) {
        stack.axis = isShort ? .horizontal : .vertical
        stack.alignment = isShort ? .lastBaseline : .fill
        stack.spacing = isShort ? Theme.Space.md : Theme.Space.xs
        leadingConstraint.constant = horizontalPadding
        trailingConstraint.constant = -horizontalPadding
        if let count, count > 0 {
            countLabel.text = String(localized: "\(count) images")
            countLabel.isHidden = false
        } else {
            countLabel.isHidden = true
        }
    }
}
