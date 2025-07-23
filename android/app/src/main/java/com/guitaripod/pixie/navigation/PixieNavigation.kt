package com.guitaripod.pixie.navigation

import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import com.guitaripod.pixie.data.model.Config
import com.guitaripod.pixie.di.AppContainer
import com.guitaripod.pixie.presentation.auth.AuthScreen
import com.guitaripod.pixie.presentation.auth.AuthViewModel
import com.guitaripod.pixie.presentation.auth.AuthViewModelFactory
import com.guitaripod.pixie.presentation.generation.GenerationScreen
import com.guitaripod.pixie.presentation.generation.GenerationViewModel
import com.guitaripod.pixie.presentation.generation.GenerationViewModelFactory
import com.guitaripod.pixie.presentation.home.HomeScreen

sealed class Screen {
    object Auth : Screen()
    object Home : Screen()
    object Generation : Screen()
    data class Results(val imageUrls: List<String>) : Screen()
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
            if (authViewModel.isAuthenticated()) Screen.Home else Screen.Auth
        )
    }
    
    when (val screen = currentScreen) {
        is Screen.Auth -> {
            AuthScreen(
                authViewModel = authViewModel,
                onAuthSuccess = { currentScreen = Screen.Home },
                modifier = modifier
            )
        }
        
        is Screen.Home -> {
            val config = authViewModel.getCurrentConfig()
            HomeScreen(
                config = config,
                onLogout = {
                    authViewModel.logout()
                    currentScreen = Screen.Auth
                },
                onNavigateToGenerate = { currentScreen = Screen.Generation },
                modifier = modifier
            )
        }
        
        is Screen.Generation -> {
            val generationViewModel: GenerationViewModel = viewModel(
                factory = GenerationViewModelFactory(appContainer.imageRepository)
            )
            
            GenerationScreen(
                viewModel = generationViewModel,
                onNavigateToResults = { imageUrls ->
                    currentScreen = Screen.Results(imageUrls)
                },
                modifier = modifier
            )
        }
        
        is Screen.Results -> {
            HomeScreen(
                config = authViewModel.getCurrentConfig(),
                onLogout = {
                    authViewModel.logout()
                    currentScreen = Screen.Auth
                },
                onNavigateToGenerate = { currentScreen = Screen.Generation },
                modifier = modifier
            )
        }
    }
}