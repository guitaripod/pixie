package com.guitaripod.pixie.navigation

import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.activity.compose.BackHandler
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
    
    var navigationStack by remember { 
        mutableStateOf(listOf(
            if (authViewModel.isAuthenticated()) Screen.Chat() else Screen.Auth
        ))
    }
    
    val currentScreen = navigationStack.lastOrNull() ?: Screen.Auth
    
    fun navigateTo(screen: Screen) {
        navigationStack = navigationStack + screen
    }
    
    fun navigateBack(): Boolean {
        return if (navigationStack.size > 1) {
            navigationStack = navigationStack.dropLast(1)
            true
        } else {
            false
        }
    }
    
    BackHandler(enabled = navigationStack.size > 1) {
        navigateBack()
    }
    
    when (currentScreen) {
        is Screen.Auth -> {
            AuthScreen(
                authViewModel = authViewModel,
                onAuthSuccess = { navigateTo(Screen.Chat()) },
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
                    navigationStack = listOf(Screen.Auth)
                },
                onNavigateToGallery = {
                    navigateTo(Screen.Gallery)
                },
                onNavigateToCredits = {
                    navigateTo(Screen.CreditsMain)
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
                    navigateBack()
                },
                onImageClick = { image ->
                    selectedImage = image
                },
                onImageAction = { image, action ->
                    when (action) {
                        ImageAction.USE_FOR_EDIT -> {
                            navigateTo(Screen.Chat(editImage = image))
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
                                navigateTo(Screen.Chat(editImage = image))
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
                onNavigateBack = { navigateBack() },
                onNavigateToDashboard = { navigateTo(Screen.UsageDashboard) },
                onNavigateToHistory = { navigateTo(Screen.TransactionHistory) },
                onNavigateToPacks = { navigateTo(Screen.CreditPacks) },
                onNavigateToEstimator = { navigateTo(Screen.CostEstimator) }
            )
        }
        
        is Screen.UsageDashboard -> {
            val creditsViewModel: CreditsViewModel = viewModel(
                factory = CreditsViewModelFactory(appContainer.creditsRepository)
            )
            
            UsageDashboardScreen(
                viewModel = creditsViewModel,
                onNavigateBack = { navigateBack() },
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
                onNavigateBack = { navigateBack() }
            )
        }
        
        is Screen.CreditPacks -> {
            val creditsViewModel: CreditsViewModel = viewModel(
                factory = CreditsViewModelFactory(appContainer.creditsRepository)
            )
            
            CreditPacksScreen(
                viewModel = creditsViewModel,
                onNavigateBack = { navigateBack() },
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
                onNavigateBack = { navigateBack() }
            )
        }
    }
}