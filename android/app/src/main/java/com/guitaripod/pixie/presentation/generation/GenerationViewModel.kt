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
                imageRepository.generateImages(options.toApiRequest())
                    .collect { result ->
                        result.fold(
                            onSuccess = { response ->
                                val imageUrls = response.data.map { it.url }
                                _generationResult.emit(imageUrls)
                                _isGenerating.value = false
                            },
                            onFailure = { exception ->
                                _error.value = exception.message ?: "Failed to generate images"
                                _isGenerating.value = false
                            }
                        )
                    }
            } catch (e: Exception) {
                _error.value = e.message ?: "An unexpected error occurred"
                _isGenerating.value = false
            }
        }
    }
    
    fun cancelGeneration() {
        generationJob?.cancel()
        _isGenerating.value = false
        _error.value = "Generation cancelled"
    }
}