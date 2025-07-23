package com.guitaripod.pixie.presentation.chat

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
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
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.guitaripod.pixie.data.model.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EditingToolbar(
    selectedImage: SelectedImage,
    editOptions: EditOptions,
    onEditOptionsChange: (EditOptions) -> Unit,
    editToolbarState: EditToolbarState,
    onEditToolbarStateChange: (EditToolbarState) -> Unit,
    isProcessing: Boolean,
    onStartEdit: () -> Unit,
    onSwitchToGenerate: () -> Unit,
    modifier: Modifier = Modifier
) {
    val transition = updateTransition(
        targetState = editToolbarState.isExpanded,
        label = "edit_toolbar"
    )
    
    val toolbarHeight by transition.animateDp(
        label = "height",
        transitionSpec = {
            spring(
                dampingRatio = Spring.DampingRatioMediumBouncy,
                stiffness = Spring.StiffnessLow
            )
        }
    ) { expanded ->
        if (expanded) 580.dp else 160.dp
    }
    
    Box(modifier = modifier.fillMaxWidth()) {
        // Main toolbar surface
        Surface(
            modifier = Modifier
                .fillMaxWidth()
                .height(toolbarHeight)
                .shadow(
                    elevation = 16.dp,
                    shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp),
                    spotColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.3f)
                ),
            shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp),
            color = MaterialTheme.colorScheme.surface,
            tonalElevation = 8.dp
        ) {
            AnimatedContent(
                targetState = editToolbarState.isExpanded,
                transitionSpec = {
                    fadeIn(animationSpec = tween(300)) togetherWith 
                    fadeOut(animationSpec = tween(150))
                }
            ) { expanded ->
                if (!expanded) {
                    // Collapsed state - shows preview and quick actions
                    CollapsedEditToolbar(
                        selectedImage = selectedImage,
                        editOptions = editOptions,
                        onExpand = {
                            onEditToolbarStateChange(
                                editToolbarState.copy(isExpanded = true)
                            )
                        }
                    )
                } else {
                    // Expanded state - full editing interface
                    ExpandedEditToolbar(
                        selectedImage = selectedImage,
                        editOptions = editOptions,
                        onEditOptionsChange = onEditOptionsChange,
                        editToolbarState = editToolbarState,
                        onEditToolbarStateChange = onEditToolbarStateChange,
                        isProcessing = isProcessing,
                        onStartEdit = onStartEdit,
                        onSwitchToGenerate = onSwitchToGenerate
                    )
                }
            }
        }
    }
}

@Composable
private fun CollapsedEditToolbar(
    selectedImage: SelectedImage,
    editOptions: EditOptions,
    onExpand: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .clickable { onExpand() }
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Preview row
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Image preview
            Surface(
                modifier = Modifier.size(48.dp),
                shape = RoundedCornerShape(12.dp),
                tonalElevation = 2.dp
            ) {
                AsyncImage(
                    model = selectedImage.uri,
                    contentDescription = "Selected image",
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize()
                )
            }
            
            // Edit info
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.Center
            ) {
                Text(
                    text = if (editOptions.prompt.isNotBlank()) 
                        editOptions.prompt 
                    else "Describe your edits...",
                    style = MaterialTheme.typography.bodyLarge,
                    color = if (editOptions.prompt.isNotBlank()) 
                        MaterialTheme.colorScheme.onSurface 
                    else MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1
                )
                Text(
                    text = "Tap to edit",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f)
                )
            }
            
            Icon(
                imageVector = Icons.Default.KeyboardArrowUp,
                contentDescription = "Expand",
                tint = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        
        // Quick stats
        val estimatedCredits = estimateEditCredits(editOptions)
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            EditStatChip(
                icon = Icons.Default.Star,
                label = "${editOptions.quality.displayName} quality"
            )
            EditStatChip(
                icon = painterResource(id = android.R.drawable.ic_menu_crop),
                label = editOptions.size.displayName
            )
            EditStatChip(
                icon = Icons.Default.ShoppingCart,
                label = "${estimatedCredits.first}-${estimatedCredits.last} credits"
            )
        }
    }
}

