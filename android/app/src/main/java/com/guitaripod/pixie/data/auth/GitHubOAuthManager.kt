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
        
        val apiUrl = configManager.getApiUrl() ?: "https://openai-image-proxy.guitaripod.workers.dev"
        val authUrl = "$apiUrl/v1/auth/github?" + buildString {
            append("state=").append(Uri.encode(state.state))
            append("&redirect_uri=").append(Uri.encode(REDIRECT_URI))
        }
        
        openCustomTab(authUrl)
        emit(AuthResult.Pending)
    }
    
    /**
     * Handle OAuth callback from deep link
     */
    suspend fun handleOAuthCallback(uri: Uri): AuthResult {
        val code = uri.getQueryParameter("code")
        val state = uri.getQueryParameter("state")
        val error = uri.getQueryParameter("error")
        
        if (error != null) {
            pendingAuthState = null
            return AuthResult.Error(error)
        }
        
        if (code == null || state == null) {
            pendingAuthState = null
            return AuthResult.Error("Missing required parameters")
        }
        
        val savedState = pendingAuthState
        if (savedState == null || savedState.state != state || !savedState.isValid()) {
            pendingAuthState = null
            return AuthResult.Error("Invalid OAuth state")
        }
        
        val callbackRequest = OAuthCallbackRequest(
            code = code,
            state = state,
            redirectUri = REDIRECT_URI
        )
        
        return when (val result = networkCallAdapter.safeApiCall { apiService.githubAuthCallback(callbackRequest) }) {
            is NetworkResult.Success -> {
                val authResponse = result.data
                
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
     * Open URL in external browser
     */
    private fun openCustomTab(url: String) {
        val browserIntent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
        browserIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(browserIntent)
    }
    
    /**
     * Clear any pending auth state
     */
    fun clearPendingAuth() {
        pendingAuthState = null
    }
}