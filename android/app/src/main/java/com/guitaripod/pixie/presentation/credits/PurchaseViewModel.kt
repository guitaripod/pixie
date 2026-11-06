package com.guitaripod.pixie.presentation.credits

import android.app.Activity
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.guitaripod.pixie.data.purchases.CreditPackWithPrice
import com.guitaripod.pixie.data.purchases.CreditPurchaseManager
import com.guitaripod.pixie.data.purchases.CreditPurchaseResult
import com.guitaripod.pixie.data.purchases.PurchaseOutcome
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** A dialog the credit packs screen shows. */
data class PurchaseMessage(val title: String, val text: String)

data class PurchaseUiState(
    val creditPacksWithPricing: List<CreditPackWithPrice> = emptyList(),
    val isLoading: Boolean = false,
    val message: PurchaseMessage? = null,
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
        observeCreditPacks()
        observeLateCredits()
    }

    private fun observeCreditPacks() {
        viewModelScope.launch {
            creditPacksWithPricing.collect { packs ->
                _uiState.update { it.copy(creditPacksWithPricing = packs) }
            }
        }
    }

    /** Shows the success dialog for a purchase that was credited after the screen had reported it pending. */
    private fun observeLateCredits() {
        viewModelScope.launch {
            purchaseManager.outcomes.collect { outcome ->
                if (outcome is PurchaseOutcome.Credited) {
                    _uiState.update { stateAfter(it, outcome) }
                }
            }
        }
    }

    fun purchaseCreditPack(activity: Activity, creditPackWithPrice: CreditPackWithPrice) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, message = null) }
            val outcome = purchaseManager.purchaseCreditPack(activity, creditPackWithPrice)
            _uiState.update { stateAfter(it.copy(isLoading = false), outcome) }
        }
    }

    fun restorePurchases() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, message = null) }
            val outcomes = purchaseManager.restorePurchases()
            _uiState.update { it.copy(isLoading = false, message = restoreMessage(outcomes)) }
        }
    }

    fun dismissSuccessDialog() {
        _uiState.update { it.copy(showSuccessDialog = false) }
    }

    fun clearMessage() {
        _uiState.update { it.copy(message = null) }
    }

    fun refreshOfferings() {
        purchaseManager.refreshOfferings()
    }

    /** Credits any pack purchase still waiting, such as one whose retries ran out while the app was in use. */
    fun reconcile() {
        purchaseManager.reconcile()
    }
}

/** The screen state after a purchase came to [outcome]. */
fun stateAfter(state: PurchaseUiState, outcome: PurchaseOutcome): PurchaseUiState = when (outcome) {
    is PurchaseOutcome.Credited -> state.copy(
        lastPurchaseResult = CreditPurchaseResult(outcome.purchaseId, outcome.creditsAdded, outcome.newBalance, amountUsd = ""),
        showSuccessDialog = true,
        message = null
    )
    is PurchaseOutcome.AlreadyCredited -> state.copy(
        message = PurchaseMessage("Purchase complete", "This pack was already added to your credits.")
    )
    is PurchaseOutcome.AwaitingPayment -> state.copy(
        message = PurchaseMessage("Payment pending", "Google Play is waiting for your payment. Your credits are added as soon as it completes.")
    )
    is PurchaseOutcome.Pending -> state.copy(
        message = PurchaseMessage("Purchase received", "Your payment went through. Your credits are being added and will appear shortly.")
    )
    is PurchaseOutcome.Refused -> state.copy(
        message = PurchaseMessage("Purchase not credited", "${outcome.message} Google Play refunds a purchase that is not credited within three days.")
    )
    PurchaseOutcome.Cancelled -> state
    is PurchaseOutcome.Failed -> state.copy(message = PurchaseMessage("Purchase error", outcome.message))
}

/** What restoring came to, in one dialog: the credits added, then anything still waiting, refused or failed. */
fun restoreMessage(outcomes: List<PurchaseOutcome>): PurchaseMessage {
    val credited = outcomes.filterIsInstance<PurchaseOutcome.Credited>()
    val waiting = outcomes.count { it is PurchaseOutcome.Pending || it is PurchaseOutcome.AwaitingPayment }
    val refused = outcomes.filterIsInstance<PurchaseOutcome.Refused>()
    val lines = buildList {
        if (credited.isNotEmpty()) {
            add("Added ${credited.sumOf { it.creditsAdded }} credits from ${purchasesText(credited.size)}.")
        }
        if (waiting > 0) {
            val verb = if (waiting == 1) "is" else "are"
            add("${purchasesText(waiting)} $verb still being confirmed; the credits are added automatically.")
        }
        refused.forEach { add(it.message) }
        outcomes.filterIsInstance<PurchaseOutcome.Failed>().forEach { add(it.message) }
    }
    val text = lines.joinToString("\n\n").ifEmpty { "No purchases are waiting to be credited." }
    return PurchaseMessage("Restore purchases", text)
}

private fun purchasesText(count: Int): String = if (count == 1) "1 purchase" else "$count purchases"
