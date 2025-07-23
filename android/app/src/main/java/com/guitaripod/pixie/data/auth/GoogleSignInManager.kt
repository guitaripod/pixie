package com.guitaripod.pixie.data.auth

import android.app.Activity
import android.content.Context
import android.content.Intent
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInAccount
import com.google.android.gms.auth.api.signin.GoogleSignInClient
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.tasks.Task
import com.guitaripod.pixie.data.api.NetworkCallAdapter
import com.guitaripod.pixie.data.api.PixieApiService
import com.guitaripod.pixie.data.api.model.NetworkResult
import com.guitaripod.pixie.data.local.ConfigManager
import com.guitaripod.pixie.data.model.*
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.tasks.await

/**
 * Manages native Google Sign-In
 */
class GoogleSignInManager(
    private val context: Context,
    private val apiService: PixieApiService,
    private val configManager: ConfigManager,
    private val networkCallAdapter: NetworkCallAdapter
) {
    
    companion object {
        // Request web client ID token (required for Google Sign-In)
        const val WEB_CLIENT_ID = "720004930052-n4tdei4ua9shd2hqr1f6udmg5ijvj25j.apps.googleusercontent.com"
    }
    
    private val googleSignInOptions = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
        .requestIdToken(WEB_CLIENT_ID)
        .requestEmail()
        .build()
        
    private val googleSignInClient: GoogleSignInClient = GoogleSignIn.getClient(context, googleSignInOptions)
    
    /**
     * Sign in with Google using native flow
     */
    fun signIn(activity: Activity, launcher: ActivityResultLauncher<Intent>) {
        val signInIntent = googleSignInClient.signInIntent
        launcher.launch(signInIntent)
    }
    
    /**
     * Handle the sign-in result
     */
    fun handleSignInResult(data: Intent?): Flow<AuthResult> = flow {
        emit(AuthResult.Pending)
        
        try {
            val task = GoogleSignIn.getSignedInAccountFromIntent(data)
            val account = task.getResult(ApiException::class.java)
            
            val idToken = account?.idToken
            if (idToken == null) {
                emit(AuthResult.Error("Failed to get ID token"))
                return@flow
            }
            
            // Send ID token to backend
            val tokenRequest = GoogleTokenRequest(idToken = idToken)
            when (val result = networkCallAdapter.safeApiCall { apiService.googleTokenAuth(tokenRequest) }) {
                is NetworkResult.Success -> {
                    val authResponse = result.data
                    
                    // Save credentials
                    val config = Config(
                        apiKey = authResponse.apiKey,
                        userId = authResponse.userId,
                        authProvider = "google",
                        apiUrl = configManager.getApiUrl()
                    )
                    configManager.saveConfig(config)
                    
                    emit(AuthResult.Success(
                        apiKey = authResponse.apiKey,
                        userId = authResponse.userId,
                        provider = "google"
                    ))
                }
                is NetworkResult.Error -> {
                    emit(AuthResult.Error(result.exception.message ?: "Authentication failed"))
                }
                is NetworkResult.Loading -> {
                    emit(AuthResult.Error("Unexpected loading state"))
                }
            }
        } catch (e: ApiException) {
            when (e.statusCode) {
                12501 -> emit(AuthResult.Cancelled) // User cancelled
                else -> emit(AuthResult.Error("Sign in failed: ${e.message}"))
            }
        } catch (e: Exception) {
            emit(AuthResult.Error("Sign in failed: ${e.message}"))
        }
    }
    
    /**
     * Sign out from Google
     */
    suspend fun signOut() {
        try {
            googleSignInClient.signOut().await()
        } catch (e: Exception) {
        }
    }
}