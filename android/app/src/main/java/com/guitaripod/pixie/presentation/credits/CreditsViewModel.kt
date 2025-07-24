package com.guitaripod.pixie.presentation.credits

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.guitaripod.pixie.data.api.model.*
import com.guitaripod.pixie.data.repository.CreditsRepository
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.format.DateTimeFormatter

data class CreditsUiState(
    val balance: CreditBalance? = null,
    val transactions: List<CreditTransaction> = emptyList(),
    val creditPacks: List<CreditPack> = emptyList(),
    val isLoadingBalance: Boolean = false,
    val isLoadingTransactions: Boolean = false,
    val isLoadingPacks: Boolean = false,
    val errorMessage: String? = null,
    val hasMoreTransactions: Boolean = true,
    val estimatedCredits: CreditEstimateResponse? = null,
    val selectedDateRange: DateRange = DateRange.LAST_30_DAYS,
    val usageData: UsageResponse? = null,
    val selectedView: UsageView = UsageView.DAILY
)

enum class DateRange(val displayName: String) {
    TODAY("Today"),
    LAST_7_DAYS("Last 7 days"),
    LAST_30_DAYS("Last 30 days"),
    LAST_90_DAYS("Last 90 days"),
    CUSTOM("Custom")
}

enum class UsageView(val displayName: String) {
    DAILY("Daily"),
    WEEKLY("Weekly"),
    MONTHLY("Monthly")
}

class CreditsViewModel(
    private val repository: CreditsRepository
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(CreditsUiState())
    val uiState: StateFlow<CreditsUiState> = _uiState.asStateFlow()
    
    private var currentTransactionLimit = 20
    
    init {
        loadInitialData()
    }
    
    private fun loadInitialData() {
        loadBalance()
        loadTransactions()
        loadCreditPacks()
        loadUsageData()
    }
    
    fun refresh() {
        loadInitialData()
    }
    
    fun loadBalance() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoadingBalance = true) }
            
            repository.getCreditBalance().fold(
                onSuccess = { balance ->
                    _uiState.update { 
                        it.copy(
                            balance = balance,
                            isLoadingBalance = false,
                            errorMessage = null
                        )
                    }
                },
                onFailure = { error ->
                    _uiState.update { 
                        it.copy(
                            isLoadingBalance = false,
                            errorMessage = error.message
                        )
                    }
                }
            )
        }
    }
    
    fun loadTransactions(loadMore: Boolean = false) {
        viewModelScope.launch {
            if (loadMore) {
                currentTransactionLimit += 20
            } else {
                currentTransactionLimit = 20
            }
            
            _uiState.update { it.copy(isLoadingTransactions = true) }
            
            repository.getCreditTransactions(currentTransactionLimit).fold(
                onSuccess = { response ->
                    _uiState.update { 
                        it.copy(
                            transactions = response.transactions,
                            isLoadingTransactions = false,
                            hasMoreTransactions = response.transactions.size < response.total,
                            errorMessage = null
                        )
                    }
                },
                onFailure = { error ->
                    _uiState.update { 
                        it.copy(
                            isLoadingTransactions = false,
                            errorMessage = error.message
                        )
                    }
                }
            )
        }
    }
    
    fun loadCreditPacks() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoadingPacks = true) }
            
            repository.getCreditPacks().fold(
                onSuccess = { response ->
                    _uiState.update { 
                        it.copy(
                            creditPacks = response.packs,
                            isLoadingPacks = false,
                            errorMessage = null
                        )
                    }
                },
                onFailure = { error ->
                    _uiState.update { 
                        it.copy(
                            isLoadingPacks = false,
                            errorMessage = error.message
                        )
                    }
                }
            )
        }
    }
    
    fun estimateCredits(quality: String, size: String, isEdit: Boolean = false) {
        viewModelScope.launch {
            repository.estimateCredits(quality, size, isEdit).fold(
                onSuccess = { estimate ->
                    _uiState.update { 
                        it.copy(
                            estimatedCredits = estimate,
                            errorMessage = null
                        )
                    }
                },
                onFailure = { error ->
                    _uiState.update { 
                        it.copy(
                            errorMessage = error.message
                        )
                    }
                }
            )
        }
    }
    
    fun setDateRange(dateRange: DateRange) {
        _uiState.update { it.copy(selectedDateRange = dateRange) }
        loadUsageData()
    }
    
    fun setUsageView(view: UsageView) {
        _uiState.update { it.copy(selectedView = view) }
    }
    
    private fun loadUsageData() {
        viewModelScope.launch {
            val (startDate, endDate) = getDateRangeValues(_uiState.value.selectedDateRange)
            
            repository.getUsage(startDate, endDate).fold(
                onSuccess = { usage ->
                    _uiState.update { 
                        it.copy(
                            usageData = usage,
                            errorMessage = null
                        )
                    }
                },
                onFailure = { error ->
                    _uiState.update { 
                        it.copy(
                            errorMessage = error.message
                        )
                    }
                }
            )
        }
    }
    
    private fun getDateRangeValues(dateRange: DateRange): Pair<String, String> {
        val formatter = DateTimeFormatter.ISO_LOCAL_DATE
        val endDate = LocalDate.now()
        
        val startDate = when (dateRange) {
            DateRange.TODAY -> endDate
            DateRange.LAST_7_DAYS -> endDate.minusDays(6)
            DateRange.LAST_30_DAYS -> endDate.minusDays(29)
            DateRange.LAST_90_DAYS -> endDate.minusDays(89)
            DateRange.CUSTOM -> endDate.minusDays(29)
        }
        
        return Pair(
            startDate.format(formatter),
            endDate.format(formatter)
        )
    }
    
    fun clearError() {
        _uiState.update { it.copy(errorMessage = null) }
    }
}