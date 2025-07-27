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
        
        throw IllegalArgumentException("Unknown ViewModel class: ${modelClass.name}")
    }
}

fun AppContainer.viewModelFactory() = ViewModelFactory(this)