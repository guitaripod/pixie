import UIKit

final class GallerySelectionBar: UIView {

    var onSave: (() -> Void)?
    var onShare: (() -> Void)?
    var onDelete: (() -> Void)?

    var actionsEnabled = false {
        didSet { buttons.forEach { $0.isEnabled = actionsEnabled } }
    }

    private let glass = SurfaceView(style: .raised, cornerRadius: Theme.Radius.xl)
    private let stack = UIStackView()
    private lazy var saveButton = PixieButton(style: .secondary, size: .medium, title: String(localized: "Save")) { [weak self] in self?.onSave?() }
    private lazy var shareButton = PixieButton(style: .secondary, size: .medium, title: String(localized: "Share")) { [weak self] in self?.onShare?() }
    private lazy var deleteButton = PixieButton(style: .destructive, size: .medium, title: String(localized: "Delete")) { [weak self] in self?.onDelete?() }
    private var buttons: [PixieButton] { [saveButton, shareButton, deleteButton] }

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(glass)
        glass.pinEdges(to: self)

        saveButton.accessibilityLabel = String(localized: "Save to Photos")
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = Theme.Space.sm
        stack.translatesAutoresizingMaskIntoConstraints = false
        buttons.forEach { stack.addArrangedSubview($0) }
        glass.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: glass.contentView.topAnchor, constant: Theme.Space.sm),
            stack.bottomAnchor.constraint(equalTo: glass.contentView.bottomAnchor, constant: -Theme.Space.sm),
            stack.leadingAnchor.constraint(equalTo: glass.contentView.leadingAnchor, constant: Theme.Space.sm),
            stack.trailingAnchor.constraint(equalTo: glass.contentView.trailingAnchor, constant: -Theme.Space.sm),
        ])
        buttons.forEach { $0.isEnabled = false }
        updateAxis()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
            updateAxis()
        }
    }

    /// Three labelled buttons no longer fit in a row at accessibility text sizes, so they stack.
    private func updateAxis() {
        let stacked = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        stack.axis = stacked ? .vertical : .horizontal
        stack.distribution = stacked ? .fill : .fillEqually
    }
}
