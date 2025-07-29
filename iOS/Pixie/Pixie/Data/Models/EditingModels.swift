import Foundation
import UIKit

struct SelectedImage {
    let image: UIImage
    let url: URL?
    let displayName: String?
}

enum ToolbarMode {
    case generate
    case edit(selectedImage: SelectedImage)
}

struct EditOptions {
    var prompt: String = ""
    var variations: Int = 1
    var size: ImageSize = .auto
    var quality: ImageQuality = .low
    var fidelity: FidelityLevel = .low
    var background: String? = "auto"
    var outputFormat: String = "png"
    var compression: Int? = nil
}

enum FidelityLevel: CaseIterable {
    case low, high
    
    var value: String {
        switch self {
        case .low: return "low"
        case .high: return "high"
        }
    }
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .high: return "High"
        }
    }
    
    var description: String {
        switch self {
        case .low: return "More creative freedom"
        case .high: return "Preserve details (faces, logos)"
        }
    }
}

struct EditToolbarState {
    var isExpanded: Bool = false
    var showAdvancedOptions: Bool = false
}