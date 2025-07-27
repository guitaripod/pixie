import UIKit

protocol HapticsManagerProtocol {
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle)
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType)
    func selection()
}

class HapticsManager: HapticsManagerProtocol {
    static let shared = HapticsManager()
    
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()
    
    private init() {
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        notificationGenerator.prepare()
        selectionGenerator.prepare()
    }
    
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard ConfigurationManager.shared.enableHaptics else { return }
        
        switch style {
        case .light:
            impactLight.impactOccurred()
        case .medium:
            impactMedium.impactOccurred()
        case .heavy:
            impactHeavy.impactOccurred()
        case .soft:
            if #available(iOS 13.0, *) {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            } else {
                impactLight.impactOccurred()
            }
        case .rigid:
            if #available(iOS 13.0, *) {
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            } else {
                impactMedium.impactOccurred()
            }
        @unknown default:
            impactMedium.impactOccurred()
        }
    }
    
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard ConfigurationManager.shared.enableHaptics else { return }
        notificationGenerator.notificationOccurred(type)
    }
    
    func selection() {
        guard ConfigurationManager.shared.enableHaptics else { return }
        selectionGenerator.selectionChanged()
    }
}

extension HapticsManager {
    enum HapticType {
        case click
        case longPress
        case toggle
        case error
        case success
        case warning
        case sliderTick
        case confirm
        case reject
        
        func trigger() {
            switch self {
            case .click:
                HapticsManager.shared.impact(.light)
            case .longPress:
                HapticsManager.shared.impact(.medium)
            case .toggle:
                HapticsManager.shared.selection()
            case .error:
                HapticsManager.shared.notification(.error)
            case .success:
                HapticsManager.shared.notification(.success)
            case .warning:
                HapticsManager.shared.notification(.warning)
            case .sliderTick:
                HapticsManager.shared.selection()
            case .confirm:
                HapticsManager.shared.impact(.medium)
            case .reject:
                HapticsManager.shared.impact(.heavy)
            }
        }
    }
}