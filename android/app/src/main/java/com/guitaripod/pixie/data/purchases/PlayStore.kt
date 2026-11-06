package com.guitaripod.pixie.data.purchases

import kotlinx.coroutines.flow.Flow

/** The Play product id prefix of PixiePocket's credit packs; the pack id follows it. */
const val PACK_PRODUCT_PREFIX = "com.guitaripod.pixie.credits."

/** The Play product id of a credit pack. */
fun productIdOf(packId: String): String = PACK_PRODUCT_PREFIX + packId

/** The credit pack a Play product id names, or null for any other product. */
fun packIdOf(productId: String): String? =
    productId.removePrefix(PACK_PRODUCT_PREFIX).takeIf { productId.startsWith(PACK_PRODUCT_PREFIX) && it.isNotEmpty() }

/** A pack product as Google Play lists it to this user. */
data class StoreProduct(
    val productId: String,
    val formattedPrice: String
)

/** Where a store purchase stands with Google Play. */
enum class StorePurchaseState {
    PURCHASED,
    PENDING,
    UNSPECIFIED
}

/** A purchase as Google Play reports it, before mako has credited it. */
data class StorePurchase(
    val purchaseToken: String,
    val productIds: List<String>,
    val orderId: String?,
    val state: StorePurchaseState
)

/** Whether the billing service can be used right now. */
sealed interface Connection {
    data object Ready : Connection

    /** [retryable] is false when asking again cannot help, such as a device without Google Play. */
    data class Unavailable(val message: String, val retryable: Boolean) : Connection
}

/** What the Play purchase sheet ended with. */
sealed interface FlowOutcome {
    data class Purchased(val purchases: List<StorePurchase>) : FlowOutcome
    data object Cancelled : FlowOutcome

    /** The user still owns an unconsumed purchase of this pack, which reconciling credits and consumes. */
    data object AlreadyOwned : FlowOutcome
    data class Failed(val message: String) : FlowOutcome
}

/** Google Play's billing service, as [PlayBillingManager] uses it. The real one is [GooglePlayStore]. */
interface PlayStore {
    /** Purchases Play reports outside a purchase sheet, such as a pending payment that completed later. */
    val updates: Flow<List<StorePurchase>>

    suspend fun connect(): Connection

    /** The products Play knows of among [productIds]; null when Play could not be asked. */
    suspend fun products(productIds: List<String>): List<StoreProduct>?

    /** Every one-time purchase the user owns and has not consumed; null when Play could not be asked. */
    suspend fun purchases(): List<StorePurchase>?

    /** Consumes a purchase so the pack can be bought again. True once Play confirmed it. */
    suspend fun consume(purchaseToken: String): Boolean
}

/**
 * Shows the Play purchase sheet for one product, tied to the caller's mako account. The real one captures the
 * Activity the sheet needs (`GooglePlayStore.launcher`).
 */
fun interface PurchaseLauncher {
    suspend fun launch(productId: String, accountId: String): FlowOutcome
}
