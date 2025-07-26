package com.guitaripod.pixie.data.local

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.*
import com.guitaripod.pixie.data.model.*
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.map
import java.io.IOException

/**
 * Manages user preferences using DataStore
 */
class PreferencesDataStore(
    private val dataStore: DataStore<Preferences>
) {
    companion object {
        private val KEY_THEME = stringPreferencesKey("theme")
        private val KEY_DEFAULT_QUALITY = stringPreferencesKey("default_quality")
        private val KEY_DEFAULT_SIZE = stringPreferencesKey("default_size")
        private val KEY_DEFAULT_OUTPUT_FORMAT = stringPreferencesKey("default_output_format")
        private val KEY_DEFAULT_COMPRESSION_LEVEL = intPreferencesKey("default_compression_level")
    }
    
    /**
     * Flow of user preferences
     */
    val userPreferencesFlow: Flow<UserPreferences> = dataStore.data
        .catch { exception ->
            if (exception is IOException) {
                emit(emptyPreferences())
            } else {
                throw exception
            }
        }
        .map { preferences ->
            UserPreferences(
                theme = AppTheme.valueOf(
                    preferences[KEY_THEME] ?: AppTheme.SYSTEM.name
                ),
                defaultQuality = DefaultImageQuality.valueOf(
                    preferences[KEY_DEFAULT_QUALITY] ?: DefaultImageQuality.LOW.name
                ),
                defaultSize = preferences[KEY_DEFAULT_SIZE] ?: "auto",
                defaultOutputFormat = DefaultOutputFormat.valueOf(
                    preferences[KEY_DEFAULT_OUTPUT_FORMAT] ?: DefaultOutputFormat.PNG.name
                ),
                defaultCompressionLevel = preferences[KEY_DEFAULT_COMPRESSION_LEVEL] ?: 75
            )
        }
    
    /**
     * Update theme preference
     */
    suspend fun updateTheme(theme: AppTheme) {
        dataStore.edit { preferences ->
            preferences[KEY_THEME] = theme.name
        }
    }
    
    /**
     * Update default quality
     */
    suspend fun updateDefaultQuality(quality: ImageQuality) {
        dataStore.edit { preferences ->
            preferences[KEY_DEFAULT_QUALITY] = when(quality) {
                ImageQuality.LOW -> DefaultImageQuality.LOW.name
                ImageQuality.MEDIUM -> DefaultImageQuality.MEDIUM.name
                ImageQuality.HIGH -> DefaultImageQuality.HIGH.name
                ImageQuality.AUTO -> DefaultImageQuality.AUTO.name
            }
        }
    }
    
    /**
     * Update default size
     */
    suspend fun updateDefaultSize(size: String) {
        dataStore.edit { preferences ->
            preferences[KEY_DEFAULT_SIZE] = size
        }
    }
    
    /**
     * Update default output format
     */
    suspend fun updateDefaultOutputFormat(format: OutputFormat) {
        dataStore.edit { preferences ->
            preferences[KEY_DEFAULT_OUTPUT_FORMAT] = when(format) {
                OutputFormat.PNG -> DefaultOutputFormat.PNG.name
                OutputFormat.JPEG -> DefaultOutputFormat.JPEG.name
                OutputFormat.WEBP -> DefaultOutputFormat.WEBP.name
            }
        }
    }
    
    /**
     * Update default compression level
     */
    suspend fun updateDefaultCompressionLevel(level: Int) {
        dataStore.edit { preferences ->
            preferences[KEY_DEFAULT_COMPRESSION_LEVEL] = level.coerceIn(0, 100)
        }
    }
    
    /**
     * Update all preferences at once
     */
    suspend fun updatePreferences(userPreferences: UserPreferences) {
        dataStore.edit { preferences ->
            preferences[KEY_THEME] = userPreferences.theme.name
            preferences[KEY_DEFAULT_QUALITY] = userPreferences.defaultQuality.name
            preferences[KEY_DEFAULT_SIZE] = userPreferences.defaultSize
            preferences[KEY_DEFAULT_OUTPUT_FORMAT] = userPreferences.defaultOutputFormat.name
            preferences[KEY_DEFAULT_COMPRESSION_LEVEL] = userPreferences.defaultCompressionLevel
        }
    }
}