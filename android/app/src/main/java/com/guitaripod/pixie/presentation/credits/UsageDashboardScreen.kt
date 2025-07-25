package com.guitaripod.pixie.presentation.credits

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.FileDownload
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.guitaripod.pixie.data.api.model.*
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import kotlin.math.absoluteValue

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun UsageDashboardScreen(
    viewModel: CreditsViewModel,
    onNavigateBack: () -> Unit,
    onExportCsv: () -> Unit
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Usage & Credits") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(onClick = { viewModel.refresh() }) {
                        Icon(Icons.Default.Refresh, contentDescription = "Refresh")
                    }
                    IconButton(onClick = onExportCsv) {
                        Icon(Icons.Default.FileDownload, contentDescription = "Export CSV")
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
        ) {
            CreditBalanceCard(
                balance = uiState.balance,
                isLoading = uiState.isLoadingBalance,
                modifier = Modifier.padding(16.dp)
            )
            
            DateRangeSelector(
                selectedRange = uiState.selectedDateRange,
                onRangeSelected = viewModel::setDateRange,
                modifier = Modifier.padding(horizontal = 16.dp)
            )
            
            ViewToggle(
                selectedView = uiState.selectedView,
                onViewSelected = viewModel::setUsageView,
                modifier = Modifier.padding(16.dp)
            )
            
            uiState.usageData?.let { usageData ->
                UsageChart(
                    usageData = usageData,
                    view = uiState.selectedView,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(300.dp)
                        .padding(16.dp)
                )
            }
            
            UsageBreakdown(
                transactions = uiState.transactions,
                modifier = Modifier.padding(16.dp)
            )
        }
    }
}

