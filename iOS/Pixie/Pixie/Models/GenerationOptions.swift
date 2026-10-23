import Foundation

nonisolated struct GenerationOptions {
    var prompt: String
    var model: String
    var quantity: Int
    var size: String
    var sizeDisplay: String
    var quality: String
    var stylePreset: String?
    var modifiers: [String]
    var removeBackground: Bool
    var background: String?
    var upscale: Int?
    var autoEnhance: Bool
    var variations: Bool
    var extractText: Bool
    var generateSimilar: Bool
    var outputFormat: String?
    var compression: Int?
    var moderation: String?
    static var `default`: GenerationOptions {
        GenerationOptions(
            prompt: "",
            model: "gemini-2.5-flash",
            quantity: 1,
            size: "1024x1024",
            sizeDisplay: String(localized: "Square"),
            quality: "low",
            stylePreset: nil,
            modifiers: [],
            removeBackground: false,
            background: nil,
            upscale: nil,
            autoEnhance: false,
            variations: false,
            extractText: false,
            generateSimilar: false,
            outputFormat: nil,
            compression: nil,
            moderation: nil
        )
    }
}
