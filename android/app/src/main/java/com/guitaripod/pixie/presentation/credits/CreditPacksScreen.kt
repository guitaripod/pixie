package com.guitaripod.pixie.presentation.credits

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.guitaripod.pixie.data.api.model.CreditPack

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreditPacksScreen(
    viewModel: CreditsViewModel,
    onNavigateBack: () -> Unit,
    onPackSelected: (CreditPack) -> Unit
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("🎁 Available Credit Packs") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            when {
                uiState.isLoadingPacks -> {
                    CircularProgressIndicator(
                        modifier = Modifier.align(Alignment.Center)
                    )
                }
                uiState.creditPacks.isEmpty() -> {
                    Text(
                        text = "No credit packs available",
                        style = MaterialTheme.typography.bodyLarge,
                        modifier = Modifier
                            .align(Alignment.Center)
                            .padding(32.dp),
                        textAlign = TextAlign.Center
                    )
                }
                else -> {
                    LazyColumn(
                        contentPadding = PaddingValues(16.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        item {
                            Card(
                                modifier = Modifier.fillMaxWidth(),
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
                                            text = "Current Balance",
                                            style = MaterialTheme.typography.labelMedium,
                                            color = MaterialTheme.colorScheme.onPrimaryContainer
                                        )
                                        Text(
                                            text = "${uiState.balance?.balance ?: 0} credits",
                                            style = MaterialTheme.typography.headlineSmall,
                                            fontWeight = FontWeight.Bold,
                                            color = MaterialTheme.colorScheme.onPrimaryContainer
                                        )
                                    }
                                    Text(
                                        text = "≈ $%.2f".format((uiState.balance?.balance ?: 0) * 0.01),
                                        style = MaterialTheme.typography.titleMedium,
                                        color = MaterialTheme.colorScheme.onPrimaryContainer
                                    )
                                }
                            }
                        }
                        
                        items(uiState.creditPacks) { pack ->
                            CreditPackCard(
                                pack = pack,
                                onPackSelected = { onPackSelected(pack) }
                            )
                        }
                        
                        item {
                            InfoCard()
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun CreditPackCard(
    pack: CreditPack,
    onPackSelected: () -> Unit,
    modifier: Modifier = Modifier
) {
    val isPopular = pack.popular || pack.name.contains("Popular", ignoreCase = true)
    
    Card(
        onClick = onPackSelected,
        modifier = modifier.fillMaxWidth(),
        border = if (isPopular) BorderStroke(2.dp, MaterialTheme.colorScheme.primary) else null,
        elevation = CardDefaults.cardElevation(
            defaultElevation = if (isPopular) 8.dp else 2.dp
        )
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Top
            ) {
                Column(
                    verticalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = pack.name,
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.Bold
                        )
                        if (isPopular) {
                            Icon(
                                Icons.Default.Star,
                                contentDescription = "Popular",
                                tint = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.size(20.dp)
                            )
                        }
                    }
                    
                    if (isPopular) {
                        Text(
                            text = "MOST POPULAR",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.primary,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
                
                Column(
                    horizontalAlignment = Alignment.End
                ) {
                    Text(
                        text = pack.priceUsd,
                        style = MaterialTheme.typography.headlineMedium,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.primary
                    )
                    if (pack.savingsPercent > 0) {
                        Text(
                            text = "Save ${pack.savingsPercent}%",
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.tertiary
                        )
                    }
                }
            }
            
            Divider()
            
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(
                    verticalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                        verticalAlignment = Alignment.Bottom
                    ) {
                        Text(
                            text = "${pack.totalCredits}",
                            style = MaterialTheme.typography.headlineSmall,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            text = "credits",
                            style = MaterialTheme.typography.bodyLarge
                        )
                    }
                    if (pack.bonusCredits > 0) {
                        Text(
                            text = "${pack.credits} + ${pack.bonusCredits} bonus",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
                
                Column(
                    horizontalAlignment = Alignment.End,
                    verticalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Text(
                        text = "Value: ${pack.creditValue}",
                        style = MaterialTheme.typography.bodyMedium,
                        textDecoration = if (pack.savingsPercent > 0) TextDecoration.LineThrough else null,
                        color = if (pack.savingsPercent > 0) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface
                    )
                    if (pack.savings != "$0.00") {
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(4.dp))
                                .background(MaterialTheme.colorScheme.tertiaryContainer)
                                .padding(horizontal = 8.dp, vertical = 4.dp)
                        ) {
                            Text(
                                text = "Save ${pack.savings}",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onTertiaryContainer,
                                fontWeight = FontWeight.Bold
                            )
                        }
                    }
                }
            }
            
            if (pack.description.isNotEmpty()) {
                Text(
                    text = pack.description,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            
            val features = getPackFeatures(pack)
            if (features.isNotEmpty()) {
                Column(
                    verticalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    features.forEach { feature ->
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                Icons.Default.CheckCircle,
                                contentDescription = null,
                                modifier = Modifier.size(16.dp),
                                tint = MaterialTheme.colorScheme.primary
                            )
                            Text(
                                text = feature,
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun InfoCard(
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.secondaryContainer
        )
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(
                text = "About Credits",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSecondaryContainer
            )
            Text(
                text = "• 1 credit = $0.01 USD\n" +
                      "• Low quality (1024x1024): 4 credits\n" +
                      "• Medium quality (1024x1024): 16 credits\n" +
                      "• High quality (1024x1024): 62 credits\n" +
                      "• Larger sizes cost more credits\n" +
                      "• Edit operations: +3-20 credits",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSecondaryContainer
            )
        }
    }
}

private fun getPackFeatures(pack: CreditPack): List<String> {
    val features = mutableListOf<String>()
    
    val lowQualityImages = pack.totalCredits / 4  // 1024x1024 low quality = 4 credits
    val mediumQualityImages = pack.totalCredits / 16  // 1024x1024 medium quality = 16 credits
    val highQualityImages = pack.totalCredits / 62  // 1024x1024 high quality = 62 credits
    
    features.add("Generate ~$lowQualityImages low quality images")
    features.add("Generate ~$mediumQualityImages medium quality images")
    features.add("Generate ~$highQualityImages high quality images")
    
    when {
        pack.totalCredits >= 5000 -> {
            features.add("Priority support")
            features.add("Bulk operations")
        }
        pack.totalCredits >= 2500 -> {
            features.add("Priority processing")
        }
        pack.totalCredits >= 1250 -> {
            features.add("Faster generation times")
        }
    }
    
    if (pack.bonusCredits > 0) {
        features.add("${pack.bonusCredits} bonus credits included!")
    }
    
    return features
}