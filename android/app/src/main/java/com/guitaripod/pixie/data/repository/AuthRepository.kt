package com.guitaripod.pixie.data.repository

import android.app.Activity
import android.net.Uri
import com.guitaripod.pixie.data.auth.OAuthManager
import com.guitaripod.pixie.data.model.AuthResult
import com.guitaripod.pixie.data.model.Config
import kotlinx.coroutines.flow.Flow

/**
 * Repository for authentication operations
 */
interface AuthRepository {
    fun authenticateGithub(): Flow<AuthResult>
    fun authenticateGoogle(): Flow<AuthResult>
    fun authenticateApple(activity: Activity): Flow<AuthResult>
    fun handleOAuthCallback(uri: Uri): AuthResult
    fun logout()
    fun isAuthenticated(): Boolean
    fun getCurrentConfig(): Config
}

/**
 * Implementation of AuthRepository
 */
class AuthRepositoryImpl(
    private val oAuthManager: OAuthManager,
    private val preferencesRepository: PreferencesRepository
) : AuthRepository {
    
    override fun authenticateGithub(): Flow<AuthResult> = oAuthManager.authenticateGithub()
    
    override fun authenticateGoogle(): Flow<AuthResult> = oAuthManager.authenticateGoogle()
    
    override fun authenticateApple(activity: Activity): Flow<AuthResult> = oAuthManager.authenticateApple(activity)
    
    override fun handleOAuthCallback(uri: Uri): AuthResult = oAuthManager.handleOAuthCallback(uri)
    
    override fun logout() {
        oAuthManager.logout()
    }
    
    override fun isAuthenticated(): Boolean = preferencesRepository.isAuthenticated()
    
    override fun getCurrentConfig(): Config = preferencesRepository.loadConfig()
}