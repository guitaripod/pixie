package com.guitaripod.pixie.presentation.credits

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.guitaripod.pixie.data.purchases.CreditPurchaseManager

class PurchaseViewModelFactory(
    private val purchaseManager: CreditPurchaseManager
) : ViewModelProvider.Factory {
    
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(PurchaseViewModel::class.java)) {
            return PurchaseViewModel(purchaseManager) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class")
    }
}