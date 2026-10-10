import UIKit

class AnimatedLoadingIndicator: UIView {

    private let dots = [UIView(), UIView(), UIView()]

    private let dotSize: CGFloat = 8
    private let spacing: CGFloat = 6
    private var isAnimating = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupViews() {
        hideFromAccessibility()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reduceMotionChanged),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
        for dot in dots {
            dot.backgroundColor = Theme.Color.accent
            dot.layer.cornerRadius = dotSize / 2
            dot.translatesAutoresizingMaskIntoConstraints = false
            addSubview(dot)
            NSLayoutConstraint.activate([
                dot.centerYAnchor.constraint(equalTo: centerYAnchor),
                dot.widthAnchor.constraint(equalToConstant: dotSize),
                dot.heightAnchor.constraint(equalToConstant: dotSize),
            ])
        }

        NSLayoutConstraint.activate([
            dots[0].leadingAnchor.constraint(equalTo: leadingAnchor),
            dots[1].leadingAnchor.constraint(equalTo: dots[0].trailingAnchor, constant: spacing),
            dots[2].leadingAnchor.constraint(equalTo: dots[1].trailingAnchor, constant: spacing),
            dots[2].trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    @objc private func reduceMotionChanged() {
        guard isAnimating else { return }
        startAnimating()
    }

    func startAnimating() {
        isAnimating = true
        stopDotAnimations()

        guard !Motion.isReduced else { return }

        let duration: TimeInterval = 0.45
        let delay: TimeInterval = 0.15

        for (index, dot) in dots.enumerated() {
            dot.alpha = 0.3

            Motion.animate(
                duration,
                delay: delay * Double(index),
                options: [.repeat, .autoreverse, .curveEaseInOut],
                animations: {
                    dot.alpha = 1.0
                    dot.transform = CGAffineTransform(scaleX: 1.25, y: 1.25).translatedBy(x: 0, y: -2)
                }
            )
        }
    }

    func stopAnimating() {
        isAnimating = false
        stopDotAnimations()
    }

    /// Leaves the dots static and fully visible, which is also how they sit while Reduce Motion is on.
    private func stopDotAnimations() {
        for dot in dots {
            dot.layer.removeAllAnimations()
            dot.alpha = 1.0
            dot.transform = .identity
        }
    }

    override var intrinsicContentSize: CGSize {
        let width = (dotSize * 3) + (spacing * 2)
        return CGSize(width: width, height: dotSize)
    }
}
