package com.guitaripod.pixie.presentation.gallery

import androidx.compose.animation.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.Download
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.guitaripod.pixie.data.api.model.ImageDetails
import com.guitaripod.pixie.utils.rememberHapticFeedback
import java.text.SimpleDateFormat
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ImageDetailBottomSheet(
    image: ImageDetails,
    onDismiss: () -> Unit,
    onAction: (ImageAction) -> Unit
) {
    val sheetState = rememberModalBottomSheetState(
        skipPartiallyExpanded = true
    )
    
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = MaterialTheme.colorScheme.surface,
        shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .navigationBarsPadding()
                .verticalScroll(rememberScrollState())
        ) {
            // Image preview
            AsyncImage(
                model = ImageRequest.Builder(LocalContext.current)
                    .data(image.url)
                    .crossfade(true)
                    .memoryCacheKey(image.id)
                    .diskCacheKey(image.id)
                    .build(),
                contentDescription = image.prompt,
                contentScale = ContentScale.FillWidth,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .clip(RoundedCornerShape(16.dp))
            )
            
            Spacer(modifier = Modifier.height(16.dp))
            
            // Quick actions
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp),
                horizontalArrangement = Arrangement.SpaceEvenly
            ) {
                ActionChip(
                    icon = Icons.Default.Edit,
                    label = "Edit",
                    onClick = { onAction(ImageAction.USE_FOR_EDIT) }
                )
                ActionChip(
                    icon = Icons.Default.ContentCopy,
                    label = "Copy",
                    onClick = { onAction(ImageAction.COPY_PROMPT) }
                )
                ActionChip(
                    icon = Icons.Default.Download,
                    label = "Save",
                    onClick = { onAction(ImageAction.DOWNLOAD) }
                )
                ActionChip(
                    icon = Icons.Default.Share,
                    label = "Share",
                    onClick = { onAction(ImageAction.SHARE) }
                )
            }
            
            Spacer(modifier = Modifier.height(16.dp))
            
            // Image details
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
            ) {
                // Prompt section
                DetailSection(
                    title = "Prompt",
                    content = {
                        Text(
                            text = image.prompt,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                )
                
                HorizontalDivider(modifier = Modifier.padding(vertical = 16.dp))
                
                // Technical details
                DetailSection(
                    title = "Details",
                    content = {
                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            DetailRow("ID", image.id.take(8) + "...")
                            DetailRow("Created", formatTimeAgo(image.createdAt))
                            image.metadata?.let { meta ->
                                DetailRow("Size", "${meta.width} × ${meta.height}")
                                meta.quality?.let { quality ->
                                    DetailRow("Quality", quality.uppercase())
                                }
                                DetailRow("Credits Used", meta.creditsUsed.toString())
                                meta.model?.let { model ->
                                    DetailRow("Model", model)
                                }
                            }
                        }
                    }
                )
                
                // Revised prompt if available
                image.metadata?.revisedPrompt?.let { revised ->
                    HorizontalDivider(modifier = Modifier.padding(vertical = 16.dp))
                    
                    DetailSection(
                        title = "Revised Prompt",
                        content = {
                            Text(
                                text = revised,
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    )
                }
            }
            
            Spacer(modifier = Modifier.height(24.dp))
        }
    }
}

@Composable
private fun ActionChip(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    onClick: () -> Unit
) {
    val haptic = rememberHapticFeedback()
    
    FilledTonalButton(
        onClick = {
            haptic.click()
            onClick()
        },
        contentPadding = PaddingValues(horizontal = 12.dp, vertical = 8.dp),
        shape = RoundedCornerShape(12.dp)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            modifier = Modifier.size(18.dp)
        )
        Spacer(modifier = Modifier.width(4.dp))
        Text(
            text = label,
            style = MaterialTheme.typography.labelMedium
        )
    }
}

@Composable
private fun DetailSection(
    title: String,
    content: @Composable () -> Unit
) {
    Column {
        Text(
            text = title,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.padding(bottom = 8.dp)
        )
        content()
    }
}

@Composable
private fun DetailRow(
    label: String,
    value: String
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.weight(1f)
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.Medium
        )
    }
}

private fun formatTimeAgo(dateString: String): String {
    return try {
        val inputFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault())
        val date = inputFormat.parse(dateString) ?: return dateString
        val now = Date()
        val diff = now.time - date.time
        
        val seconds = diff / 1000
        val minutes = seconds / 60
        val hours = minutes / 60
        val days = hours / 24
        
        when {
            days > 0 -> "$days day${if (days > 1) "s" else ""} ago"
            hours > 0 -> "$hours hour${if (hours > 1) "s" else ""} ago"
            minutes > 0 -> "$minutes minute${if (minutes > 1) "s" else ""} ago"
            else -> "Just now"
        }
    } catch (e: Exception) {
        dateString
    }
}