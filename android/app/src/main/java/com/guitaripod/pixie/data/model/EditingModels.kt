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