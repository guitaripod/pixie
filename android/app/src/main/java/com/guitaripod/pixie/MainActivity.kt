package com.guitaripod.pixie

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.lifecycle.lifecycleScope
import androidx.compose.foundation.isSystemInDarkTheme
import com.guitaripod.pixie.ui.theme.PixieTheme
import com.guitaripod.pixie.data.model.AuthResult
import com.guitaripod.pixie.navigation.PixieNavigation
import kotlinx.coroutines.launch
import androidx.lifecycle.compose.collectAsStateWithLifecycle

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        
        handleIntent(intent)
        
        val appContainer = (application as PixieApplication).appContainer
        
        // Set RevenueCat user ID if authenticated
        val config = appContainer.preferencesRepository.loadConfig()
        config.userId?.let { userId ->
            appContainer.revenueCatManager.setUserId(userId)
        }
        
        setContent {
            val userPreferences by appContainer.preferencesDataStore.userPreferencesFlow.collectAsStateWithLifecycle(
                initialValue = com.guitaripod.pixie.data.model.UserPreferences()
            )
            
            PixieTheme(
                darkTheme = when (userPreferences.theme) {
                    com.guitaripod.pixie.data.model.AppTheme.LIGHT -> false
                    com.guitaripod.pixie.data.model.AppTheme.DARK -> true
                    com.guitaripod.pixie.data.model.AppTheme.SYSTEM -> isSystemInDarkTheme()
                }
            ) {
                PixieNavigation(
                    appContainer = appContainer,
                    modifier = Modifier.fillMaxSize()
                )
            }
        }
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }
    
    private fun handleIntent(intent: Intent) {
        intent.data?.let { uri ->
            if (uri.scheme == "pixie" && uri.host == "auth") {
                lifecycleScope.launch {
                    val appContainer = (application as PixieApplication).appContainer
                    val result = appContainer.authRepository.handleOAuthCallback(uri)
                    
                    when (result) {
                        is AuthResult.Success -> {
                            recreate()
                        }
                        is AuthResult.Error -> {
                        }
                        is AuthResult.Cancelled -> {
                        }
                        is AuthResult.Pending -> {
                        }
                    }
                }
            }
        }
    }
}