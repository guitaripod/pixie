package com.guitaripod.pixie.presentation.gallery

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.staggeredgrid.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
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
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GalleryScreen(
    viewModel: GalleryViewModel,
    onNavigateToChat: () -> Unit,
    onImageClick: (ImageDetails) -> Unit,
    modifier: Modifier = Modifier
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    var selectedTab by remember { mutableIntStateOf(0) }
    
    LaunchedEffect(selectedTab) {
        viewModel.setGalleryType(
            if (selectedTab == 0) GalleryType.PERSONAL else GalleryType.PUBLIC
        )
    }
    
    // Load initial data when screen is first opened
    LaunchedEffect(Unit) {
        if (!uiState.hasLoadedInitialData && uiState.images.isEmpty()) {
            viewModel.loadInitialData()
        }
    }
    
    Scaffold(
        modifier = modifier,
        floatingActionButton = {
            ExtendedFloatingActionButton(
                onClick = onNavigateToChat,
                icon = { 
                    Icon(
                        Icons.Default.Add, 
                        contentDescription = "Generate"
                    ) 
                },
                text = { Text("Generate") },
                modifier = Modifier.padding(16.dp)
            )
        }
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            when {
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
                        isPersonalGallery = selectedTab == 0,
                        onNavigateToChat = onNavigateToChat
                    )
                }
                else -> {
                    GalleryGrid(
                        viewModel = viewModel,
                        images = uiState.images,
                        isLoading = uiState.isLoading,
                        hasMore = uiState.hasMore,
                        onLoadMore = { viewModel.loadMore() },
                        onImageClick = onImageClick,
                        onImageAction = { image, action ->
                            viewModel.handleImageAction(image, action)
                        },
                        selectedTab = selectedTab,
                        onTabSelected = { selectedTab = it },
                        onRefresh = { viewModel.refresh() }
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun GalleryTopBar(
    selectedTab: Int,
    onTabSelected: (Int) -> Unit,
    isLoading: Boolean,
    onRefresh: () -> Unit
) {
    Surface(
        color = MaterialTheme.colorScheme.surface,
        tonalElevation = 3.dp
    ) {
        Column {
            TopAppBar(
                title = { 
                    Text(
                        "Gallery",
                        fontWeight = FontWeight.Bold
                    ) 
                },
                actions = {
                    IconButton(onClick = onRefresh) {
                        Icon(
                            imageVector = Icons.Default.Refresh,
                            contentDescription = "Refresh"
                        )
                    }
                    if (isLoading) {
                        CircularProgressIndicator(
                            modifier = Modifier
                                .size(24.dp)
                                .padding(horizontal = 16.dp),
                            strokeWidth = 2.dp
                        )
                    }
                }
            )
            
            TabRow(
                selectedTabIndex = selectedTab,
                containerColor = Color.Transparent,
                divider = {}
            ) {
                Tab(
                    selected = selectedTab == 0,
                    onClick = { onTabSelected(0) },
                    text = { Text("My Images") },
                    icon = { Icon(Icons.Outlined.Person, null) }
                )
                Tab(
                    selected = selectedTab == 1,
                    onClick = { onTabSelected(1) },
                    text = { Text("Explore") },
                    icon = { Icon(Icons.Outlined.Search, null) }
                )
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun GalleryGrid(
    viewModel: GalleryViewModel,
    images: List<ImageDetails>,
    isLoading: Boolean,
    hasMore: Boolean,
    onLoadMore: () -> Unit,
    onImageClick: (ImageDetails) -> Unit,
    onImageAction: (ImageDetails, ImageAction) -> Unit,
    selectedTab: Int,
    onTabSelected: (Int) -> Unit,
    onRefresh: () -> Unit
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    LazyVerticalStaggeredGrid(
        columns = StaggeredGridCells.Adaptive(180.dp),
        contentPadding = PaddingValues(8.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalItemSpacing = 8.dp,
        modifier = Modifier.fillMaxSize()
    ) {
        // Header that scrolls with content
        item(span = StaggeredGridItemSpan.FullLine) {
            GalleryTopBar(
                selectedTab = selectedTab,
                onTabSelected = onTabSelected,
                isLoading = isLoading,
                onRefresh = onRefresh
            )
        }
        
        itemsIndexed(
            items = images,
            key = { _, image -> image.id }
        ) { index, image ->
            // Load more when reaching the end
            if (index >= images.size - 5 && hasMore && !isLoading) {
                LaunchedEffect(Unit) {
                    onLoadMore()
                }
            }
            
            GalleryImageCard(
                image = image,
                onClick = { onImageClick(image) },
                onAction = { action -> onImageAction(image, action) },
                modifier = Modifier.animateItem()
            )
        }
        
        if (isLoading && images.isNotEmpty()) {
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
        
        // Show message when reaching paging limit
        if (!isLoading && images.isNotEmpty() && uiState.totalPagesLoaded >= 5 && !uiState.hasReachedEnd) {
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

@OptIn(ExperimentalFoundationApi::class, ExperimentalMaterial3Api::class)
@Composable
private fun GalleryImageCard(
    image: ImageDetails,
    onClick: () -> Unit,
    onAction: (ImageAction) -> Unit,
    modifier: Modifier = Modifier
) {
    var showMenu by remember { mutableStateOf(false) }
    val scale by animateFloatAsState(
        targetValue = if (showMenu) 0.95f else 1f,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy
        )
    )
    
    Card(
        onClick = onClick,
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
            
            // Gradient overlay
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
            
            // Action menu button
            Box(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(8.dp)
            ) {
                IconButtonDefaults.filledIconButtonColors(
                    containerColor = Color.Black.copy(alpha = 0.5f)
                )
                FilledIconButton(
                    onClick = { showMenu = true },
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
                            showMenu = false
                            onAction(ImageAction.USE_FOR_EDIT)
                        }
                    )
                    DropdownMenuItem(
                        text = { Text("Copy Prompt") },
                        leadingIcon = { Icon(Icons.Default.Star, null) },
                        onClick = {
                            showMenu = false
                            onAction(ImageAction.COPY_PROMPT)
                        }
                    )
                    DropdownMenuItem(
                        text = { Text("Download") },
                        leadingIcon = { Icon(Icons.Default.Add, null) },
                        onClick = {
                            showMenu = false
                            onAction(ImageAction.DOWNLOAD)
                        }
                    )
                    DropdownMenuItem(
                        text = { Text("Share") },
                        leadingIcon = { Icon(Icons.Default.Share, null) },
                        onClick = {
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
        
        Button(onClick = onRetry) {
            Text("Try Again")
        }
    }
}

@Composable
private fun EmptyState(
    isPersonalGallery: Boolean,
    onNavigateToChat: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            imageVector = if (isPersonalGallery) Icons.Default.AccountBox else Icons.Outlined.Search,
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
                onClick = onNavigateToChat,
                modifier = Modifier.height(48.dp)
            ) {
                Icon(Icons.Default.Add, null)
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