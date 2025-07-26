package com.guitaripod.pixie.presentation.chat

import android.Manifest
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.ripple.rememberRipple
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.guitaripod.pixie.utils.ImageSaver
import kotlinx.coroutines.launch
import com.guitaripod.pixie.utils.rememberHapticFeedback
import com.guitaripod.pixie.utils.hapticClickable

@OptIn(ExperimentalAnimationApi::class)
@Composable
fun ImageBubble(
    imageUrl: String,
    onSaveSuccess: (String) -> Unit,
    onSaveError: (String) -> Unit,
    onEdit: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val imageSaver = remember { ImageSaver(context) }
    
    var isExpanded by remember { mutableStateOf(false) }
    var isSaving by remember { mutableStateOf(false) }
    var showFullscreen by remember { mutableStateOf(false) }
    
    val hasStoragePermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        true
    } else {
        ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.WRITE_EXTERNAL_STORAGE
        ) == PackageManager.PERMISSION_GRANTED
    }
    
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        if (isGranted) {
            scope.launch {
                saveImage(imageUrl, imageSaver, onSaveSuccess, onSaveError) { isSaving = it }
            }
        } else {
            onSaveError("Storage permission denied")
        }
    }
    
    Box(modifier = modifier) {
        Surface(
            shape = RoundedCornerShape(
                topStart = 4.dp,
                topEnd = 20.dp,
                bottomStart = 20.dp,
                bottomEnd = 20.dp
            ),
            tonalElevation = 2.dp,
            modifier = Modifier
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null
                ) { isExpanded = !isExpanded }
        ) {
            Box {
                AsyncImage(
                    model = ImageRequest.Builder(LocalContext.current)
                        .data(imageUrl)
                        .crossfade(300)
                        .build(),
                    contentDescription = "Generated image",
                    modifier = Modifier
                        .widthIn(max = 280.dp)
                        .clip(RoundedCornerShape(
                            topStart = 4.dp,
                            topEnd = 16.dp,
                            bottomStart = 16.dp,
                            bottomEnd = 16.dp
                        )),
                    contentScale = ContentScale.FillWidth
                )
                
                // Fullscreen button always visible in top right
                IconButton(
                    onClick = { showFullscreen = true },
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(4.dp)
                        .size(32.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Fullscreen,
                        contentDescription = "View fullscreen",
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.size(20.dp)
                    )
                }
                
                AnimatedVisibility(
                    visible = isExpanded,
                    enter = fadeIn() + scaleIn(),
                    exit = fadeOut() + scaleOut()
                ) {
                    Box(
                        modifier = Modifier
                            .matchParentSize()
                            .background(
                                Brush.verticalGradient(
                                    colors = listOf(
                                        Color.Transparent,
                                        Color.Black.copy(alpha = 0.7f)
                                    ),
                                    startY = 100f
                                )
                            )
                    )
                }
            }
        }
        
        AnimatedVisibility(
            visible = isExpanded,
            enter = fadeIn() + slideInHorizontally { -it },
            exit = fadeOut() + slideOutHorizontally { -it },
            modifier = Modifier
                .align(Alignment.CenterStart)
                .padding(8.dp)
        ) {
            Column(
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                if (onEdit != null) {
                    ImageActionButton(
                        icon = Icons.Default.Edit,
                        label = "Edit",
                        onClick = onEdit
                    )
                }
                
                ImageActionButton(
                    icon = Icons.Default.Share,
                    label = "Share",
                    onClick = {
                        scope.launch {
                            imageSaver.shareImageFromUrl(imageUrl).fold(
                                onSuccess = { },
                                onFailure = {
                                    onSaveError("Failed to share image")
                                }
                            )
                        }
                    }
                )
                
                ImageActionButton(
                    icon = if (isSaving) Icons.Default.Check else Icons.Default.Download,
                    label = if (isSaving) "Saving..." else "Save",
                    onClick = {
                        if (!isSaving) {
                            if (hasStoragePermission) {
                                scope.launch {
                                    saveImage(imageUrl, imageSaver, onSaveSuccess, onSaveError) { isSaving = it }
                                }
                            } else {
                                permissionLauncher.launch(Manifest.permission.WRITE_EXTERNAL_STORAGE)
                            }
                        }
                    },
                    enabled = !isSaving
                )
            }
        }
    }
    
    if (showFullscreen) {
        ImagePreviewDialog(
            imageUri = Uri.parse(imageUrl),
            onDismiss = { showFullscreen = false },
            onConfirm = { showFullscreen = false }
        )
    }
}

@Composable
private fun ImageActionButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    onClick: () -> Unit,
    enabled: Boolean = true,
    modifier: Modifier = Modifier
) {
    val haptic = rememberHapticFeedback()
    Surface(
        onClick = {
            haptic.click()
            onClick()
        },
        enabled = enabled,
        shape = CircleShape,
        color = MaterialTheme.colorScheme.surface.copy(alpha = 0.9f),
        modifier = modifier
            .shadow(
                elevation = 8.dp,
                shape = CircleShape,
                spotColor = Color.Black.copy(alpha = 0.3f)
            )
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
            horizontalArrangement = Arrangement.spacedBy(4.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                modifier = Modifier.size(16.dp)
            )
            Text(
                text = label,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.Medium
            )
        }
    }
}

private suspend fun saveImage(
    imageUrl: String,
    imageSaver: ImageSaver,
    onSuccess: (String) -> Unit,
    onError: (String) -> Unit,
    setLoading: (Boolean) -> Unit
) {
    setLoading(true)
    imageSaver.saveImageToGallery(imageUrl).fold(
        onSuccess = {
            onSuccess("Image saved to gallery")
            setLoading(false)
        },
        onFailure = { error ->
            onError(error.message ?: "Failed to save image")
            setLoading(false)
        }
    )
}