import UIKit

extension UIDevice {
    static var isPad: Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }
    
    static var isPhone: Bool {
        return UIDevice.current.userInterfaceIdiom == .phone
    }
    
    static var isLandscape: Bool {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            return windowScene.interfaceOrientation.isLandscape
        }
        return false
    }
    
    static var isPortrait: Bool {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            return windowScene.interfaceOrientation.isPortrait
        }
        return true
    }
    
    static var supportsMultipleWindows: Bool {
        return isPad && UIApplication.shared.supportsMultipleScenes
    }
}

extension UITraitCollection {
    var isRegularWidth: Bool {
        return horizontalSizeClass == .regular
    }
    
    var isRegularHeight: Bool {
        return verticalSizeClass == .regular
    }
    
    var isCompact: Bool {
        return horizontalSizeClass == .compact || verticalSizeClass == .compact
    }
    
    var isIPadFullScreen: Bool {
        return isRegularWidth && isRegularHeight
    }
    
    var isIPadSplitView: Bool {
        return UIDevice.isPad && (horizontalSizeClass == .compact || verticalSizeClass == .compact)
    }
    
    var isIPadSlideOver: Bool {
        return UIDevice.isPad && horizontalSizeClass == .compact && verticalSizeClass == .regular
    }
}

enum AdaptiveLayout {
    case phonePortrait
    case phoneLandscape
    case padCompact
    case padRegular
    case padFullScreen
    
    init(traitCollection: UITraitCollection) {
        if UIDevice.isPhone {
            self = UIDevice.isLandscape ? .phoneLandscape : .phonePortrait
        } else if traitCollection.isIPadFullScreen {
            self = .padFullScreen
        } else if traitCollection.isRegularWidth {
            self = .padRegular
        } else {
            self = .padCompact
        }
    }
    
    var columns: Int {
        switch self {
        case .phonePortrait: return 1
        case .phoneLandscape: return 2
        case .padCompact: return 2
        case .padRegular: return 3
        case .padFullScreen: return UIDevice.isLandscape ? 4 : 3
        }
    }
    
    var galleryColumns: Int {
        switch self {
        case .phonePortrait: return 2
        case .phoneLandscape: return 3
        case .padCompact: return 3
        case .padRegular: return 4
        case .padFullScreen: return UIDevice.isLandscape ? 6 : 4
        }
    }
    
    var shouldShowSidebar: Bool {
        switch self {
        case .padRegular, .padFullScreen:
            return true
        default:
            return false
        }
    }
    
    var contentInsets: UIEdgeInsets {
        switch self {
        case .phonePortrait, .phoneLandscape:
            return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        case .padCompact:
            return UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        case .padRegular:
            return UIEdgeInsets(top: 0, left: 40, bottom: 0, right: 40)
        case .padFullScreen:
            return UIEdgeInsets(top: 0, left: 60, bottom: 0, right: 60)
        }
    }
}

protocol AdaptiveLayoutDelegate: AnyObject {
    func layoutDidChange(to layout: AdaptiveLayout)
}

class AdaptiveLayoutManager {
    weak var delegate: AdaptiveLayoutDelegate?
    private(set) var currentLayout: AdaptiveLayout
    
    init(traitCollection: UITraitCollection) {
        self.currentLayout = AdaptiveLayout(traitCollection: traitCollection)
    }
    
    func updateLayout(for traitCollection: UITraitCollection) {
        let newLayout = AdaptiveLayout(traitCollection: traitCollection)
        if newLayout != currentLayout {
            currentLayout = newLayout
            delegate?.layoutDidChange(to: newLayout)
        }
    }
}