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
                defaultQuality = ImageQuality.valueOf(
                    preferences[KEY_DEFAULT_QUALITY] ?: ImageQuality.LOW.name
                ),
                defaultSize = preferences[KEY_DEFAULT_SIZE] ?: "1024x1024",
                defaultOutputFormat = OutputFormat.valueOf(
                    preferences[KEY_DEFAULT_OUTPUT_FORMAT] ?: OutputFormat.PNG.name
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
            preferences[KEY_DEFAULT_QUALITY] = quality.name
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
            preferences[KEY_DEFAULT_OUTPUT_FORMAT] = format.name
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