package com.guitaripod.pixie.navigation

import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.viewmodel.compose.viewModel
import com.guitaripod.pixie.data.model.Config
import com.guitaripod.pixie.di.AppContainer
import com.guitaripod.pixie.presentation.auth.AuthScreen
import com.guitaripod.pixie.presentation.auth.AuthViewModel
import com.guitaripod.pixie.presentation.auth.AuthViewModelFactory
import com.guitaripod.pixie.presentation.chat.ChatGenerationScreen
import com.guitaripod.pixie.presentation.generation.GenerationViewModel
import com.guitaripod.pixie.presentation.generation.GenerationViewModelFactory
import com.guitaripod.pixie.presentation.gallery.GalleryScreen
import com.guitaripod.pixie.presentation.gallery.GalleryViewModel
import com.guitaripod.pixie.presentation.gallery.GalleryViewModelFactory
import com.guitaripod.pixie.presentation.gallery.ImageDetailBottomSheet
import com.guitaripod.pixie.presentation.gallery.ImageAction
import com.guitaripod.pixie.data.api.model.ImageDetails
import com.guitaripod.pixie.presentation.credits.*

sealed class Screen {
    object Auth : Screen()
    data class Chat(val editImage: ImageDetails? = null) : Screen()
    object Gallery : Screen()
    object CreditsMain : Screen()
    object UsageDashboard : Screen()
    object TransactionHistory : Screen()
    object CreditPacks : Screen()
    object CostEstimator : Screen()
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
        mutableStateOf<Screen>(
            if (authViewModel.isAuthenticated()) Screen.Chat() else Screen.Auth
        )
    }
    
    when (currentScreen) {
        is Screen.Auth -> {
            AuthScreen(
                authViewModel = authViewModel,
                onAuthSuccess = { currentScreen = Screen.Chat() },
                modifier = modifier
            )
        }
        
        is Screen.Chat -> {
            val chatScreen = currentScreen as Screen.Chat
            val generationViewModel: GenerationViewModel = viewModel(
                factory = GenerationViewModelFactory(appContainer.imageRepository)
            )
            
            ChatGenerationScreen(
                viewModel = generationViewModel,
                initialEditImage = chatScreen.editImage,
                onLogout = {
                    authViewModel.logout()
                    currentScreen = Screen.Auth
                },
                onNavigateToGallery = {
                    currentScreen = Screen.Gallery
                },
                onNavigateToCredits = {
                    currentScreen = Screen.CreditsMain
                },
                modifier = modifier
            )
        }
        
        is Screen.Gallery -> {
            val context = LocalContext.current
            val galleryViewModel: GalleryViewModel = viewModel(
                factory = GalleryViewModelFactory(
                    appContainer.galleryRepository,
                    appContainer.imageSaver,
                    context.applicationContext as android.app.Application
                )
            )
            
            var selectedImage by remember { mutableStateOf<ImageDetails?>(null) }
            
            GalleryScreen(
                viewModel = galleryViewModel,
                onNavigateToChat = {
                    currentScreen = Screen.Chat()
                },
                onImageClick = { image ->
                    selectedImage = image
                },
                onImageAction = { image, action ->
                    when (action) {
                        ImageAction.USE_FOR_EDIT -> {
                            currentScreen = Screen.Chat(editImage = image)
                        }
                        else -> {
                            galleryViewModel.handleImageAction(image, action)
                        }
                    }
                },
                modifier = modifier
            )
            
            selectedImage?.let { image ->
                ImageDetailBottomSheet(
                    image = image,
                    onDismiss = { selectedImage = null },
                    onAction = { action ->
                        when (action) {
                            ImageAction.USE_FOR_EDIT -> {
                                currentScreen = Screen.Chat(editImage = image)
                                selectedImage = null
                            }
                            else -> {
                                galleryViewModel.handleImageAction(image, action)
                                selectedImage = null
                            }
                        }
                    }
                )
            }
        }
        
        is Screen.CreditsMain -> {
            val creditsViewModel: CreditsViewModel = viewModel(
                factory = CreditsViewModelFactory(appContainer.creditsRepository)
            )
            
            CreditsMainScreen(
                viewModel = creditsViewModel,
                onNavigateBack = { currentScreen = Screen.Chat() },
                onNavigateToDashboard = { currentScreen = Screen.UsageDashboard },
                onNavigateToHistory = { currentScreen = Screen.TransactionHistory },
                onNavigateToPacks = { currentScreen = Screen.CreditPacks },
                onNavigateToEstimator = { currentScreen = Screen.CostEstimator }
            )
        }
        
        is Screen.UsageDashboard -> {
            val creditsViewModel: CreditsViewModel = viewModel(
                factory = CreditsViewModelFactory(appContainer.creditsRepository)
            )
            
            UsageDashboardScreen(
                viewModel = creditsViewModel,
                onNavigateBack = { currentScreen = Screen.CreditsMain },
                onExportCsv = {
                }
            )
        }
        
        is Screen.TransactionHistory -> {
            val creditsViewModel: CreditsViewModel = viewModel(
                factory = CreditsViewModelFactory(appContainer.creditsRepository)
            )
            
            TransactionHistoryScreen(
                viewModel = creditsViewModel,
                onNavigateBack = { currentScreen = Screen.CreditsMain }
            )
        }
        
        is Screen.CreditPacks -> {
            val creditsViewModel: CreditsViewModel = viewModel(
                factory = CreditsViewModelFactory(appContainer.creditsRepository)
            )
            
            CreditPacksScreen(
                viewModel = creditsViewModel,
                onNavigateBack = { currentScreen = Screen.CreditsMain },
                onPackSelected = { pack ->
                }
            )
        }
        
        is Screen.CostEstimator -> {
            val creditsViewModel: CreditsViewModel = viewModel(
                factory = CreditsViewModelFactory(appContainer.creditsRepository)
            )
            
            CostEstimatorScreen(
                viewModel = creditsViewModel,
                onNavigateBack = { currentScreen = Screen.CreditsMain }
            )
        }
    }
}