package com.guitaripod.pixie.presentation.utils

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.guitaripod.pixie.di.AppContainer

/**
 * Factory for creating ViewModels with dependencies from AppContainer.
 * This allows us to inject dependencies into ViewModels without using Hilt.
 */
class ViewModelFactory(
    private val appContainer: AppContainer
) : ViewModelProvider.Factory {
    
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        // Add ViewModel creation logic here as we create them
        // Example:
        // if (modelClass.isAssignableFrom(MainViewModel::class.java)) {
        //     return MainViewModel(appContainer.someRepository) as T
        // }
        
        throw IllegalArgumentException("Unknown ViewModel class: ${modelClass.name}")
    }
}

// Extension function to create ViewModelFactory from AppContainer
fun AppContainer.viewModelFactory() = ViewModelFactory(this)