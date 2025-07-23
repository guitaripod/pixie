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
import androidx.lifecycle.viewmodel.compose.viewModel
import com.guitaripod.pixie.ui.theme.PixieTheme
import com.guitaripod.pixie.data.model.AuthResult
import com.guitaripod.pixie.presentation.auth.AuthScreen
import com.guitaripod.pixie.presentation.auth.AuthViewModel
import com.guitaripod.pixie.presentation.auth.AuthViewModelFactory
import com.guitaripod.pixie.presentation.home.HomeScreen
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        
        // Handle OAuth callback if launched from deep link
        handleIntent(intent)
        
        val appContainer = (application as PixieApplication).appContainer
        
        setContent {
            PixieTheme {
                val authViewModel: AuthViewModel = viewModel(
                    factory = AuthViewModelFactory(appContainer.authRepository)
                )
                
                var isAuthenticated by remember { mutableStateOf(authViewModel.isAuthenticated()) }
                
                Scaffold(modifier = Modifier.fillMaxSize()) { innerPadding ->
                    if (isAuthenticated) {
                        val config = authViewModel.getCurrentConfig()
                        HomeScreen(
                            config = config,
                            onLogout = {
                                authViewModel.logout()
                                isAuthenticated = false
                            },
                            modifier = Modifier.padding(innerPadding)
                        )
                    } else {
                        AuthScreen(
                            authViewModel = authViewModel,
                            onAuthSuccess = { isAuthenticated = true },
                            modifier = Modifier.padding(innerPadding)
                        )
                    }
                }
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
                // Handle OAuth callback
                lifecycleScope.launch {
                    val appContainer = (application as PixieApplication).appContainer
                    val result = appContainer.authRepository.handleOAuthCallback(uri)
                    
                    // TODO: Handle the auth result (e.g., show toast, navigate to home)
                    when (result) {
                        is AuthResult.Success -> {
                            // TODO: Navigate to home screen
                            // For now, just recreate to refresh auth state
                            recreate()
                        }
                        is AuthResult.Error -> {
                            // TODO: Show error message
                        }
                        is AuthResult.Cancelled -> {
                            // TODO: Handle cancellation
                        }
                        is AuthResult.Pending -> {
                            // Should not happen for callback
                        }
                    }
                }
            }
        }
    }
}