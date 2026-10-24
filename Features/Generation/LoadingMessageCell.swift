import UIKit

class LoadingMessageCell: ChatColumnCell {
    static let identifier = "LoadingMessageCell"
    private let container = UIView()
    private let card = SurfaceView(style: .card, cornerRadius: 24)
    private let shimmer = ShimmerView()
    private let sparkle = IconBadge(symbol: "sparkles", size: 56)
    private let titleLabel = UILabel()
    private let elapsedLabel = UILabel()
    private var startedAt = Date()
    private var timer: Timer?
    private var sizingConstraints: [NSLayoutConstraint] = []

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    private func setupViews() {
        container.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(container)
        container.addSubview(card)
        card.contentView.addSubview(shimmer)
        shimmer.pinEdges(to: card.contentView)

        titleLabel.apply(.headline)
        titleLabel.textAlignment = .center
        elapsedLabel.apply(.footnote)
        elapsedLabel.textAlignment = .center
        elapsedLabel.font = UIFont.monospacedDigitSystemFont(ofSize: elapsedLabel.font.pointSize, weight: .medium)
        elapsedLabel.adjustsFontForContentSizeCategory = true
        elapsedLabel.hideFromAccessibility()

        let stack = UIStackView(arrangedSubviews: [sparkle, titleLabel, elapsedLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = Theme.Space.sm
        stack.setCustomSpacing(Theme.Space.md, after: sparkle)
        card.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: column.topAnchor),
            container.bottomAnchor.constraint(equalTo: column.bottomAnchor),
            container.leadingAnchor.constraint(equalTo: column.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: column.trailingAnchor),
            stack.centerXAnchor.constraint(equalTo: card.contentView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: card.contentView.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: card.contentView.leadingAnchor, constant: Theme.Space.lg),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: card.contentView.trailingAnchor, constant: -Theme.Space.lg),
            stack.topAnchor.constraint(greaterThanOrEqualTo: card.contentView.topAnchor, constant: Theme.Space.lg),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: card.contentView.bottomAnchor, constant: -Theme.Space.lg)
        ])
        shimmer.layer.cornerRadius = 24
        shimmer.backgroundColor = Theme.Color.accentSoft
        describe(String(localized: "Generating image"), traits: .staticText)
    }

    /// With `actionsBeside` the card sits where the picture will, left of the room the result's
    /// column of actions takes, so the result lands in place.
    func configure(with message: ChatMessage, aspect: CGFloat, maxImageHeight: CGFloat, actionsBeside: Bool = false) {
        startedAt = message.timestamp
        titleLabel.text = String(localized: "Creating your image") + "\u{2026}"
        updateElapsed()
        NSLayoutConstraint.deactivate(sizingConstraints)
        let offset = actionsBeside ? -(AssistantMessageCell.sideActionsWidth + AssistantMessageCell.sideActionsSpacing) / 2 : 0
        sizingConstraints = sizeCard(card, in: container, aspect: aspect, maxWidth: maxImageHeight > 0 ? maxImageHeight / aspect : nil, centerOffset: offset)
    }

    func startAnimating() {
        startTimer()
        startPulse()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        stopTimer()
        sparkle.layer.removeAllAnimations()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            stopTimer()
        } else {
            startAnimating()
        }
    }

    private func startTimer() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.updateElapsed() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateElapsed() {
        let seconds = max(0, Int(Date().timeIntervalSince(startedAt)))
        elapsedLabel.text = String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func startPulse() {
        sparkle.layer.removeAllAnimations()
        guard !Motion.isReduced else { return }
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.92
        scale.toValue = 1.08
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0.7
        fade.toValue = 1
        let group = CAAnimationGroup()
        group.animations = [scale, fade]
        group.duration = 1.1
        group.autoreverses = true
        group.repeatCount = .infinity
        group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        sparkle.layer.add(group, forKey: "pulse")
    }
}
