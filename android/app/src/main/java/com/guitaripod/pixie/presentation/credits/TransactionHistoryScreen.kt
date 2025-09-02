package com.guitaripod.pixie.presentation.credits

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Undo
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import java.time.ZoneOffset
import androidx.compose.runtime.*
import kotlinx.coroutines.flow.collect
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.guitaripod.pixie.data.api.model.*
import java.time.LocalDateTime
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.time.temporal.ChronoUnit

@OptIn(ExperimentalMaterial3Api::class, ExperimentalFoundationApi::class)
@Composable
fun TransactionHistoryScreen(
    viewModel: CreditsViewModel,
    onNavigateBack: () -> Unit
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val listState = rememberLazyListState()
    
    LaunchedEffect(Unit) {
        viewModel.loadTransactions(limit = 50)
    }
    
    uiState.errorMessage?.let { error ->
        LaunchedEffect(error) {
            println("Transaction History Error: $error")
        }
    }
    
    val groupedTransactions = remember(uiState.transactions) {
        groupTransactionsByDate(uiState.transactions)
    }
    
    LaunchedEffect(listState) {
        snapshotFlow { listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index }
            .collect { lastVisibleIndex ->
                if (lastVisibleIndex != null && 
                    lastVisibleIndex >= uiState.transactions.size - 5 &&
                    uiState.hasMoreTransactions && 
                    !uiState.isLoadingTransactions) {
                    viewModel.loadTransactions(loadMore = true)
                }
            }
    }
    
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Transaction History") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(onClick = { viewModel.loadTransactions() }) {
                        Icon(Icons.Default.Refresh, contentDescription = "Refresh")
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
                uiState.isLoadingTransactions && uiState.transactions.isEmpty() -> {
                    CircularProgressIndicator(
                        modifier = Modifier.align(Alignment.Center)
                    )
                }
                uiState.transactions.isEmpty() -> {
                    Column(
                        modifier = Modifier
                            .align(Alignment.Center)
                            .padding(16.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        EmptyTransactionsMessage()
                        
                        Text(
                            text = "Debug: isLoading=${uiState.isLoadingTransactions}, " +
                                   "count=${uiState.transactions.size}, " +
                                   "error=${uiState.errorMessage ?: "none"}",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f)
                        )
                    }
                }
                else -> {
                    LazyColumn(
                        state = listState,
                        contentPadding = PaddingValues(vertical = 8.dp),
                        verticalArrangement = Arrangement.spacedBy(0.dp)
                    ) {
                        groupedTransactions.forEach { (dateHeader, transactions) ->
                            stickyHeader {
                                DateHeader(dateHeader)
                            }
                            
                            items(
                                items = transactions,
                                key = { it.id }
                            ) { transaction ->
                                TransactionCard(
                                    transaction = transaction,
                                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)
                                )
                            }
                        }
                        
                        if (uiState.isLoadingTransactions && uiState.transactions.isNotEmpty()) {
                            item {
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(16.dp),
                                    contentAlignment = Alignment.Center
                                ) {
                                    CircularProgressIndicator()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun TransactionCard(
    transaction: CreditTransaction,
    modifier: Modifier = Modifier
) {
    val transactionType = transaction.transactionType.toTransactionType()
    val isSpend = transactionType == TransactionType.SPEND
    
    Card(
        modifier = modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface
        )
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.weight(1f)
            ) {
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .clip(CircleShape)
                        .background(
                            if (isSpend) 
                                MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.5f)
                            else 
                                MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.5f)
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = getTransactionIcon(transaction),
                        contentDescription = null,
                        tint = if (isSpend) 
                            MaterialTheme.colorScheme.error
                        else 
                            MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(24.dp)
                    )
                }
                
                Column(
                    verticalArrangement = Arrangement.spacedBy(2.dp),
                    modifier = Modifier.weight(1f)
                ) {
                    Text(
                        text = transaction.description,
                        style = MaterialTheme.typography.bodyLarge,
                        fontWeight = FontWeight.Medium,
                        maxLines = 1,
                        overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis
                    )
                    Text(
                        text = formatTime(transaction.createdAt),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
            
            Column(
                horizontalAlignment = Alignment.End,
                verticalArrangement = Arrangement.spacedBy(2.dp)
            ) {
                Text(
                    text = "${if (isSpend) "-" else "+"}${transaction.amount}",
                    style = MaterialTheme.typography.titleMedium,
                    color = if (isSpend) 
                        MaterialTheme.colorScheme.error
                    else 
                        MaterialTheme.colorScheme.primary,
                    fontWeight = FontWeight.SemiBold
                )
                Text(
                    text = "Balance: ${transaction.balanceAfter}",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f)
                )
            }
        }
    }
}

private fun getTransactionIcon(transaction: CreditTransaction): androidx.compose.ui.graphics.vector.ImageVector {
    val description = transaction.description.lowercase()
    val isSpend = transaction.transactionType == "spend"
    
    return when {
        isSpend -> when {
            description.contains("edit") -> Icons.Outlined.Edit
            description.contains("upscale") -> Icons.Outlined.ZoomIn
            description.contains("generat") || description.contains("created") -> Icons.Outlined.AutoAwesome
            else -> Icons.Outlined.AutoAwesome
        }
        else -> when {
            description.contains("purchase") -> Icons.Filled.CreditCard
            description.contains("bonus") -> Icons.Filled.CardGiftcard
            description.contains("refund") -> Icons.AutoMirrored.Filled.Undo
            description.contains("admin") -> Icons.Filled.AdminPanelSettings
            else -> Icons.Filled.Add
        }
    }
}

