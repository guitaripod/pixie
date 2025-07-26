package com.guitaripod.pixie.presentation.generation

import android.graphics.Bitmap
import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.guitaripod.pixie.data.model.*
import com.guitaripod.pixie.data.repository.ImageRepository
import com.guitaripod.pixie.utils.NotificationHelper
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import com.guitaripod.pixie.service.ImageGenerationForegroundService
import com.guitaripod.pixie.utils.HapticFeedbackManager

class GenerationViewModel(
    private val imageRepository: ImageRepository,
    private val notificationHelper: NotificationHelper,
    private val context: Context,
    private val hapticFeedbackManager: HapticFeedbackManager
) : ViewModel() {
    
    private val _isGenerating = MutableStateFlow(false)
    val isGenerating: StateFlow<Boolean> = _isGenerating.asStateFlow()
    
    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()
    
    private val _generationResult = MutableSharedFlow<List<String>?>()
    val generationResult: SharedFlow<List<String>?> = _generationResult.asSharedFlow()
    
    private var generationJob: Job? = null
    
    // Chat state
    private val _messages = MutableStateFlow<List<ChatMessage>>(emptyList())
    val messages: StateFlow<List<ChatMessage>> = _messages.asStateFlow()
    
    private val _prompt = MutableStateFlow("")
    val prompt: StateFlow<String> = _prompt.asStateFlow()
    
    private val _isToolbarExpanded = MutableStateFlow(false)
    val isToolbarExpanded: StateFlow<Boolean> = _isToolbarExpanded.asStateFlow()
    
    private val _toolbarMode = MutableStateFlow<ToolbarMode>(ToolbarMode.Generate)
    val toolbarMode: StateFlow<ToolbarMode> = _toolbarMode.asStateFlow()
    
    private val _previewImageUri = MutableStateFlow<Uri?>(null)
    val previewImageUri: StateFlow<Uri?> = _previewImageUri.asStateFlow()
    
    // Generation options state
    private val _selectedSize = MutableStateFlow(ImageSize.AUTO)
    val selectedSize: StateFlow<ImageSize> = _selectedSize.asStateFlow()
    
    
    private val _selectedQuality = MutableStateFlow(ImageQuality.LOW)
    val selectedQuality: StateFlow<ImageQuality> = _selectedQuality.asStateFlow()
    
    private val _selectedBackground = MutableStateFlow<BackgroundStyle?>(null)
    val selectedBackground: StateFlow<BackgroundStyle?> = _selectedBackground.asStateFlow()
    
    private val _selectedFormat = MutableStateFlow<OutputFormat?>(null)
    val selectedFormat: StateFlow<OutputFormat?> = _selectedFormat.asStateFlow()
    
    private val _compressionLevel = MutableStateFlow(85)
    val compressionLevel: StateFlow<Int> = _compressionLevel.asStateFlow()
    
    private val _selectedModeration = MutableStateFlow<ModerationLevel?>(null)
    val selectedModeration: StateFlow<ModerationLevel?> = _selectedModeration.asStateFlow()
    
    // Edit options state
    private val _editOptions = MutableStateFlow(EditOptions())
    val editOptions: StateFlow<EditOptions> = _editOptions.asStateFlow()
    
    private val _editToolbarState = MutableStateFlow(EditToolbarState())
    val editToolbarState: StateFlow<EditToolbarState> = _editToolbarState.asStateFlow()
    
    private val imageGeneratedReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                "com.guitaripod.pixie.IMAGE_GENERATED" -> {
                    val imageUrls = intent.getStringArrayListExtra("imageUrls")
                    if (imageUrls != null) {
                        hapticFeedbackManager.performHapticFeedback(HapticFeedbackManager.HapticType.SUCCESS)
                        viewModelScope.launch {
                            _generationResult.emit(imageUrls)
                            _isGenerating.value = false
                        }
                    }
                }
                "com.guitaripod.pixie.IMAGE_GENERATION_ERROR" -> {
                    val error = intent.getStringExtra("error")
                    hapticFeedbackManager.performHapticFeedback(HapticFeedbackManager.HapticType.ERROR)
                    viewModelScope.launch {
                        _error.value = error ?: "Generation failed"
                        _isGenerating.value = false
                    }
                }
            }
        }
    }
    
    init {
        val filter = IntentFilter().apply {
            addAction("com.guitaripod.pixie.IMAGE_GENERATED")
            addAction("com.guitaripod.pixie.IMAGE_GENERATION_ERROR")
        }
        
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(
                imageGeneratedReceiver,
                filter,
                Context.RECEIVER_NOT_EXPORTED
            )
        } else {
            context.registerReceiver(
                imageGeneratedReceiver,
                filter
            )
        }
    }
    
    fun generateImages(options: GenerationOptions) {
        _error.value = null
        _isGenerating.value = true
        
        ImageGenerationForegroundService.startService(context, options.toApiRequest())
    }
    
    fun cancelGeneration() {
        ImageGenerationForegroundService.stopService(context)
        _isGenerating.value = false
        _error.value = "Generation cancelled"
    }
    
    fun resetChat() {
        _messages.value = emptyList()
        _prompt.value = ""
        _isToolbarExpanded.value = false
        _toolbarMode.value = ToolbarMode.Generate
        _selectedSize.value = ImageSize.AUTO
        _selectedQuality.value = ImageQuality.LOW
        _selectedBackground.value = null
        _selectedFormat.value = null
        _compressionLevel.value = 85
        _selectedModeration.value = null
        _editOptions.value = EditOptions()
        _editToolbarState.value = EditToolbarState()
        _previewImageUri.value = null
    }
    
    fun updateMessages(messages: List<ChatMessage>) {
        _messages.value = messages
    }
    
    fun updatePrompt(prompt: String) {
        _prompt.value = prompt
    }
    
    fun updateToolbarExpanded(expanded: Boolean) {
        _isToolbarExpanded.value = expanded
    }
    
    fun updateToolbarMode(mode: ToolbarMode) {
        _toolbarMode.value = mode
    }
    
    fun updatePreviewImageUri(uri: Uri?) {
        _previewImageUri.value = uri
    }
    
    fun updateSelectedSize(size: ImageSize) {
        _selectedSize.value = size
    }
    
    
    fun updateSelectedQuality(quality: ImageQuality) {
        _selectedQuality.value = quality
    }
    
    fun updateSelectedBackground(background: BackgroundStyle?) {
        _selectedBackground.value = background
    }
    
    fun updateSelectedFormat(format: OutputFormat?) {
        _selectedFormat.value = format
    }
    
    fun updateCompressionLevel(level: Int) {
        _compressionLevel.value = level
    }
    
    fun updateSelectedModeration(moderation: ModerationLevel?) {
        _selectedModeration.value = moderation
    }
    
    fun updateEditOptions(options: EditOptions) {
        _editOptions.value = options
    }
    
    fun updateEditToolbarState(state: EditToolbarState) {
        _editToolbarState.value = state
    }
    
    fun initializeWithUserPreferences(userPreferences: UserPreferences) {
        _selectedSize.value = when (userPreferences.defaultSize) {
            "square" -> ImageSize.SQUARE
            "landscape" -> ImageSize.LANDSCAPE
            "portrait" -> ImageSize.PORTRAIT
            "auto" -> ImageSize.AUTO
            else -> ImageSize.AUTO
        }
        
        _selectedQuality.value = when (userPreferences.defaultQuality) {
            DefaultImageQuality.LOW -> ImageQuality.LOW
            DefaultImageQuality.MEDIUM -> ImageQuality.MEDIUM
            DefaultImageQuality.HIGH -> ImageQuality.HIGH
            DefaultImageQuality.AUTO -> ImageQuality.AUTO
        }
        
        _selectedFormat.value = when (userPreferences.defaultOutputFormat) {
            DefaultOutputFormat.PNG -> OutputFormat.PNG
            DefaultOutputFormat.JPEG -> OutputFormat.JPEG
            DefaultOutputFormat.WEBP -> OutputFormat.WEBP
        }
        
        _compressionLevel.value = userPreferences.defaultCompressionLevel
    }
    
    fun editImage(
        imageUri: Uri,
        editOptions: EditOptions
    ) {
        _error.value = null
        _isGenerating.value = true
        
        val editData = com.guitaripod.pixie.data.model.EditImageData(
            imageUri = imageUri.toString(),
            prompt = editOptions.prompt,
            variations = editOptions.variations,
            size = if (editOptions.size.value == "auto") "1024x1024" else editOptions.size.value,
            quality = editOptions.quality.value,
            fidelity = editOptions.fidelity.value
        )
        
        ImageGenerationForegroundService.startEditService(
            context = context,
            editData = editData
        )
    }
    
    override fun onCleared() {
        super.onCleared()
        context.unregisterReceiver(imageGeneratedReceiver)
    }
}