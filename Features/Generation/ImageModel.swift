import Foundation

/// The two image tiers PixiePocket sells. mako picks the models behind each tier and prices it in edits (mako
/// migration 035), so the app asks for a tier by name. A model id an older version saved reads as Standard.
nonisolated enum ImageModel: String, CaseIterable {
    case standard
    case max

    init(storedValue: String) {
        self = ImageModel(rawValue: storedValue) ?? .standard
    }

    var displayName: String {
        switch self {
        case .standard: return String(localized: "Standard")
        case .max: return String(localized: "Max")
        }
    }

    var description: String {
        switch self {
        case .standard: return String(localized: "Fast and great for most edits")
        case .max: return String(localized: "Our most detailed model, for the shots that matter")
        }
    }

    var value: String { rawValue }

    /// What one image on this tier costs in edits until mako's balance says otherwise.
    var defaultEdits: Int {
        switch self {
        case .standard: return 1
        case .max: return 5
        }
    }

    /// The name a gallery image shows for the model that made it: a tier, or one of the model ids mako has served
    /// and older versions sent.
    static func displayName(forRecorded model: String) -> String {
        switch model {
        case "standard", "max": return ImageModel(storedValue: model).displayName
        case "gemini-nano-banana-2.1": return "Nano Banana 2.1"
        case "gemini-2.5-flash", "gemini-2.5-flash-image", "gemini-3.1-flash-image": return "Nano Banana 2"
        case "gemini-3-pro-image", "nano-banana-pro": return "Nano Banana Pro"
        case "gpt-image-2.6-sunburst", "gpt-image-2.6-flare": return "GPT Image 2.6"
        case "gpt-image-2.5-sunburst", "gpt-image-2.5-flare": return "GPT Image 2.5"
        case "gpt-image-1", "gpt-image-2": return "GPT Image"
        default: return model
        }
    }
}
