package com.guitaripod.pixie.data.model

data class UserPreferences(
    val theme: AppTheme = AppTheme.SYSTEM,
    val defaultQuality: DefaultImageQuality = DefaultImageQuality.LOW,
    val defaultSize: String = "1024x1024",
    val defaultOutputFormat: DefaultOutputFormat = DefaultOutputFormat.PNG,
    val defaultCompressionLevel: Int = 75,
    val customApiUrl: String? = null
)

enum class AppTheme {
    LIGHT,
    DARK,
    SYSTEM
}

enum class DefaultImageQuality {
    LOW,
    HIGH
}

enum class DefaultOutputFormat {
    PNG,
    JPEG,
    WEBP
}