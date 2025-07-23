package com.guitaripod.pixie

import android.app.Activity
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.viewmodel.compose.viewModel
import com.guitaripod.pixie.ui.theme.PixieTheme
import com.guitaripod.pixie.presentation.auth.AuthScreen
import com.guitaripod.pixie.presentation.auth.AuthViewModel
import com.guitaripod.pixie.presentation.auth.AuthViewModelFactory
import com.guitaripod.pixie.presentation.home.HomeScreen

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        
        
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
                        val activity = LocalContext.current as Activity
                        AuthScreen(
                            onGithubAuth = { authViewModel.authenticateGithub() },
                            onGoogleAuth = { authViewModel.authenticateGoogle() },
                            onAppleAuth = { authViewModel.authenticateApple(activity) },
                            onAuthSuccess = { isAuthenticated = true },
                            modifier = Modifier.padding(innerPadding)
                        )
                    }
                }
            }
        }
    }
    
}