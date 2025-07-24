package com.guitaripod.pixie.presentation.credits

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.guitaripod.pixie.data.repository.CreditsRepository

class CreditsViewModelFactory(
    private val repository: CreditsRepository
) : ViewModelProvider.Factory {
    
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(CreditsViewModel::class.java)) {
            return CreditsViewModel(repository) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class")
    }
}