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
import androidx.lifecycle.compose.collectAsStateWithLifecycle

sealed class Screen {
    object Auth : Screen()
    data class Chat(val editImage: ImageDetails? = null) : Screen()
    object Gallery : Screen()
    object CreditsMain : Screen()
    object UsageDashboard : Screen()
    object TransactionHistory : Screen()
    object CreditPacks : Screen()
    object CostEstimator : Screen()
    object Settings : Screen()
    object Help : Screen()
    object Admin : Screen()
    object AdminStats : Screen()
    object AdminCreditAdjustment : Screen()
    object AdminAdjustmentHistory : Screen()
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
            val chatScreen = currentScreen
            val generationViewModel: GenerationViewModel = viewModel(
                factory = GenerationViewModelFactory(appContainer.imageRepository)
            )
            
            val userPreferences by appContainer.preferencesDataStore.userPreferencesFlow.collectAsStateWithLifecycle(
                initialValue = com.guitaripod.pixie.data.model.UserPreferences()
            )
            
            ChatGenerationScreen(
                viewModel = generationViewModel,
                userPreferences = userPreferences,
                initialEditImage = chatScreen.editImage,
                onNavigateToGallery = {
                    navigateTo(Screen.Gallery)
                },
                onNavigateToCredits = {
                    navigateTo(Screen.CreditsMain)
                },
                onNavigateToSettings = {
                    navigateTo(Screen.Settings)
                },
                onEditGeneratedImage = { imageUrl, prompt ->
                    val tempImageDetails = ImageDetails(
                        id = "temp_${System.currentTimeMillis()}",
                        userId = "",
                        url = imageUrl,
                        thumbnailUrl = imageUrl,
                        prompt = prompt,
                        createdAt = System.currentTimeMillis().toString(),
                        metadata = null,
                        isPublic = false,
                        tags = null
                    )
                    navigateTo(Screen.Chat(editImage = tempImageDetails))
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
                onNavigateBack = {
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
            
            val purchaseViewModel: PurchaseViewModel = viewModel(
                factory = PurchaseViewModelFactory(appContainer.creditPurchaseManager)
            )
            
            EnhancedCreditPacksScreen(
                creditsViewModel = creditsViewModel,
                purchaseViewModel = purchaseViewModel,
                onNavigateBack = { navigateBack() }
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
        
        is Screen.Settings -> {
            val settingsViewModel: com.guitaripod.pixie.presentation.settings.SettingsViewModel = viewModel(
                factory = com.guitaripod.pixie.presentation.settings.SettingsViewModelFactory(
                    appContainer.preferencesRepository,
                    appContainer.configManager,
                    appContainer.pixieApiService,
                    appContainer.cacheManager,
                    appContainer.adminRepository
                )
            )
            
            com.guitaripod.pixie.presentation.settings.SettingsScreen(
                viewModel = settingsViewModel,
                onNavigateBack = { navigateBack() },
                onNavigateToHelp = { navigateTo(Screen.Help) },
                onNavigateToAdmin = { navigateTo(Screen.Admin) },
                onLogout = {
                    authViewModel.logout()
                    navigationStack = listOf(Screen.Auth)
                }
            )
        }
        
        is Screen.Help -> {
            com.guitaripod.pixie.presentation.help.HelpScreen(
                onNavigateBack = { navigateBack() }
            )
        }
        
        is Screen.Admin -> {
            val adminViewModel: com.guitaripod.pixie.presentation.admin.AdminViewModel = viewModel(
                factory = com.guitaripod.pixie.presentation.admin.AdminViewModelFactory(
                    appContainer.adminRepository
                )
            )
            
            com.guitaripod.pixie.presentation.admin.AdminScreen(
                viewModel = adminViewModel,
                onNavigateBack = { navigateBack() },
                onNavigateToStats = { navigateTo(Screen.AdminStats) },
                onNavigateToCreditAdjustment = { navigateTo(Screen.AdminCreditAdjustment) },
                onNavigateToAdjustmentHistory = { navigateTo(Screen.AdminAdjustmentHistory) }
            )
        }
        
        is Screen.AdminStats -> {
            val adminStatsViewModel: com.guitaripod.pixie.presentation.admin.AdminStatsViewModel = viewModel(
                factory = com.guitaripod.pixie.presentation.admin.AdminStatsViewModelFactory(
                    appContainer.adminRepository
                )
            )
            
            com.guitaripod.pixie.presentation.admin.AdminStatsScreen(
                viewModel = adminStatsViewModel,
                onNavigateBack = { navigateBack() }
            )
        }
        
        is Screen.AdminCreditAdjustment -> {
            val adminCreditAdjustmentViewModel: com.guitaripod.pixie.presentation.admin.AdminCreditAdjustmentViewModel = viewModel(
                factory = com.guitaripod.pixie.presentation.admin.AdminCreditAdjustmentViewModelFactory(
                    appContainer.adminRepository
                )
            )
            
            com.guitaripod.pixie.presentation.admin.AdminCreditAdjustmentScreen(
                viewModel = adminCreditAdjustmentViewModel,
                onNavigateBack = { navigateBack() }
            )
        }
        
        is Screen.AdminAdjustmentHistory -> {
            val adminAdjustmentHistoryViewModel: com.guitaripod.pixie.presentation.admin.AdminAdjustmentHistoryViewModel = viewModel(
                factory = com.guitaripod.pixie.presentation.admin.AdminAdjustmentHistoryViewModelFactory(
                    appContainer.adminRepository
                )
            )
            
            com.guitaripod.pixie.presentation.admin.AdminAdjustmentHistoryScreen(
                viewModel = adminAdjustmentHistoryViewModel,
                onNavigateBack = { navigateBack() }
            )
        }
    }
}