package com.guitaripod.pixie.presentation.generation

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.guitaripod.pixie.data.repository.ImageRepository
import com.guitaripod.pixie.utils.NotificationHelper
import com.guitaripod.pixie.utils.HapticFeedbackManager

class GenerationViewModelFactory(
    private val imageRepository: ImageRepository,
    private val notificationHelper: NotificationHelper,
    private val context: Context,
    private val hapticFeedbackManager: HapticFeedbackManager
) : ViewModelProvider.Factory {
    
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(GenerationViewModel::class.java)) {
            return GenerationViewModel(imageRepository, notificationHelper, context, hapticFeedbackManager) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class")
    }
}