package com.guitaripod.pixie.data.api.interceptor

import com.guitaripod.pixie.data.local.ConfigManager
import okhttp3.Interceptor
import okhttp3.Response

/**
 * OkHttp interceptor that adds the authentication token to requests.
 * Retrieves the token from ConfigManager.
 */
class AuthInterceptor(
    private val configManager: ConfigManager
) : Interceptor {
    
    companion object {
        private const val HEADER_AUTHORIZATION = "Authorization"
        private const val BEARER_PREFIX = "Bearer "
    }
    
    override fun intercept(chain: Interceptor.Chain): Response {
        val originalRequest = chain.request()
        
        // Get the API token from config
        val apiToken = configManager.getApiKey()
        
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
}