package com.guitaripod.pixie.data.purchases

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.util.concurrent.atomic.AtomicBoolean

/** What one purchase came to. */
sealed interface PurchaseOutcome {
    data class Credited(val productId: String, val purchaseId: String, val creditsAdded: Int, val newBalance: Int) : PurchaseOutcome

    /** mako had credited it before; it is consumed now. */
    data class AlreadyCredited(val productId: String) : PurchaseOutcome

    /** Google Play is still waiting for the payment (cash, bank transfer); it is credited once Play reports it paid. */
    data class AwaitingPayment(val productId: String) : PurchaseOutcome

    /** Paid but not credited yet; the purchase is kept and asked about again. */
    data class Pending(val productId: String, val reason: String) : PurchaseOutcome

    /** mako will never credit it; it is left unconsumed, so Google refunds it after three days. */
    data class Refused(val productId: String, val message: String) : PurchaseOutcome
    data object Cancelled : PurchaseOutcome
    data class Failed(val message: String) : PurchaseOutcome
}

/**
 * Sells credit packs through Google Play and has mako credit them. A purchase is consumed only after mako answered
 * that it is credited (now or before); while mako cannot credit it yet, the purchase stays unconsumed and is offered
 * to mako again: after each of [retryDelaysMillis], whenever Play reports purchases, at [start] (launch with a
 * signed-in user, or the sign-in) and at every [refresh] (each time the credit packs screen opens). Google refunds a
 * purchase that is never consumed or acknowledged after three days, so a purchase mako never credits costs the buyer
 * nothing.
 */
