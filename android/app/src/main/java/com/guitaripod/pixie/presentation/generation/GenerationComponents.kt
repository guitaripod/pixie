package com.guitaripod.pixie.presentation.generation

import androidx.compose.animation.*
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import com.guitaripod.pixie.data.model.*

@Composable
fun SizeSelector(
    selectedSize: ImageSize,
    onSizeSelected: (ImageSize) -> Unit,
    customSize: String,
    onCustomSizeChanged: (String) -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "Size",
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Medium
            )
            Text(
                text = if (selectedSize == ImageSize.CUSTOM) customSize.ifEmpty { "Custom" } else selectedSize.dimensions,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            ImageSize.values().forEach { size ->
                FilterChip(
                    selected = selectedSize == size,
                    onClick = { onSizeSelected(size) },
                    label = { Text(size.displayName) },
                    modifier = Modifier.weight(1f)
                )
            }
        }
        
        AnimatedVisibility(
            visible = selectedSize == ImageSize.CUSTOM,
            enter = expandVertically() + fadeIn(),
            exit = shrinkVertically() + fadeOut()
        ) {
            OutlinedTextField(
                value = customSize,
                onValueChange = onCustomSizeChanged,
                modifier = Modifier.fillMaxWidth(),
                placeholder = { Text("e.g., 1024x1024") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Ascii),
                shape = RoundedCornerShape(8.dp)
            )
        }
    }
}

@Composable
fun QualitySelector(
    selectedQuality: ImageQuality,
    onQualitySelected: (ImageQuality) -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "Quality",
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Medium
            )
            Text(
                text = selectedQuality.creditRange,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.primary,
                fontWeight = FontWeight.Medium
            )
        }
        
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            ImageQuality.values().forEach { quality ->
                FilterChip(
                    selected = selectedQuality == quality,
                    onClick = { onQualitySelected(quality) },
                    label = { Text(quality.displayName) },
                    modifier = Modifier.weight(1f),
                    colors = FilterChipDefaults.filterChipColors(
                        selectedContainerColor = when (quality) {
                            ImageQuality.HIGH -> MaterialTheme.colorScheme.error.copy(alpha = 0.2f)
                            ImageQuality.MEDIUM -> MaterialTheme.colorScheme.primary.copy(alpha = 0.2f)
                            else -> MaterialTheme.colorScheme.secondaryContainer
                        }
                    )
                )
            }
        }
    }
}

@Composable
fun NumberPicker(
    number: Int,
    onNumberChanged: (Int) -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = "Number of images",
            style = MaterialTheme.typography.bodyLarge,
            fontWeight = FontWeight.Medium
        )
        
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            IconButton(
                onClick = { if (number > 1) onNumberChanged(number - 1) },
                enabled = number > 1,
                modifier = Modifier.size(36.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.Remove,
                    contentDescription = "Decrease"
                )
            }
            
            Text(
                text = number.toString(),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.widthIn(min = 32.dp),
                textAlign = TextAlign.Center
            )
            
            IconButton(
                onClick = { if (number < 10) onNumberChanged(number + 1) },
                enabled = number < 10,
                modifier = Modifier.size(36.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.Add,
                    contentDescription = "Increase"
                )
            }
        }
    }
}

@Composable
fun BackgroundSelector(
    selected: BackgroundStyle?,
    onSelected: (BackgroundStyle?) -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            text = "Background",
            style = MaterialTheme.typography.bodyLarge,
            fontWeight = FontWeight.Medium
        )
        
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            FilterChip(
                selected = selected == null,
                onClick = { onSelected(null) },
                label = { Text("Default") },
                modifier = Modifier.weight(1f)
            )
            BackgroundStyle.values().forEach { style ->
                FilterChip(
                    selected = selected == style,
                    onClick = { onSelected(style) },
                    label = { Text(style.displayName) },
                    modifier = Modifier.weight(1f)
                )
            }
        }
    }
}

@Composable
fun OutputFormatSelector(
    selected: OutputFormat?,
    onSelected: (OutputFormat?) -> Unit,
    compressionLevel: Int,
    onCompressionChanged: (Int) -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            text = "Output format",
            style = MaterialTheme.typography.bodyLarge,
            fontWeight = FontWeight.Medium
        )
        
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            FilterChip(
                selected = selected == null,
                onClick = { onSelected(null) },
                label = { Text("Default") },
                modifier = Modifier.weight(1f)
            )
            OutputFormat.values().forEach { format ->
                FilterChip(
                    selected = selected == format,
                    onClick = { onSelected(format) },
                    label = { Text(format.displayName) },
                    modifier = Modifier.weight(1f)
                )
            }
        }
        
        AnimatedVisibility(
            visible = selected?.supportsCompression == true,
            enter = expandVertically() + fadeIn(),
            exit = shrinkVertically() + fadeOut()
        ) {
            Column(
                modifier = Modifier.padding(top = 8.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(
                        text = "Compression",
                        style = MaterialTheme.typography.bodyMedium
                    )
                    Text(
                        text = "$compressionLevel%",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.primary
                    )
                }
                Slider(
                    value = compressionLevel.toFloat(),
                    onValueChange = { onCompressionChanged(it.toInt()) },
                    valueRange = 0f..100f,
                    steps = 19
                )
            }
        }
    }
}

@Composable
fun ModerationSelector(
    selected: ModerationLevel?,
    onSelected: (ModerationLevel?) -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "Moderation",
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Medium
            )
            selected?.let {
                Text(
                    text = it.description,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
        
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            FilterChip(
                selected = selected == null,
                onClick = { onSelected(null) },
                label = { Text("Default") },
                modifier = Modifier.weight(1f)
            )
            ModerationLevel.values().forEach { level ->
                FilterChip(
                    selected = selected == level,
                    onClick = { onSelected(level) },
                    label = { Text(level.displayName) },
                    modifier = Modifier.weight(1f)
                )
            }
        }
    }
}