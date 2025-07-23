package com.guitaripod.pixie.data.auth

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.browser.customtabs.CustomTabsIntent
import com.guitaripod.pixie.data.api.NetworkCallAdapter
import com.guitaripod.pixie.data.api.PixieApiService
import com.guitaripod.pixie.data.api.model.NetworkResult
import com.guitaripod.pixie.data.local.ConfigManager
import com.guitaripod.pixie.data.model.*
import com.guitaripod.pixie.data.api.model.DeviceCodeResponse
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.withTimeoutOrNull

/**
 * Manages OAuth authentication flows
 */
class OAuthManager(
    private val context: Context,
    private val apiService: PixieApiService,
    private val configManager: ConfigManager,
    private val networkCallAdapter: NetworkCallAdapter
) {
    
    companion object {
        const val DEVICE_FLOW_TIMEOUT_MS = 300_000L // 5 minutes
        const val DEVICE_FLOW_POLL_INTERVAL_MS = 5_000L // 5 seconds
        const val OAUTH_CALLBACK_SCHEME = "pixie"
        const val OAUTH_CALLBACK_HOST = "auth"
    }
    
    private var currentOAuthState: OAuthState? = null
    
    /**
     * Start GitHub authentication using device flow
     */
    fun authenticateGithub(): Flow<AuthResult> = flow {
        emit(AuthResult.Pending)
        
        val request = DeviceCodeRequest(provider = "github")
        when (val result = networkCallAdapter.safeApiCall { apiService.startDeviceAuth(request) }) {
            is NetworkResult.Success -> {
                val deviceCode = result.data
                emit(AuthResult.Pending)
                
                // Open browser with device code URL
                openCustomTab(deviceCode.verificationUriComplete ?: deviceCode.verificationUri)
                
                // Poll for completion
                pollDeviceAuth(deviceCode)?.let { authResult ->
                    emit(authResult)
                } ?: emit(AuthResult.Error("Authentication timeout"))
            }
            is NetworkResult.Error -> {
                emit(AuthResult.Error(result.exception.message ?: "Authentication failed"))
            }
            is NetworkResult.Loading -> { /* Should not happen */ }
        }
    }
    
    /**
     * Start Google authentication using device flow
     */
    fun authenticateGoogle(): Flow<AuthResult> = flow {
        emit(AuthResult.Pending)
        
        val request = DeviceCodeRequest(provider = "google")
        when (val result = networkCallAdapter.safeApiCall { apiService.startDeviceAuth(request) }) {
            is NetworkResult.Success -> {
                val deviceCode = result.data
                emit(AuthResult.Pending)
                
                // Open browser with device code URL
                openCustomTab(deviceCode.verificationUriComplete ?: deviceCode.verificationUri)
                
                // Poll for completion
                pollDeviceAuth(deviceCode)?.let { authResult ->
                    emit(authResult)
                } ?: emit(AuthResult.Error("Authentication timeout"))
            }
            is NetworkResult.Error -> {
                emit(AuthResult.Error(result.exception.message ?: "Authentication failed"))
            }
            is NetworkResult.Loading -> { /* Should not happen */ }
        }
    }
    
    /**
     * Start Apple authentication using web flow
     */
    fun authenticateApple(@Suppress("UNUSED_PARAMETER") activity: Activity): Flow<AuthResult> = flow {
        emit(AuthResult.Pending)
        
        // Generate state for security
        val state = OAuthState(provider = "apple")
        currentOAuthState = state
        
        // Build OAuth URL
        val apiUrl = configManager.getApiUrl() ?: "https://openai-image-proxy.guitaripod.workers.dev"
        val redirectUri = "$OAUTH_CALLBACK_SCHEME://$OAUTH_CALLBACK_HOST/apple"
        val authUrl = "$apiUrl/v1/auth/apple?state=${state.state}&redirect_uri=${Uri.encode(redirectUri)}"
        
        // Open browser
        openCustomTab(authUrl)
        
        // Since Apple flow returns to a web page with credentials,
        // we'll need the user to manually enter them (like CLI does)
        emit(AuthResult.Error("Please complete authentication in browser and enter credentials manually"))
    }
    
    /**
     * Handle OAuth callback from deep link
     */
    fun handleOAuthCallback(uri: Uri): AuthResult {
        // Extract parameters from callback URL
        @Suppress("UNUSED_VARIABLE")
        val code = uri.getQueryParameter("code")
        val state = uri.getQueryParameter("state")
        val error = uri.getQueryParameter("error")
        
        // Check for errors
        if (error != null) {
            return AuthResult.Error(error)
        }
        
        // Validate state
        val savedState = currentOAuthState
        if (savedState == null || savedState.state != state || !savedState.isValid()) {
            return AuthResult.Error("Invalid OAuth state")
        }
        
        // Clear state
        currentOAuthState = null
        
        // For now, return error as we need to implement the callback endpoint
        return AuthResult.Error("OAuth callback not fully implemented")
    }
    
    /**
     * Poll device authentication endpoint
     */
    private suspend fun pollDeviceAuth(deviceCode: DeviceCodeResponse): AuthResult? {
        val request = DeviceTokenRequest(deviceCode = deviceCode.deviceCode)
        val intervalMs = deviceCode.interval * 1000L
        
        return withTimeoutOrNull(DEVICE_FLOW_TIMEOUT_MS) {
            var authResult: AuthResult? = null
            while (authResult == null) {
                val result = networkCallAdapter.safeApiCall { apiService.checkDeviceAuth(request) }
                when (result) {
                    is NetworkResult.Success -> {
                        val tokenResponse = result.data
                        
                        // Save credentials
                        val provider = when {
                            deviceCode.verificationUriComplete?.contains("github") == true -> "github"
                            deviceCode.verificationUriComplete?.contains("google") == true -> "google"
                            else -> "unknown"
                        }
                        
                        val config = Config(
                            apiKey = tokenResponse.apiKey,
                            userId = tokenResponse.userId,
                            authProvider = provider,
                            apiUrl = configManager.getApiUrl()
                        )
                        configManager.saveConfig(config)
                        
                        authResult = AuthResult.Success(
                            apiKey = tokenResponse.apiKey,
                            userId = tokenResponse.userId,
                            provider = config.authProvider ?: "unknown"
                        )
                    }
                    is NetworkResult.Error -> {
                        // Check if it's a pending error
                        if (result.exception.message?.contains("pending") == true) {
                            // Continue polling
                            delay(intervalMs)
                        } else {
                            authResult = AuthResult.Error(
                                result.exception.message ?: "Authentication failed"
                            )
                        }
                    }
                    is NetworkResult.Loading -> { /* Should not happen */ }
                }
            }
            authResult
        }
    }
    
    /**
     * Open URL in Chrome Custom Tab
     */
    private fun openCustomTab(url: String) {
        val customTabsIntent = CustomTabsIntent.Builder()
            .setShowTitle(true)
            .setUrlBarHidingEnabled(true)
            .build()
        
        customTabsIntent.launchUrl(context, Uri.parse(url))
    }
    
    /**
     * Logout - clear stored credentials
     */
    fun logout() {
        configManager.clearConfig()
    }
}