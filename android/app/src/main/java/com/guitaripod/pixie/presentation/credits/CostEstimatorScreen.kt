package com.guitaripod.pixie.presentation.credits

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Info
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.guitaripod.pixie.data.api.model.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CostEstimatorScreen(
    viewModel: CreditsViewModel,
    onNavigateBack: () -> Unit
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    
    var selectedQuality by remember { mutableStateOf("medium") }
    var selectedSize by remember { mutableStateOf("1024x1024") }
    var isEdit by remember { mutableStateOf(false) }
    var numberOfImages by remember { mutableIntStateOf(1) }
    
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Cost Estimator") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            uiState.balance?.let { balance ->
                CurrentBalanceCard(balance = balance)
            }
            
            QualitySelector(
                selectedQuality = selectedQuality,
                onQualitySelected = { selectedQuality = it }
            )
            
            SizeSelector(
                selectedSize = selectedSize,
                onSizeSelected = { selectedSize = it }
            )
            
            EditToggle(
                isEdit = isEdit,
                onToggle = { isEdit = it }
            )
            
            NumberOfImagesSelector(
                numberOfImages = numberOfImages,
                onNumberChanged = { numberOfImages = it }
            )
            
            Button(
                onClick = {
                    viewModel.estimateCredits(
                        quality = selectedQuality,
                        size = selectedSize,
                        isEdit = isEdit
                    )
                },
                modifier = Modifier.fillMaxWidth(),
                contentPadding = PaddingValues(16.dp)
            ) {
                Icon(
                    Icons.Default.Info,
                    contentDescription = null,
                    modifier = Modifier.size(20.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text("Calculate Cost")
            }
            
            AnimatedVisibility(
                visible = uiState.estimatedCredits != null,
                enter = expandVertically(),
                exit = shrinkVertically()
            ) {
                uiState.estimatedCredits?.let { estimate ->
                    EstimationResultCard(
                        estimate = estimate,
                        numberOfImages = numberOfImages,
                        currentBalance = uiState.balance?.balance ?: 0
                    )
                }
            }
            
            CostReferenceCard()
        }
    }
}

@Composable
fun CurrentBalanceCard(
    balance: CreditBalance,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.primaryContainer
        )
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
                    text = "Your Balance",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onPrimaryContainer
                )
                Text(
                    text = "${balance.balance} credits",
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold,
                    color = balance.getBalanceColor()
                )
            }
        }
    }
}

@Composable
fun QualitySelector(
    selectedQuality: String,
    onQualitySelected: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    Card(modifier = modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text(
                text = "Quality",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
            
            val qualities = listOf(
                "low" to "Fast & affordable",
                "medium" to "Balanced quality",
                "high" to "Best quality",
                "auto" to "AI optimized"
            )
            
            qualities.forEach { (quality, description) ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    RadioButton(
                        selected = selectedQuality == quality,
                        onClick = { onQualitySelected(quality) }
                    )
                    Column(
                        modifier = Modifier.weight(1f)
                    ) {
                        Text(
                            text = quality.replaceFirstChar { it.uppercase() },
                            style = MaterialTheme.typography.bodyLarge,
                            fontWeight = FontWeight.Medium
                        )
                        Text(
                            text = description,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    Text(
                        text = getQualityCreditRange(quality),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.primary,
                        fontWeight = FontWeight.Medium
                    )
                }
            }
        }
    }
}

@Composable
fun SizeSelector(
    selectedSize: String,
    onSizeSelected: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    Card(modifier = modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text(
                text = "Size",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
            
            val sizes = listOf(
                "1024x1024" to "Square",
                "1536x1024" to "Landscape",
                "1024x1536" to "Portrait"
            )
            
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                sizes.forEach { (size, label) ->
                    FilterChip(
                        selected = selectedSize == size,
                        onClick = { onSizeSelected(size) },
                        label = {
                            Column(
                                horizontalAlignment = Alignment.CenterHorizontally
                            ) {
                                Text(label)
                                Text(
                                    text = size,
                                    style = MaterialTheme.typography.labelSmall
                                )
                            }
                        },
                        modifier = Modifier.weight(1f)
                    )
                }
            }
        }
    }
}

