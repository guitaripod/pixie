package com.guitaripod.pixie.data.model

import android.net.Uri

data class SelectedImage(
    val uri: Uri,
    val displayName: String? = null
)

sealed class ToolbarMode {
    object Generate : ToolbarMode()
    data class Edit(val selectedImage: SelectedImage) : ToolbarMode()
}

sealed class EditMode {
    object Simple : EditMode()
}

data class EditOptions(
    val prompt: String = "",
    val variations: Int = 1,
    val size: ImageSize = ImageSize.AUTO,
    val quality: ImageQuality = ImageQuality.LOW,
    val fidelity: FidelityLevel = FidelityLevel.LOW
)

enum class FidelityLevel(val value: String, val displayName: String, val description: String) {
    LOW("low", "Low", "More creative freedom"),
    HIGH("high", "High", "Preserve details (faces, logos)")
}

data class EditToolbarState(
    val isExpanded: Boolean = false,
    val showAdvancedOptions: Boolean = false
)