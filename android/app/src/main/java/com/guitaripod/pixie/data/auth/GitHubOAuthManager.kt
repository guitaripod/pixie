package com.guitaripod.pixie.data.auth

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.browser.customtabs.CustomTabsIntent
import com.guitaripod.pixie.data.api.NetworkCallAdapter
import com.guitaripod.pixie.data.api.PixieApiService
import com.guitaripod.pixie.data.api.model.NetworkResult
import com.guitaripod.pixie.data.api.model.OAuthCallbackRequest
import com.guitaripod.pixie.data.local.ConfigManager
import com.guitaripod.pixie.data.model.*
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import java.util.UUID

/**
 * Manages GitHub OAuth flow
 */
class GitHubOAuthManager(
    private val context: Context,
    private val apiService: PixieApiService,
    private val configManager: ConfigManager,
    private val networkCallAdapter: NetworkCallAdapter
) {
    
    companion object {
        const val OAUTH_CALLBACK_SCHEME = "pixie"
        const val OAUTH_CALLBACK_HOST = "auth"
        const val REDIRECT_URI = "$OAUTH_CALLBACK_SCHEME://$OAUTH_CALLBACK_HOST"
    }
    
    private var pendingAuthState: OAuthState? = null
    
    /**
     * Start GitHub authentication using web flow
     */
    fun authenticate(): Flow<AuthResult> = flow {
        emit(AuthResult.Pending)
        
        val state = OAuthState(provider = "github")
        pendingAuthState = state
        
        // Build OAuth URL
        val apiUrl = configManager.getApiUrl() ?: "https://openai-image-proxy.guitaripod.workers.dev"
        val authUrl = "$apiUrl/v1/auth/github?" + buildString {
            append("state=").append(Uri.encode(state.state))
            append("&redirect_uri=").append(Uri.encode(REDIRECT_URI))
        }
        
        // Open browser
        openCustomTab(authUrl)
        
        emit(AuthResult.Pending)
    }
    
    /**
     * Handle OAuth callback from deep link
     */
    suspend fun handleOAuthCallback(uri: Uri): AuthResult {
        // Extract parameters from callback URL
        val code = uri.getQueryParameter("code")
        val state = uri.getQueryParameter("state")
        val error = uri.getQueryParameter("error")
        
        // Check for errors
        if (error != null) {
            pendingAuthState = null
            return AuthResult.Error(error)
        }
        
        // Validate we have required parameters
        if (code == null || state == null) {
            pendingAuthState = null
            return AuthResult.Error("Missing required parameters")
        }
        
        // Validate state
        val savedState = pendingAuthState
        if (savedState == null || savedState.state != state || !savedState.isValid()) {
            pendingAuthState = null
            return AuthResult.Error("Invalid OAuth state")
        }
        
        // Exchange code for token
        val callbackRequest = OAuthCallbackRequest(
            code = code,
            state = state,
            redirectUri = REDIRECT_URI
        )
        
        return when (val result = networkCallAdapter.safeApiCall { apiService.githubAuthCallback(callbackRequest) }) {
            is NetworkResult.Success -> {
                val authResponse = result.data
                
                // Save credentials
                val config = Config(
                    apiKey = authResponse.apiKey,
                    userId = authResponse.userId,
                    authProvider = "github",
                    apiUrl = configManager.getApiUrl()
                )
                configManager.saveConfig(config)
                
                pendingAuthState = null
                AuthResult.Success(
                    apiKey = authResponse.apiKey,
                    userId = authResponse.userId,
                    provider = "github"
                )
            }
            is NetworkResult.Error -> {
                pendingAuthState = null
                AuthResult.Error(result.exception.message ?: "Authentication failed")
            }
            is NetworkResult.Loading -> {
                AuthResult.Error("Unexpected loading state")
            }
        }
    }
    
    /**
     * Open URL in Chrome Custom Tab
     */
    private fun openCustomTab(url: String) {
        try {
            val customTabsIntent = CustomTabsIntent.Builder()
                .setShowTitle(true)
                .setUrlBarHidingEnabled(true)
                .build()
            
            customTabsIntent.intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            customTabsIntent.launchUrl(context, Uri.parse(url))
        } catch (e: Exception) {
            val browserIntent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
            browserIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(browserIntent)
        }
    }
    
    /**
     * Clear any pending auth state
     */
    fun clearPendingAuth() {
        pendingAuthState = null
    }
}