@Composable
private fun EditStatChip(
    icon: Any,
    label: String
) {
    Surface(
        shape = RoundedCornerShape(8.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
            horizontalArrangement = Arrangement.spacedBy(4.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            when (icon) {
                is androidx.compose.ui.graphics.vector.ImageVector -> {
                    Icon(
                        imageVector = icon,
                        contentDescription = null,
                        modifier = Modifier.size(14.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                is androidx.compose.ui.graphics.painter.Painter -> {
                    Icon(
                        painter = icon,
                        contentDescription = null,
                        modifier = Modifier.size(14.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
            Text(
                text = label,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ExpandedEditToolbar(
    selectedImage: SelectedImage,
    editOptions: EditOptions,
    onEditOptionsChange: (EditOptions) -> Unit,
    editToolbarState: EditToolbarState,
    onEditToolbarStateChange: (EditToolbarState) -> Unit,
    isProcessing: Boolean,
    onStartEdit: () -> Unit,
    onSwitchToGenerate: () -> Unit
) {
    val scrollState = rememberScrollState()
    
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(scrollState)
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        // Header
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.Top
        ) {
            Column(
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text(
                    text = "Edit Image",
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.SemiBold
                )
            }
            
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                TextButton(onClick = onSwitchToGenerate) {
                    Text("New image")
                }
                IconButton(
                    onClick = {
                        onEditToolbarStateChange(
                            editToolbarState.copy(isExpanded = false)
                        )
                    }
                ) {
                    Icon(
                        imageVector = Icons.Default.KeyboardArrowDown,
                        contentDescription = "Collapse"
                    )
                }
            }
        }
        
        
        // Edit prompt
        OutlinedTextField(
            value = editOptions.prompt,
            onValueChange = { onEditOptionsChange(editOptions.copy(prompt = it)) },
            modifier = Modifier.fillMaxWidth(),
            placeholder = {
                Text("Describe how you want to transform the image...")
            },
            minLines = 3,
            maxLines = 5,
            keyboardOptions = KeyboardOptions(
                capitalization = KeyboardCapitalization.Sentences,
                imeAction = ImeAction.Default
            ),
            shape = RoundedCornerShape(16.dp)
        )
        
        // Quick options
        QuickEditOptions(
            editOptions = editOptions,
            onEditOptionsChange = onEditOptionsChange
        )
        
        // Advanced options toggle
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .clickable {
                    onEditToolbarStateChange(
                        editToolbarState.copy(
                            showAdvancedOptions = !editToolbarState.showAdvancedOptions
                        )
                    )
                },
            shape = RoundedCornerShape(12.dp)
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Advanced Options",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Medium
                )
                Icon(
                    imageVector = if (editToolbarState.showAdvancedOptions)
                        Icons.Default.KeyboardArrowUp
                    else Icons.Default.KeyboardArrowDown,
                    contentDescription = null
                )
            }
        }
        
        // Advanced options
        AnimatedVisibility(visible = editToolbarState.showAdvancedOptions) {
            AdvancedEditOptions(
                editOptions = editOptions,
                onEditOptionsChange = onEditOptionsChange
            )
        }
        
        // Edit button
        val estimatedCredits = estimateEditCredits(editOptions)
        Button(
            onClick = onStartEdit,
            modifier = Modifier
                .fillMaxWidth()
                .height(56.dp),
            enabled = editOptions.prompt.isNotBlank() && !isProcessing,
            shape = RoundedCornerShape(28.dp)
        ) {
            if (isProcessing) {
                CircularProgressIndicator(
                    modifier = Modifier.size(20.dp),
                    color = MaterialTheme.colorScheme.onPrimary,
                    strokeWidth = 2.5.dp
                )
            } else {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Create,
                        contentDescription = null,
                        modifier = Modifier.size(22.dp)
                    )
                    Text(
                        text = "Edit (${estimatedCredits.first}-${estimatedCredits.last} credits)",
                        style = MaterialTheme.typography.labelLarge,
                        fontWeight = FontWeight.Medium
                    )
                }
            }
        }
    }
}


@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun QuickEditOptions(
    editOptions: EditOptions,
    onEditOptionsChange: (EditOptions) -> Unit
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Quality selector
        Column(
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Quality",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Medium
                )
                Text(
                    text = "${estimateQualityCredits(editOptions.quality)} credits",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.primary
                )
            }
            
            SingleChoiceSegmentedButtonRow(
                modifier = Modifier.fillMaxWidth()
            ) {
                ImageQuality.values().forEachIndexed { index, quality ->
                    SegmentedButton(
                        shape = SegmentedButtonDefaults.itemShape(
                            index = index,
                            count = ImageQuality.values().size
                        ),
                        onClick = {
                            onEditOptionsChange(editOptions.copy(quality = quality))
                        },
                        selected = editOptions.quality == quality
                    ) {
                        Text(
                            text = quality.displayName,
                            style = MaterialTheme.typography.labelMedium
                        )
                    }
                }
            }
        }
        
        // Variations
        Column(
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(
                    text = "Variations",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Medium
                )
                Text(
                    text = "${editOptions.variations} ${if (editOptions.variations == 1) "image" else "images"}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.primary
                )
            }
            
            FlowRow(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                (1..5).forEach { num ->
                    FilterChip(
                        selected = editOptions.variations == num,
                        onClick = {
                            onEditOptionsChange(editOptions.copy(variations = num))
                        },
                        label = { Text(num.toString()) }
                    )
                }
            }
        }
    }
}

