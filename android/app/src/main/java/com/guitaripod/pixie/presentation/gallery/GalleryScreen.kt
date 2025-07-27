package com.guitaripod.pixie.presentation.gallery

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.staggeredgrid.*
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material.icons.filled.AddAPhoto
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Explore
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.PhotoLibrary
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.material3.pulltorefresh.rememberPullToRefreshState
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.guitaripod.pixie.data.api.model.ImageDetails
import com.guitaripod.pixie.utils.formatTimeAgo
import com.guitaripod.pixie.utils.rememberHapticFeedback
import com.guitaripod.pixie.utils.hapticClickable
import com.guitaripod.pixie.utils.hapticCombinedClickable
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class, ExperimentalFoundationApi::class)
@Composable
fun GalleryScreen(
    viewModel: GalleryViewModel,
    onNavigateToChat: () -> Unit,
    onImageClick: (ImageDetails) -> Unit,
    onImageAction: (ImageDetails, ImageAction) -> Unit,
    onNavigateBack: () -> Unit = {}
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val pagerState = rememberPagerState(pageCount = { 2 })
    val coroutineScope = rememberCoroutineScope()
    
    LaunchedEffect(pagerState.currentPage) {
        viewModel.setGalleryType(
            if (pagerState.currentPage == 0) GalleryType.PERSONAL else GalleryType.PUBLIC
        )
    }
    
    LaunchedEffect(Unit) {
        if (!uiState.hasLoadedInitialData && uiState.images.isEmpty()) {
            viewModel.loadInitialData()
        }
    }
    
    Scaffold(
        modifier = Modifier
            .fillMaxSize(),
        topBar = {
            val haptic = rememberHapticFeedback()
            TopAppBar(
                title = { 
                    Text(
                        "Gallery",
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold
                    ) 
                },
                navigationIcon = {
                    IconButton(onClick = {
                        haptic.click()
                        onNavigateBack()
                    }) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back"
                        )
                    }
                },
                actions = {
                    IconButton(onClick = { 
                        haptic.click()
                        viewModel.refresh() 
                    }) {
                        Icon(
                            imageVector = Icons.Default.Refresh,
                            contentDescription = "Refresh"
                        )
                    }
                    if (uiState.isLoading) {
                        CircularProgressIndicator(
                            modifier = Modifier
                                .size(20.dp)
                                .padding(end = 12.dp),
                            strokeWidth = 2.dp
                        )
                    }
                }
            )
        },
        floatingActionButton = {
            val fabHaptic = rememberHapticFeedback()
            ExtendedFloatingActionButton(
                onClick = {
                    fabHaptic.click()
                    onNavigateToChat()
                },
                icon = { 
                    Icon(
                        Icons.Default.AddAPhoto, 
                        contentDescription = "Generate"
                    ) 
                },
                text = { Text("Generate") },
                modifier = Modifier.padding(16.dp)
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            val haptic = rememberHapticFeedback()
            TabRow(
                selectedTabIndex = pagerState.currentPage,
                containerColor = MaterialTheme.colorScheme.surface,
                contentColor = MaterialTheme.colorScheme.onSurface,
                divider = {},
                modifier = Modifier.height(48.dp)
            ) {
                Tab(
                    selected = pagerState.currentPage == 0,
                    onClick = {
                        haptic.click()
                        coroutineScope.launch {
                            pagerState.animateScrollToPage(0)
                        }
                    },
                    modifier = Modifier.height(48.dp)
                ) {
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            Icons.Default.Person,
                            contentDescription = null,
                            modifier = Modifier.size(18.dp)
                        )
                        Text("My Images", fontSize = 14.sp)
                    }
                }
                Tab(
                    selected = pagerState.currentPage == 1,
                    onClick = {
                        haptic.click()
                        coroutineScope.launch {
                            pagerState.animateScrollToPage(1)
                        }
                    },
                    modifier = Modifier.height(48.dp)
                ) {
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            Icons.Default.Explore,
                            contentDescription = null,
                            modifier = Modifier.size(18.dp)
                        )
                        Text("Explore", fontSize = 14.sp)
                    }
                }
            }
            
            HorizontalDivider()
            
            HorizontalPager(
                state = pagerState,
                modifier = Modifier.fillMaxSize()
            ) { page ->
                val galleryType = if (page == 0) GalleryType.PERSONAL else GalleryType.PUBLIC
                
                GalleryPageContent(
                    viewModel = viewModel,
                    galleryType = galleryType,
                    onImageClick = onImageClick,
                    onImageAction = onImageAction,
                    onNavigateToChat = onNavigateToChat
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class, ExperimentalFoundationApi::class)
@Composable
private fun GalleryPageContent(
    viewModel: GalleryViewModel,
    galleryType: GalleryType,
    onImageClick: (ImageDetails) -> Unit,
    onImageAction: (ImageDetails, ImageAction) -> Unit,
    onNavigateToChat: () -> Unit
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    
    val isCurrentGallery = uiState.galleryType == galleryType
    
    var hasInitialized by remember(galleryType) { mutableStateOf(false) }
    
    LaunchedEffect(galleryType) {
        if (!hasInitialized && isCurrentGallery) {
            val hasData = when (galleryType) {
                GalleryType.PERSONAL -> viewModel.hasPersonalData()
                GalleryType.PUBLIC -> viewModel.hasPublicData()
            }
            if (!hasData) {
                viewModel.setGalleryType(galleryType)
            }
            hasInitialized = true
        }
    }
    
    val pullToRefreshState = rememberPullToRefreshState()
    
    val refreshHaptic = rememberHapticFeedback()
    
    PullToRefreshBox(
        isRefreshing = uiState.isLoading && uiState.images.isNotEmpty(),
        onRefresh = { 
            refreshHaptic.confirm()
            viewModel.refresh() 
        },
        state = pullToRefreshState,
        modifier = Modifier.fillMaxSize()
    ) {
        when {
            !isCurrentGallery -> {
                LoadingState()
            }
            uiState.isLoading && uiState.images.isEmpty() -> {
                LoadingState()
            }
            uiState.error != null && uiState.images.isEmpty() -> {
                ErrorState(
                    message = uiState.error ?: "An error occurred",
                    onRetry = { viewModel.refresh() }
                )
            }
            uiState.images.isEmpty() -> {
                EmptyState(
                    isPersonalGallery = galleryType == GalleryType.PERSONAL,
                    onNavigateToChat = onNavigateToChat
                )
            }
            else -> {
                LazyVerticalStaggeredGrid(
                    columns = StaggeredGridCells.Adaptive(180.dp),
                    contentPadding = PaddingValues(
                        start = 8.dp,
                        end = 8.dp,
                        top = 8.dp,
                        bottom = 80.dp // Account for FAB
                    ),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalItemSpacing = 8.dp,
                    modifier = Modifier.fillMaxSize()
                ) {
                    itemsIndexed(
                        items = uiState.images,
                        key = { _, image -> image.id }
                    ) { index, image ->
                        if (index >= uiState.images.size - 5 && uiState.hasMore && !uiState.isLoading) {
                            LaunchedEffect(Unit) {
                                viewModel.loadMore()
                            }
                        }
                        
                        GalleryImageCard(
                            image = image,
                            onClick = { onImageClick(image) },
                            onAction = { action -> onImageAction(image, action) },
                            modifier = Modifier.animateItem()
                        )
                    }
                    
                    if (uiState.isLoading && uiState.images.isNotEmpty()) {
                        item(span = StaggeredGridItemSpan.FullLine) {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(16.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                CircularProgressIndicator()
                            }
                        }
                    }
                    
                    if (!uiState.isLoading && uiState.images.isNotEmpty() && 
                        uiState.galleryType == GalleryType.PUBLIC && 
                        uiState.totalPagesLoaded >= 5 && 
                        !uiState.hasReachedEnd) {
                        item(span = StaggeredGridItemSpan.FullLine) {
                            Card(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(16.dp),
                                colors = CardDefaults.cardColors(
                                    containerColor = MaterialTheme.colorScheme.secondaryContainer
                                )
                            ) {
                                Column(
                                    modifier = Modifier.padding(16.dp),
                                    horizontalAlignment = Alignment.CenterHorizontally
                                ) {
                                    Icon(
                                        imageVector = Icons.Default.Info,
                                        contentDescription = null,
                                        tint = MaterialTheme.colorScheme.onSecondaryContainer
                                    )
                                    Spacer(modifier = Modifier.height(8.dp))
                                    Text(
                                        text = "Reached viewing limit (100 images)",
                                        style = MaterialTheme.typography.bodyMedium,
                                        color = MaterialTheme.colorScheme.onSecondaryContainer,
                                        textAlign = TextAlign.Center
                                    )
                                    Text(
                                        text = "Refresh to see more recent images",
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.onSecondaryContainer.copy(alpha = 0.7f),
                                        textAlign = TextAlign.Center
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class, ExperimentalMaterial3Api::class)
@Composable
private fun GalleryImageCard(
    image: ImageDetails,
    onClick: () -> Unit,
    onAction: (ImageAction) -> Unit,
    modifier: Modifier = Modifier
) {
    val haptic = rememberHapticFeedback()
    var showMenu by remember { mutableStateOf(false) }
    val scale by animateFloatAsState(
        targetValue = if (showMenu) 0.95f else 1f,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy
        )
    )
    
    Card(
        onClick = {
            haptic.click()
            onClick()
        },
        modifier = modifier
            .scale(scale)
            .fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        elevation = CardDefaults.cardElevation(
            defaultElevation = 2.dp,
            pressedElevation = 8.dp
        )
    ) {
        Box {
            AsyncImage(
                model = ImageRequest.Builder(LocalContext.current)
                    .data(image.thumbnailUrl ?: image.url)
                    .crossfade(true)
                    .memoryCacheKey(image.id)
                    .diskCacheKey(image.id)
                    .build(),
                contentDescription = image.prompt,
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .fillMaxWidth()
                    .aspectRatio(
                        image.metadata?.let { 
                            it.width.toFloat() / it.height.toFloat() 
                        } ?: 1f
                    )
            )
            
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .align(Alignment.BottomCenter)
                    .background(
                        brush = Brush.verticalGradient(
                            colors = listOf(
                                Color.Transparent,
                                Color.Black.copy(alpha = 0.7f)
                            )
                        )
                    )
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(12.dp)
                ) {
                    Text(
                        text = image.prompt,
                        style = MaterialTheme.typography.bodySmall,
                        color = Color.White,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis
                    )
                    
                    Spacer(modifier = Modifier.height(4.dp))
                    
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = formatTimeAgo(image.createdAt),
                            style = MaterialTheme.typography.labelSmall,
                            color = Color.White.copy(alpha = 0.7f)
                        )
                        
                        image.metadata?.creditsUsed?.let { credits ->
                            Row(
                                horizontalArrangement = Arrangement.spacedBy(4.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Star,
                                    contentDescription = null,
                                    modifier = Modifier.size(12.dp),
                                    tint = Color.White.copy(alpha = 0.7f)
                                )
                                Text(
                                    text = credits.toString(),
                                    style = MaterialTheme.typography.labelSmall,
                                    color = Color.White.copy(alpha = 0.7f)
                                )
                            }
                        }
                    }
                }
            }
            
            Box(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(8.dp)
            ) {
                IconButtonDefaults.filledIconButtonColors(
                    containerColor = Color.Black.copy(alpha = 0.5f)
                )
                FilledIconButton(
                    onClick = { 
                        haptic.click()
                        showMenu = true 
                    },
                    modifier = Modifier.size(32.dp),
                    colors = IconButtonDefaults.filledIconButtonColors(
                        containerColor = Color.Black.copy(alpha = 0.5f)
                    )
                ) {
                    Icon(
                        imageVector = Icons.Default.MoreVert,
                        contentDescription = "More options",
                        tint = Color.White,
                        modifier = Modifier.size(20.dp)
                    )
                }
                
                DropdownMenu(
                    expanded = showMenu,
                    onDismissRequest = { showMenu = false }
                ) {
                    DropdownMenuItem(
                        text = { Text("Use for Edit") },
                        leadingIcon = { Icon(Icons.Default.Edit, null) },
                        onClick = {
                            haptic.click()
                            showMenu = false
                            onAction(ImageAction.USE_FOR_EDIT)
                        }
                    )
                    DropdownMenuItem(
                        text = { Text("Copy Prompt") },
                        leadingIcon = { Icon(Icons.Default.ContentCopy, null) },
                        onClick = {
                            haptic.click()
                            showMenu = false
                            onAction(ImageAction.COPY_PROMPT)
                        }
                    )
                    DropdownMenuItem(
                        text = { Text("Download") },
                        leadingIcon = { Icon(Icons.Default.Download, null) },
                        onClick = {
                            haptic.click()
                            showMenu = false
                            onAction(ImageAction.DOWNLOAD)
                        }
                    )
                    DropdownMenuItem(
                        text = { Text("Share") },
                        leadingIcon = { Icon(Icons.Default.Share, null) },
                        onClick = {
                            haptic.click()
                            showMenu = false
                            onAction(ImageAction.SHARE)
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun LoadingState() {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        CircularProgressIndicator()
    }
}

@Composable
private fun ErrorState(
    message: String,
    onRetry: () -> Unit
) {
    val haptic = rememberHapticFeedback()
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            imageVector = Icons.Default.Warning,
            contentDescription = null,
            modifier = Modifier.size(64.dp),
            tint = MaterialTheme.colorScheme.error
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        Text(
            text = "Something went wrong",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Medium
        )
        
        Spacer(modifier = Modifier.height(8.dp))
        
        Text(
            text = message,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        
        Spacer(modifier = Modifier.height(24.dp))
        
        Button(onClick = {
            haptic.click()
            onRetry()
        }) {
            Text("Try Again")
        }
    }
}

@Composable
private fun EmptyState(
    isPersonalGallery: Boolean,
    onNavigateToChat: () -> Unit
) {
    val haptic = rememberHapticFeedback()
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            imageVector = if (isPersonalGallery) Icons.Default.PhotoLibrary else Icons.Default.Explore,
            contentDescription = null,
            modifier = Modifier.size(80.dp),
            tint = MaterialTheme.colorScheme.primary.copy(alpha = 0.6f)
        )
        
        Spacer(modifier = Modifier.height(24.dp))
        
        Text(
            text = if (isPersonalGallery) "No images yet" else "Gallery is empty",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Medium
        )
        
        Spacer(modifier = Modifier.height(8.dp))
        
        Text(
            text = if (isPersonalGallery) 
                "Start creating amazing images with AI" 
                else 
                "Be the first to share your creations",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        
        if (isPersonalGallery) {
            Spacer(modifier = Modifier.height(32.dp))
            
            Button(
                onClick = {
                    haptic.click()
                    onNavigateToChat()
                },
                modifier = Modifier.height(48.dp)
            ) {
                Icon(Icons.Default.AddAPhoto, null)
                Spacer(modifier = Modifier.width(8.dp))
                Text("Generate Your First Image")
            }
        }
    }
}

enum class GalleryType {
    PUBLIC,
    PERSONAL
}

enum class ImageAction {
    USE_FOR_EDIT,
    COPY_PROMPT,
    DOWNLOAD,
    SHARE
}