package com.guitaripod.pixie.data.model

import com.squareup.moshi.JsonClass

@JsonClass(generateAdapter = true)
data class GenerationOptions(
    val prompt: String,
    val number: Int = 1,
    val size: String = "auto",
    val quality: String = "low",
    val background: String? = null,
    val outputFormat: String? = null,
    val compression: Int? = null,
    val moderation: String? = null
) {
    fun toApiRequest(): ImageGenerationRequest {
        return ImageGenerationRequest(
            prompt = prompt,
            model = "gpt-image-1",
            n = number,
            size = size,
            quality = quality,
            background = background,
            moderation = moderation,
            output_compression = compression,
            output_format = outputFormat
        )
    }
    
    fun estimateCredits(): IntRange {
        val baseCredits = when (quality) {
            "low" -> when (size) {
                "1024x1024" -> 4..4
                "1536x1024", "1024x1536" -> 6..6
                else -> 4..6
            }
            "medium" -> when (size) {
                "1024x1024" -> 16..16
                "1536x1024", "1024x1536" -> 24..24
                else -> 16..24
            }
            "high" -> when (size) {
                "1024x1024" -> 62..62
                "1536x1024", "1024x1536" -> 94..94
                else -> 62..94
            }
            "auto" -> 50..75
            else -> 4..6
        }
        
        val totalMin = baseCredits.first * number
        val totalMax = baseCredits.last * number
        return totalMin..totalMax
    }
}

enum class ImageSize(val value: String, val displayName: String, val dimensions: String) {
    AUTO("auto", "Auto", "Optimal"),
    SQUARE("1024x1024", "Square", "1024×1024"),
    LANDSCAPE("1536x1024", "Landscape", "1536×1024"),
    PORTRAIT("1024x1536", "Portrait", "1024×1536"),
    CUSTOM("custom", "Custom", "Custom size")
}

enum class ImageQuality(val value: String, val displayName: String, val creditRange: String) {
    LOW("low", "Low", "4-6 credits"),
    MEDIUM("medium", "Medium", "16-24 credits"),
    HIGH("high", "High", "62-94 credits"),
    AUTO("auto", "Auto", "50-75 credits")
}

enum class BackgroundStyle(val value: String, val displayName: String) {
    AUTO("auto", "Auto"),
    TRANSPARENT("transparent", "Transparent"),
    WHITE("white", "White"),
    BLACK("black", "Black")
}

enum class OutputFormat(val value: String, val displayName: String, val supportsCompression: Boolean) {
    PNG("png", "PNG", false),
    JPEG("jpeg", "JPEG", true),
    WEBP("webp", "WebP", true)
}

enum class ModerationLevel(val value: String, val displayName: String, val description: String) {
    AUTO("auto", "Auto", "Default moderation"),
    LOW("low", "Low", "Less restrictive")
}