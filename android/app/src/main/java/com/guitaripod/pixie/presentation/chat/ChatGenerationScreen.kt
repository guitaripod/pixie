package com.guitaripod.pixie.presentation.chat

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
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
import com.guitaripod.pixie.presentation.generation.GenerationViewModel
import kotlinx.coroutines.launch
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.SnackbarDuration

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatGenerationScreen(
    viewModel: GenerationViewModel,
    onLogout: () -> Unit,
    onNavigateToGallery: () -> Unit = {},
    modifier: Modifier = Modifier
) {
    var messages by remember { mutableStateOf(listOf<ChatMessage>()) }
    var isToolbarExpanded by remember { mutableStateOf(false) }
    var toolbarMode by remember { mutableStateOf<ToolbarMode>(ToolbarMode.Generate) }
    var previewImageUri by remember { mutableStateOf<android.net.Uri?>(null) }
    val listState = rememberLazyListState()
    val coroutineScope = rememberCoroutineScope()
    val snackbarHostState = remember { SnackbarHostState() }
    
    val isGenerating by viewModel.isGenerating.collectAsState()
    val error by viewModel.error.collectAsState()
    
    // Generation options state
    var prompt by remember { mutableStateOf("") }
    var number by remember { mutableIntStateOf(1) }
    var selectedSize by remember { mutableStateOf(ImageSize.AUTO) }
    var customSize by remember { mutableStateOf("") }
    var selectedQuality by remember { mutableStateOf(ImageQuality.LOW) }
    var selectedBackground by remember { mutableStateOf<BackgroundStyle?>(null) }
    var selectedFormat by remember { mutableStateOf<OutputFormat?>(null) }
    var compressionLevel by remember { mutableIntStateOf(85) }
    var selectedModeration by remember { mutableStateOf<ModerationLevel?>(null) }
    
    // Edit-specific state
    var editOptions by remember { mutableStateOf(EditOptions()) }
    var editToolbarState by remember { mutableStateOf(EditToolbarState()) }
    
    LaunchedEffect(viewModel) {
        viewModel.generationResult.collect { result ->
            result?.let { imageUrls ->
                messages = messages.dropLast(1) + ChatMessage.ImageResponse(
                    imageUrls = imageUrls,
                    isLoading = false
                )
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
                messages = messages.dropLast(1) + lastMessage.copy(
                    isLoading = false,
                    error = errorMessage
                )
            }
        }
    }
    
    Scaffold(
        modifier = modifier
            .fillMaxSize()
            .navigationBarsPadding(),
        snackbarHost = {
            SnackbarHost(hostState = snackbarHostState)
        },
        topBar = {
            TopAppBar(
                title = { 
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Icon(
                            painter = painterResource(id = android.R.drawable.star_on),
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(24.dp)
                        )
                        Text(
                            text = "Pixie",
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                },
                actions = {
                    IconButton(onClick = onNavigateToGallery) {
                        Icon(
                            imageVector = Icons.Default.AccountBox,
                            contentDescription = "Gallery",
                            tint = MaterialTheme.colorScheme.primary
                        )
                    }
                    TextButton(
                        onClick = onLogout,
                        colors = ButtonDefaults.textButtonColors(
                            contentColor = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    ) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ExitToApp,
                            contentDescription = "Logout",
                            modifier = Modifier.size(20.dp)
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Logout")
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
                .padding(paddingValues)
        ) {
            LazyColumn(
                state = listState,
                modifier = Modifier
                    .fillMaxSize(),
                contentPadding = PaddingValues(
                    start = 16.dp,
                    end = 16.dp,
                    top = 16.dp,
                    bottom = 96.dp
                ),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                if (messages.isEmpty()) {
                    item {
                        RecentImagesRow(
                            onImageSelected = { uri ->
                                previewImageUri = uri
                            }
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
                        onExpandedChange = { isToolbarExpanded = it },
                        prompt = prompt,
                        onPromptChange = { prompt = it },
                        number = number,
                        onNumberChange = { number = it },
                        selectedSize = selectedSize,
                        onSizeSelected = { selectedSize = it },
                        customSize = customSize,
                        onCustomSizeChanged = { customSize = it },
                        selectedQuality = selectedQuality,
                        onQualitySelected = { selectedQuality = it },
                        selectedBackground = selectedBackground,
                        onBackgroundSelected = { selectedBackground = it },
                        selectedFormat = selectedFormat,
                        onFormatSelected = { selectedFormat = it },
                        compressionLevel = compressionLevel,
                        onCompressionChanged = { compressionLevel = it },
                        selectedModeration = selectedModeration,
                        onModerationSelected = { selectedModeration = it },
                        isGenerating = isGenerating,
                        onGenerate = {
                            val actualSize = if (selectedSize == ImageSize.CUSTOM) {
                                customSize.ifEmpty { "1024x1024" }
                            } else {
                                selectedSize.value
                            }
                            
                            val userMessage = ChatMessage.UserMessage(
                                prompt = prompt,
                                quality = selectedQuality.value,
                                size = selectedSize.displayName,
                                actualSize = actualSize,
                                quantity = number,
                                background = selectedBackground?.displayName,
                                format = selectedFormat?.displayName,
                                compression = if (selectedFormat?.supportsCompression == true) compressionLevel else null,
                                moderation = selectedModeration?.displayName
                            )
                            messages = messages + userMessage
                            
                            messages = messages + ChatMessage.ImageResponse(
                                imageUrls = emptyList(),
                                isLoading = true
                            )
                            
                            coroutineScope.launch {
                                listState.animateScrollToItem(messages.size - 1)
                            }
                            
                            val options = GenerationOptions(
                                prompt = prompt,
                                number = number,
                                size = actualSize,
                                quality = selectedQuality.value,
                                background = selectedBackground?.value,
                                outputFormat = selectedFormat?.value,
                                compression = if (selectedFormat?.supportsCompression == true) compressionLevel else null,
                                moderation = selectedModeration?.value
                            )
                            viewModel.generateImages(options)
                            
                            prompt = ""
                            isToolbarExpanded = false
                        },
                        onSwitchToGenerate = {
                            toolbarMode = ToolbarMode.Generate
                            prompt = ""
                        },
                        modifier = Modifier.align(Alignment.BottomCenter)
                    )
                }
                is ToolbarMode.Edit -> {
                    val editMode = toolbarMode as ToolbarMode.Edit
                    EditingToolbar(
                        selectedImage = editMode.selectedImage,
                        editOptions = editOptions,
                        onEditOptionsChange = { editOptions = it },
                        editToolbarState = editToolbarState,
                        onEditToolbarStateChange = { editToolbarState = it },
                        isProcessing = isGenerating,
                        onStartEdit = {
                            val actualSize = if (editOptions.size == ImageSize.CUSTOM) {
                                editOptions.customSize.ifEmpty { "1024x1024" }
                            } else {
                                editOptions.size.value
                            }
                            
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
                            messages = messages + userMessage
                            
                            messages = messages + ChatMessage.ImageResponse(
                                imageUrls = emptyList(),
                                isLoading = true
                            )
                            
                            coroutineScope.launch {
                                listState.animateScrollToItem(messages.size - 1)
                            }
                            
                            viewModel.editImage(
                                imageUri = editMode.selectedImage.uri,
                                editOptions = editOptions
                            )
                            
                            editOptions = EditOptions()
                            editToolbarState = EditToolbarState()
                        },
                        onSwitchToGenerate = {
                            toolbarMode = ToolbarMode.Generate
                            prompt = ""
                            editOptions = EditOptions()
                            editToolbarState = EditToolbarState()
                        },
                        modifier = Modifier.align(Alignment.BottomCenter)
                    )
                }
            }
            
            previewImageUri?.let { uri ->
                ImagePreviewDialog(
                    imageUri = uri,
                    onConfirm = {
                        toolbarMode = ToolbarMode.Edit(
                            SelectedImage(uri = uri)
                        )
                        previewImageUri = null
                        editToolbarState = editToolbarState.copy(isExpanded = true)
                    },
                    onDismiss = {
                        previewImageUri = null
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
            modifier = Modifier.widthIn(max = 320.dp),
            shape = RoundedCornerShape(
                topStart = 20.dp,
                topEnd = 4.dp,
                bottomStart = 20.dp,
                bottomEnd = 20.dp
            ),
            color = MaterialTheme.colorScheme.primary,
            tonalElevation = 2.dp
        ) {
            Column(
                modifier = Modifier.padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text(
                    text = "🎨 Generation Request",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onPrimary
                )
                
                Text(
                    text = message.prompt,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onPrimary
                )
                
                Spacer(modifier = Modifier.height(4.dp))
                HorizontalDivider(color = MaterialTheme.colorScheme.onPrimary.copy(alpha = 0.3f))
                Spacer(modifier = Modifier.height(4.dp))
                
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
    onShowSnackbar: (String) -> Unit
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
                            onSaveError = onShowSnackbar
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