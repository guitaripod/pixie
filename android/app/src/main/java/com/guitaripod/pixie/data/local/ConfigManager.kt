package com.guitaripod.pixie.data.local

import android.content.SharedPreferences
import com.guitaripod.pixie.data.model.Config

/**
 * Manages encrypted configuration storage
 */
class ConfigManager(
    private val encryptedPreferences: SharedPreferences
) {
    companion object {
        private const val KEY_API_URL = "api_url"
        private const val KEY_API_KEY = "api_key"
        private const val KEY_USER_ID = "user_id"
        private const val KEY_AUTH_PROVIDER = "auth_provider"
    }
    
    /**
     * Save configuration to encrypted storage
     */
    fun saveConfig(config: Config) {
        encryptedPreferences.edit().apply {
            config.apiUrl?.let { putString(KEY_API_URL, it) } ?: remove(KEY_API_URL)
            config.apiKey?.let { putString(KEY_API_KEY, it) } ?: remove(KEY_API_KEY)
            config.userId?.let { putString(KEY_USER_ID, it) } ?: remove(KEY_USER_ID)
            config.authProvider?.let { putString(KEY_AUTH_PROVIDER, it) } ?: remove(KEY_AUTH_PROVIDER)
            apply()
        }
    }
    
    /**
     * Load configuration from encrypted storage
     */
    fun loadConfig(): Config {
        return Config(
            apiUrl = encryptedPreferences.getString(KEY_API_URL, null),
            apiKey = encryptedPreferences.getString(KEY_API_KEY, null),
            userId = encryptedPreferences.getString(KEY_USER_ID, null),
            authProvider = encryptedPreferences.getString(KEY_AUTH_PROVIDER, null)
        )
    }
    
    /**
     * Clear all configuration (logout)
     */
    fun clearConfig() {
        encryptedPreferences.edit().clear().apply()
    }
    
    /**
     * Check if user is authenticated
     */
    fun isAuthenticated(): Boolean {
        return loadConfig().isAuthenticated()
    }
    
    /**
     * Get current API key
     */
    fun getApiKey(): String? {
        return encryptedPreferences.getString(KEY_API_KEY, null)
    }
    
    /**
     * Get custom API URL or null for default
     */
    fun getApiUrl(): String? {
        return encryptedPreferences.getString(KEY_API_URL, null)
    }
}