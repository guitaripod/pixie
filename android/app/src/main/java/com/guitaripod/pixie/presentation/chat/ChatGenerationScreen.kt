package com.guitaripod.pixie.presentation.chat

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.automirrored.filled.ExitToApp
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.guitaripod.pixie.data.model.*
import com.guitaripod.pixie.data.api.model.ImageDetails
import com.guitaripod.pixie.presentation.generation.GenerationViewModel
import kotlinx.coroutines.launch
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.SnackbarDuration
import android.net.Uri
import com.guitaripod.pixie.utils.NotificationPermissionEffect
import com.guitaripod.pixie.utils.rememberHapticFeedback
import com.guitaripod.pixie.utils.hapticClickable
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.ui.input.pointer.pointerInput

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatGenerationScreen(
    viewModel: GenerationViewModel,
    userPreferences: com.guitaripod.pixie.data.model.UserPreferences,
    initialEditImage: ImageDetails? = null,
    onNavigateToGallery: () -> Unit = {},
    onNavigateToCredits: () -> Unit = {},
    onNavigateToSettings: () -> Unit = {},
    onEditGeneratedImage: (imageUrl: String, prompt: String) -> Unit = { _, _ -> }
) {
    val messages by viewModel.messages.collectAsState()
    val isToolbarExpanded by viewModel.isToolbarExpanded.collectAsState()
    val toolbarMode by viewModel.toolbarMode.collectAsState()
    val previewImageUri by viewModel.previewImageUri.collectAsState()
    val listState = rememberLazyListState()
    val coroutineScope = rememberCoroutineScope()
    val snackbarHostState = remember { SnackbarHostState() }
    
    val configuration = LocalConfiguration.current
    val density = LocalDensity.current
    val screenHeight = with(density) { configuration.screenHeightDp.dp }
    val expandedToolbarHeight = screenHeight * 0.85f
    
    val isGenerating by viewModel.isGenerating.collectAsState()
    val error by viewModel.error.collectAsState()
    
    val prompt by viewModel.prompt.collectAsState()
    val selectedModel by viewModel.selectedModel.collectAsState()
    val selectedSize by viewModel.selectedSize.collectAsState()
    val selectedQuality by viewModel.selectedQuality.collectAsState()
    val selectedBackground by viewModel.selectedBackground.collectAsState()
    val selectedFormat by viewModel.selectedFormat.collectAsState()
    val compressionLevel by viewModel.compressionLevel.collectAsState()
    val selectedModeration by viewModel.selectedModeration.collectAsState()
    
    LaunchedEffect(userPreferences) {
        viewModel.initializeWithUserPreferences(userPreferences)
    }
    
    val editOptions by viewModel.editOptions.collectAsState()
    val editToolbarState by viewModel.editToolbarState.collectAsState()
    
    LaunchedEffect(initialEditImage) {
        initialEditImage?.let { image ->
            val uri = Uri.parse(image.url)
            viewModel.updateToolbarMode(ToolbarMode.Edit(
                SelectedImage(
                    uri = uri,
                    displayName = "Gallery Image"
                )
            ))
        }
    }
    
    LaunchedEffect(viewModel) {
        viewModel.generationResult.collect { result ->
            result?.let { imageUrls ->
                viewModel.updateMessages(messages.dropLast(1) + ChatMessage.ImageResponse(
                    imageUrls = imageUrls,
                    isLoading = false
                ))
                coroutineScope.launch {
                    listState.animateScrollToItem(messages.size - 1)
                }
            }
        }
    }
    
    LaunchedEffect(error) {
        error?.let { errorMessage ->
            val lastMessage = messages.lastOrNull()
            if (lastMessage is ChatMessage.ImageResponse && lastMessage.isLoading) {
                viewModel.updateMessages(messages.dropLast(1) + lastMessage.copy(
                    isLoading = false,
                    error = errorMessage
                ))
            }
        }
    }
    
    NotificationPermissionEffect { granted ->
        if (granted) {
            coroutineScope.launch {
                snackbarHostState.showSnackbar(
                    message = "Notifications enabled! You'll be notified when images are ready.",
                    duration = SnackbarDuration.Short
                )
            }
        }
    }
    
    Scaffold(
        modifier = Modifier
            .fillMaxSize(),
        snackbarHost = {
            SnackbarHost(hostState = snackbarHostState)
        },
        topBar = {
            val haptic = rememberHapticFeedback()
            TopAppBar(
                modifier = Modifier.height(80.dp),
                navigationIcon = {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .padding(start = 8.dp)
                            .hapticClickable {
                                viewModel.resetChat()
                            }
                    ) {
                        Icon(
                            imageVector = Icons.Default.AutoAwesome,
                            contentDescription = "New Chat",
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.padding(8.dp)
                        )
                        Text(
                            text = "New",
                            style = MaterialTheme.typography.labelLarge,
                            color = MaterialTheme.colorScheme.primary,
                            fontWeight = FontWeight.Medium,
                            modifier = Modifier.padding(end = 8.dp)
                        )
                    }
                },
                title = { },
                actions = {
                    TextButton(
                        onClick = {
                            haptic.click()
                            onNavigateToGallery()
                        },
                        colors = ButtonDefaults.textButtonColors(
                            contentColor = MaterialTheme.colorScheme.primary
                        )
                    ) {
                        Text("Gallery")
                    }
                    TextButton(
                        onClick = {
                            haptic.click()
                            onNavigateToCredits()
                        },
                        colors = ButtonDefaults.textButtonColors(
                            contentColor = MaterialTheme.colorScheme.primary
                        )
                    ) {
                        Text("Credits")
                    }
                    IconButton(
                        onClick = {
                            haptic.click()
                            onNavigateToSettings()
                        }
                    ) {
                        Icon(
                            imageVector = Icons.Default.Settings,
                            contentDescription = "Settings",
                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface,
                    scrolledContainerColor = MaterialTheme.colorScheme.surface
                )
            )
        }
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
        ) {
            LazyColumn(
                state = listState,
                modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingValues)
                    .pointerInput(isToolbarExpanded) {
                        if (isToolbarExpanded) {
                            detectTapGestures {
                                viewModel.updateToolbarExpanded(false)
                            }
                        }
                    },
                contentPadding = PaddingValues(
                    start = 12.dp,
                    end = 12.dp,
                    top = 12.dp,
                    bottom = if (isToolbarExpanded) expandedToolbarHeight + 40.dp else 120.dp
                ),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                if (messages.isEmpty()) {
                    item {
                        SuggestionsView(
                            onPromptSelected = { selectedPrompt ->
                                when (toolbarMode) {
                                    is ToolbarMode.Generate -> viewModel.updatePrompt(selectedPrompt)
                                    is ToolbarMode.Edit -> viewModel.updateEditOptions(editOptions.copy(prompt = selectedPrompt))
                                }
                                viewModel.updateToolbarExpanded(true)
                            },
                            onImageSelected = { uri ->
                                viewModel.updatePreviewImageUri(uri)
                            },
                            isInEditMode = toolbarMode is ToolbarMode.Edit
                        )
                    }
                }
                
                items(messages) { message ->
                    when (message) {
                        is ChatMessage.UserMessage -> {
                            UserMessageBubble(message)
                        }
                        is ChatMessage.ImageResponse -> {
                            val previousUserMessage = messages.findLast { 
                                it is ChatMessage.UserMessage && messages.indexOf(it) < messages.indexOf(message) 
                            } as? ChatMessage.UserMessage
                            ImageResponseBubble(
                                message = message,
                                quantity = previousUserMessage?.quantity ?: 1,
                                onShowSnackbar = { text ->
                                    coroutineScope.launch {
                                        snackbarHostState.showSnackbar(
                                            message = text,
                                            duration = SnackbarDuration.Short
                                        )
                                    }
                                },
                                onEditImage = { imageUrl ->
                                    onEditGeneratedImage(imageUrl, "")
                                }
                            )
                        }
                    }
                }
            }
            
            when (toolbarMode) {
                is ToolbarMode.Generate -> {
                    GenerationToolbar(
                        mode = toolbarMode,
                        isExpanded = isToolbarExpanded,
                        onExpandedChange = { viewModel.updateToolbarExpanded(it) },
                        prompt = prompt,
                        onPromptChange = { viewModel.updatePrompt(it) },
                        selectedModel = selectedModel,
                        onModelSelected = { viewModel.updateSelectedModel(it) },
                        selectedSize = selectedSize,
                        onSizeSelected = { viewModel.updateSelectedSize(it) },
                        selectedQuality = selectedQuality,
                        onQualitySelected = { viewModel.updateSelectedQuality(it) },
                        selectedBackground = selectedBackground,
                        onBackgroundSelected = { viewModel.updateSelectedBackground(it) },
                        selectedFormat = selectedFormat,
                        onFormatSelected = { viewModel.updateSelectedFormat(it) },
                        compressionLevel = compressionLevel,
                        onCompressionChanged = { viewModel.updateCompressionLevel(it) },
                        selectedModeration = selectedModeration,
                        onModerationSelected = { viewModel.updateSelectedModeration(it) },
                        isGenerating = isGenerating,
                        onGenerate = {
                            val actualSize = selectedSize.value
                            
                            val userMessage = ChatMessage.UserMessage(
                                prompt = prompt,
                                model = selectedModel.value,
                                quality = if (selectedModel == ImageModel.OPENAI) selectedQuality.value else "standard",
                                size = if (selectedModel == ImageModel.OPENAI) selectedSize.displayName else "Auto",
                                actualSize = if (selectedModel == ImageModel.OPENAI) actualSize else "auto",
                                quantity = 1,
                                background = if (selectedModel == ImageModel.OPENAI) selectedBackground?.displayName else null,
                                format = if (selectedModel == ImageModel.OPENAI) selectedFormat?.displayName else null,
                                compression = if (selectedModel == ImageModel.OPENAI && selectedFormat?.supportsCompression == true) compressionLevel else null,
                                moderation = if (selectedModel == ImageModel.OPENAI) selectedModeration?.displayName else null
                            )
                            viewModel.updateMessages(messages + userMessage + ChatMessage.ImageResponse(
                                imageUrls = emptyList(),
                                isLoading = true
                            ))
                            
                            coroutineScope.launch {
                                listState.animateScrollToItem(messages.size - 1)
                            }
                            
                            val options = GenerationOptions(
                                prompt = prompt,
                                model = selectedModel.value,
                                number = 1,
                                size = actualSize,
                                quality = selectedQuality.value,
                                background = selectedBackground?.value,
                                outputFormat = selectedFormat?.value,
                                compression = if (selectedFormat?.supportsCompression == true) compressionLevel else null,
                                moderation = selectedModeration?.value
                            )
                            viewModel.generateImages(options)
                            
                            viewModel.updatePrompt("")
                            viewModel.updateToolbarExpanded(false)
                        },
                        onSwitchToGenerate = {
                            viewModel.updateToolbarMode(ToolbarMode.Generate)
                            viewModel.updatePrompt("")
                        },
                        modifier = Modifier.align(Alignment.BottomCenter)
                    )
                }
                is ToolbarMode.Edit -> {
                    val editMode = toolbarMode as ToolbarMode.Edit
                    EditingToolbar(
                        selectedImage = editMode.selectedImage,
                        editOptions = editOptions,
                        onEditOptionsChange = { viewModel.updateEditOptions(it) },
                        editToolbarState = editToolbarState,
                        onEditToolbarStateChange = { viewModel.updateEditToolbarState(it) },
                        isProcessing = isGenerating,
                        onStartEdit = {
                            val actualSize = editOptions.size.value
                            
                            val editModeText = "Edit"
                            
                            val userMessage = ChatMessage.UserMessage(
                                prompt = "$editModeText: ${editOptions.prompt}",
                                model = editOptions.model.value,
                                quality = if (editOptions.model == ImageModel.OPENAI) editOptions.quality.value else "standard",
                                size = if (editOptions.model == ImageModel.OPENAI) editOptions.size.displayName else "Auto",
                                actualSize = if (editOptions.model == ImageModel.OPENAI) actualSize else "auto",
                                quantity = editOptions.variations,
                                background = null,
                                format = "PNG",
                                compression = null,
                                moderation = null
                            )
                            viewModel.updateMessages(messages + userMessage + ChatMessage.ImageResponse(
                                imageUrls = emptyList(),
                                isLoading = true
                            ))
                            
                            coroutineScope.launch {
                                listState.animateScrollToItem(messages.size - 1)
                            }
                            
                            viewModel.editImage(
                                imageUri = editMode.selectedImage.uri,
                                editOptions = editOptions
                            )
                            
                            viewModel.updateEditOptions(EditOptions())
                            viewModel.updateEditToolbarState(EditToolbarState())
                        },
                        onSwitchToGenerate = {
                            viewModel.updateToolbarMode(ToolbarMode.Generate)
                            viewModel.updatePrompt("")
                            viewModel.updateEditOptions(EditOptions())
                            viewModel.updateEditToolbarState(EditToolbarState())
                        },
                        modifier = Modifier.align(Alignment.BottomCenter)
                    )
                }
            }
            
            previewImageUri?.let { uri ->
                ImagePreviewDialog(
                    imageUri = uri,
                    onConfirm = {
                        viewModel.updateToolbarMode(ToolbarMode.Edit(
                            SelectedImage(uri = uri)
                        ))
                        viewModel.updatePreviewImageUri(null)
                    },
                    onDismiss = {
                        viewModel.updatePreviewImageUri(null)
                    }
                )
            }
        }
    }
}

