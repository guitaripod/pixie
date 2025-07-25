package com.guitaripod.pixie.presentation.auth

import android.app.Activity
import android.content.Intent
import androidx.activity.result.ActivityResultLauncher
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.guitaripod.pixie.data.model.AuthResult
import com.guitaripod.pixie.data.repository.AuthRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.launch

class AuthViewModel(
    private val authRepository: AuthRepository
) : ViewModel() {
    
    fun authenticateGithub(): Flow<AuthResult> {
        return authRepository.authenticateGithub()
    }
    
    fun authenticateGoogle(activity: Activity, launcher: ActivityResultLauncher<Intent>): Flow<AuthResult> {
        return authRepository.authenticateGoogle(activity, launcher)
    }
    
    fun handleGoogleSignInResult(data: Intent?): Flow<AuthResult> {
        return authRepository.handleGoogleSignInResult(data)
    }
    
    fun authenticateApple(activity: Activity): Flow<AuthResult> {
        return authRepository.authenticateApple(activity)
    }
    
    fun authenticateManually(apiKey: String, userId: String, provider: String): Flow<AuthResult> {
        return authRepository.authenticateManually(apiKey, userId, provider)
    }
    
    fun authenticateDebug(): Flow<AuthResult> {
        return authRepository.authenticateDebug()
    }
    
    fun isAuthenticated(): Boolean {
        return authRepository.isAuthenticated()
    }
    
    fun logout() {
        viewModelScope.launch {
            authRepository.logout()
        }
    }
    
    fun getCurrentConfig() = authRepository.getCurrentConfig()
}

class AuthViewModelFactory(
    private val authRepository: AuthRepository
) : ViewModelProvider.Factory {
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(AuthViewModel::class.java)) {
            @Suppress("UNCHECKED_CAST")
            return AuthViewModel(authRepository) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class")
    }
}