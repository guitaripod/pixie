package com.guitaripod.pixie.presentation.credits

import android.app.Activity
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.guitaripod.pixie.data.api.model.CreditBalance
import com.guitaripod.pixie.data.purchases.CreditPackWithPrice
import com.guitaripod.pixie.data.purchases.PurchaseState
import com.guitaripod.pixie.utils.rememberHapticFeedback
import com.guitaripod.pixie.utils.hapticClickable

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EnhancedCreditPacksScreen(
    creditsViewModel: CreditsViewModel,
    purchaseViewModel: PurchaseViewModel,
    onNavigateBack: () -> Unit
) {
    val creditsUiState by creditsViewModel.uiState.collectAsStateWithLifecycle()
    val purchaseUiState by purchaseViewModel.uiState.collectAsStateWithLifecycle()
    val creditPacksWithPricing by purchaseViewModel.creditPacksWithPricing.collectAsStateWithLifecycle()
    
    val activity = LocalContext.current as? Activity
    
    var showRestoreDialog by remember { mutableStateOf(false) }
    
    Scaffold(
        topBar = {
            val haptic = rememberHapticFeedback()
            TopAppBar(
                title = { Text("🎁 Available Credit Packs") },
                navigationIcon = {
                    IconButton(onClick = {
                        haptic.click()
                        onNavigateBack()
                    }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    TextButton(
                        onClick = { 
                            haptic.click()
                            showRestoreDialog = true 
                        }
                    ) {
                        Text("Restore")
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
                creditPacksWithPricing.isEmpty() && !purchaseUiState.isLoading -> {
                    Column(
                        modifier = Modifier
                            .align(Alignment.Center)
                            .padding(32.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(16.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Warning,
                            contentDescription = null,
                            modifier = Modifier.size(48.dp),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Text(
                            text = "Credit packs unavailable",
                            style = MaterialTheme.typography.bodyLarge,
                            textAlign = TextAlign.Center
                        )
                        Text(
                            text = if (purchaseUiState.errorMessage?.contains("configuration") == true) {
                                "App needs to be published to Google Play testing track first"
                            } else {
                                "Please check your internet connection and try again"
                            },
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            textAlign = TextAlign.Center
                        )
                        val retryHaptic = rememberHapticFeedback()
                        Button(
                            onClick = { 
                                retryHaptic.click()
                                creditsViewModel.loadCreditPacks() 
                            }
                        ) {
                            Text("Retry")
                        }
                    }
                }
                else -> {
                    LazyColumn(
                        contentPadding = PaddingValues(16.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        item {
                            EnhancedCurrentBalanceCard(
                                balance = creditsUiState.balance
                            )
                        }
                        
                        items(creditPacksWithPricing) { packWithPrice ->
                            RevenueCatCreditPackCard(
                                creditPackWithPrice = packWithPrice,
                                onPackSelected = {
                                    activity?.let { act ->
                                        purchaseViewModel.purchaseCreditPack(act, packWithPrice)
                                    }
                                },
                                isLoading = purchaseUiState.purchaseState is PurchaseState.Loading
                            )
                        }
                        
                        item {
                            InfoCard()
                        }
                    }
                }
            }
            
            if (purchaseUiState.isLoading || purchaseUiState.purchaseState is PurchaseState.Loading) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(MaterialTheme.colorScheme.scrim.copy(alpha = 0.5f)),
                    contentAlignment = Alignment.Center
                ) {
                    Card {
                        CircularProgressIndicator(
                            modifier = Modifier.padding(32.dp)
                        )
                    }
                }
            }
        }
    }
    
    purchaseUiState.errorMessage?.let { error ->
        AlertDialog(
            onDismissRequest = { purchaseViewModel.clearError() },
            title = { Text("Purchase Error") },
            text = { Text(error) },
            confirmButton = {
                val errorHaptic = rememberHapticFeedback()
                TextButton(onClick = { 
                    errorHaptic.click()
                    purchaseViewModel.clearError() 
                }) {
                    Text("OK")
                }
            }
        )
    }
    
    if (purchaseUiState.showSuccessDialog) {
        purchaseUiState.lastPurchaseResult?.let { result ->
            PurchaseSuccessDialog(
                result = result,
                onDismiss = { 
                    purchaseViewModel.dismissSuccessDialog()
                    creditsViewModel.loadBalance()
                }
            )
        }
    }
    
    if (showRestoreDialog) {
        RestorePurchasesDialog(
            onConfirm = {
                purchaseViewModel.restorePurchases()
                showRestoreDialog = false
            },
            onDismiss = { showRestoreDialog = false }
        )
    }
}

@Composable
fun EnhancedCurrentBalanceCard(
    balance: CreditBalance?,
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
                    text = "Current Balance",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onPrimaryContainer
                )
                Text(
                    text = "${balance?.balance ?: 0} credits",
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onPrimaryContainer
                )
            }
        }
    }
}

