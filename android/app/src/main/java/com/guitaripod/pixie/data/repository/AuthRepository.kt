package com.guitaripod.pixie.data.repository

import android.app.Activity
import android.content.Intent
import android.net.Uri
import androidx.activity.result.ActivityResultLauncher
import com.guitaripod.pixie.data.auth.GitHubOAuthManager
import com.guitaripod.pixie.data.auth.GoogleSignInManager
import com.guitaripod.pixie.data.auth.OAuthWebFlowManager
import com.guitaripod.pixie.data.model.AuthResult
import com.guitaripod.pixie.data.model.Config
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow

interface AuthRepository {
    fun authenticateGithub(): Flow<AuthResult>
    fun authenticateGoogle(activity: Activity, launcher: ActivityResultLauncher<Intent>): Flow<AuthResult>
    fun handleGoogleSignInResult(data: Intent?): Flow<AuthResult>
    fun authenticateApple(activity: Activity): Flow<AuthResult>
    fun authenticateManually(apiKey: String, userId: String, provider: String): Flow<AuthResult>
    suspend fun handleOAuthCallback(uri: Uri): AuthResult
    suspend fun logout()
    fun isAuthenticated(): Boolean
    fun getCurrentConfig(): Config
    fun saveCredentials(config: Config)
}

class AuthRepositoryImpl(
    private val gitHubOAuthManager: GitHubOAuthManager,
    private val googleSignInManager: GoogleSignInManager,
    private val oAuthWebFlowManager: OAuthWebFlowManager,
    private val preferencesRepository: PreferencesRepository
) : AuthRepository {
    
    override fun authenticateGithub(): Flow<AuthResult> = gitHubOAuthManager.authenticate()
    
    override fun authenticateGoogle(activity: Activity, launcher: ActivityResultLauncher<Intent>): Flow<AuthResult> = flow {
        emit(AuthResult.Pending)
        googleSignInManager.signIn(activity, launcher)
    }
    
    override fun handleGoogleSignInResult(data: Intent?): Flow<AuthResult> = 
        googleSignInManager.handleSignInResult(data)
    
    override fun authenticateApple(activity: Activity): Flow<AuthResult> = 
        oAuthWebFlowManager.authenticateApple()
    
    override suspend fun handleOAuthCallback(uri: Uri): AuthResult = 
        gitHubOAuthManager.handleOAuthCallback(uri)
    
    override suspend fun logout() {
        preferencesRepository.clearConfig()
        gitHubOAuthManager.clearPendingAuth()
        googleSignInManager.signOut()
    }
    
    override fun isAuthenticated(): Boolean = preferencesRepository.isAuthenticated()
    
    override fun getCurrentConfig(): Config = preferencesRepository.loadConfig()
    
    override fun saveCredentials(config: Config) {
        preferencesRepository.saveConfig(config)
    }
    
    override fun authenticateManually(apiKey: String, userId: String, provider: String): Flow<AuthResult> = flow {
        emit(AuthResult.Pending)
        
        val config = Config(
            apiKey = apiKey,
            userId = userId,
            authProvider = provider,
            apiUrl = preferencesRepository.loadConfig().apiUrl
        )
        saveCredentials(config)
        
        emit(AuthResult.Success(
            apiKey = apiKey,
            userId = userId,
            provider = provider
        ))
    }
}