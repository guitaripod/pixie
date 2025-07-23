package com.guitaripod.pixie.data.model

/**
 * User preferences for non-sensitive settings
 */
data class UserPreferences(
    val theme: AppTheme = AppTheme.SYSTEM,
    val defaultQuality: ImageQuality = ImageQuality.LOW,
    val defaultSize: String = "1024x1024",
    val defaultOutputFormat: OutputFormat = OutputFormat.PNG,
    val defaultCompressionLevel: Int = 75,
    val customApiUrl: String? = null
)

enum class AppTheme {
    LIGHT,
    DARK,
    SYSTEM
}

enum class ImageQuality {
    LOW,      // draft quality - 4-5 credits
    HIGH      // standard quality - 50-80 credits
}

enum class OutputFormat {
    PNG,
    JPEG,
    WEBP
}