import UIKit

class SplashView: UIView {
    
    private let titleLabel = UILabel()
    private let gradientLayer = CAGradientLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
    
    private func setupView() {
        backgroundColor = .systemBackground
        
        gradientLayer.colors = [
            UIColor.systemPurple.withAlphaComponent(0.3).cgColor,
            UIColor.systemBlue.withAlphaComponent(0.3).cgColor,
            UIColor.systemBackground.cgColor
        ]
        gradientLayer.locations = [0, 0.5, 1]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        layer.insertSublayer(gradientLayer, at: 0)
        
        titleLabel.text = "Pixie"
        titleLabel.font = .systemFont(ofSize: 48, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        
        animateElements()
    }
    
    private func animateElements() {
        titleLabel.alpha = 0
        titleLabel.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        UIView.animate(withDuration: 0.8, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            self.titleLabel.transform = .identity
            self.titleLabel.alpha = 1
        }
    }
    
    func animateOut(completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.5, delay: 0, options: [.curveEaseInOut]) {
            self.transform = CGAffineTransform(translationX: 0, y: -self.bounds.height)
            self.alpha = 0
        } completion: { _ in
            completion()
        }
    }
}