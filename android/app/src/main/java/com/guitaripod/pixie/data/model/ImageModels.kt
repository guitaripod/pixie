package com.guitaripod.pixie.data.model

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass

@JsonClass(generateAdapter = true)
data class ImageGenerationRequest(
    val prompt: String,
    val model: String = "gpt-image-1",
    val n: Int = 1,
    val size: String = "auto",
    val quality: String = "low",
    val background: String? = null,
    val moderation: String? = null,
    val output_compression: Int? = null,
    val output_format: String? = null,
    val partial_images: Int? = null,
    val stream: Boolean? = null,
    val user: String? = null
)

@JsonClass(generateAdapter = true)
data class ImageGenerationResponse(
    val created: Long,
    val data: List<GeneratedImage>
)

@JsonClass(generateAdapter = true)
data class GeneratedImage(
    val url: String,
    val id: String? = null,
    @Json(name = "revised_prompt") val revisedPrompt: String? = null
)