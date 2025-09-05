package com.guitaripod.pixie.data.model

data class UserPreferences(
    val theme: AppTheme = AppTheme.SYSTEM,
    val defaultModel: ImageModel = ImageModel.GEMINI,
    val defaultQuality: DefaultImageQuality = DefaultImageQuality.LOW,
    val defaultSize: String = "square",
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
    MEDIUM,
    HIGH,
    AUTO
}

enum class DefaultOutputFormat {
    PNG,
    JPEG,
    WEBP
}

enum class ImageModel(val value: String, val displayName: String, val description: String) {
    GEMINI("gemini-2.5-flash", "Gemini", "Fast & affordable (15 credits)"),
    OPENAI("gpt-image-1", "OpenAI GPT", "Advanced options (5-94 credits)")
}