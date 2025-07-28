import UIKit

class OAuthButton: UIButton {
    
    private var provider: AuthProvider?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }
    
    private func setupButton() {
        translatesAutoresizingMaskIntoConstraints = false
        
        configurationUpdateHandler = { [weak self] button in
            guard let self = self else { return }
            
            var config = button.configuration ?? UIButton.Configuration.plain()
            
            switch button.state {
            case .highlighted:
                config.background.backgroundColor = self.getBackgroundColor(for: self.provider)?.withAlphaComponent(0.8)
                button.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            default:
                config.background.backgroundColor = self.getBackgroundColor(for: self.provider)
                button.transform = .identity
            }
            
            UIView.animate(withDuration: 0.1) {
                button.configuration = config
            }
        }
    }
    
    func configure(provider: AuthProvider, title: String, backgroundColor: UIColor, textColor: UIColor, borderColor: UIColor?, iconName: String?) {
        self.provider = provider
        
        var config = UIButton.Configuration.plain()
        config.title = title
        config.baseForegroundColor = textColor
        config.background.backgroundColor = backgroundColor
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
        
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 16, weight: .medium)
            return outgoing
        }
        
        switch provider {
        case .google:
            config.cornerStyle = .fixed
            config.background.cornerRadius = 4
            config.image = createGoogleIcon()
            config.imagePlacement = .leading
            config.imagePadding = 8
            
            if let borderColor = borderColor {
                config.background.strokeColor = borderColor
                config.background.strokeWidth = 1
            }
            
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOffset = CGSize(width: 0, height: 1)
            layer.shadowOpacity = 0.1
            layer.shadowRadius = 2
            
        case .github:
            config.cornerStyle = .fixed
            config.background.cornerRadius = 6
            config.image = UIImage(named: "github_mark")?.withRenderingMode(.alwaysTemplate)
            config.imagePlacement = .leading
            config.imagePadding = 8
            
        case .apple:
            break
        }
        
        self.configuration = config
    }
    
    private func getBackgroundColor(for provider: AuthProvider?) -> UIColor? {
        guard let provider = provider else { return nil }
        
        switch provider {
        case .google:
            return .white
        case .github:
            return UIColor(red: 0.141, green: 0.161, blue: 0.180, alpha: 1.0)
        case .apple:
            return .black
        }
    }
    
    private func createGoogleIcon() -> UIImage? {
        let size = CGSize(width: 20, height: 20)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let path = UIBezierPath()
            
            path.move(to: CGPoint(x: 19.8, y: 10.2))
            path.addCurve(to: CGPoint(x: 19.5, y: 12.0), controlPoint1: CGPoint(x: 19.8, y: 10.8), controlPoint2: CGPoint(x: 19.7, y: 11.4))
            path.addLine(to: CGPoint(x: 12.0, y: 12.0))
            path.addLine(to: CGPoint(x: 12.0, y: 8.0))
            path.addLine(to: CGPoint(x: 19.5, y: 8.0))
            path.addCurve(to: CGPoint(x: 19.8, y: 10.2), controlPoint1: CGPoint(x: 19.7, y: 8.6), controlPoint2: CGPoint(x: 19.8, y: 9.4))
            path.close()
            UIColor(red: 0.259, green: 0.522, blue: 0.957, alpha: 1.0).setFill()
            path.fill()
            
            let path2 = UIBezierPath()
            path2.move(to: CGPoint(x: 10.0, y: 0.2))
            path2.addCurve(to: CGPoint(x: 16.7, y: 3.5), controlPoint1: CGPoint(x: 12.6, y: 0.2), controlPoint2: CGPoint(x: 15.0, y: 1.4))
            path2.addLine(to: CGPoint(x: 13.8, y: 6.4))
            path2.addCurve(to: CGPoint(x: 10.0, y: 4.0), controlPoint1: CGPoint(x: 12.8, y: 5.0), controlPoint2: CGPoint(x: 11.5, y: 4.0))
            path2.addCurve(to: CGPoint(x: 4.0, y: 10.0), controlPoint1: CGPoint(x: 6.7, y: 4.0), controlPoint2: CGPoint(x: 4.0, y: 6.7))
            path2.addCurve(to: CGPoint(x: 10.0, y: 16.0), controlPoint1: CGPoint(x: 4.0, y: 13.3), controlPoint2: CGPoint(x: 6.7, y: 16.0))
            path2.addCurve(to: CGPoint(x: 13.8, y: 13.6), controlPoint1: CGPoint(x: 11.5, y: 16.0), controlPoint2: CGPoint(x: 12.8, y: 15.0))
            path2.addLine(to: CGPoint(x: 16.7, y: 16.5))
            path2.addCurve(to: CGPoint(x: 10.0, y: 19.8), controlPoint1: CGPoint(x: 15.0, y: 18.6), controlPoint2: CGPoint(x: 12.6, y: 19.8))
            path2.addCurve(to: CGPoint(x: 0.2, y: 10.0), controlPoint1: CGPoint(x: 4.5, y: 19.8), controlPoint2: CGPoint(x: 0.2, y: 15.5))
            path2.addCurve(to: CGPoint(x: 10.0, y: 0.2), controlPoint1: CGPoint(x: 0.2, y: 4.5), controlPoint2: CGPoint(x: 4.5, y: 0.2))
            path2.close()
            UIColor(red: 0.918, green: 0.255, blue: 0.263, alpha: 1.0).setFill()
            path2.fill()
            
            let path3 = UIBezierPath()
            path3.move(to: CGPoint(x: 19.8, y: 10.2))
            path3.addCurve(to: CGPoint(x: 19.5, y: 8.0), controlPoint1: CGPoint(x: 19.8, y: 9.4), controlPoint2: CGPoint(x: 19.7, y: 8.6))
            path3.addLine(to: CGPoint(x: 12.0, y: 8.0))
            path3.addLine(to: CGPoint(x: 12.0, y: 4.0))
            path3.addCurve(to: CGPoint(x: 13.8, y: 6.4), controlPoint1: CGPoint(x: 12.0, y: 4.9), controlPoint2: CGPoint(x: 12.7, y: 5.8))
            path3.addLine(to: CGPoint(x: 16.7, y: 3.5))
            path3.addCurve(to: CGPoint(x: 19.8, y: 10.2), controlPoint1: CGPoint(x: 18.6, y: 5.1), controlPoint2: CGPoint(x: 19.8, y: 7.5))
            path3.close()
            UIColor(red: 0.984, green: 0.737, blue: 0.020, alpha: 1.0).setFill()
            path3.fill()
            
            let path4 = UIBezierPath()
            path4.move(to: CGPoint(x: 4.0, y: 10.0))
            path4.addCurve(to: CGPoint(x: 10.0, y: 4.0), controlPoint1: CGPoint(x: 4.0, y: 6.7), controlPoint2: CGPoint(x: 6.7, y: 4.0))
            path4.addCurve(to: CGPoint(x: 12.0, y: 4.0), controlPoint1: CGPoint(x: 10.7, y: 4.0), controlPoint2: CGPoint(x: 11.4, y: 4.0))
            path4.addLine(to: CGPoint(x: 12.0, y: 16.0))
            path4.addCurve(to: CGPoint(x: 10.0, y: 16.0), controlPoint1: CGPoint(x: 11.4, y: 16.0), controlPoint2: CGPoint(x: 10.7, y: 16.0))
            path4.addCurve(to: CGPoint(x: 4.0, y: 10.0), controlPoint1: CGPoint(x: 6.7, y: 16.0), controlPoint2: CGPoint(x: 4.0, y: 13.3))
            path4.close()
            UIColor(red: 0.251, green: 0.643, blue: 0.349, alpha: 1.0).setFill()
            path4.fill()
        }
    }
    
}