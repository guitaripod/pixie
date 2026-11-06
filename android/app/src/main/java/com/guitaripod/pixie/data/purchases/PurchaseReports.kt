package com.guitaripod.pixie.data.purchases

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.receiveAsFlow

/**
 * Routes Play's purchase reports. A report goes to the purchase sheet waiting for it; every other one (no sheet open,
 * or a sheet whose caller is gone, such as a screen closed while Play's sheet was up) goes to [updates], which keeps
 * them until [PlayBillingManager] collects, so no paid purchase is dropped before billing starts.
 */
class PurchaseReports {
    private val lock = Any()
    private var sheet: CompletableDeferred<FlowOutcome>? = null
    private val unclaimed = Channel<List<StorePurchase>>(Channel.UNLIMITED)

    /** Purchases no sheet took, buffered for the one collector. */
    val updates: Flow<List<StorePurchase>> = unclaimed.receiveAsFlow()

    /** Opens the sheet that the next report goes to. A sheet still open is told it was superseded. */
    fun open(): CompletableDeferred<FlowOutcome> = synchronized(lock) {
        sheet?.complete(FlowOutcome.Failed(SUPERSEDED_MESSAGE))
        CompletableDeferred<FlowOutcome>().also { sheet = it }
    }

    /** Closes a sheet that never showed (Play refused to launch it). */
    fun close(waiting: CompletableDeferred<FlowOutcome>) {
        synchronized(lock) {
            if (sheet === waiting) {
                sheet = null
            }
        }
    }

    /**
     * Waits for the report of [waiting]. When the caller is cancelled first, the sheet is abandoned: a report that
     * arrives later, or that arrived just as the caller went away, goes to [updates] instead of being lost.
     */
    suspend fun await(waiting: CompletableDeferred<FlowOutcome>): FlowOutcome =
        try {
            waiting.await()
        } catch (cancelled: CancellationException) {
            abandon(waiting)
            throw cancelled
        } finally {
            close(waiting)
        }

    /** Hands Play's report to the open sheet, or to [updates] when no live sheet takes it. */
    fun report(outcome: FlowOutcome) {
        val waiting = synchronized(lock) { sheet.also { sheet = null } }
        val taken = waiting?.complete(outcome) ?: false
        if (!taken && outcome is FlowOutcome.Purchased) {
            unclaimed.trySend(outcome.purchases)
        }
    }

    /**
     * Marks a sheet nobody waits for any more. Exactly one of this and [report] completes the deferred: if the report
     * won, its purchases are forwarded here; if this won, [report]'s `complete` fails and it forwards them itself.
     */
    @OptIn(ExperimentalCoroutinesApi::class)
    private fun abandon(waiting: CompletableDeferred<FlowOutcome>) {
        if (waiting.completeExceptionally(CancellationException(ABANDONED_MESSAGE))) {
            return
        }
        val reported = runCatching { waiting.getCompleted() }.getOrNull()
        if (reported is FlowOutcome.Purchased) {
            unclaimed.trySend(reported.purchases)
        }
    }

    private companion object {
        const val SUPERSEDED_MESSAGE = "Another purchase was started."
        const val ABANDONED_MESSAGE = "The purchase sheet's caller is gone."
    }
}
