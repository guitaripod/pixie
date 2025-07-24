package com.guitaripod.pixie.presentation.credits

import android.app.Activity
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.guitaripod.pixie.data.purchases.*
import com.revenuecat.purchases.Package
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

data class PurchaseUiState(
    val creditPacksWithPricing: List<CreditPackWithPrice> = emptyList(),
    val purchaseState: PurchaseState = PurchaseState.Idle,
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
    val lastPurchaseResult: CreditPurchaseResult? = null,
    val showSuccessDialog: Boolean = false
)

class PurchaseViewModel(
    private val purchaseManager: CreditPurchaseManager
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(PurchaseUiState())
    val uiState: StateFlow<PurchaseUiState> = _uiState.asStateFlow()
    
    val creditPacksWithPricing = purchaseManager.getCreditPacksWithPricing()
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5000),
            initialValue = emptyList()
        )
    
    init {
        observePurchaseState()
        observeCreditPacks()
    }
    
    private fun observePurchaseState() {
        viewModelScope.launch {
            purchaseManager.purchaseState.collect { state ->
                _uiState.update { it.copy(purchaseState = state) }
            }
        }
    }
    
    private fun observeCreditPacks() {
        viewModelScope.launch {
            creditPacksWithPricing.collect { packs ->
                _uiState.update { it.copy(creditPacksWithPricing = packs) }
            }
        }
    }
    
    fun purchaseCreditPack(activity: Activity, creditPackWithPrice: CreditPackWithPrice) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, errorMessage = null) }
            
            purchaseManager.purchaseCreditPack(activity, creditPackWithPrice.rcPackage)
                .fold(
                    onSuccess = { result ->
                        _uiState.update { 
                            it.copy(
                                isLoading = false,
                                lastPurchaseResult = result,
                                showSuccessDialog = true,
                                errorMessage = null
                            )
                        }
                    },
                    onFailure = { error ->
                        val errorMessage = when (error) {
                            is PurchaseCancelledException -> null
                            else -> error.message ?: "Purchase failed"
                        }
                        
                        _uiState.update { 
                            it.copy(
                                isLoading = false,
                                errorMessage = errorMessage
                            )
                        }
                    }
                )
        }
    }
    
    fun restorePurchases() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, errorMessage = null) }
            
            purchaseManager.restorePurchases()
                .fold(
                    onSuccess = { restoredPurchases ->
                        val message = if (restoredPurchases.isEmpty()) {
                            "No purchases to restore"
                        } else {
                            "Restored ${restoredPurchases.size} purchase(s)"
                        }
                        
                        _uiState.update { 
                            it.copy(
                                isLoading = false,
                                errorMessage = message
                            )
                        }
                    },
                    onFailure = { error ->
                        _uiState.update { 
                            it.copy(
                                isLoading = false,
                                errorMessage = error.message ?: "Restore failed"
                            )
                        }
                    }
                )
        }
    }
    
    fun dismissSuccessDialog() {
        _uiState.update { it.copy(showSuccessDialog = false) }
        purchaseManager.resetPurchaseState()
    }
    
    fun clearError() {
        _uiState.update { it.copy(errorMessage = null) }
    }
}