package com.guitaripod.pixie.presentation.gallery

import android.app.Application
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.guitaripod.pixie.data.repository.GalleryRepository
import com.guitaripod.pixie.utils.ImageSaver

class GalleryViewModelFactory(
    private val repository: GalleryRepository,
    private val imageSaver: ImageSaver,
    private val application: Application
) : ViewModelProvider.Factory {
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(GalleryViewModel::class.java)) {
            @Suppress("UNCHECKED_CAST")
            return GalleryViewModel(repository, imageSaver, application) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class")
    }
}