@Composable
private fun AdvancedEditOptions(
    editOptions: EditOptions,
    onEditOptionsChange: (EditOptions) -> Unit
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Size selector
        SizeSelector(
            selectedSize = editOptions.size,
            onSizeSelected = { onEditOptionsChange(editOptions.copy(size = it)) },
            customSize = editOptions.customSize,
            onCustomSizeChanged = { onEditOptionsChange(editOptions.copy(customSize = it)) }
        )
        
        // Fidelity selector
        Column(
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(
                text = "Fidelity",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Medium
            )
            
            SingleChoiceSegmentedButtonRow(
                modifier = Modifier.fillMaxWidth()
            ) {
                FidelityLevel.values().forEachIndexed { index, fidelity ->
                    SegmentedButton(
                        shape = SegmentedButtonDefaults.itemShape(
                            index = index,
                            count = FidelityLevel.values().size
                        ),
                        onClick = {
                            onEditOptionsChange(editOptions.copy(fidelity = fidelity))
                        },
                        selected = editOptions.fidelity == fidelity
                    ) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Text(
                                text = fidelity.displayName,
                                style = MaterialTheme.typography.labelMedium
                            )
                            Text(
                                text = fidelity.description,
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            }
        }
    }
}

private fun estimateEditCredits(options: EditOptions): IntRange {
    val base = when (options.quality) {
        ImageQuality.LOW -> 7..9
        ImageQuality.MEDIUM -> 14..18
        ImageQuality.HIGH -> 70..112
        ImageQuality.AUTO -> 66..95
    }
    
    // Add 2-5 credits for input processing
    val inputCost = 2..5
    
    return (base.first + inputCost.first)..(base.last + inputCost.last)
}

private fun estimateQualityCredits(quality: ImageQuality): String {
    return when (quality) {
        ImageQuality.LOW -> "~7"
        ImageQuality.MEDIUM -> "~16"
        ImageQuality.HIGH -> "72-110"
        ImageQuality.AUTO -> "68-93"
    }
}