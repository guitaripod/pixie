package com.guitaripod.pixie.presentation.generation

import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import com.guitaripod.pixie.data.model.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GenerationScreen(
    viewModel: GenerationViewModel,
    onNavigateToResults: (List<String>) -> Unit,
    modifier: Modifier = Modifier
) {
    var prompt by remember { mutableStateOf("") }
    var number by remember { mutableIntStateOf(1) }
    var selectedSize by remember { mutableStateOf(ImageSize.AUTO) }
    var customSize by remember { mutableStateOf("") }
    var selectedQuality by remember { mutableStateOf(ImageQuality.LOW) }
    var showAdvanced by remember { mutableStateOf(false) }
    
    var selectedBackground by remember { mutableStateOf<BackgroundStyle?>(null) }
    var selectedFormat by remember { mutableStateOf<OutputFormat?>(null) }
    var compressionLevel by remember { mutableIntStateOf(85) }
    var selectedModeration by remember { mutableStateOf<ModerationLevel?>(null) }
    
    val isGenerating by viewModel.isGenerating.collectAsState()
    val generationProgress by viewModel.generationProgress.collectAsState()
    val error by viewModel.error.collectAsState()
    
    val options = GenerationOptions(
        prompt = prompt,
        number = number,
        size = if (selectedSize == ImageSize.CUSTOM) customSize.ifEmpty { "1024x1024" } else selectedSize.value,
        quality = selectedQuality.value,
        background = selectedBackground?.value,
        outputFormat = selectedFormat?.value,
        compression = if (selectedFormat?.supportsCompression == true) compressionLevel else null,
        moderation = selectedModeration?.value
    )
    
    val estimatedCredits = options.estimateCredits()
    
    LaunchedEffect(viewModel) {
        viewModel.generationResult.collect { result ->
            result?.let { onNavigateToResults(it) }
        }
    }
    
    Box(modifier = modifier.fillMaxSize()) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(12.dp)
            ) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    Text(
                        text = "Describe your image",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold
                    )
                    
                    OutlinedTextField(
                        value = prompt,
                        onValueChange = { prompt = it },
                        modifier = Modifier.fillMaxWidth(),
                        placeholder = { Text("e.g., a serene landscape with mountains at sunset") },
                        minLines = 3,
                        maxLines = 6,
                        keyboardOptions = KeyboardOptions(
                            capitalization = KeyboardCapitalization.Sentences,
                            imeAction = ImeAction.Done
                        ),
                        shape = RoundedCornerShape(8.dp)
                    )
                }
            }
            
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(12.dp)
            ) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    Text(
                        text = "Basic Options",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold
                    )
                    
                    SizeSelector(
                        selectedSize = selectedSize,
                        onSizeSelected = { selectedSize = it },
                        customSize = customSize,
                        onCustomSizeChanged = { customSize = it }
                    )
                    
                    HorizontalDivider()
                    
                    QualitySelector(
                        selectedQuality = selectedQuality,
                        onQualitySelected = { selectedQuality = it }
                    )
                    
                    HorizontalDivider()
                    
                    NumberPicker(
                        number = number,
                        onNumberChanged = { number = it }
                    )
                }
            }
            
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .clickable { showAdvanced = !showAdvanced },
                shape = RoundedCornerShape(12.dp)
            ) {
                Column {
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
                            fontWeight = FontWeight.Bold
                        )
                        Icon(
                            imageVector = if (showAdvanced) Icons.Default.KeyboardArrowUp else Icons.Default.KeyboardArrowDown,
                            contentDescription = if (showAdvanced) "Hide" else "Show"
                        )
                    }
                    
                    AnimatedVisibility(
                        visible = showAdvanced,
                        enter = expandVertically() + fadeIn(),
                        exit = shrinkVertically() + fadeOut()
                    ) {
                        Column(
                            modifier = Modifier.padding(16.dp),
                            verticalArrangement = Arrangement.spacedBy(16.dp)
                        ) {
                            HorizontalDivider()
                            
                            BackgroundSelector(
                                selected = selectedBackground,
                                onSelected = { selectedBackground = it }
                            )
                            
                            HorizontalDivider()
                            
                            OutputFormatSelector(
                                selected = selectedFormat,
                                onSelected = { selectedFormat = it },
                                compressionLevel = compressionLevel,
                                onCompressionChanged = { compressionLevel = it }
                            )
                            
                            HorizontalDivider()
                            
                            ModerationSelector(
                                selected = selectedModeration,
                                onSelected = { selectedModeration = it }
                            )
                        }
                    }
                }
            }
            
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.primaryContainer
                ),
                shape = RoundedCornerShape(12.dp)
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text(
                            text = "Estimated cost",
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onPrimaryContainer
                        )
                        Text(
                            text = "${estimatedCredits.first}-${estimatedCredits.last} credits",
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onPrimaryContainer
                        )
                    }
                    
                    Button(
                        onClick = { viewModel.generateImages(options) },
                        enabled = prompt.isNotBlank() && !isGenerating,
                        modifier = Modifier.height(48.dp),
                        shape = RoundedCornerShape(24.dp)
                    ) {
                        if (isGenerating) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(16.dp),
                                color = MaterialTheme.colorScheme.onPrimary,
                                strokeWidth = 2.dp
                            )
                        } else {
                            Icon(
                                imageVector = Icons.Default.AutoAwesome,
                                contentDescription = null,
                                modifier = Modifier.size(20.dp)
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text("Generate")
                        }
                    }
                }
            }
            
            error?.let { errorMessage ->
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.errorContainer
                    ),
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Text(
                        text = errorMessage,
                        modifier = Modifier.padding(12.dp),
                        color = MaterialTheme.colorScheme.onErrorContainer,
                        style = MaterialTheme.typography.bodySmall
                    )
                }
            }
            
            Spacer(modifier = Modifier.height(80.dp))
        }
        
        if (isGenerating && generationProgress != null) {
            GenerationProgressOverlay(
                progress = generationProgress,
                onCancel = { viewModel.cancelGeneration() }
            )
        }
    }
}