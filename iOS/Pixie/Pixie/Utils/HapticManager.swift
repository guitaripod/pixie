import UIKit
import CoreHaptics

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
}

class HapticManager {
    
    static let shared = HapticManager()
    
    private var engine: CHHapticEngine?
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let selection = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()
    
    private init() {
        prepareHaptics()
    }
    
    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("Haptic engine creation error: \(error)")
        }
        
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        selection.prepare()
        notification.prepare()
    }
    
    func impact(_ type: HapticType) {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        
        switch type {
        case .click:
            impactLight.impactOccurred()
        case .longPress:
            impactMedium.impactOccurred()
        case .toggle:
            impactLight.impactOccurred()
        case .error:
            notification.notificationOccurred(.error)
        case .success:
            notification.notificationOccurred(.success)
        case .warning:
            notification.notificationOccurred(.warning)
        case .sliderTick:
            selection.selectionChanged()
        case .confirm:
            impactMedium.impactOccurred()
        case .reject:
            impactHeavy.impactOccurred()
        }
    }
    
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        notification.notificationOccurred(type)
    }
    
    func selectionChanged() {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        selection.selectionChanged()
    }
    
    func customHaptic(intensity: Float = 1.0, sharpness: Float = 1.0, duration: TimeInterval = 0.1) {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = engine else { return }
        
        var events = [CHHapticEvent]()
        
        let hapticIntensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
        let hapticSharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [hapticIntensity, hapticSharpness], relativeTime: 0)
        events.append(event)
        
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play custom haptic: \(error)")
        }
    }
}