@Composable
fun RevenueCatCreditPackCard(
    creditPackWithPrice: CreditPackWithPrice,
    onPackSelected: () -> Unit,
    isLoading: Boolean,
    modifier: Modifier = Modifier
) {
    val pack = creditPackWithPrice.creditPack
    val isPopular = pack.id == "popular"
    val haptic = rememberHapticFeedback()
    
    Card(
        onClick = {
            if (isPopular) {
                haptic.confirm() // Special haptic for popular pack
            } else {
                haptic.click()
            }
            onPackSelected()
        },
        modifier = modifier.fillMaxWidth(),
        enabled = !isLoading,
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
                        text = creditPackWithPrice.localizedPrice,
                        style = MaterialTheme.typography.headlineMedium,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.primary
                    )
                }
            }
            
            HorizontalDivider()
            
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
                
            }
            
            if (pack.description.isNotEmpty()) {
                Text(
                    text = pack.description,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

@Composable
fun PurchaseSuccessDialog(
    result: com.guitaripod.pixie.data.purchases.CreditPurchaseResult,
    onDismiss: () -> Unit
) {
    Dialog(onDismissRequest = onDismiss) {
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(16.dp)
        ) {
            Column(
                modifier = Modifier.padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.CheckCircle,
                    contentDescription = null,
                    modifier = Modifier.size(64.dp),
                    tint = MaterialTheme.colorScheme.primary
                )
                
                Text(
                    text = "Purchase Successful! 🎉",
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold,
                    textAlign = TextAlign.Center
                )
                
                Text(
                    text = "You've added ${result.credits} credits to your account",
                    style = MaterialTheme.typography.bodyLarge,
                    textAlign = TextAlign.Center
                )
                
                Surface(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(8.dp),
                    color = MaterialTheme.colorScheme.primaryContainer
                ) {
                    Column(
                        modifier = Modifier.padding(16.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Text(
                            text = "New Balance",
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onPrimaryContainer
                        )
                        Text(
                            text = "${result.newBalance} credits",
                            style = MaterialTheme.typography.headlineMedium,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onPrimaryContainer
                        )
                    }
                }
                
                val successHaptic = rememberHapticFeedback()
                Button(
                    onClick = {
                        successHaptic.confirm()
                        onDismiss()
                    },
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text("Continue")
                }
            }
        }
    }
}

@Composable
fun RestorePurchasesDialog(
    onConfirm: () -> Unit,
    onDismiss: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        icon = {
            Icon(
                imageVector = Icons.Default.Refresh,
                contentDescription = null
            )
        },
        title = { Text("Restore Purchases") },
        text = { 
            Text("This will restore any previous credit purchases made with this Google account.")
        },
        confirmButton = {
            val restoreHaptic = rememberHapticFeedback()
            TextButton(onClick = {
                restoreHaptic.click()
                onConfirm()
            }) {
                Text("Restore")
            }
        },
        dismissButton = {
            val cancelHaptic = rememberHapticFeedback()
            TextButton(onClick = {
                cancelHaptic.click()
                onDismiss()
            }) {
                Text("Cancel")
            }
        }
    )
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
                text = "• Low quality (1024x1024): 4 credits\n" +
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