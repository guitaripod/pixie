package com.guitaripod.pixie.data.purchases

import android.app.Activity
import android.content.Context
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClient.BillingResponseCode
import com.android.billingclient.api.BillingClient.ProductType
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.ConsumeParams
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.util.concurrent.ConcurrentHashMap
import kotlin.coroutines.resume

/** [PlayStore] over Google Play Billing Library: one-time products, pending purchases on, reconnecting by itself. */
class GooglePlayStore(context: Context) : PlayStore, PurchasesUpdatedListener {
    private val reported = MutableSharedFlow<List<StorePurchase>>(extraBufferCapacity = 8)
    private val details = ConcurrentHashMap<String, ProductDetails>()
    private val connecting = Mutex()
    private val sheetLock = Any()
    private var sheet: CompletableDeferred<FlowOutcome>? = null

    private val client: BillingClient = BillingClient.newBuilder(context.applicationContext)
        .setListener(this)
        .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
        .enableAutoServiceReconnection()
        .build()

    override val updates: Flow<List<StorePurchase>> = reported.asSharedFlow()

    /** A launcher that shows Play's purchase sheet over [activity]. */
    fun launcher(activity: Activity): PurchaseLauncher = PurchaseLauncher { productId, accountId ->
        launch(activity, productId, accountId)
    }

    override suspend fun connect(): Connection = connecting.withLock {
        if (client.isReady) {
            return@withLock Connection.Ready
        }
        suspendCancellableCoroutine<Connection> { continuation ->
            client.startConnection(object : BillingClientStateListener {
                override fun onBillingSetupFinished(result: BillingResult) {
                    if (continuation.isActive) {
                        continuation.resume(connectionOf(result))
                    }
                }

                override fun onBillingServiceDisconnected() {
                    if (continuation.isActive) {
                        continuation.resume(Connection.Unavailable(UNREACHABLE_MESSAGE, retryable = true))
                    }
                }
            })
        }
    }

    override suspend fun products(productIds: List<String>): List<StoreProduct>? {
        if (productIds.isEmpty()) {
            return emptyList()
        }
        val params = QueryProductDetailsParams.newBuilder()
            .setProductList(productIds.map { id ->
                QueryProductDetailsParams.Product.newBuilder().setProductId(id).setProductType(ProductType.INAPP).build()
            })
            .build()
        val listed = suspendCancellableCoroutine<List<ProductDetails>?> { continuation ->
            client.queryProductDetailsAsync(params) { result, found ->
                continuation.resume(if (result.responseCode == BillingResponseCode.OK) found.productDetailsList else null)
            }
        } ?: return null
        return listed.mapNotNull { product ->
            val offer = offerOf(product) ?: return@mapNotNull null
            details[product.productId] = product
            StoreProduct(product.productId, offer.formattedPrice)
        }
    }

    override suspend fun purchases(): List<StorePurchase>? {
        val params = QueryPurchasesParams.newBuilder().setProductType(ProductType.INAPP).build()
        return suspendCancellableCoroutine { continuation ->
            client.queryPurchasesAsync(params) { result, purchases ->
                continuation.resume(if (result.responseCode == BillingResponseCode.OK) purchases.map(::storePurchaseOf) else null)
            }
        }
    }

    override suspend fun consume(purchaseToken: String): Boolean {
        val params = ConsumeParams.newBuilder().setPurchaseToken(purchaseToken).build()
        return suspendCancellableCoroutine { continuation ->
            client.consumeAsync(params) { result, _ ->
                continuation.resume(result.responseCode == BillingResponseCode.OK || result.responseCode == BillingResponseCode.ITEM_NOT_OWNED)
            }
        }
    }

    /** Routes Play's report to the sheet that is waiting for it, or to [updates] when no sheet is open. */
    override fun onPurchasesUpdated(result: BillingResult, purchases: MutableList<Purchase>?) {
        val outcome = flowOutcomeOf(result, purchases)
        val waiting = synchronized(sheetLock) { sheet.also { sheet = null } }
        when {
            waiting != null -> waiting.complete(outcome)
            outcome is FlowOutcome.Purchased -> reported.tryEmit(outcome.purchases)
        }
    }

