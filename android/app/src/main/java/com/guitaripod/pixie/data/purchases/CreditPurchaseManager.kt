package com.guitaripod.pixie.data.purchases

import android.app.Activity
import android.util.Log
import com.guitaripod.pixie.data.api.PixieApiService
import com.guitaripod.pixie.data.api.model.CreditPack
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch

/**
 * The credit packs screen's view of buying credits: mako's pack list priced by Google Play, purchases through
 * [PlayBillingManager], and restoring as reconciling the purchases Play still holds.
 */
class CreditPurchaseManager(
    private val apiService: PixieApiService,
    private val store: GooglePlayStore,
    private val billing: PlayBillingManager,
    private val scope: CoroutineScope
) {
    private val backendPacks = MutableStateFlow<List<CreditPack>>(emptyList())
    private val storeProducts = MutableStateFlow<Map<String, StoreProduct>>(emptyMap())

    /** Credits that landed outside a purchase the user is watching, such as a pending one finished on a retry. */
    val outcomes: SharedFlow<PurchaseOutcome> = billing.outcomes

    /**
     * Starts the billing manager, which credits whatever an earlier run left unconsumed. Called at launch for a signed-in
     * user and after every sign-in; only the first call does anything.
     */
    fun start() {
        billing.start()
    }

    /** Every pack mako sells that Google Play also lists for this user, cheapest first, with Play's localized price. */
    fun getCreditPacksWithPricing(): Flow<List<CreditPackWithPrice>> =
        combine(backendPacks, storeProducts) { packs, products ->
            packs.mapNotNull { pack ->
                products[pack.id]?.let { product ->
                    CreditPackWithPrice(
                        creditPack = pack.copy(popular = pack.id == "popular"),
                        productId = product.productId,
                        localizedPrice = product.formattedPrice
                    )
                }
            }.sortedBy { it.creditPack.priceUsdCents }
        }

    /** Loads mako's packs and then Play's prices for them. */
    fun refreshOfferings() {
        scope.launch {
            val packs = fetchBackendPacks() ?: backendPacks.value
            backendPacks.value = packs
            if (packs.isNotEmpty()) {
                storeProducts.value = billing.products(packs.map { it.id })
            }
        }
    }

    suspend fun purchaseCreditPack(activity: Activity, pack: CreditPackWithPrice): PurchaseOutcome =
        billing.purchase(pack.creditPack.id, store.launcher(activity))

    /** Credits every pack purchase Play still holds unconsumed for this Google account; the outcomes are only returned. */
    suspend fun restorePurchases(): List<PurchaseOutcome> {
        val connection = billing.connect()
        if (connection is Connection.Unavailable) {
            return listOf(PurchaseOutcome.Failed(connection.message))
        }
        return billing.reconcile(announce = false)
    }

    private suspend fun fetchBackendPacks(): List<CreditPack>? =
        try {
            val response = apiService.getCreditPacks()
            if (response.isSuccessful) {
                response.body()?.packs
            } else {
                Log.e(TAG, "Failed to fetch credit packs: ${response.code()}")
                null
            }
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (failure: Exception) {
            Log.e(TAG, "Error fetching credit packs", failure)
            null
        }

    private companion object {
        const val TAG = "CreditPurchaseManager"
    }
}

data class CreditPurchaseResult(
    val purchaseId: String,
    val credits: Int,
    val newBalance: Int,
    val amountUsd: String
)

data class CreditPackWithPrice(
    val creditPack: CreditPack,
    val productId: String,
    val localizedPrice: String
)

data class CreditPurchaseRequest(
    val packId: String,
    val paymentProvider: String,
    val paymentId: String,
    val productId: String
)

data class CreditPurchaseResponse(
    val purchaseId: String,
    val credits: Int,
    val newBalance: Int,
    val amountUsd: String,
    val status: String
)
