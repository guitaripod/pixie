package com.guitaripod.pixie.data.purchases

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.take
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.withTimeoutOrNull
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class PurchaseReportsTest {
    private val reports = PurchaseReports()
    private val paid = FlowOutcome.Purchased(listOf(StorePurchase("t1", listOf("com.guitaripod.pixie.credits.starter"), "GPA.1", StorePurchaseState.PURCHASED)))
    private val later = FlowOutcome.Purchased(listOf(StorePurchase("t2", listOf("com.guitaripod.pixie.credits.popular"), "GPA.2", StorePurchaseState.PURCHASED)))

    private suspend fun nextUpdate(): List<StorePurchase>? = withTimeoutOrNull(1_000L) { reports.updates.first() }

    @Test
    fun aReportGoesToTheOpenSheet() = runTest {
        val waiting = reports.open()
        val outcome = async { reports.await(waiting) }
        runCurrent()
        reports.report(paid)
        assertEquals(paid, outcome.await())
        assertNull("the sheet took it", nextUpdate())
    }

    @Test
    fun reportsBeforeAnyoneCollectsAreKeptInOrder() = runTest {
        reports.report(paid)
        reports.report(FlowOutcome.Cancelled)
        reports.report(later)
        assertEquals(listOf(paid.purchases, later.purchases), reports.updates.take(2).toList())
    }

    @Test
    fun aReportAfterTheCallerWentAwayIsNotLost() = runTest {
        val waiting = reports.open()
        val caller = launch { reports.await(waiting) }
        runCurrent()
        caller.cancel()
        runCurrent()
        reports.report(paid)
        assertEquals(paid.purchases, nextUpdate())
    }

    @Test
    fun aReportThatArrivesAsTheCallerGoesAwayIsForwarded() = runTest {
        val waiting = reports.open()
        val caller = launch { reports.await(waiting) }
        runCurrent()
        reports.report(paid)
        caller.cancel()
        runCurrent()
        assertTrue(caller.isCancelled)
        assertEquals(paid.purchases, nextUpdate())
    }

    @Test
    fun aCancelledSheetForwardsNothing() = runTest {
        val waiting = reports.open()
        val caller = launch { reports.await(waiting) }
        runCurrent()
        caller.cancel()
        runCurrent()
        reports.report(FlowOutcome.Cancelled)
        assertNull(nextUpdate())
    }

    @Test
    fun aSecondSheetSupersedesTheFirst() = runTest {
        val first = reports.open()
        val firstOutcome = async { reports.await(first) }
        runCurrent()
        val second = reports.open()
        val secondOutcome = async { reports.await(second) }
        runCurrent()
        reports.report(paid)
        assertTrue(firstOutcome.await() is FlowOutcome.Failed)
        assertEquals(paid, secondOutcome.await())
    }

    @Test
    fun aSheetThatNeverShowedLeavesReportsToTheUpdates() = runTest {
        val waiting = reports.open()
        reports.close(waiting)
        reports.report(paid)
        assertEquals(paid.purchases, nextUpdate())
    }
}
