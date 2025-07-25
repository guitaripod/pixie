package com.guitaripod.pixie.presentation.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.guitaripod.pixie.data.api.PixieApiService
import com.guitaripod.pixie.data.local.ConfigManager
import com.guitaripod.pixie.data.local.PreferencesDataStore
import com.guitaripod.pixie.data.model.*
import com.guitaripod.pixie.data.repository.PreferencesRepository
import com.guitaripod.pixie.data.repository.AdminRepository
import com.guitaripod.pixie.utils.CacheManager
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import retrofit2.HttpException

data class SettingsUiState(
    val userPreferences: UserPreferences = UserPreferences(),
    val apiUrl: String = "https://openai-image-proxy.guitaripod.workers.dev",
    val cacheSize: String = "Calculating...",
    val connectionStatus: ConnectionStatus = ConnectionStatus.Idle,
    val isAdmin: Boolean = false
)

sealed class ConnectionStatus {
    object Idle : ConnectionStatus()
    object Testing : ConnectionStatus()
    object Success : ConnectionStatus()
    data class Error(val message: String) : ConnectionStatus()
}

class SettingsViewModel(
    private val preferencesRepository: PreferencesRepository,
    private val configManager: ConfigManager,
    private val apiService: PixieApiService,
    private val cacheManager: CacheManager,
    private val adminRepository: AdminRepository
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(SettingsUiState())
    val uiState: StateFlow<SettingsUiState> = _uiState.asStateFlow()
    
    init {
        viewModelScope.launch {
            // Load user preferences
            preferencesRepository.userPreferencesFlow.collect { preferences ->
                _uiState.update { it.copy(userPreferences = preferences) }
            }
        }
        
        viewModelScope.launch {
            // Load API URL
            val apiUrl = configManager.getApiUrl() ?: "https://openai-image-proxy.guitaripod.workers.dev"
            _uiState.update { it.copy(apiUrl = apiUrl) }
            
            // Check admin status
            val isAdmin = adminRepository.checkAdminStatus()
            _uiState.update { it.copy(isAdmin = isAdmin) }
            
            // Calculate cache size
            updateCacheSize()
        }
    }
    
    suspend fun updateTheme(theme: AppTheme) {
        preferencesRepository.updateTheme(theme)
    }
    
    suspend fun updateDefaultQuality(quality: ImageQuality) {
        preferencesRepository.updateDefaultQuality(quality)
    }
    
    suspend fun updateDefaultSize(size: String) {
        preferencesRepository.updateDefaultSize(size)
    }
    
    suspend fun updateDefaultOutputFormat(format: OutputFormat) {
        preferencesRepository.updateDefaultOutputFormat(format)
    }
    
    suspend fun updateDefaultCompressionLevel(level: Int) {
        preferencesRepository.updateDefaultCompressionLevel(level)
    }
    
    suspend fun clearCache() {
        cacheManager.clearCache()
        updateCacheSize()
    }
    
    private suspend fun updateCacheSize() {
        val size = cacheManager.getCacheSize()
        _uiState.update { it.copy(cacheSize = formatCacheSize(size)) }
    }
    
    private fun formatCacheSize(bytes: Long): String {
        return when {
            bytes < 1024 -> "$bytes B"
            bytes < 1024 * 1024 -> "${bytes / 1024} KB"
            bytes < 1024 * 1024 * 1024 -> "${bytes / (1024 * 1024)} MB"
            else -> "${bytes / (1024 * 1024 * 1024)} GB"
        }
    }
    
    suspend fun testConnection() {
        _uiState.update { it.copy(connectionStatus = ConnectionStatus.Testing) }
        
        try {
            // Use the same health check approach as CLI - GET request to base URL
            val response = apiService.healthCheck()
            if (response.isSuccessful) {
                _uiState.update { it.copy(connectionStatus = ConnectionStatus.Success) }
            } else {
                _uiState.update { 
                    it.copy(connectionStatus = ConnectionStatus.Error("API returned error: ${response.code()}"))
                }
            }
        } catch (e: HttpException) {
            _uiState.update { 
                it.copy(connectionStatus = ConnectionStatus.Error("HTTP ${e.code()}: ${e.message()}"))
            }
        } catch (e: Exception) {
            _uiState.update { 
                it.copy(connectionStatus = ConnectionStatus.Error(e.message ?: "Unknown error"))
            }
        }
    }
}