@Composable
fun EditToggle(
    isEdit: Boolean,
    onToggle: (Boolean) -> Unit,
    modifier: Modifier = Modifier
) {
    Card(modifier = modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Text(
                    text = "Edit Operation",
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.Medium
                )
                Text(
                    text = "Adds 3-20 credits for input processing",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            Switch(
                checked = isEdit,
                onCheckedChange = onToggle
            )
        }
    }
}

@Composable
fun NumberOfImagesSelector(
    numberOfImages: Int,
    onNumberChanged: (Int) -> Unit,
    modifier: Modifier = Modifier
) {
    Card(modifier = modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(
                text = "Number of Images",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
            
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                (1..4).forEach { num ->
                    FilterChip(
                        selected = numberOfImages == num,
                        onClick = { onNumberChanged(num) },
                        label = { Text("$num") },
                        modifier = Modifier.weight(1f)
                    )
                }
            }
        }
    }
}

@Composable
fun EstimationResultCard(
    estimate: CreditEstimateResponse,
    numberOfImages: Int,
    currentBalance: Int,
    modifier: Modifier = Modifier
) {
    val totalCredits = estimate.estimatedCredits * numberOfImages
    val canAfford = currentBalance >= totalCredits
    
    Card(
        modifier = modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = if (canAfford) 
                MaterialTheme.colorScheme.primaryContainer 
            else 
                MaterialTheme.colorScheme.errorContainer
        )
    ) {
        Column(
            modifier = Modifier.padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Top
            ) {
                Column {
                    Text(
                        text = "Estimated Cost",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold
                    )
                    if (numberOfImages > 1) {
                        Text(
                            text = "${estimate.estimatedCredits} credits × $numberOfImages images",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
                
                Icon(
                    imageVector = if (canAfford) Icons.Default.Check else Icons.Default.Close,
                    contentDescription = null,
                    tint = if (canAfford) 
                        MaterialTheme.colorScheme.primary 
                    else 
                        MaterialTheme.colorScheme.error
                )
            }
            
            Text(
                text = "$totalCredits credits",
                style = MaterialTheme.typography.displaySmall,
                fontWeight = FontWeight.Bold
            )
            
            
            if (estimate.note.isNotEmpty()) {
                Text(
                    text = estimate.note,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            
            HorizontalDivider()
            
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = if (canAfford) "Balance after" else "Shortage",
                        style = MaterialTheme.typography.labelMedium
                    )
                    Text(
                        text = if (canAfford) 
                            "${currentBalance - totalCredits} credits" 
                        else 
                            "${totalCredits - currentBalance} credits needed",
                        style = MaterialTheme.typography.bodyLarge,
                        fontWeight = FontWeight.Medium
                    )
                }
                
                if (!canAfford) {
                    TextButton(onClick = { }) {
                        Text("Buy Credits")
                    }
                }
            }
        }
    }
}

@Composable
fun CostReferenceCard(
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant
        )
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(
                text = "Quick Reference",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
            
            val references = listOf(
                "Low quality" to "4-6 credits",
                "Medium quality" to "16-24 credits",
                "High quality" to "62-94 credits",
                "Auto quality" to "50-75 credits",
                "Edit bonus" to "+3-20 credits"
            )
            
            references.forEach { (label, cost) ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(
                        text = label,
                        style = MaterialTheme.typography.bodyMedium
                    )
                    Text(
                        text = cost,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Medium,
                        color = MaterialTheme.colorScheme.primary
                    )
                }
            }
        }
    }
}

private fun getQualityCreditRange(quality: String): String = when (quality) {
    "low" -> "4-6"
    "medium" -> "16-24"
    "high" -> "62-94"
    "auto" -> "50-75"
    else -> "?"
}