@Composable
fun TransactionChip(
    text: String,
    color: androidx.compose.ui.graphics.Color,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(color.copy(alpha = 0.1f))
            .padding(horizontal = 8.dp, vertical = 4.dp)
    ) {
        Text(
            text = text,
            style = MaterialTheme.typography.labelSmall,
            color = color,
            fontWeight = FontWeight.Medium
        )
    }
}

@Composable
fun DateHeader(
    date: String,
    modifier: Modifier = Modifier
) {
    Surface(
        modifier = modifier.fillMaxWidth(),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
    ) {
        Text(
            text = date,
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.Medium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
        )
    }
}

private fun groupTransactionsByDate(transactions: List<CreditTransaction>): List<Pair<String, List<CreditTransaction>>> {
    if (transactions.isEmpty()) return emptyList()
    
    val grouped = transactions.groupBy { transaction ->
        formatDateHeader(transaction.createdAt)
    }
    
    val specialOrder = listOf("Today", "Yesterday")
    
    return grouped.entries.sortedWith(compareBy(
        { entry -> 
            val index = specialOrder.indexOf(entry.key)
            if (index >= 0) index else Int.MAX_VALUE
        },
        { entry ->
            if (!specialOrder.contains(entry.key)) {
                try {
                    val firstTransaction = entry.value.firstOrNull()
                    firstTransaction?.createdAt?.let {
                        -parseDateTime(it).toEpochSecond(java.time.ZoneOffset.UTC)
                    } ?: 0L
                } catch (e: Exception) {
                    0L
                }
            } else {
                0L
            }
        }
    )).map { entry ->
        entry.key to entry.value.sortedByDescending { 
            try {
                parseDateTime(it.createdAt).toEpochSecond(java.time.ZoneOffset.UTC)
            } catch (e: Exception) {
                0L
            }
        }
    }
}

private fun formatDateHeader(dateTimeString: String): String {
    return try {
        val dateTime = parseDateTime(dateTimeString)
        val now = LocalDateTime.now()
        val daysBetween = ChronoUnit.DAYS.between(dateTime.toLocalDate(), now.toLocalDate())
        
        when {
            daysBetween == 0L -> "Today"
            daysBetween == 1L -> "Yesterday"
            daysBetween < 7L -> dateTime.format(DateTimeFormatter.ofPattern("EEEE"))
            else -> dateTime.format(DateTimeFormatter.ofPattern("MMMM d, yyyy"))
        }
    } catch (e: Exception) {
        dateTimeString.split('T').firstOrNull() ?: dateTimeString
    }
}

private fun parseDateTime(dateTimeString: String): LocalDateTime {
    return when {
        dateTimeString.contains("T") -> {
            if (dateTimeString.contains("Z") || dateTimeString.contains("+")) {
                ZonedDateTime.parse(dateTimeString).toLocalDateTime()
            } else {
                LocalDateTime.parse(dateTimeString)
            }
        }
        else -> LocalDateTime.parse(dateTimeString.replace(" ", "T"))
    }
}

@Composable
fun EmptyTransactionsMessage(
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier.padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(
            text = "No transactions yet",
            style = MaterialTheme.typography.headlineSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Text(
            text = "Your credit transactions will appear here",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center
        )
    }
}

private fun formatTime(dateTimeString: String): String {
    return try {
        val dateTime = parseDateTime(dateTimeString)
        dateTime.format(DateTimeFormatter.ofPattern("h:mm a"))
    } catch (e: Exception) {
        ""
    }
}

private fun formatDateTime(dateTimeString: String): String {
    return try {
        val dateTime = when {
            dateTimeString.contains("T") -> {
                if (dateTimeString.contains("Z") || dateTimeString.contains("+")) {
                    ZonedDateTime.parse(dateTimeString).toLocalDateTime()
                } else {
                    LocalDateTime.parse(dateTimeString)
                }
            }
            else -> LocalDateTime.parse(dateTimeString.replace(" ", "T"))
        }
        
        val now = LocalDateTime.now()
        val daysBetween = ChronoUnit.DAYS.between(dateTime.toLocalDate(), now.toLocalDate())
        
        when {
            daysBetween == 0L -> "Today ${dateTime.format(DateTimeFormatter.ofPattern("HH:mm"))}"
            daysBetween == 1L -> "Yesterday ${dateTime.format(DateTimeFormatter.ofPattern("HH:mm"))}"
            daysBetween < 7L -> dateTime.format(DateTimeFormatter.ofPattern("EEEE HH:mm"))
            else -> dateTime.format(DateTimeFormatter.ofPattern("MMM dd, yyyy HH:mm"))
        }
    } catch (e: Exception) {
        dateTimeString.split('T').firstOrNull() ?: dateTimeString
    }
}