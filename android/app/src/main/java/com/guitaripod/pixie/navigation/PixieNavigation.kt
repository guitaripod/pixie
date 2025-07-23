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
import com.guitaripod.pixie.presentation.results.ResultsScreen

sealed class Screen {
    object Auth : Screen()
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
            if (authViewModel.isAuthenticated()) Screen.Generation else Screen.Auth
        )
    }
    
    when (currentScreen) {
        is Screen.Auth -> {
            AuthScreen(
                authViewModel = authViewModel,
                onAuthSuccess = { currentScreen = Screen.Generation },
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
                onLogout = {
                    authViewModel.logout()
                    currentScreen = Screen.Auth
                },
                modifier = modifier
            )
        }
        
        is Screen.Results -> {
            val results = currentScreen as Screen.Results
            ResultsScreen(
                imageUrls = results.imageUrls,
                onNavigateBack = { currentScreen = Screen.Generation },
                onLogout = {
                    authViewModel.logout()
                    currentScreen = Screen.Auth
                },
                modifier = modifier
            )
        }
    }
}