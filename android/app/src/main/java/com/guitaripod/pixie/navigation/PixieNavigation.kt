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

sealed class Screen {
    object Auth : Screen()
    object Chat : Screen()
    object Gallery : Screen()
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
                onNavigateToGallery = {
                    currentScreen = Screen.Gallery
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
                    currentScreen = Screen.Chat
                },
                onImageClick = { image ->
                    selectedImage = image
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
                                // TODO: Navigate to chat with edit mode
                                currentScreen = Screen.Chat
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
    }
}