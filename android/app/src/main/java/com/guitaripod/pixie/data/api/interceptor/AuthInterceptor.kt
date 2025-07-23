package com.guitaripod.pixie.data.api.interceptor

import android.content.SharedPreferences
import okhttp3.Interceptor
import okhttp3.Response

/**
 * OkHttp interceptor that adds the authentication token to requests.
 * Retrieves the token from encrypted SharedPreferences.
 */
class AuthInterceptor(
    private val encryptedPreferences: SharedPreferences
) : Interceptor {
    
    companion object {
        private const val KEY_API_TOKEN = "api_token"
        private const val HEADER_AUTHORIZATION = "Authorization"
        private const val BEARER_PREFIX = "Bearer "
    }
    
    override fun intercept(chain: Interceptor.Chain): Response {
        val originalRequest = chain.request()
        
        // Get the API token from encrypted storage
        val apiToken = encryptedPreferences.getString(KEY_API_TOKEN, null)
        
        // If no token, proceed with original request
        if (apiToken.isNullOrEmpty()) {
            return chain.proceed(originalRequest)
        }
        
        // Add authorization header
        val authorizedRequest = originalRequest.newBuilder()
            .header(HEADER_AUTHORIZATION, "$BEARER_PREFIX$apiToken")
            .build()
        
        return chain.proceed(authorizedRequest)
    }
    
    /**
     * Save the API token to encrypted storage
     */
    fun saveToken(token: String) {
        encryptedPreferences.edit()
            .putString(KEY_API_TOKEN, token)
            .apply()
    }
    
    /**
     * Clear the stored API token
     */
    fun clearToken() {
        encryptedPreferences.edit()
            .remove(KEY_API_TOKEN)
            .apply()
    }
    
    /**
     * Check if we have a stored token
     */
    fun hasToken(): Boolean {
        return !encryptedPreferences.getString(KEY_API_TOKEN, null).isNullOrEmpty()
    }
}