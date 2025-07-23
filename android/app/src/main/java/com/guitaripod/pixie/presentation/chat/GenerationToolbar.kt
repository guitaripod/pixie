package com.guitaripod.pixie.presentation.chat

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import androidx.compose.ui.layout.ContentScale
import com.guitaripod.pixie.data.model.*
import coil.compose.AsyncImage
import androidx.compose.ui.platform.LocalContext
import coil.request.ImageRequest

@OptIn(ExperimentalAnimationApi::class)
@Composable
fun GenerationToolbar(
    mode: ToolbarMode,
    isExpanded: Boolean,
    onExpandedChange: (Boolean) -> Unit,
    prompt: String,
    onPromptChange: (String) -> Unit,
    number: Int,
    onNumberChange: (Int) -> Unit,
    selectedSize: ImageSize,
    onSizeSelected: (ImageSize) -> Unit,
    customSize: String,
    onCustomSizeChanged: (String) -> Unit,
    selectedQuality: ImageQuality,
    onQualitySelected: (ImageQuality) -> Unit,
    selectedBackground: BackgroundStyle?,
    onBackgroundSelected: (BackgroundStyle?) -> Unit,
    selectedFormat: OutputFormat?,
    onFormatSelected: (OutputFormat?) -> Unit,
    compressionLevel: Int,
    onCompressionChanged: (Int) -> Unit,
    selectedModeration: ModerationLevel?,
    onModerationSelected: (ModerationLevel?) -> Unit,
    isGenerating: Boolean,
    onGenerate: () -> Unit,
    onSwitchToGenerate: () -> Unit,
    modifier: Modifier = Modifier
) {
    val transition = updateTransition(targetState = isExpanded, label = "toolbar")
    
    val toolbarHeight by transition.animateDp(
        label = "height",
        transitionSpec = {
            spring(
                dampingRatio = Spring.DampingRatioMediumBouncy,
                stiffness = Spring.StiffnessLow
            )
        }
    ) { expanded ->
        if (expanded) 600.dp else 80.dp
    }
    
    val cornerRadius by transition.animateDp(
        label = "corner",
        transitionSpec = {
            spring(
                dampingRatio = Spring.DampingRatioMediumBouncy,
                stiffness = Spring.StiffnessMedium
            )
        }
    ) { expanded ->
        if (expanded) 24.dp else 28.dp
    }
    
    val shadowElevation by transition.animateDp(
        label = "shadow",
        transitionSpec = {
            spring(
                dampingRatio = Spring.DampingRatioMediumBouncy,
                stiffness = Spring.StiffnessMedium
            )
        }
    ) { expanded ->
        if (expanded) 24.dp else 12.dp
    }
    
    Surface(
        modifier = modifier
            .fillMaxWidth()
            .height(toolbarHeight)
            .shadow(
                elevation = shadowElevation,
                shape = RoundedCornerShape(topStart = cornerRadius, topEnd = cornerRadius),
                spotColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.3f),
                ambientColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.15f)
            ),
        shape = RoundedCornerShape(topStart = cornerRadius, topEnd = cornerRadius),
        color = MaterialTheme.colorScheme.surface,
        tonalElevation = 8.dp
    ) {
        AnimatedContent(
            targetState = isExpanded,
            transitionSpec = {
                fadeIn(animationSpec = tween(300)) togetherWith fadeOut(animationSpec = tween(150))
            }
        ) { expanded ->
            if (expanded) {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState())
                        .padding(20.dp),
                    verticalArrangement = Arrangement.spacedBy(20.dp)
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            when (mode) {
                                is ToolbarMode.Generate -> {
                                    Icon(
                                        painter = painterResource(id = android.R.drawable.star_on),
                                        contentDescription = null,
                                        tint = MaterialTheme.colorScheme.primary,
                                        modifier = Modifier.size(24.dp)
                                    )
                                    Text(
                                        text = "Create Image",
                                        style = MaterialTheme.typography.headlineSmall,
                                        fontWeight = FontWeight.SemiBold
                                    )
                                }
                                is ToolbarMode.Edit -> {
                                    Surface(
                                        modifier = Modifier.size(32.dp),
                                        shape = CircleShape,
                                        tonalElevation = 2.dp
                                    ) {
                                        AsyncImage(
                                            model = mode.selectedImage.uri,
                                            contentDescription = "Selected image",
                                            contentScale = ContentScale.Crop,
                                            modifier = Modifier.fillMaxSize()
                                        )
                                    }
                                    Text(
                                        text = "Edit Image",
                                        style = MaterialTheme.typography.headlineSmall,
                                        fontWeight = FontWeight.SemiBold
                                    )
                                }
                            }
                        }
                        
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            if (mode is ToolbarMode.Edit) {
                                TextButton(onClick = onSwitchToGenerate) {
                                    Text("New image")
                                }
                            }
                            IconButton(onClick = { onExpandedChange(false) }) {
                                Icon(
                                    imageVector = Icons.Default.KeyboardArrowDown,
                                    contentDescription = "Collapse",
                                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                    
                    OutlinedTextField(
                        value = prompt,
                        onValueChange = onPromptChange,
                        modifier = Modifier.fillMaxWidth(),
                        placeholder = { 
                            Text(
                                when (mode) {
                                    is ToolbarMode.Generate -> "Describe what you want to create..."
                                    is ToolbarMode.Edit -> "Describe how you want to edit this image..."
                                }
                            ) 
                        },
                        minLines = 3,
                        maxLines = 5,
                        keyboardOptions = KeyboardOptions(
                            capitalization = KeyboardCapitalization.Sentences,
                            imeAction = ImeAction.Default
                        ),
                        shape = RoundedCornerShape(16.dp)
                    )
                    
                    SizeSelector(
                        selectedSize = selectedSize,
                        onSizeSelected = onSizeSelected,
                        customSize = customSize,
                        onCustomSizeChanged = onCustomSizeChanged
                    )
                    
                    QualitySelector(
                        selectedQuality = selectedQuality,
                        onQualitySelected = onQualitySelected
                    )
                    
                    NumberPicker(
                        number = number,
                        onNumberChanged = onNumberChange
                    )
                    
                    var showAdvanced by remember { mutableStateOf(false) }
                    
                    Surface(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(16.dp))
                            .clickable { showAdvanced = !showAdvanced },
                        shape = RoundedCornerShape(16.dp),
                        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
                    ) {
                        Row(
                            modifier = Modifier.padding(16.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = "Advanced Options",
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Medium
                            )
                            Icon(
                                imageVector = if (showAdvanced) Icons.Default.KeyboardArrowUp else Icons.Default.KeyboardArrowDown,
                                contentDescription = if (showAdvanced) "Hide" else "Show"
                            )
                        }
                    }
                    
                    AnimatedVisibility(visible = showAdvanced) {
                        Column(
                            verticalArrangement = Arrangement.spacedBy(20.dp)
                        ) {
                            BackgroundSelector(
                                selected = selectedBackground,
                                onSelected = onBackgroundSelected
                            )
                            
                            OutputFormatSelector(
                                selected = selectedFormat,
                                onSelected = onFormatSelected,
                                compressionLevel = compressionLevel,
                                onCompressionChanged = onCompressionChanged
                            )
                            
                            ModerationSelector(
                                selected = selectedModeration,
                                onSelected = onModerationSelected
                            )
                        }
                    }
                    
                    val estimatedCredits = GenerationOptions(
                        prompt = prompt,
                        number = number,
                        size = if (selectedSize == ImageSize.CUSTOM) customSize.ifEmpty { "1024x1024" } else selectedSize.value,
                        quality = selectedQuality.value,
                        background = selectedBackground?.value,
                        outputFormat = selectedFormat?.value,
                        compression = if (selectedFormat?.supportsCompression == true) compressionLevel else null,
                        moderation = selectedModeration?.value
                    ).estimateCredits()
                    
                    Button(
                        onClick = onGenerate,
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(56.dp),
                        enabled = prompt.isNotBlank() && !isGenerating,
                        shape = RoundedCornerShape(28.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = MaterialTheme.colorScheme.primary
                        )
                    ) {
                        if (isGenerating) {
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
                                    painter = painterResource(id = android.R.drawable.star_on),
                                    contentDescription = null,
                                    modifier = Modifier.size(22.dp)
                                )
                                Text(
                                    text = when (mode) {
                                        is ToolbarMode.Generate -> "Generate (${estimatedCredits.first}-${estimatedCredits.last} credits)"
                                        is ToolbarMode.Edit -> "Edit (${estimatedCredits.first}-${estimatedCredits.last} credits)"
                                    },
                                    style = MaterialTheme.typography.labelLarge,
                                    fontWeight = FontWeight.Medium
                                )
                            }
                        }
                    }
                }
            } else {
                Row(
                    modifier = Modifier
                        .fillMaxSize()
                        .clickable(
                            interactionSource = remember { MutableInteractionSource() },
                            indication = null
                        ) { onExpandedChange(true) }
                        .padding(horizontal = 20.dp, vertical = 16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    when (mode) {
                        is ToolbarMode.Generate -> {
                            Surface(
                                modifier = Modifier
                                    .size(48.dp)
                                    .shadow(
                                        elevation = 8.dp,
                                        shape = CircleShape,
                                        spotColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.4f),
                                        ambientColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.2f)
                                    ),
                                shape = CircleShape,
                                color = MaterialTheme.colorScheme.primary,
                                tonalElevation = 4.dp
                            ) {
                                Box(
                                    contentAlignment = Alignment.Center
                                ) {
                                    Icon(
                                        painter = painterResource(id = android.R.drawable.star_on),
                                        contentDescription = "Create",
                                        tint = MaterialTheme.colorScheme.onPrimary,
                                        modifier = Modifier.size(24.dp)
                                    )
                                }
                            }
                        }
                        is ToolbarMode.Edit -> {
                            Surface(
                                modifier = Modifier
                                    .size(48.dp)
                                    .shadow(
                                        elevation = 8.dp,
                                        shape = CircleShape,
                                        spotColor = MaterialTheme.colorScheme.secondary.copy(alpha = 0.4f),
                                        ambientColor = MaterialTheme.colorScheme.secondary.copy(alpha = 0.2f)
                                    ),
                                shape = CircleShape,
                                tonalElevation = 4.dp
                            ) {
                                AsyncImage(
                                    model = ImageRequest.Builder(LocalContext.current)
                                        .data(mode.selectedImage.uri)
                                        .crossfade(true)
                                        .build(),
                                    contentDescription = "Selected image",
                                    contentScale = ContentScale.Crop,
                                    modifier = Modifier.fillMaxSize()
                                )
                            }
                        }
                    }
                    
                    Column(
                        modifier = Modifier.weight(1f),
                        verticalArrangement = Arrangement.Center
                    ) {
                        when (mode) {
                            is ToolbarMode.Generate -> {
                                Text(
                                    text = if (prompt.isNotBlank()) prompt else "What do you want to create?",
                                    style = MaterialTheme.typography.bodyLarge,
                                    color = if (prompt.isNotBlank()) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurfaceVariant,
                                    maxLines = 1
                                )
                                Text(
                                    text = "Tap to customize",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f)
                                )
                            }
                            is ToolbarMode.Edit -> {
                                Text(
                                    text = if (prompt.isNotBlank()) prompt else "How do you want to edit this image?",
                                    style = MaterialTheme.typography.bodyLarge,
                                    color = if (prompt.isNotBlank()) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurfaceVariant,
                                    maxLines = 1
                                )
                                Text(
                                    text = "Tap to describe edits",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f)
                                )
                            }
                        }
                    }
                    
                    Icon(
                        imageVector = Icons.Default.KeyboardArrowUp,
                        contentDescription = "Expand",
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    }
}