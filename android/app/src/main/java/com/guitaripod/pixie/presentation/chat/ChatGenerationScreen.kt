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
    
    val isGenerating by viewModel.isGenerating.collectAsState()
    val error by viewModel.error.collectAsState()
    
    // Generation options state from ViewModel
    val prompt by viewModel.prompt.collectAsState()
    val selectedSize by viewModel.selectedSize.collectAsState()
    val selectedQuality by viewModel.selectedQuality.collectAsState()
    val selectedBackground by viewModel.selectedBackground.collectAsState()
    val selectedFormat by viewModel.selectedFormat.collectAsState()
    val compressionLevel by viewModel.compressionLevel.collectAsState()
    val selectedModeration by viewModel.selectedModeration.collectAsState()
    
    // Initialize with user preferences
    LaunchedEffect(userPreferences) {
        viewModel.initializeWithUserPreferences(userPreferences)
    }
    
    // Edit-specific state from ViewModel
    val editOptions by viewModel.editOptions.collectAsState()
    val editToolbarState by viewModel.editToolbarState.collectAsState()
    
    // Handle initial edit image from gallery navigation
    LaunchedEffect(initialEditImage) {
        initialEditImage?.let { image ->
            // Convert the image URL to a Uri and set edit mode
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
    
    Scaffold(
        modifier = Modifier
            .fillMaxSize(),
        snackbarHost = {
            SnackbarHost(hostState = snackbarHostState)
        },
        topBar = {
            TopAppBar(
                navigationIcon = {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .padding(start = 8.dp)
                            .clickable {
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
                        onClick = onNavigateToGallery,
                        colors = ButtonDefaults.textButtonColors(
                            contentColor = MaterialTheme.colorScheme.primary
                        )
                    ) {
                        Text("Gallery")
                    }
                    TextButton(
                        onClick = onNavigateToCredits,
                        colors = ButtonDefaults.textButtonColors(
                            contentColor = MaterialTheme.colorScheme.primary
                        )
                    ) {
                        Text("Credits")
                    }
                    IconButton(
                        onClick = onNavigateToSettings
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
                    .padding(paddingValues),
                contentPadding = PaddingValues(
                    start = 12.dp,
                    end = 12.dp,
                    top = 12.dp,
                    bottom = if (isToolbarExpanded) 620.dp else 120.dp
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
                                quality = selectedQuality.value,
                                size = selectedSize.displayName,
                                actualSize = actualSize,
                                quantity = 1,
                                background = selectedBackground?.displayName,
                                format = selectedFormat?.displayName,
                                compression = if (selectedFormat?.supportsCompression == true) compressionLevel else null,
                                moderation = selectedModeration?.displayName
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
                                quality = editOptions.quality.value,
                                size = editOptions.size.displayName,
                                actualSize = actualSize,
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
            modifier = Modifier.widthIn(max = 280.dp),
            shape = RoundedCornerShape(
                topStart = 16.dp,
                topEnd = 4.dp,
                bottomStart = 16.dp,
                bottomEnd = 16.dp
            ),
            color = MaterialTheme.colorScheme.primary,
            tonalElevation = 2.dp
        ) {
            Column(
                modifier = Modifier.padding(12.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Text(
                    text = "🎨 Generation Request",
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onPrimary
                )
                
                Text(
                    text = message.prompt,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onPrimary
                )
                
                Spacer(modifier = Modifier.height(2.dp))
                HorizontalDivider(color = MaterialTheme.colorScheme.onPrimary.copy(alpha = 0.3f))
                Spacer(modifier = Modifier.height(2.dp))
                
                DetailRow("Quality", message.quality.uppercase(), MaterialTheme.colorScheme.onPrimary)
                DetailRow("Size", message.size + if (message.size != message.actualSize) " (${message.actualSize})" else "", MaterialTheme.colorScheme.onPrimary)
                DetailRow("Quantity", message.quantity.toString(), MaterialTheme.colorScheme.onPrimary)
                
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
        when {
            message.isLoading -> {
                Surface(
                    modifier = Modifier.widthIn(max = 320.dp),
                    shape = RoundedCornerShape(
                        topStart = 4.dp,
                        topEnd = 20.dp,
                        bottomStart = 20.dp,
                        bottomEnd = 20.dp
                    ),
                    color = MaterialTheme.colorScheme.surfaceVariant,
                    tonalElevation = 1.dp
                ) {
                    Row(
                        modifier = Modifier.padding(16.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(24.dp),
                            strokeWidth = 3.dp
                        )
                        Text(
                            text = if (quantity == 1) "Generating image..." else "Generating $quantity images...",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
            message.error != null -> {
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
                            text = message.error,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onErrorContainer
                        )
                    }
                }
            }
            else -> {
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