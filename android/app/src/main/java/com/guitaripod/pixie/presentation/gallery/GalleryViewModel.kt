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
    val lastRefreshTime: Long = 0L,
    val totalPagesLoaded: Int = 0,
    val hasReachedEnd: Boolean = false
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
    
    // Intelligent paging configuration
    private val MAX_PAGES_TO_LOAD = 5 // Load maximum 5 pages (100 images) per gallery type
    private var publicPagesLoaded = 0
    private var personalPagesLoaded = 0
    private var publicHasReachedEnd = false
    private var personalHasReachedEnd = false
    
    init {
        // Don't auto-load on init
    }
    
    fun setGalleryType(type: GalleryType) {
        if (_uiState.value.galleryType != type) {
            // Check if we have cached data for this gallery type
            val cachedImages = when (type) {
                GalleryType.PUBLIC -> if (hasLoadedPublic) cachedPublicImages.toList() else emptyList()
                GalleryType.PERSONAL -> if (hasLoadedPersonal) cachedPersonalImages.toList() else emptyList()
            }
            
            // Ensure cached images are deduplicated (defensive programming)
            val deduplicatedImages = cachedImages.distinctBy { it.id }
            
            val pagesLoaded = when (type) {
                GalleryType.PUBLIC -> publicPagesLoaded
                GalleryType.PERSONAL -> personalPagesLoaded
            }
            
            val hasReachedEnd = when (type) {
                GalleryType.PUBLIC -> publicHasReachedEnd
                GalleryType.PERSONAL -> personalHasReachedEnd
            }
            
            _uiState.update { it.copy(
                galleryType = type,
                images = deduplicatedImages,
                currentPage = if (deduplicatedImages.isNotEmpty()) (deduplicatedImages.size / 20) else 0,
                hasMore = !hasReachedEnd && pagesLoaded < MAX_PAGES_TO_LOAD,
                error = null,
                hasLoadedInitialData = deduplicatedImages.isNotEmpty(),
                totalPagesLoaded = pagesLoaded,
                hasReachedEnd = hasReachedEnd
            )}
            
            // Only load if we don't have cached data for this gallery type
            if (deduplicatedImages.isEmpty()) {
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
                publicPagesLoaded = 0
                publicHasReachedEnd = false
            }
            GalleryType.PERSONAL -> {
                cachedPersonalImages.clear()
                hasLoadedPersonal = false
                personalPagesLoaded = 0
                personalHasReachedEnd = false
            }
        }
        
        _uiState.update { it.copy(
            images = emptyList(),
            currentPage = 0,
            hasMore = true,
            error = null,
            hasLoadedInitialData = false,
            lastRefreshTime = System.currentTimeMillis(),
            totalPagesLoaded = 0,
            hasReachedEnd = false
        )}
        loadImages()
    }
    
    fun loadMore() {
        val currentState = _uiState.value
        val pagesLoaded = when (currentState.galleryType) {
            GalleryType.PUBLIC -> publicPagesLoaded
            GalleryType.PERSONAL -> personalPagesLoaded
        }
        
        // Check if we should load more based on intelligent paging
        if (!currentState.isLoading && 
            currentState.hasMore && 
            pagesLoaded < MAX_PAGES_TO_LOAD &&
            !currentState.hasReachedEnd) {
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
                        
                        val hasReachedEndOfData = galleryResponse.images.size < galleryResponse.perPage
                        
                        // Update cache with deduplication and track pages
                        when (currentState.galleryType) {
                            GalleryType.PUBLIC -> {
                                if (!isLoadMore) {
                                    cachedPublicImages.clear()
                                    cachedPublicImages.addAll(galleryResponse.images)
                                    publicPagesLoaded = 1
                                } else {
                                    // Only add new images that aren't already in the cache
                                    val existingIds = cachedPublicImages.map { it.id }.toSet()
                                    val newImagesToCache = galleryResponse.images.filter { it.id !in existingIds }
                                    cachedPublicImages.addAll(newImagesToCache)
                                    publicPagesLoaded++
                                }
                                hasLoadedPublic = true
                                publicHasReachedEnd = hasReachedEndOfData
                            }
                            GalleryType.PERSONAL -> {
                                if (!isLoadMore) {
                                    cachedPersonalImages.clear()
                                    cachedPersonalImages.addAll(galleryResponse.images)
                                    personalPagesLoaded = 1
                                } else {
                                    // Only add new images that aren't already in the cache
                                    val existingIds = cachedPersonalImages.map { it.id }.toSet()
                                    val newImagesToCache = galleryResponse.images.filter { it.id !in existingIds }
                                    cachedPersonalImages.addAll(newImagesToCache)
                                    personalPagesLoaded++
                                }
                                hasLoadedPersonal = true
                                personalHasReachedEnd = hasReachedEndOfData
                            }
                        }
                        
                        val currentPagesLoaded = when (currentState.galleryType) {
                            GalleryType.PUBLIC -> publicPagesLoaded
                            GalleryType.PERSONAL -> personalPagesLoaded
                        }
                        
                        _uiState.update { it.copy(
                            images = newImages,
                            isLoading = false,
                            currentPage = page,
                            hasMore = !hasReachedEndOfData && currentPagesLoaded < MAX_PAGES_TO_LOAD,
                            hasLoadedInitialData = true,
                            lastRefreshTime = if (!isLoadMore) System.currentTimeMillis() else it.lastRefreshTime,
                            totalPagesLoaded = currentPagesLoaded,
                            hasReachedEnd = hasReachedEndOfData
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