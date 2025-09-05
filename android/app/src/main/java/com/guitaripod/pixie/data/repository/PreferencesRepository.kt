package com.guitaripod.pixie.data.repository

import com.guitaripod.pixie.data.local.ConfigManager
import com.guitaripod.pixie.data.local.PreferencesDataStore
import com.guitaripod.pixie.data.model.*
import kotlinx.coroutines.flow.Flow

/**
 * Repository for managing all app preferences and configuration
 */
interface PreferencesRepository {
    fun saveConfig(config: Config)
    fun loadConfig(): Config
    fun clearConfig()
    fun isAuthenticated(): Boolean
    fun getApiKey(): String?
    fun getApiUrl(): String?
    val userPreferencesFlow: Flow<UserPreferences>
    suspend fun updateTheme(theme: AppTheme)
    suspend fun updateDefaultModel(model: ImageModel)
    suspend fun updateDefaultQuality(quality: ImageQuality)
    suspend fun updateDefaultSize(size: String)
    suspend fun updateDefaultOutputFormat(format: OutputFormat)
    suspend fun updateDefaultCompressionLevel(level: Int)
    suspend fun updatePreferences(userPreferences: UserPreferences)
}

/**
 * Implementation of PreferencesRepository
 */
class PreferencesRepositoryImpl(
    private val configManager: ConfigManager,
    private val preferencesDataStore: PreferencesDataStore
) : PreferencesRepository {
    override fun saveConfig(config: Config) = configManager.saveConfig(config)
    override fun loadConfig(): Config = configManager.loadConfig()
    override fun clearConfig() = configManager.clearConfig()
    override fun isAuthenticated(): Boolean = configManager.isAuthenticated()
    override fun getApiKey(): String? = configManager.getApiKey()
    override fun getApiUrl(): String? = configManager.getApiUrl()
    override val userPreferencesFlow: Flow<UserPreferences> = preferencesDataStore.userPreferencesFlow
    override suspend fun updateTheme(theme: AppTheme) = preferencesDataStore.updateTheme(theme)
    override suspend fun updateDefaultModel(model: ImageModel) = preferencesDataStore.updateDefaultModel(model)
    override suspend fun updateDefaultQuality(quality: ImageQuality) = preferencesDataStore.updateDefaultQuality(quality)
    override suspend fun updateDefaultSize(size: String) = preferencesDataStore.updateDefaultSize(size)
    override suspend fun updateDefaultOutputFormat(format: OutputFormat) = preferencesDataStore.updateDefaultOutputFormat(format)
    override suspend fun updateDefaultCompressionLevel(level: Int) = preferencesDataStore.updateDefaultCompressionLevel(level)
    override suspend fun updatePreferences(userPreferences: UserPreferences) = preferencesDataStore.updatePreferences(userPreferences)
}