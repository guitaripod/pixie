package com.guitaripod.pixie.presentation.generation

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.guitaripod.pixie.data.repository.ImageRepository
import com.guitaripod.pixie.utils.NotificationHelper

class GenerationViewModelFactory(
    private val imageRepository: ImageRepository,
    private val notificationHelper: NotificationHelper,
    private val context: Context
) : ViewModelProvider.Factory {
    
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(GenerationViewModel::class.java)) {
            return GenerationViewModel(imageRepository, notificationHelper, context) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class")
    }
}