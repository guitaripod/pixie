package com.guitaripod.pixie.presentation.gallery

import android.app.Application
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.widget.Toast
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.guitaripod.pixie.data.api.model.ImageDetails
import com.guitaripod.pixie.data.repository.GalleryRepository
import com.guitaripod.pixie.utils.ImageSaver
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

data class GalleryUiState(
    val images: List<ImageDetails> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null,
    val hasMore: Boolean = true,
    val currentPage: Int = 0,
    val galleryType: GalleryType = GalleryType.PUBLIC
)

class GalleryViewModel(
    private val repository: GalleryRepository,
    private val imageSaver: ImageSaver,
    application: Application
) : AndroidViewModel(application) {
    
    private val _uiState = MutableStateFlow(GalleryUiState())
    val uiState: StateFlow<GalleryUiState> = _uiState.asStateFlow()
    
    private val clipboardManager = application.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    
    init {
        loadImages()
    }
    
    fun setGalleryType(type: GalleryType) {
        if (_uiState.value.galleryType != type) {
            _uiState.update { it.copy(
                galleryType = type,
                images = emptyList(),
                currentPage = 0,
                hasMore = true,
                error = null
            )}
            loadImages()
        }
    }
    
    fun refresh() {
        _uiState.update { it.copy(
            images = emptyList(),
            currentPage = 0,
            hasMore = true,
            error = null
        )}
        loadImages()
    }
    
    fun loadMore() {
        if (!_uiState.value.isLoading && _uiState.value.hasMore) {
            loadImages(isLoadMore = true)
        }
    }
    
    private fun loadImages(isLoadMore: Boolean = false) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }
            
            try {
                val currentState = _uiState.value
                val page = if (isLoadMore) currentState.currentPage + 1 else 1
                
                val response = when (currentState.galleryType) {
                    GalleryType.PUBLIC -> repository.getPublicGallery(
                        page = page,
                        perPage = 20
                    )
                    GalleryType.PERSONAL -> repository.getMyImages(
                        page = page,
                        perPage = 20
                    )
                }
                
                response.fold(
                    onSuccess = { galleryResponse ->
                        val newImages = if (isLoadMore) {
                            currentState.images + galleryResponse.images
                        } else {
                            galleryResponse.images
                        }
                        
                        _uiState.update { it.copy(
                            images = newImages,
                            isLoading = false,
                            currentPage = page,
                            hasMore = galleryResponse.images.size == galleryResponse.perPage
                        )}
                    },
                    onFailure = { exception ->
                        _uiState.update { it.copy(
                            isLoading = false,
                            error = exception.message ?: "Failed to load images"
                        )}
                    }
                )
            } catch (e: Exception) {
                _uiState.update { it.copy(
                    isLoading = false,
                    error = e.message ?: "An unexpected error occurred"
                )}
            }
        }
    }
    
    fun handleImageAction(image: ImageDetails, action: ImageAction) {
        when (action) {
            ImageAction.USE_FOR_EDIT -> {
                // This will be handled by the parent composable to navigate
                // For now, just show a toast
                Toast.makeText(
                    getApplication(),
                    "Opening edit mode with this image",
                    Toast.LENGTH_SHORT
                ).show()
            }
            
            ImageAction.COPY_PROMPT -> {
                val clip = ClipData.newPlainText("Image Prompt", image.prompt)
                clipboardManager.setPrimaryClip(clip)
                Toast.makeText(
                    getApplication(),
                    "Prompt copied to clipboard",
                    Toast.LENGTH_SHORT
                ).show()
            }
            
            ImageAction.DOWNLOAD -> {
                viewModelScope.launch {
                    imageSaver.saveImageToGallery(
                        imageUrl = image.url,
                        fileName = "pixie_${image.id}"
                    ).fold(
                        onSuccess = {
                            Toast.makeText(
                                getApplication(),
                                "Image saved to gallery",
                                Toast.LENGTH_SHORT
                            ).show()
                        },
                        onFailure = { error ->
                            Toast.makeText(
                                getApplication(),
                                "Failed to save image: ${error.message}",
                                Toast.LENGTH_LONG
                            ).show()
                        }
                    )
                }
            }
            
            ImageAction.SHARE -> {
                viewModelScope.launch {
                    imageSaver.shareImageFromUrl(
                        imageUrl = image.url
                    ).fold(
                        onSuccess = {
                            // Share intent launched successfully
                        },
                        onFailure = { error ->
                            Toast.makeText(
                                getApplication(),
                                "Failed to share image: ${error.message}",
                                Toast.LENGTH_LONG
                            ).show()
                        }
                    )
                }
            }
        }
    }
}