package com.guitaripod.pixie.presentation.generation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.guitaripod.pixie.data.repository.ImageRepository

class GenerationViewModelFactory(
    private val imageRepository: ImageRepository
) : ViewModelProvider.Factory {
    
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(GenerationViewModel::class.java)) {
            return GenerationViewModel(imageRepository) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class")
    }
}