    /** Shows the sheet for a product and waits for Play's report of it. */
    private suspend fun launch(activity: Activity, productId: String, accountId: String): FlowOutcome {
        val product = details[productId] ?: products(listOf(productId)).let { details[productId] }
            ?: return FlowOutcome.Failed(UNAVAILABLE_PACK_MESSAGE)
        val productParams = BillingFlowParams.ProductDetailsParams.newBuilder().setProductDetails(product)
        offerOf(product)?.offerToken?.let(productParams::setOfferToken)
        val flowParams = BillingFlowParams.newBuilder().setProductDetailsParamsList(listOf(productParams.build()))
        accountId.takeIf { it.length <= MAX_ACCOUNT_ID_LENGTH }?.let(flowParams::setObfuscatedAccountId)
        val waiting = CompletableDeferred<FlowOutcome>()
        synchronized(sheetLock) {
            sheet?.complete(FlowOutcome.Failed(SUPERSEDED_MESSAGE))
            sheet = waiting
        }
        val launched = withContext(Dispatchers.Main) { client.launchBillingFlow(activity, flowParams.build()) }
        if (launched.responseCode != BillingResponseCode.OK) {
            synchronized(sheetLock) {
                if (sheet === waiting) {
                    sheet = null
                }
            }
            return flowOutcomeOf(launched, null)
        }
        return waiting.await()
    }

    /** The purchase option a pack is sold with: the product's default one-time offer. */
    private fun offerOf(product: ProductDetails): ProductDetails.OneTimePurchaseOfferDetails? =
        product.oneTimePurchaseOfferDetails ?: product.oneTimePurchaseOfferDetailsList?.firstOrNull()

    private fun storePurchaseOf(purchase: Purchase): StorePurchase = StorePurchase(
        purchaseToken = purchase.purchaseToken,
        productIds = purchase.products,
        orderId = purchase.orderId?.takeIf { it.isNotBlank() },
        state = when (purchase.purchaseState) {
            Purchase.PurchaseState.PURCHASED -> StorePurchaseState.PURCHASED
            Purchase.PurchaseState.PENDING -> StorePurchaseState.PENDING
            else -> StorePurchaseState.UNSPECIFIED
        }
    )

    private fun flowOutcomeOf(result: BillingResult, purchases: List<Purchase>?): FlowOutcome = when (result.responseCode) {
        BillingResponseCode.OK -> purchases?.takeIf { it.isNotEmpty() }?.let { FlowOutcome.Purchased(it.map(::storePurchaseOf)) }
            ?: FlowOutcome.Failed(PlayBillingManager.NO_PURCHASE_MESSAGE)
        BillingResponseCode.USER_CANCELED -> FlowOutcome.Cancelled
        BillingResponseCode.ITEM_ALREADY_OWNED -> FlowOutcome.AlreadyOwned
        else -> FlowOutcome.Failed(messageOf(result))
    }

    private fun connectionOf(result: BillingResult): Connection = when (result.responseCode) {
        BillingResponseCode.OK -> Connection.Ready
        BillingResponseCode.BILLING_UNAVAILABLE,
        BillingResponseCode.FEATURE_NOT_SUPPORTED,
        BillingResponseCode.DEVELOPER_ERROR -> Connection.Unavailable(messageOf(result), retryable = false)
        else -> Connection.Unavailable(messageOf(result), retryable = true)
    }

    private fun messageOf(result: BillingResult): String = when (result.responseCode) {
        BillingResponseCode.BILLING_UNAVAILABLE -> "Google Play billing is not available on this device or account."
        BillingResponseCode.ITEM_UNAVAILABLE -> UNAVAILABLE_PACK_MESSAGE
        BillingResponseCode.SERVICE_UNAVAILABLE,
        BillingResponseCode.SERVICE_DISCONNECTED,
        BillingResponseCode.NETWORK_ERROR -> UNREACHABLE_MESSAGE
        else -> "Google Play could not complete the purchase (code ${result.responseCode})."
    }

    private companion object {
        const val MAX_ACCOUNT_ID_LENGTH = 64
        const val UNREACHABLE_MESSAGE = "Could not reach Google Play. Check your connection and try again."
        const val UNAVAILABLE_PACK_MESSAGE = "This pack is not available on Google Play right now."
        const val SUPERSEDED_MESSAGE = "Another purchase was started."
    }
}
