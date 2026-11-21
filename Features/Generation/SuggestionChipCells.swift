import UIKit

class ModifierChipCell: UICollectionViewCell {
    static let reuseIdentifier = "ModifierChipCell"
    private var chip: ChipView?
    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = true
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func prepareForReuse() {
        super.prepareForReuse()
        chip?.removeFromSuperview()
        chip = nil
    }
    func configure(with text: String, isSelected: Bool = false, symbol: String? = nil, category: String) {
        chip?.removeFromSuperview()
        let chip = ChipView(title: text, symbol: symbol, isSelected: isSelected)
        chip.isUserInteractionEnabled = false
        chip.isAccessibilityElement = false
        contentView.addSubview(chip)
        NSLayoutConstraint.activate([
            chip.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            chip.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            chip.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
        self.chip = chip
        accessibilityLabel = String(localized: "\(category): \(text)")
        accessibilityTraits = isSelected ? [.button, .selected] : .button
    }
}


/// A modifier category tab: single-select, drawn as an accent-outlined pill so it reads as a tab
/// beside the filled toggle chips.
class CategoryChipCell: UICollectionViewCell {
    static let reuseIdentifier = "CategoryChipCell"
    let label = UILabel()
    private let pill = PillView()
    override var isSelected: Bool {
        didSet {
            updateAppearance()
        }
    }
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    private func setupUI() {
        pill.translatesAutoresizingMaskIntoConstraints = false
        pill.layer.borderWidth = 1.5
        pill.layer.cornerCurve = .continuous
        contentView.addSubview(pill)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.apply(.subhead)
        label.numberOfLines = 1
        label.textAlignment = .center
        pill.addSubview(label)
        NSLayoutConstraint.activate([
            pill.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            pill.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            pill.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            pill.heightAnchor.constraint(greaterThanOrEqualToConstant: 38),
            label.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -14),
            label.topAnchor.constraint(equalTo: pill.topAnchor, constant: 9),
            label.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -9)
        ])
        isAccessibilityElement = true
        updateAppearance()
    }
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateAppearance()
    }
    func configure(with text: String) {
        label.text = text
        accessibilityLabel = text
    }
    private func updateAppearance() {
        accessibilityTraits = isSelected ? [.button, .selected] : .button
        Motion.animate(0.2) {
            self.pill.backgroundColor = self.isSelected ? Theme.Color.accentSoft : .clear
            self.pill.layer.borderColor = (self.isSelected ? Theme.Color.accent : Theme.Color.line).resolvedColor(with: self.traitCollection).cgColor
            self.label.textColor = self.isSelected ? Theme.Color.accentText : Theme.Color.ink
        }
    }
}


private final class PillView: UIView {
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }
}
