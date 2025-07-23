package com.guitaripod.pixie.navigation

import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import com.guitaripod.pixie.data.model.Config
import com.guitaripod.pixie.di.AppContainer
import com.guitaripod.pixie.presentation.auth.AuthScreen
import com.guitaripod.pixie.presentation.auth.AuthViewModel
import com.guitaripod.pixie.presentation.auth.AuthViewModelFactory
import com.guitaripod.pixie.presentation.chat.ChatGenerationScreen
import com.guitaripod.pixie.presentation.generation.GenerationViewModel
import com.guitaripod.pixie.presentation.generation.GenerationViewModelFactory

sealed class Screen {
    object Auth : Screen()
    object Chat : Screen()
}

@Composable
fun PixieNavigation(
    appContainer: AppContainer,
    modifier: Modifier = Modifier
) {
    val authViewModel: AuthViewModel = viewModel(
        factory = AuthViewModelFactory(appContainer.authRepository)
    )
    
    var currentScreen by remember { 
        mutableStateOf(
            if (authViewModel.isAuthenticated()) Screen.Chat else Screen.Auth
        )
    }
    
    when (currentScreen) {
        is Screen.Auth -> {
            AuthScreen(
                authViewModel = authViewModel,
                onAuthSuccess = { currentScreen = Screen.Chat },
                modifier = modifier
            )
        }
        
        is Screen.Chat -> {
            val generationViewModel: GenerationViewModel = viewModel(
                factory = GenerationViewModelFactory(appContainer.imageRepository)
            )
            
            ChatGenerationScreen(
                viewModel = generationViewModel,
                onLogout = {
                    authViewModel.logout()
                    currentScreen = Screen.Auth
                },
                modifier = modifier
            )
        }
    }
}