@Composable
fun CreditBalanceCard(
    balance: CreditBalance?,
    isLoading: Boolean,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(24.dp),
            contentAlignment = Alignment.Center
        ) {
            if (isLoading) {
                CircularProgressIndicator()
            } else if (balance != null) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text(
                        text = "💰 Current Balance",
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalAlignment = Alignment.Bottom
                    ) {
                        Text(
                            text = "${balance.balance}",
                            style = MaterialTheme.typography.displayLarge,
                            color = balance.getBalanceColor(),
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            text = "credits",
                            style = MaterialTheme.typography.titleLarge,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(bottom = 8.dp)
                        )
                    }
                    
                    when {
                        balance.balance == 0 -> {
                            Text(
                                text = "⚠️ No credits remaining!",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.error,
                                fontWeight = FontWeight.Bold,
                                modifier = Modifier.padding(top = 8.dp)
                            )
                        }
                        balance.balance < 50 -> {
                            Text(
                                text = "⚠️ Low balance warning",
                                style = MaterialTheme.typography.bodyMedium,
                                color = Color(0xFFFF9800),
                                fontWeight = FontWeight.Bold,
                                modifier = Modifier.padding(top = 8.dp)
                            )
                        }
                    }
                    
                    Spacer(modifier = Modifier.height(16.dp))
                    
                    if (balance.balance > 0) {
                        Text(
                            text = "📊 Estimated Usage:",
                            style = MaterialTheme.typography.titleSmall,
                            fontWeight = FontWeight.Bold
                        )
                        
                        Column(
                            modifier = Modifier.padding(top = 8.dp),
                            verticalArrangement = Arrangement.spacedBy(4.dp)
                        ) {
                            val lowImages = balance.balance / 5
                            val mediumImages = balance.balance / 13
                            val highImages = balance.balance / 55
                            
                            if (lowImages > 0) {
                                Row {
                                    Text("• Low quality: ", style = MaterialTheme.typography.bodyMedium)
                                    Text(
                                        "~$lowImages images",
                                        style = MaterialTheme.typography.bodyMedium,
                                        color = MaterialTheme.colorScheme.primary,
                                        fontWeight = FontWeight.Medium
                                    )
                                }
                            }
                            if (mediumImages > 0) {
                                Row {
                                    Text("• Medium quality: ", style = MaterialTheme.typography.bodyMedium)
                                    Text(
                                        "~$mediumImages images",
                                        style = MaterialTheme.typography.bodyMedium,
                                        color = MaterialTheme.colorScheme.primary,
                                        fontWeight = FontWeight.Medium
                                    )
                                }
                            }
                            if (highImages > 0) {
                                Row {
                                    Text("• High quality: ", style = MaterialTheme.typography.bodyMedium)
                                    Text(
                                        "~$highImages images",
                                        style = MaterialTheme.typography.bodyMedium,
                                        color = MaterialTheme.colorScheme.primary,
                                        fontWeight = FontWeight.Medium
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

@Composable
fun DateRangeSelector(
    selectedRange: DateRange,
    onRangeSelected: (DateRange) -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        DateRange.values().filter { it != DateRange.CUSTOM }.forEach { range ->
            FilterChip(
                selected = selectedRange == range,
                onClick = { onRangeSelected(range) },
                label = { Text(range.displayName) },
                modifier = Modifier.weight(1f)
            )
        }
    }
}

@Composable
fun ViewToggle(
    selectedView: UsageView,
    onViewSelected: (UsageView) -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        UsageView.values().forEach { view ->
            FilterChip(
                selected = selectedView == view,
                onClick = { onViewSelected(view) },
                label = { Text(view.displayName) },
                modifier = Modifier.weight(1f)
            )
        }
    }
}

@Composable
fun UsageChart(
    usageData: UsageResponse,
    view: UsageView,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier,
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            Text(
                text = "Credits Usage",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(bottom = 16.dp)
            )
            
            Canvas(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(200.dp)
            ) {
                drawUsageChart(usageData, view)
            }
        }
    }
}

fun DrawScope.drawUsageChart(usageData: UsageResponse, view: UsageView) {
    val data = when (view) {
        UsageView.DAILY -> usageData.breakdown.daily ?: emptyList()
        UsageView.WEEKLY -> aggregateToWeekly(usageData.breakdown.daily ?: emptyList())
        UsageView.MONTHLY -> aggregateToMonthly(usageData.breakdown.daily ?: emptyList())
    }
    
    if (data.isEmpty()) return
    
    val maxValue = data.maxOf { it.credits }.toFloat().coerceAtLeast(1f)
    val barWidth = size.width / (data.size * 1.5f)
    val spacing = barWidth * 0.5f
    val chartHeight = size.height * 0.8f
    
    data.forEachIndexed { index, usage ->
        val barHeight = (usage.credits / maxValue) * chartHeight
        val x = index * (barWidth + spacing) + spacing
        val y = size.height - barHeight
        
        // Draw bar
        drawRect(
            color = Color(0xFF4CAF50),
            topLeft = Offset(x, y),
            size = Size(barWidth, barHeight)
        )
        
        // Draw value on top
        drawContext.canvas.nativeCanvas.apply {
            drawText(
                usage.credits.toString(),
                x + barWidth / 2,
                y - 5,
                android.graphics.Paint().apply {
                    textSize = 24f
                    textAlign = android.graphics.Paint.Align.CENTER
                    color = android.graphics.Color.BLACK
                }
            )
        }
    }
}

@Composable
fun UsageBreakdown(
    transactions: List<CreditTransaction>,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            Text(
                text = "Usage Breakdown",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(bottom = 16.dp)
            )
            
            val breakdown = transactions
                .filter { it.transactionType == "spend" }
                .groupBy { it.description.substringBefore(" ").lowercase() }
                .mapValues { (_, transactions) -> 
                    transactions.map { it.amount.absoluteValue }.sum()
                }
            
            if (breakdown.isEmpty()) {
                Text(
                    text = "No usage data available",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(vertical = 16.dp)
                )
            } else {
                val total = breakdown.values.sum()
                
                breakdown.forEach { (type, amount) ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 8.dp),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(
                            text = type.replaceFirstChar { it.uppercase() },
                            style = MaterialTheme.typography.bodyMedium
                        )
                        Column(
                            horizontalAlignment = Alignment.End
                        ) {
                            Text(
                                text = "$amount credits",
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = FontWeight.Bold
                            )
                            Text(
                                text = "${(amount * 100 / total)}%",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                    
                    LinearProgressIndicator(
                        progress = { amount.toFloat() / total },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(8.dp)
                            .clip(RoundedCornerShape(4.dp)),
                        color = getTypeColor(type),
                    )
                }
            }
        }
    }
}

private fun getTypeColor(type: String): Color = when (type.lowercase()) {
    "generated" -> Color(0xFF4CAF50)
    "edited" -> Color(0xFF2196F3)
    "variations" -> Color(0xFFFF9800)
    else -> Color(0xFF9E9E9E)
}

private fun aggregateToWeekly(daily: List<DailyUsage>): List<DailyUsage> {
    // Simple weekly aggregation - group by week
    return daily.chunked(7).map { week ->
        DailyUsage(
            date = week.first().date,
            requests = week.sumOf { it.requests },
            credits = week.sumOf { it.credits },
            images = week.sumOf { it.images }
        )
    }
}

private fun aggregateToMonthly(daily: List<DailyUsage>): List<DailyUsage> {
    // Simple monthly aggregation - group by month
    return daily.groupBy { 
        LocalDate.parse(it.date).withDayOfMonth(1).toString()
    }.map { (date, days) ->
        DailyUsage(
            date = date,
            requests = days.sumOf { it.requests },
            credits = days.sumOf { it.credits },
            images = days.sumOf { it.images }
        )
    }.sortedBy { it.date }
}