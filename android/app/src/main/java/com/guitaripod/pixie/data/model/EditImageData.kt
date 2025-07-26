package com.guitaripod.pixie.data.model

import com.squareup.moshi.JsonClass

@JsonClass(generateAdapter = true)
data class EditImageData(
    val imageUri: String,
    val prompt: String,
    val variations: Int = 1,
    val size: String = "1024x1024",
    val quality: String = "low",
    val fidelity: String = "low"
)