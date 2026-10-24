import Foundation

nonisolated enum ImageModel: String, CaseIterable {
    case gemini = "gemini-2.5-flash"
    case geminiPro = "gemini-3-pro-image"
    case openai = "gpt-image-1"

    var displayName: String {
        switch self {
        case .gemini: return "Nano Banana 2"
        case .geminiPro: return "Nano Banana Pro"
        case .openai: return "GPT Image"
        }
    }

    var description: String {
        switch self {
        case .gemini: return String(localized: "Fast & affordable (21 credits)")
        case .geminiPro: return String(localized: "Sharper detail and text (41 credits)")
        case .openai: return String(localized: "Advanced options (5-94 credits)")
        }
    }

    var value: String { rawValue }

    var fixedCost: Int? {
        switch self {
        case .gemini: return 21
        case .geminiPro: return 41
        case .openai: return nil
        }
    }

    var requiresAdvancedOptions: Bool {
        switch self {
        case .gemini, .geminiPro: return false
        case .openai: return true
        }
    }

    /// The model a one-tap preset runs on: presets are tuned for Nano Banana, so only an
    /// explicit Pro choice changes it.
    var presetModel: ImageModel {
        self == .geminiPro ? .geminiPro : .gemini
    }
}