class PlayBillingManager(
    private val store: PlayStore,
    private val validator: PurchaseValidator,
    private val scope: CoroutineScope,
    private val accountId: () -> String?,
    private val connectDelaysMillis: List<Long> = CONNECT_DELAYS_MILLIS,
    private val retryDelaysMillis: List<Long> = RETRY_DELAYS_MILLIS
) {
    private val settling = Mutex()
    private val settled = mutableSetOf<String>()
    private val started = AtomicBoolean(false)
    private val announced = MutableSharedFlow<PurchaseOutcome>(extraBufferCapacity = 16)
    private var retryJob: Job? = null

    /** Outcomes of purchases settled outside [purchase]: on start, from Play's updates and by the retries. */
    val outcomes: SharedFlow<PurchaseOutcome> = announced.asSharedFlow()

    /**
     * Starts handling purchases Play reports outside a purchase sheet (the store keeps them until then) and credits
     * what earlier runs left. Call it once a user is signed in; later calls do nothing.
     */
    fun start() {
        if (!started.compareAndSet(false, true)) {
            return
        }
        scope.launch { store.updates.collect { purchases -> settle(purchases, announce = true) } }
        scope.launch { reconcile() }
    }

    /**
     * Reconciles in the background, announcing what it credits on [outcomes], so a purchase whose retries ran out is
     * settled as soon as the user looks at their credits. Before [start] there is no signed-in user, and it does nothing.
     */
    fun refresh() {
        if (started.get()) {
            scope.launch { reconcile() }
        }
    }

    /** Connects to Play, asking again after each of [connectDelaysMillis] while the failure is one a retry can fix. */
    suspend fun connect(): Connection {
        var connection = store.connect()
        for (pause in connectDelaysMillis) {
            if (connection !is Connection.Unavailable || !connection.retryable) {
                return connection
            }
            delay(pause)
            connection = store.connect()
        }
        return connection
    }

    /** The Play product of every pack Play sells to this user, by pack id. Empty when Play cannot be reached. */
    suspend fun products(packIds: List<String>): Map<String, StoreProduct> {
        if (connect() !is Connection.Ready) {
            return emptyMap()
        }
        val listed = store.products(packIds.map(::productIdOf)) ?: return emptyMap()
        return listed.mapNotNull { product -> packIdOf(product.productId)?.let { packId -> packId to product } }.toMap()
    }

    /** Buys one pack: shows Play's sheet for the signed-in account, then settles what Play reports. */
    suspend fun purchase(packId: String, launcher: PurchaseLauncher): PurchaseOutcome {
        val account = accountId()?.takeIf { it.isNotBlank() } ?: return PurchaseOutcome.Failed(SIGN_IN_MESSAGE)
        val connection = connect()
        if (connection is Connection.Unavailable) {
            return PurchaseOutcome.Failed(connection.message)
        }
        val productId = productIdOf(packId)
        return when (val flow = launcher.launch(productId, account)) {
            is FlowOutcome.Purchased -> outcomeFor(productId, settle(flow.purchases, announce = false))
                ?: PurchaseOutcome.Failed(NO_PURCHASE_MESSAGE)
            FlowOutcome.Cancelled -> PurchaseOutcome.Cancelled
            FlowOutcome.AlreadyOwned -> outcomeFor(productId, reconcile(announce = false))
                ?: PurchaseOutcome.Pending(productId, "Play reports the pack owned but listed no purchase of it")
            is FlowOutcome.Failed -> PurchaseOutcome.Failed(flow.message)
        }
    }

    /**
     * Settles every pack purchase the user owns and has not consumed: a credit that stayed pending, a consume that
     * never ran, a purchase made while the app was closed. Returns their outcomes, and also sends them to [outcomes]
     * when [announce] is set; empty when Play cannot be reached.
     */
    suspend fun reconcile(announce: Boolean = true): List<PurchaseOutcome> {
        if (connect() !is Connection.Ready) {
            return emptyList()
        }
        val owned = store.purchases() ?: return emptyList()
        return settle(owned, announce)
    }

    /** Settles purchases one at a time, so a purchase reported twice at once is offered to mako once. */
    private suspend fun settle(purchases: List<StorePurchase>, announce: Boolean): List<PurchaseOutcome> {
        val results = purchases.mapNotNull { purchase -> settling.withLock { settleOne(purchase) } }
        if (announce) {
            results.forEach { announced.tryEmit(it.outcome) }
        }
        if (results.any { !it.finished }) {
            scheduleRetry()
        }
        return results.map { it.outcome }
    }

    private class Settled(val outcome: PurchaseOutcome, val finished: Boolean)

    private suspend fun settleOne(purchase: StorePurchase): Settled? {
        if (purchase.purchaseToken in settled) {
            return null
        }
        val productId = purchase.productIds.firstOrNull() ?: return null
        val packId = packIdOf(productId) ?: return null
        return when (purchase.state) {
            StorePurchaseState.PENDING -> Settled(PurchaseOutcome.AwaitingPayment(productId), finished = true)
            StorePurchaseState.UNSPECIFIED -> null
            StorePurchaseState.PURCHASED -> credit(purchase, packId, productId)
        }
    }

    private suspend fun credit(purchase: StorePurchase, packId: String, productId: String): Settled {
        val request = PurchaseValidationRequest(
            packId = packId,
            purchaseToken = purchase.purchaseToken,
            productId = productId,
            playOrderId = purchase.orderId
        )
        return when (val validation = validator.validate(request)) {
            is Validation.Credited -> Settled(
                PurchaseOutcome.Credited(productId, validation.purchaseId, validation.creditsAdded, validation.newBalance),
                finished = consume(purchase)
            )
            Validation.AlreadyProcessed -> Settled(PurchaseOutcome.AlreadyCredited(productId), finished = consume(purchase))
            is Validation.Pending -> Settled(PurchaseOutcome.Pending(productId, validation.reason), finished = false)
            is Validation.Refused -> {
                settled += purchase.purchaseToken
                Settled(PurchaseOutcome.Refused(productId, validation.message), finished = true)
            }
        }
    }

    /** Consumes a credited purchase. One Play would not consume is left for a retry, which mako answers `already_processed`. */
    private suspend fun consume(purchase: StorePurchase): Boolean {
        val consumed = store.consume(purchase.purchaseToken)
        if (consumed) {
            settled += purchase.purchaseToken
        }
        return consumed
    }

    /** Reconciles after each of [retryDelaysMillis] until nothing is left unsettled. One retry runs at a time. */
    private fun scheduleRetry() {
        synchronized(this) {
            if (retryJob?.isActive == true || retryDelaysMillis.isEmpty()) {
                return
            }
            retryJob = scope.launch {
                for (pause in retryDelaysMillis) {
                    delay(pause)
                    if (retryUntilSettled()) {
                        return@launch
                    }
                }
            }
        }
    }

    /** One retry round; true once every owned pack purchase is settled. */
    private suspend fun retryUntilSettled(): Boolean {
        if (connect() !is Connection.Ready) {
            return false
        }
        val owned = store.purchases() ?: return false
        val results = owned.mapNotNull { purchase -> settling.withLock { settleOne(purchase) } }
        results.forEach { announced.tryEmit(it.outcome) }
        return results.all { it.finished }
    }

    private fun outcomeFor(productId: String, outcomes: List<PurchaseOutcome>): PurchaseOutcome? =
        outcomes.firstOrNull { productOf(it) == productId } ?: outcomes.firstOrNull()

    private fun productOf(outcome: PurchaseOutcome): String? = when (outcome) {
        is PurchaseOutcome.Credited -> outcome.productId
        is PurchaseOutcome.AlreadyCredited -> outcome.productId
        is PurchaseOutcome.AwaitingPayment -> outcome.productId
        is PurchaseOutcome.Pending -> outcome.productId
        is PurchaseOutcome.Refused -> outcome.productId
        PurchaseOutcome.Cancelled, is PurchaseOutcome.Failed -> null
    }

    companion object {
        val CONNECT_DELAYS_MILLIS = listOf(1_000L, 2_000L, 4_000L)
        val RETRY_DELAYS_MILLIS = listOf(5_000L, 30_000L, 120_000L, 600_000L)
        const val SIGN_IN_MESSAGE = "Sign in to buy credits."
        const val NO_PURCHASE_MESSAGE = "Google Play reported no purchase."
    }
}
