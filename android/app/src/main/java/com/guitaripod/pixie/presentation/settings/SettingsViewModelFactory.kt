package com.guitaripod.pixie.presentation.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.guitaripod.pixie.data.api.PixieApiService
import com.guitaripod.pixie.data.local.ConfigManager
import com.guitaripod.pixie.data.repository.PreferencesRepository
import com.guitaripod.pixie.data.repository.AdminRepository
import com.guitaripod.pixie.utils.CacheManager

class SettingsViewModelFactory(
    private val preferencesRepository: PreferencesRepository,
    private val configManager: ConfigManager,
    private val apiService: PixieApiService,
    private val cacheManager: CacheManager,
    private val adminRepository: AdminRepository
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(SettingsViewModel::class.java)) {
            return SettingsViewModel(
                preferencesRepository,
                configManager,
                apiService,
                cacheManager,
                adminRepository
            ) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class")
    }
}