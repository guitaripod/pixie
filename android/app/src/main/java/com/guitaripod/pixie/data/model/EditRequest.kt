package com.guitaripod.pixie.data.model

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass

@JsonClass(generateAdapter = true)
data class EditRequest(
    @Json(name = "image") val image: List<String>,
    @Json(name = "prompt") val prompt: String,
    @Json(name = "mask") val mask: String? = null,
    @Json(name = "model") val model: String = "gpt-image-1",
    @Json(name = "n") val n: Int = 1,
    @Json(name = "size") val size: String = "1024x1024",
    @Json(name = "quality") val quality: String = "low",
    @Json(name = "background") val background: String = "auto",
    @Json(name = "input_fidelity") val inputFidelity: String = "low",
    @Json(name = "output_format") val outputFormat: String = "png",
    @Json(name = "output_compression") val outputCompression: Int? = null,
    @Json(name = "partial_images") val partialImages: Int = 0,
    @Json(name = "stream") val stream: Boolean = false,
    @Json(name = "user") val user: String? = null
)