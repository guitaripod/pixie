import UIKit

final class HitSlopButton: UIButton {
    var hitInsets = UIEdgeInsets.zero

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.inset(by: UIEdgeInsets(top: -hitInsets.top, left: -hitInsets.left, bottom: -hitInsets.bottom, right: -hitInsets.right)).contains(point)
    }
}

final class ComposerPhotoSlot: UIView {
    static let size = CGSize(width: 48, height: 44)
    private static let thumbnailSide: CGFloat = 40

    var onAdd: (() -> Void)?
    var onRemove: (() -> Void)?

    private let addButton = HitSlopButton(type: .custom)
    private let thumbnail = UIImageView()
    private let removeButton = HitSlopButton(type: .custom)
    private let removeDisc = UIView()
    private let removeGlyph = UIImageView(image: UIImage(systemName: "xmark"))

    var image: UIImage? {
        didSet { applyImage() }
    }

    var isActionEnabled = true {
        didSet {
            addButton.isEnabled = isActionEnabled
            removeButton.isEnabled = isActionEnabled
            alpha = isActionEnabled ? 1 : 0.5
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        setupAddButton()
        setupThumbnail()
        setupRemoveButton()
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.size.width),
            heightAnchor.constraint(equalToConstant: Self.size.height),
        ])
        applyImage()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        thumbnail.layer.borderColor = Theme.Color.line.resolvedColor(with: traitCollection).cgColor
        removeDisc.layer.borderColor = Theme.Color.surfaceRaised.resolvedColor(with: traitCollection).cgColor
    }

    private func setupAddButton() {
        let side = Self.thumbnailSide
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.backgroundColor = Theme.Color.accentSoft
        addButton.layer.cornerRadius = side / 2
        addButton.setImage(UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)), for: .normal)
        addButton.tintColor = Theme.Color.accentText
        addButton.accessibilityLabel = String(localized: "Choose Image")
        addButton.addAction(UIAction { [weak self] _ in
            HapticManager.shared.impact(.click)
            self?.onAdd?()
        }, for: .touchUpInside)
        addSubview(addButton)
        NSLayoutConstraint.activate([
            addButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            addButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            addButton.widthAnchor.constraint(equalToConstant: side),
            addButton.heightAnchor.constraint(equalToConstant: side),
        ])
        addButton.hitInsets = UIEdgeInsets(top: 2, left: 2, bottom: 2, right: 6)
    }

    private func setupThumbnail() {
        let side = Self.thumbnailSide
        thumbnail.translatesAutoresizingMaskIntoConstraints = false
        thumbnail.contentMode = .scaleAspectFill
        thumbnail.clipsToBounds = true
        thumbnail.layer.cornerRadius = Theme.Radius.sm
        thumbnail.layer.cornerCurve = .continuous
        thumbnail.layer.borderWidth = 1
        thumbnail.accessibilityIgnoresInvertColors = true
        thumbnail.describe(String(localized: "Photo to edit"), traits: .image)
        addSubview(thumbnail)
        NSLayoutConstraint.activate([
            thumbnail.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            thumbnail.centerYAnchor.constraint(equalTo: centerYAnchor),
            thumbnail.widthAnchor.constraint(equalToConstant: side),
            thumbnail.heightAnchor.constraint(equalToConstant: side),
        ])
    }

    private func setupRemoveButton() {
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        removeButton.accessibilityLabel = String(localized: "Remove photo")
        removeButton.hitInsets = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        removeDisc.translatesAutoresizingMaskIntoConstraints = false
        removeDisc.isUserInteractionEnabled = false
        removeDisc.backgroundColor = Theme.Color.ink
        removeDisc.layer.cornerRadius = 10
        removeDisc.layer.borderWidth = 1.5
        removeGlyph.translatesAutoresizingMaskIntoConstraints = false
        removeGlyph.tintColor = Theme.Color.canvas
        removeGlyph.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 9, weight: .heavy)
        removeButton.addSubview(removeDisc)
        removeButton.addSubview(removeGlyph)
        removeButton.addAction(UIAction { [weak self] _ in
            HapticManager.shared.impact(.click)
            self?.onRemove?()
        }, for: .touchUpInside)
        addSubview(removeButton)
        NSLayoutConstraint.activate([
            removeButton.widthAnchor.constraint(equalToConstant: 20),
            removeButton.heightAnchor.constraint(equalToConstant: 20),
            removeButton.centerXAnchor.constraint(equalTo: thumbnail.trailingAnchor, constant: -1),
            removeButton.centerYAnchor.constraint(equalTo: thumbnail.topAnchor, constant: 1),
            removeDisc.topAnchor.constraint(equalTo: removeButton.topAnchor),
            removeDisc.bottomAnchor.constraint(equalTo: removeButton.bottomAnchor),
            removeDisc.leadingAnchor.constraint(equalTo: removeButton.leadingAnchor),
            removeDisc.trailingAnchor.constraint(equalTo: removeButton.trailingAnchor),
            removeGlyph.centerXAnchor.constraint(equalTo: removeButton.centerXAnchor),
            removeGlyph.centerYAnchor.constraint(equalTo: removeButton.centerYAnchor),
        ])
    }

    private func applyImage() {
        thumbnail.image = image
        let hasPhoto = image != nil
        thumbnail.isHidden = !hasPhoto
        removeButton.isHidden = !hasPhoto
        addButton.isHidden = hasPhoto
    }
}

