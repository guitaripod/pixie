import UIKit

class AnimatedLoadingIndicator: UIView {
    
    private let dot1 = UIView()
    private let dot2 = UIView()
    private let dot3 = UIView()
    
    private let dotSize: CGFloat = 8
    private let spacing: CGFloat = 6
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        [dot1, dot2, dot3].forEach { dot in
            dot.backgroundColor = .systemGray
            dot.layer.cornerRadius = dotSize / 2
            dot.translatesAutoresizingMaskIntoConstraints = false
            addSubview(dot)
        }
        
        NSLayoutConstraint.activate([
            dot1.centerYAnchor.constraint(equalTo: centerYAnchor),
            dot1.widthAnchor.constraint(equalToConstant: dotSize),
            dot1.heightAnchor.constraint(equalToConstant: dotSize),
            
            dot2.centerYAnchor.constraint(equalTo: centerYAnchor),
            dot2.leadingAnchor.constraint(equalTo: dot1.trailingAnchor, constant: spacing),
            dot2.widthAnchor.constraint(equalToConstant: dotSize),
            dot2.heightAnchor.constraint(equalToConstant: dotSize),
            
            dot3.centerYAnchor.constraint(equalTo: centerYAnchor),
            dot3.leadingAnchor.constraint(equalTo: dot2.trailingAnchor, constant: spacing),
            dot3.widthAnchor.constraint(equalToConstant: dotSize),
            dot3.heightAnchor.constraint(equalToConstant: dotSize),
            
            dot1.leadingAnchor.constraint(equalTo: leadingAnchor),
            dot3.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
    
    func startAnimating() {
        let duration: TimeInterval = 0.6
        let delay: TimeInterval = 0.1
        
        [dot1, dot2, dot3].enumerated().forEach { index, dot in
            dot.alpha = 0.3
            
            UIView.animateKeyframes(
                withDuration: duration,
                delay: delay * Double(index),
                options: [.repeat, .autoreverse],
                animations: {
                    UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.5) {
                        dot.alpha = 1.0
                        dot.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
                    }
                    UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.5) {
                        dot.alpha = 0.3
                        dot.transform = .identity
                    }
                }
            )
        }
    }
    
    func stopAnimating() {
        [dot1, dot2, dot3].forEach { dot in
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