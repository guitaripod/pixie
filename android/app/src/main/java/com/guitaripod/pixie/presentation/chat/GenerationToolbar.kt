package com.guitaripod.pixie.presentation.chat

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.AutoAwesome
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
import com.guitaripod.pixie.utils.hapticClickable
import com.guitaripod.pixie.utils.rememberHapticFeedback
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity

@OptIn(ExperimentalAnimationApi::class)
@Composable
fun GenerationToolbar(
    mode: ToolbarMode,
    isExpanded: Boolean,
    onExpandedChange: (Boolean) -> Unit,
    prompt: String,
    onPromptChange: (String) -> Unit,
    selectedSize: ImageSize,
    onSizeSelected: (ImageSize) -> Unit,
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
    val configuration = LocalConfiguration.current
    val density = LocalDensity.current
    
    val screenHeight = with(density) { configuration.screenHeightDp.dp }
    val expandedHeight = screenHeight * 0.85f
    val collapsedHeight = 80.dp
    
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
        if (expanded) expandedHeight else collapsedHeight
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
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(toolbarHeight)
                .navigationBarsPadding()
        ) {
        AnimatedContent(
            targetState = isExpanded,
            transitionSpec = {
                fadeIn(animationSpec = tween(300)) togetherWith fadeOut(animationSpec = tween(150))
            }
        ) { expanded ->
            if (expanded) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .hapticClickable { onExpandedChange(false) }
                ) {
                    Box(
                        modifier = Modifier
                            .align(Alignment.TopCenter)
                            .padding(top = 8.dp)
                            .width(40.dp)
                            .height(4.dp)
                            .background(
                                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.3f),
                                shape = RoundedCornerShape(2.dp)
                            )
                    )
                    
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .verticalScroll(rememberScrollState())
                            .padding(16.dp)
                            .padding(top = 8.dp), // Extra padding to account for handlebar
                        verticalArrangement = Arrangement.spacedBy(12.dp)
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
                                        imageVector = Icons.Default.AutoAwesome,
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
                        
                        if (mode is ToolbarMode.Edit) {
                            TextButton(onClick = onSwitchToGenerate) {
                                Text("New image")
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
                            imeAction = ImeAction.None
                        ),
                        singleLine = false,
                        shape = RoundedCornerShape(16.dp)
                    )
                    
                    SizeSelector(
                        selectedSize = selectedSize,
                        onSizeSelected = onSizeSelected
                    )
                    
                    QualitySelector(
                        selectedQuality = selectedQuality,
                        onQualitySelected = onQualitySelected
                    )
                    
                    var showAdvanced by remember { mutableStateOf(false) }
                    
                    Surface(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(16.dp))
                            .hapticClickable { showAdvanced = !showAdvanced },
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
                                imageVector = if (showAdvanced) Icons.Default.ExpandLess else Icons.Default.ExpandMore,
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
                        number = 1,
                        size = selectedSize.value,
                        quality = selectedQuality.value,
                        background = selectedBackground?.value,
                        outputFormat = selectedFormat?.value,
                        compression = if (selectedFormat?.supportsCompression == true) compressionLevel else null,
                        moderation = selectedModeration?.value
                    ).estimateCredits()
                    
                    val haptic = rememberHapticFeedback()
                    
                    Button(
                        onClick = {
                            haptic.click()
                            onGenerate()
                        },
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
                                    imageVector = Icons.Default.AutoAwesome,
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
                }
            } else {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .hapticClickable { onExpandedChange(true) }
                ) {
                    Box(
                        modifier = Modifier
                            .align(Alignment.TopCenter)
                            .padding(top = 8.dp)
                            .width(40.dp)
                            .height(4.dp)
                            .background(
                                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.3f),
                                shape = RoundedCornerShape(2.dp)
                            )
                    )
                    
                    Row(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(horizontal = 20.dp, vertical = 12.dp),
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
                                        imageVector = Icons.Default.AutoAwesome,
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
                    }
                }
            }
        }
        }
    }
}