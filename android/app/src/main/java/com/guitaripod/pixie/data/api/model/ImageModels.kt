package com.guitaripod.pixie.data.api.model

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass

// Image Generation Models

@JsonClass(generateAdapter = true)
data class ImageGenerationRequest(
    @Json(name = "prompt") val prompt: String,
    @Json(name = "model") val model: String = "gpt-image-1",
    @Json(name = "n") val n: Int? = 1,
    @Json(name = "quality") val quality: String? = "auto",
    @Json(name = "size") val size: String? = "auto",
    @Json(name = "style") val style: String? = null,
    @Json(name = "response_format") val responseFormat: String? = "url",
    @Json(name = "user") val user: String? = null,
    @Json(name = "transparency") val transparency: String? = null,
    @Json(name = "background") val background: String? = null,
    @Json(name = "output_format") val outputFormat: String? = null,
    @Json(name = "output_quality") val outputQuality: Int? = null,
    @Json(name = "store") val store: Boolean? = true,
    @Json(name = "metadata") val metadata: Map<String, String>? = null
)

@JsonClass(generateAdapter = true)
data class ImageGenerationResponse(
    @Json(name = "created") val created: Long,
    @Json(name = "data") val data: List<ImageData>
)

@JsonClass(generateAdapter = true)
data class ImageData(
    @Json(name = "url") val url: String?,
    @Json(name = "b64_json") val b64Json: String?,
    @Json(name = "revised_prompt") val revisedPrompt: String?,
    @Json(name = "id") val id: String?,
    @Json(name = "metadata") val metadata: ImageMetadata?
)

@JsonClass(generateAdapter = true)
data class ImageMetadata(
    @Json(name = "width") val width: Int,
    @Json(name = "height") val height: Int,
    @Json(name = "format") val format: String,
    @Json(name = "size_bytes") val sizeBytes: Long,
    @Json(name = "credits_used") val creditsUsed: Int,
    @Json(name = "quality") val quality: String? = null,
    @Json(name = "model") val model: String? = null,
    @Json(name = "revised_prompt") val revisedPrompt: String? = null
)

// Gallery Models

@JsonClass(generateAdapter = true)
data class ImageListResponse(
    @Json(name = "images") val images: List<ImageDetails>,
    @Json(name = "total") val total: Int,
    @Json(name = "page") val page: Int,
    @Json(name = "per_page") val perPage: Int
)

@JsonClass(generateAdapter = true)
data class ImageDetails(
    @Json(name = "id") val id: String,
    @Json(name = "user_id") val userId: String,
    @Json(name = "url") val url: String,
    @Json(name = "thumbnail_url") val thumbnailUrl: String?,
    @Json(name = "prompt") val prompt: String,
    @Json(name = "created_at") val createdAt: String,
    @Json(name = "metadata") val metadata: ImageMetadata?,
    @Json(name = "is_public") val isPublic: Boolean? = null,
    @Json(name = "tags") val tags: List<String>?
)