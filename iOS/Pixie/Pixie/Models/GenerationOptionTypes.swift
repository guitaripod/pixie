import Foundation

nonisolated enum ImageSize: CaseIterable {
    case auto, square, landscape, portrait
    
    var displayName: String {
        switch self {
        case .auto: return String(localized: "Auto")
        case .square: return String(localized: "Square")
        case .landscape: return String(localized: "Landscape")
        case .portrait: return String(localized: "Portrait")
        }
    }
    
    var dimensions: String {
        switch self {
        case .auto: return String(localized: "Optimal")
        case .square: return "1024×1024"
        case .landscape: return "1536×1024"
        case .portrait: return "1024×1536"
        }
    }
    
    var value: String {
        switch self {
        case .auto: return "auto"
        case .square: return "1024x1024"
        case .landscape: return "1536x1024"
        case .portrait: return "1024x1536"
        }
    }
}

nonisolated enum ImageQuality: CaseIterable {
    case low, medium, high, auto
    
    var displayName: String {
        switch self {
        case .low: return String(localized: "Low")
        case .medium: return String(localized: "Medium")
        case .high: return String(localized: "High")
        case .auto: return String(localized: "Auto")
        }
    }
    
    var creditRange: String {
        switch self {
        case .low: return String(localized: "4-6 credits")
        case .medium: return String(localized: "16-24 credits")
        case .high: return String(localized: "62-94 credits")
        case .auto: return String(localized: "50-75 credits")
        }
    }
    
    var value: String {
        switch self {
        case .low: return "low"
        case .medium: return "medium"
        case .high: return "high"
        case .auto: return "auto"
        }
    }
}

nonisolated enum BackgroundStyle: CaseIterable {
    case auto, transparent, white, black
    
    var displayName: String {
        switch self {
        case .auto: return String(localized: "Auto")
        case .transparent: return String(localized: "Transparent")
        case .white: return String(localized: "White")
        case .black: return String(localized: "Black")
        }
    }
    
    var value: String {
        switch self {
        case .auto: return "auto"
        case .transparent: return "transparent"
        case .white: return "white"
        case .black: return "black"
        }
    }
}

nonisolated enum OutputFormat: CaseIterable {
    case png, jpeg, webp
    
    var displayName: String {
        switch self {
        case .png: return "PNG"
        case .jpeg: return "JPEG"
        case .webp: return "WebP"
        }
    }
    
    var value: String {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpeg"
        case .webp: return "webp"
        }
    }
    
    var supportsCompression: Bool {
        switch self {
        case .png: return false
        case .jpeg, .webp: return true
        }
    }
}

nonisolated enum ModerationLevel: CaseIterable {
    case auto, low
    
    var displayName: String {
        switch self {
        case .auto: return String(localized: "Auto")
        case .low: return String(localized: "Low")
        }
    }
    
    var description: String {
        switch self {
        case .auto: return String(localized: "Default moderation")
        case .low: return String(localized: "Less restrictive")
        }
    }
    
    var value: String {
        switch self {
        case .auto: return "auto"
        case .low: return "low"
        }
    }
}