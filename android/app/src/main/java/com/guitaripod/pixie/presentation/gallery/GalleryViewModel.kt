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
    val galleryType: GalleryType = GalleryType.PERSONAL,
    val hasLoadedInitialData: Boolean = false,
    val lastRefreshTime: Long = 0L
)

class GalleryViewModel(
    private val repository: GalleryRepository,
    private val imageSaver: ImageSaver,
    application: Application
) : AndroidViewModel(application) {
    
    private val _uiState = MutableStateFlow(GalleryUiState())
    val uiState: StateFlow<GalleryUiState> = _uiState.asStateFlow()
    
    private val clipboardManager = application.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    
    // Session-based cache: data for each gallery type
    private val cachedPublicImages = mutableListOf<ImageDetails>()
    private val cachedPersonalImages = mutableListOf<ImageDetails>()
    private var hasLoadedPublic = false
    private var hasLoadedPersonal = false
    
    init {
        // Don't auto-load on init
    }
    
    fun setGalleryType(type: GalleryType) {
        if (_uiState.value.galleryType != type) {
            // Check if we have cached data for this gallery type
            val cachedImages = when (type) {
                GalleryType.PUBLIC -> if (hasLoadedPublic) cachedPublicImages else emptyList()
                GalleryType.PERSONAL -> if (hasLoadedPersonal) cachedPersonalImages else emptyList()
            }
            
            _uiState.update { it.copy(
                galleryType = type,
                images = cachedImages,
                currentPage = if (cachedImages.isNotEmpty()) (cachedImages.size / 20) else 0,
                hasMore = true,
                error = null,
                hasLoadedInitialData = cachedImages.isNotEmpty()
            )}
            
            // Only load if we don't have cached data for this gallery type
            if (cachedImages.isEmpty()) {
                loadImages()
            }
        }
    }
    
    fun refresh() {
        // Clear cache for current gallery type
        when (_uiState.value.galleryType) {
            GalleryType.PUBLIC -> {
                cachedPublicImages.clear()
                hasLoadedPublic = false
            }
            GalleryType.PERSONAL -> {
                cachedPersonalImages.clear()
                hasLoadedPersonal = false
            }
        }
        
        _uiState.update { it.copy(
            images = emptyList(),
            currentPage = 0,
            hasMore = true,
            error = null,
            hasLoadedInitialData = false,
            lastRefreshTime = System.currentTimeMillis()
        )}
        loadImages()
    }
    
    fun loadMore() {
        if (!_uiState.value.isLoading && _uiState.value.hasMore) {
            loadImages(isLoadMore = true)
        }
    }
    
    fun loadInitialData() {
        // Only load if we haven't loaded data for the current gallery type
        val currentType = _uiState.value.galleryType
        val hasData = when (currentType) {
            GalleryType.PUBLIC -> hasLoadedPublic
            GalleryType.PERSONAL -> hasLoadedPersonal
        }
        
        if (!hasData) {
            loadImages()
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
                        // Create deduplicated image list for UI state
                        val newImages = if (isLoadMore) {
                            // When loading more, we need to ensure no duplicates in the final list
                            val existingIds = currentState.images.map { it.id }.toSet()
                            val newUniqueImages = galleryResponse.images.filter { it.id !in existingIds }
                            currentState.images + newUniqueImages
                        } else {
                            galleryResponse.images
                        }
                        
                        // Update cache with deduplication
                        when (currentState.galleryType) {
                            GalleryType.PUBLIC -> {
                                if (!isLoadMore) {
                                    cachedPublicImages.clear()
                                    cachedPublicImages.addAll(galleryResponse.images)
                                } else {
                                    // Only add new images that aren't already in the cache
                                    val existingIds = cachedPublicImages.map { it.id }.toSet()
                                    val newImagesToCache = galleryResponse.images.filter { it.id !in existingIds }
                                    cachedPublicImages.addAll(newImagesToCache)
                                }
                                hasLoadedPublic = true
                            }
                            GalleryType.PERSONAL -> {
                                if (!isLoadMore) {
                                    cachedPersonalImages.clear()
                                    cachedPersonalImages.addAll(galleryResponse.images)
                                } else {
                                    // Only add new images that aren't already in the cache
                                    val existingIds = cachedPersonalImages.map { it.id }.toSet()
                                    val newImagesToCache = galleryResponse.images.filter { it.id !in existingIds }
                                    cachedPersonalImages.addAll(newImagesToCache)
                                }
                                hasLoadedPersonal = true
                            }
                        }
                        
                        _uiState.update { it.copy(
                            images = newImages,
                            isLoading = false,
                            currentPage = page,
                            hasMore = galleryResponse.images.size == galleryResponse.perPage,
                            hasLoadedInitialData = true,
                            lastRefreshTime = if (!isLoadMore) System.currentTimeMillis() else it.lastRefreshTime
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