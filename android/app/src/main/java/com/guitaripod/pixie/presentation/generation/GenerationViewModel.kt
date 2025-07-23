package com.guitaripod.pixie.presentation.generation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.guitaripod.pixie.data.model.GenerationOptions
import com.guitaripod.pixie.data.repository.ImageRepository
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

class GenerationViewModel(
    private val imageRepository: ImageRepository
) : ViewModel() {
    
    private val _isGenerating = MutableStateFlow(false)
    val isGenerating: StateFlow<Boolean> = _isGenerating.asStateFlow()
    
    private val _generationProgress = MutableStateFlow<GenerationProgress?>(null)
    val generationProgress: StateFlow<GenerationProgress?> = _generationProgress.asStateFlow()
    
    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()
    
    private val _generationResult = MutableSharedFlow<List<String>?>()
    val generationResult: SharedFlow<List<String>?> = _generationResult.asSharedFlow()
    
    private var generationJob: Job? = null
    
    fun generateImages(options: GenerationOptions) {
        _error.value = null
        _isGenerating.value = true
        
        generationJob = viewModelScope.launch {
            try {
                _generationProgress.value = GenerationProgress(
                    currentImage = 0,
                    totalImages = options.number,
                    status = "Preparing your request..."
                )
                
                imageRepository.generateImages(options.toApiRequest())
                    .collect { result ->
                        result.fold(
                            onSuccess = { response ->
                                val imageUrls = response.data.map { it.url }
                                
                                _generationProgress.value = GenerationProgress(
                                    currentImage = options.number,
                                    totalImages = options.number,
                                    status = "Generation complete!",
                                    isComplete = true
                                )
                                
                                _generationResult.emit(imageUrls)
                                _isGenerating.value = false
                                _generationProgress.value = null
                            },
                            onFailure = { exception ->
                                _error.value = exception.message ?: "Failed to generate images"
                                _isGenerating.value = false
                                _generationProgress.value = null
                            }
                        )
                    }
                
                var progress = 1
                while (_isGenerating.value && progress < options.number) {
                    kotlinx.coroutines.delay(1500)
                    _generationProgress.value = GenerationProgress(
                        currentImage = progress,
                        totalImages = options.number,
                        status = getProgressMessage(progress, options.number)
                    )
                    progress++
                }
                
            } catch (e: Exception) {
                _error.value = e.message ?: "An unexpected error occurred"
                _isGenerating.value = false
                _generationProgress.value = null
            }
        }
    }
    
    fun cancelGeneration() {
        generationJob?.cancel()
        _isGenerating.value = false
        _generationProgress.value = null
        _error.value = "Generation cancelled"
    }
    
    private fun getProgressMessage(current: Int, total: Int): String {
        val messages = listOf(
            "Creating magic with AI...",
            "Bringing your vision to life...",
            "Crafting your masterpiece...",
            "Almost there...",
            "Finalizing details..."
        )
        
        val index = ((current.toFloat() / total) * (messages.size - 1)).toInt()
        return messages[index]
    }
}