final class ComposerOptionsButton: UIControl {
    private let disc = UIView()
    private let iconView = UIImageView(image: UIImage(systemName: "slider.horizontal.3"))
    private let dot = UIView()

    var showsChangeDot = false {
        didSet { dot.isHidden = !showsChangeDot }
    }

    override var isSelected: Bool {
        didSet { applyState() }
    }

    override var isEnabled: Bool {
        didSet { alpha = isEnabled ? 1 : 0.4 }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        disc.translatesAutoresizingMaskIntoConstraints = false
        disc.isUserInteractionEnabled = false
        disc.layer.cornerRadius = 18
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.backgroundColor = Theme.Color.accent
        dot.layer.cornerRadius = 4
        dot.layer.borderWidth = 1.5
        dot.isHidden = true
        dot.isUserInteractionEnabled = false
        addSubview(disc)
        addSubview(iconView)
        addSubview(dot)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 40),
            heightAnchor.constraint(equalToConstant: 44),
            disc.centerXAnchor.constraint(equalTo: centerXAnchor),
            disc.centerYAnchor.constraint(equalTo: centerYAnchor),
            disc.widthAnchor.constraint(equalToConstant: 36),
            disc.heightAnchor.constraint(equalToConstant: 36),
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8),
            dot.centerXAnchor.constraint(equalTo: disc.trailingAnchor, constant: -4),
            dot.centerYAnchor.constraint(equalTo: disc.topAnchor, constant: 4),
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
        applyState()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var isHighlighted: Bool {
        didSet {
            guard oldValue != isHighlighted, !Motion.isReduced else { return }
            Motion.animate(0.12, options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.92, y: 0.92) : .identity
            }
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyState()
    }

    private func applyState() {
        Motion.animate(0.2, options: .beginFromCurrentState) {
            self.disc.backgroundColor = self.isSelected ? Theme.Color.accentSoft : .clear
            self.iconView.tintColor = self.isSelected ? Theme.Color.accentText : Theme.Color.inkSecondary
        }
        dot.layer.borderColor = Theme.Color.surfaceRaised.resolvedColor(with: traitCollection).cgColor
    }
}

final class ComposerSendButton: UIControl {
    enum Mode {
        case disabled
        case ready
        case stop
    }

    private let gradient = GradientView()
    private let flatDisc = UIView()
    private let iconView = UIImageView()
    private(set) var mode = Mode.disabled

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        let side: CGFloat = 40
        flatDisc.translatesAutoresizingMaskIntoConstraints = false
        flatDisc.isUserInteractionEnabled = false
        flatDisc.layer.cornerRadius = side / 2
        gradient.translatesAutoresizingMaskIntoConstraints = false
        gradient.cornerRadius = side / 2
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .center
        addSubview(flatDisc)
        addSubview(gradient)
        addSubview(iconView)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 44),
            heightAnchor.constraint(equalToConstant: 44),
            flatDisc.centerXAnchor.constraint(equalTo: centerXAnchor),
            flatDisc.centerYAnchor.constraint(equalTo: centerYAnchor),
            flatDisc.widthAnchor.constraint(equalToConstant: side),
            flatDisc.heightAnchor.constraint(equalToConstant: side),
            gradient.centerXAnchor.constraint(equalTo: centerXAnchor),
            gradient.centerYAnchor.constraint(equalTo: centerYAnchor),
            gradient.widthAnchor.constraint(equalToConstant: side),
            gradient.heightAnchor.constraint(equalToConstant: side),
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        isAccessibilityElement = true
        apply(.disabled, animated: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var isHighlighted: Bool {
        didSet {
            guard oldValue != isHighlighted, !Motion.isReduced else { return }
            Motion.animate(0.12, options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.92, y: 0.92) : .identity
            }
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        apply(mode, animated: false)
    }

    func apply(_ newMode: Mode, animated: Bool) {
        mode = newMode
        isEnabled = newMode != .disabled
        accessibilityTraits = newMode == .disabled ? [.button, .notEnabled] : .button
        let change = {
            self.gradient.alpha = newMode == .disabled ? 0 : 1
            self.flatDisc.backgroundColor = Theme.Color.fill
            switch newMode {
            case .disabled:
                self.iconView.image = UIImage(systemName: "arrow.up", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .bold))
                self.iconView.tintColor = Theme.Color.inkTertiary
            case .ready:
                self.iconView.image = UIImage(systemName: "arrow.up", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .bold))
                self.iconView.tintColor = .white
            case .stop:
                self.iconView.image = UIImage(systemName: "stop.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .bold))
                self.iconView.tintColor = .white
            }
        }
        if animated {
            Motion.animate(0.2, options: [.beginFromCurrentState, .allowUserInteraction], animations: change)
        } else {
            change()
        }
    }
}

final class FootnoteLinkButton: UIButton {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.insetBy(dx: -10, dy: -14).contains(point)
    }

    init(title: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        var config = UIButton.Configuration.plain()
        config.contentInsets = .zero
        config.baseForegroundColor = Theme.Color.accentText
        config.title = title
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.scaled(.footnote, size: 13, weight: .semibold)
            return outgoing
        }
        configuration = config
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}

extension UIView {
    func layoutFromTopOfHierarchy() {
        var top: UIView = self
        while let parent = top.superview, !(parent is UIWindow) { top = parent }
        top.layoutIfNeeded()
    }
}