@Composable
fun UserMessageBubble(message: ChatMessage.UserMessage) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.End
    ) {
        Surface(
            modifier = Modifier.widthIn(max = 240.dp),
            shape = RoundedCornerShape(
                topStart = 12.dp,
                topEnd = 4.dp,
                bottomStart = 12.dp,
                bottomEnd = 12.dp
            ),
            color = MaterialTheme.colorScheme.primary,
            tonalElevation = 2.dp
        ) {
            Column(
                modifier = Modifier.padding(10.dp),
                verticalArrangement = Arrangement.spacedBy(3.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "🎨 Generation Request",
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onPrimary
                    )
                    Text(
                        text = if (message.model.startsWith("gemini")) "Gemini" else "OpenAI",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onPrimary.copy(alpha = 0.9f),
                        modifier = Modifier
                            .background(
                                MaterialTheme.colorScheme.onPrimary.copy(alpha = 0.1f),
                                RoundedCornerShape(4.dp)
                            )
                            .padding(horizontal = 6.dp, vertical = 2.dp)
                    )
                }
                
                Text(
                    text = message.prompt,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onPrimary
                )
                
                if (!message.model.startsWith("gemini") || message.prompt.startsWith("Edit:")) {
                    Spacer(modifier = Modifier.height(2.dp))
                    HorizontalDivider(color = MaterialTheme.colorScheme.onPrimary.copy(alpha = 0.3f))
                    Spacer(modifier = Modifier.height(2.dp))
                    
                    if (!message.model.startsWith("gemini")) {
                        DetailRow("Quality", message.quality.uppercase(), MaterialTheme.colorScheme.onPrimary)
                        DetailRow("Size", message.size + if (message.size != message.actualSize && message.actualSize != "auto") " (${message.actualSize})" else "", MaterialTheme.colorScheme.onPrimary)
                        
                        message.background?.let {
                            DetailRow("Background", it, MaterialTheme.colorScheme.onPrimary)
                        }
                        message.format?.let {
                            DetailRow("Format", it, MaterialTheme.colorScheme.onPrimary)
                            message.compression?.let { comp ->
                                DetailRow("Compress", "$comp%", MaterialTheme.colorScheme.onPrimary)
                            }
                        }
                        message.moderation?.let {
                            DetailRow("Moderation", it, MaterialTheme.colorScheme.onPrimary)
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun DetailRow(label: String, value: String, color: Color) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodySmall,
            color = color.copy(alpha = 0.8f)
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodySmall,
            fontWeight = FontWeight.Medium,
            color = color
        )
    }
}

@Composable
fun ImageResponseBubble(
    message: ChatMessage.ImageResponse,
    quantity: Int = 1,
    onShowSnackbar: (String) -> Unit,
    onEditImage: ((String) -> Unit)? = null
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.Start
    ) {
        AnimatedContent(
            targetState = when {
                message.isLoading -> "loading"
                message.error != null -> "error"
                else -> "success"
            },
            transitionSpec = {
                fadeIn(animationSpec = tween(300)) + scaleIn(
                    initialScale = 0.92f,
                    animationSpec = tween(300)
                ) togetherWith fadeOut(animationSpec = tween(200)) + scaleOut(
                    targetScale = 0.92f,
                    animationSpec = tween(200)
                )
            },
            label = "image_response_transition"
        ) { state ->
            when (state) {
                "loading" -> {
                Surface(
                    modifier = Modifier
                        .widthIn(max = 280.dp)
                        .height(200.dp),
                    shape = RoundedCornerShape(
                        topStart = 4.dp,
                        topEnd = 16.dp,
                        bottomStart = 16.dp,
                        bottomEnd = 16.dp
                    ),
                    color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f),
                    tonalElevation = 1.dp
                ) {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(16.dp)
                        ) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(40.dp),
                                strokeWidth = 3.dp,
                                color = MaterialTheme.colorScheme.primary
                            )
                            Text(
                                text = if (quantity == 1) "Generating image..." else "Generating $quantity images...",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            }
            "error" -> {
                Surface(
                    modifier = Modifier.widthIn(max = 320.dp),
                    shape = RoundedCornerShape(
                        topStart = 4.dp,
                        topEnd = 20.dp,
                        bottomStart = 20.dp,
                        bottomEnd = 20.dp
                    ),
                    color = MaterialTheme.colorScheme.errorContainer,
                    tonalElevation = 1.dp
                ) {
                    Row(
                        modifier = Modifier.padding(16.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        verticalAlignment = Alignment.Top
                    ) {
                        Icon(
                            imageVector = Icons.Default.Warning,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onErrorContainer,
                            modifier = Modifier.size(20.dp)
                        )
                        Text(
                            text = message.error ?: "Unknown error",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onErrorContainer
                        )
                    }
                }
            }
            "success" -> {
                Column(
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    message.imageUrls.forEach { imageUrl ->
                        ImageBubble(
                            imageUrl = imageUrl,
                            onSaveSuccess = onShowSnackbar,
                            onSaveError = onShowSnackbar,
                            onEdit = if (onEditImage != null) {
                                { onEditImage(imageUrl) }
                            } else null
                        )
                    }
                    
                    if (message.imageUrls.size > 1) {
                        SaveAllButton(
                            imageUrls = message.imageUrls,
                            onSaveSuccess = onShowSnackbar,
                            onSaveError = onShowSnackbar
                        )
                    }
                }
            }
            }
        }
    }
}