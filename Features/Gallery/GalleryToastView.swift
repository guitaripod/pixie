import UIKit

enum GalleryToastKind {
    case success
    case error
    case undo
    case progress
}

final class GalleryToastView: UIView {

    let kind: GalleryToastKind
    var onAction: (() -> Void)?

    var isUndo: Bool { kind == .undo }
    var isProgress: Bool { kind == .progress }

    private let capsule = SurfaceView(style: .raised, cornerRadius: Theme.Radius.xl)
    private let label = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let iconView = UIImageView()
    private var expiry: Task<Void, Never>?
    private var isDismissing = false

    private static let maxWidth: CGFloat = 560

    init(message: String, actionTitle: String?, kind: GalleryToastKind) {
        self.kind = kind
        super.init(frame: .zero)
        setupUI(message: message, actionTitle: actionTitle)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        capsule.cornerRadius = min(capsule.bounds.height / 2, Theme.Radius.xl)
    }

    private func setupUI(message: String, actionTitle: String?) {
        translatesAutoresizingMaskIntoConstraints = false
        capsule.translatesAutoresizingMaskIntoConstraints = false
        addSubview(capsule)

        label.apply(.subhead, color: Theme.Color.ink)
        label.text = message
        label.setContentCompressionResistancePriority(.required, for: .vertical)

        let leading = makeLeadingView()
        let stack = UIStackView(arrangedSubviews: [leading, label])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = Theme.Space.md
        stack.translatesAutoresizingMaskIntoConstraints = false
        capsule.contentView.addSubview(stack)

        if let actionTitle {
            let button = PixieButton(style: .plain, size: .small, title: actionTitle) { [weak self] in self?.onAction?() }
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            button.setContentHuggingPriority(.required, for: .horizontal)
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
            button.setupPointerInteraction()
            stack.addArrangedSubview(button)
        }

        capsule.pinEdges(to: self)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: capsule.contentView.topAnchor, constant: Theme.Space.sm),
            stack.bottomAnchor.constraint(equalTo: capsule.contentView.bottomAnchor, constant: -Theme.Space.sm),
            stack.leadingAnchor.constraint(equalTo: capsule.contentView.leadingAnchor, constant: Theme.Space.lg),
            stack.trailingAnchor.constraint(equalTo: capsule.contentView.trailingAnchor, constant: actionTitle == nil ? -Theme.Space.lg : -Theme.Space.xs),
            widthAnchor.constraint(lessThanOrEqualToConstant: Self.maxWidth),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 48),
        ])

        accessibilityViewIsModal = false
        label.isAccessibilityElement = true
    }

    private func makeLeadingView() -> UIView {
        switch kind {
        case .progress:
            spinner.color = Theme.Color.accentText
            spinner.startAnimating()
            spinner.setContentHuggingPriority(.required, for: .horizontal)
            spinner.hideFromAccessibility()
            return spinner
        case .success:
            return makeIcon("checkmark.circle.fill", tint: Theme.Color.success)
        case .error:
            return makeIcon("exclamationmark.triangle.fill", tint: Theme.Color.warning)
        case .undo:
            return makeIcon("trash.fill", tint: Theme.Color.inkSecondary)
        }
    }

    private func makeIcon(_ symbol: String, tint: UIColor) -> UIView {
        iconView.image = UIImage(systemName: symbol)
        iconView.tintColor = tint
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .body, scale: .medium)
        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        iconView.setContentCompressionResistancePriority(.required, for: .horizontal)
        iconView.hideFromAccessibility()
        return iconView
    }

    func setMessage(_ message: String) {
        label.text = message
    }

    func present(lifetime: TimeInterval?) {
        alpha = 0
        transform = Motion.isReduced ? .identity : CGAffineTransform(translationX: 0, y: 20).scaledBy(x: 0.96, y: 0.96)
        Motion.spring(0.4, damping: 0.82) {
            self.alpha = 1
            self.transform = .identity
        }
        guard let lifetime else { return }
        expiry = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(lifetime * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.dismiss() }
        }
    }

    func dismiss() {
        guard !isDismissing else { return }
        isDismissing = true
        expiry?.cancel()
        Motion.animate(0.2, options: .curveEaseOut) {
            self.alpha = 0
            self.transform = Motion.isReduced ? .identity : CGAffineTransform(translationX: 0, y: 12)
        } completion: { _ in
            self.removeFromSuperview()
        }
    }
}
