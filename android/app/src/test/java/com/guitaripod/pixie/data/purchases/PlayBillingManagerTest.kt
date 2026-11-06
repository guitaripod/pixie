package com.guitaripod.pixie.data.purchases

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

private const val USER = "6f1c2a9e-1b7d-4c55-9a0e-2f4b8d3c7e11"
private const val STARTER = "com.guitaripod.pixie.credits.starter"
private const val POPULAR = "com.guitaripod.pixie.credits.popular"

private fun paid(token: String, product: String = STARTER, order: String? = "GPA.$token") =
    StorePurchase(token, listOf(product), order, StorePurchaseState.PURCHASED)

private fun credited(credits: Int = 150, balance: Int = 250) = Validation.Credited("purchase-1", credits, balance)

/** Google Play as a script: connections answered in order (then Ready), owned purchases, consumes recorded. */
private class FakeStore : PlayStore {
    val reports = MutableSharedFlow<List<StorePurchase>>()
    val connections = ArrayDeque<Connection>()
    var connects = 0
    var listed: List<StoreProduct>? = emptyList()
    var owned: MutableList<StorePurchase>? = mutableListOf()
    val consumed = mutableListOf<String>()
    var consumeWorks = true
    var purchaseQueries = 0

    override val updates = reports
    val subscribers: Int get() = reports.subscriptionCount.value

    override suspend fun connect(): Connection {
        connects++
        return connections.removeFirstOrNull() ?: Connection.Ready
    }

    override suspend fun products(productIds: List<String>): List<StoreProduct>? =
        listed?.filter { it.productId in productIds }

    override suspend fun purchases(): List<StorePurchase>? {
        purchaseQueries++
        return owned?.toList()
    }

    override suspend fun consume(purchaseToken: String): Boolean {
        if (!consumeWorks) {
            return false
        }
        consumed += purchaseToken
        owned?.removeAll { it.purchaseToken == purchaseToken }
        return true
    }
}

/** mako as a script: answers in order, then [otherwise]; records every request. */
private class FakeValidator(vararg answers: Validation) : PurchaseValidator {
    val answers = ArrayDeque(answers.toList())
    val requests = mutableListOf<PurchaseValidationRequest>()
    var otherwise: Validation = credited()

    override suspend fun validate(request: PurchaseValidationRequest): Validation {
        requests += request
        return answers.removeFirstOrNull() ?: otherwise
    }
}

/** A purchase sheet that answers [outcome] and records what it was opened for. */
private class FakeSheet(private val outcome: FlowOutcome, private val store: FakeStore? = null) : PurchaseLauncher {
    val opened = mutableListOf<Pair<String, String>>()

    override suspend fun launch(productId: String, accountId: String): FlowOutcome {
        opened += productId to accountId
        if (outcome is FlowOutcome.Purchased) {
            store?.owned?.addAll(outcome.purchases)
        }
        return outcome
    }
}

@OptIn(ExperimentalCoroutinesApi::class)
class PlayBillingManagerTest {
    private val store = FakeStore()

    private fun TestScope.manager(
        validator: PurchaseValidator,
        account: String? = USER,
        retries: List<Long> = listOf(5_000L, 30_000L)
    ) = PlayBillingManager(
        store = store,
        validator = validator,
        scope = backgroundScope,
        accountId = { account },
        connectDelaysMillis = listOf(1_000L, 2_000L, 4_000L),
        retryDelaysMillis = retries
    )

    @Test
    fun aPaidPackIsCreditedThenConsumed() = runTest {
        val validator = FakeValidator(credited())
        val sheet = FakeSheet(FlowOutcome.Purchased(listOf(paid("t1"))), store)

        val outcome = manager(validator).purchase("starter", sheet)

        assertEquals(PurchaseOutcome.Credited(STARTER, "purchase-1", 150, 250), outcome)
        assertEquals(listOf(STARTER to USER), sheet.opened)
        assertEquals(listOf(PurchaseValidationRequest("starter", "t1", STARTER, "android", "GPA.t1")), validator.requests)
        assertEquals(listOf("t1"), store.consumed)
    }

    @Test
    fun aPurchaseMakoCreditedBeforeIsConsumed() = runTest {
        val validator = FakeValidator(Validation.AlreadyProcessed)
        val outcome = manager(validator).purchase("starter", FakeSheet(FlowOutcome.Purchased(listOf(paid("t1"))), store))
        assertEquals(PurchaseOutcome.AlreadyCredited(STARTER), outcome)
        assertEquals(listOf("t1"), store.consumed)
    }

    @Test
    fun aPendingCreditKeepsThePurchaseAndARetryCreditsIt() = runTest {
        val validator = FakeValidator(Validation.Pending("credit_pending"), credited())
        val billing = manager(validator)
        val announced = mutableListOf<PurchaseOutcome>()
        backgroundScope.launch { billing.outcomes.collect { announced += it } }
        runCurrent()

        val outcome = billing.purchase("starter", FakeSheet(FlowOutcome.Purchased(listOf(paid("t1"))), store))

        assertEquals(PurchaseOutcome.Pending(STARTER, "credit_pending"), outcome)
        assertTrue("nothing is consumed before mako credits it", store.consumed.isEmpty())
        advanceTimeBy(4_999L)
        runCurrent()
        assertEquals(1, validator.requests.size)
        advanceTimeBy(1L)
        runCurrent()
        assertEquals(2, validator.requests.size)
        assertEquals(listOf("t1"), store.consumed)
        assertEquals(listOf<PurchaseOutcome>(PurchaseOutcome.Credited(STARTER, "purchase-1", 150, 250)), announced)
    }

    @Test
    fun retriesStopWhenTheirDelaysRunOut() = runTest {
        val validator = FakeValidator().apply { otherwise = Validation.Pending("not_configured") }
        val billing = manager(validator)
        billing.purchase("starter", FakeSheet(FlowOutcome.Purchased(listOf(paid("t1"))), store))
        advanceTimeBy(60_000L)
        runCurrent()
        assertEquals("the purchase and one ask per retry delay", 3, validator.requests.size)
        assertTrue(store.consumed.isEmpty())
    }

    @Test
    fun aPurchaseWhoseRetriesRanOutIsCreditedWhenTheCreditsScreenOpens() = runTest {
        val validator = FakeValidator().apply { otherwise = Validation.Pending("credit_pending") }
        val billing = manager(validator)
        billing.start()
        runCurrent()
        val announced = mutableListOf<PurchaseOutcome>()
        backgroundScope.launch { billing.outcomes.collect { announced += it } }
        billing.purchase("starter", FakeSheet(FlowOutcome.Purchased(listOf(paid("t1"))), store))
        advanceTimeBy(60_000L)
        runCurrent()
        assertEquals(3, validator.requests.size)
        assertTrue(store.consumed.isEmpty())

        validator.otherwise = credited()
        billing.refresh()
        runCurrent()

        assertEquals(listOf("t1"), store.consumed)
        assertEquals(listOf<PurchaseOutcome>(PurchaseOutcome.Credited(STARTER, "purchase-1", 150, 250)), announced.filterIsInstance<PurchaseOutcome.Credited>())
    }

    @Test
    fun refreshingBeforeStartAsksNothing() = runTest {
        store.owned = mutableListOf(paid("t1"))
        val validator = FakeValidator(credited())
        manager(validator).refresh()
        runCurrent()
        assertEquals(0, store.purchaseQueries)
        assertTrue(validator.requests.isEmpty())
    }

    @Test
    fun aRefusedPurchaseIsNeitherConsumedNorAskedAboutAgain() = runTest {
        val validator = FakeValidator(Validation.Refused("This purchase was refunded, so it is not credited."))
        val billing = manager(validator)

        val outcome = billing.purchase("starter", FakeSheet(FlowOutcome.Purchased(listOf(paid("t1"))), store))

        assertEquals(PurchaseOutcome.Refused(STARTER, "This purchase was refunded, so it is not credited."), outcome)
        assertTrue(store.consumed.isEmpty())
        assertTrue("a refusal is final for the session", billing.reconcile().isEmpty())
        advanceTimeBy(60_000L)
        runCurrent()
        assertEquals(1, validator.requests.size)
    }

    @Test
    fun aConsumeThatFailsIsRetriedAndMakoAnswersAlreadyProcessed() = runTest {
        val validator = FakeValidator(credited(), Validation.AlreadyProcessed)
        store.consumeWorks = false
        val billing = manager(validator)

        val outcome = billing.purchase("starter", FakeSheet(FlowOutcome.Purchased(listOf(paid("t1"))), store))

        assertTrue(outcome is PurchaseOutcome.Credited)
        store.consumeWorks = true
        advanceTimeBy(5_000L)
        runCurrent()
        assertEquals(listOf("t1"), store.consumed)
        assertEquals(2, validator.requests.size)
    }

    @Test
    fun aPurchaseAwaitingPaymentIsNotSentToMakoUntilPlayReportsItPaid() = runTest {
        val validator = FakeValidator(credited())
        val billing = manager(validator)
        billing.start()
        runCurrent()
        val waiting = StorePurchase("t1", listOf(STARTER), null, StorePurchaseState.PENDING)

        val outcome = billing.purchase("starter", FakeSheet(FlowOutcome.Purchased(listOf(waiting)), store))

        assertEquals(PurchaseOutcome.AwaitingPayment(STARTER), outcome)
        assertTrue(validator.requests.isEmpty())
        store.reports.emit(listOf(paid("t1")))
        runCurrent()
        assertEquals(listOf("t1"), store.consumed)
        assertEquals(1, validator.requests.size)
    }

    @Test
    fun startCreditsWhatAnEarlierRunLeftAndAnnouncesIt() = runTest {
        store.owned = mutableListOf(paid("left-1"), paid("left-2", POPULAR))
        val validator = FakeValidator(credited(150, 250), credited(1500, 1750))
        val billing = manager(validator)
        val announced = mutableListOf<PurchaseOutcome>()
        backgroundScope.launch { billing.outcomes.collect { announced += it } }
        runCurrent()

        billing.start()
        runCurrent()

        assertEquals(listOf("left-1", "left-2"), store.consumed)
        assertEquals(listOf("starter", "popular"), validator.requests.map { it.packId })
        assertEquals(2, announced.size)
    }

    @Test
    fun startingAgainDoesNothing() = runTest {
        store.owned = mutableListOf(paid("left"))
        val validator = FakeValidator(credited())
        val billing = manager(validator)
        billing.start()
        billing.start()
        runCurrent()
        store.reports.emit(listOf(paid("new")))
        runCurrent()
        assertEquals(listOf("left", "new"), validator.requests.map { it.purchaseToken })
        assertEquals("one reconcile", 1, store.purchaseQueries)
        assertEquals("one collector", 1, store.subscribers)
    }

    @Test
    fun aPurchaseARefreshSettledFirstIsStillASuccess() = runTest {
        val validator = FakeValidator(credited())
        val billing = manager(validator)
        billing.start()
        runCurrent()
        val bought = paid("t1")
        val sheet = PurchaseLauncher { _, _ ->
            store.owned?.add(bought)
            billing.reconcile()
            FlowOutcome.Purchased(listOf(bought))
        }

        val outcome = billing.purchase("starter", sheet)

        assertEquals(PurchaseOutcome.Credited(STARTER, "purchase-1", 150, 250), outcome)
        assertEquals(1, validator.requests.size)
        assertEquals(listOf("t1"), store.consumed)
    }

    @Test
    fun aPurchaseMakoAlreadyProcessedThroughAnotherPathIsASuccess() = runTest {
        val validator = FakeValidator(Validation.AlreadyProcessed)
        val billing = manager(validator)
        val bought = paid("t1")
        val sheet = PurchaseLauncher { _, _ ->
            store.owned?.add(bought)
            billing.reconcile()
            FlowOutcome.Purchased(listOf(bought))
        }
        assertEquals(PurchaseOutcome.AlreadyCredited(STARTER), billing.purchase("starter", sheet))
    }

    @Test
    fun aPurchaseReportedTwiceIsCreditedOnce() = runTest {
        val validator = FakeValidator(credited())
        val billing = manager(validator)
        billing.start()
        runCurrent()
        val purchase = paid("t1")

        billing.purchase("starter", FakeSheet(FlowOutcome.Purchased(listOf(purchase)), store))
        store.reports.emit(listOf(purchase))
        runCurrent()

        assertEquals(1, validator.requests.size)
        assertEquals(listOf("t1"), store.consumed)
    }

    @Test
    fun anOwnedPackIsSettledByReconcilingInsteadOfBuyingAgain() = runTest {
        store.owned = mutableListOf(paid("old"))
        val validator = FakeValidator(credited())
        val outcome = manager(validator).purchase("starter", FakeSheet(FlowOutcome.AlreadyOwned))
        assertEquals(PurchaseOutcome.Credited(STARTER, "purchase-1", 150, 250), outcome)
        assertEquals(listOf("old"), store.consumed)
    }

    @Test
    fun aCancelledOrFailedSheetAsksMakoNothing() = runTest {
        val validator = FakeValidator()
        val billing = manager(validator)
        assertEquals(PurchaseOutcome.Cancelled, billing.purchase("starter", FakeSheet(FlowOutcome.Cancelled)))
        assertEquals(PurchaseOutcome.Failed("Play said no"), billing.purchase("starter", FakeSheet(FlowOutcome.Failed("Play said no"))))
        assertEquals(
            PurchaseOutcome.Failed(PlayBillingManager.NO_PURCHASE_MESSAGE),
            billing.purchase("starter", FakeSheet(FlowOutcome.Purchased(emptyList())))
        )
        assertTrue(validator.requests.isEmpty())
    }

    @Test
    fun buyingNeedsASignedInAccount() = runTest {
        val sheet = FakeSheet(FlowOutcome.Cancelled)
        for (account in listOf(null, "", "  ")) {
            val outcome = manager(FakeValidator(), account = account).purchase("starter", sheet)
            assertEquals(PurchaseOutcome.Failed(PlayBillingManager.SIGN_IN_MESSAGE), outcome)
        }
        assertTrue(sheet.opened.isEmpty())
    }

    @Test
    fun aDeviceWithoutPlayBillingNeverOpensTheSheet() = runTest {
        store.connections += Connection.Unavailable("Google Play billing is not available on this device or account.", retryable = false)
        val sheet = FakeSheet(FlowOutcome.Cancelled)
        val outcome = manager(FakeValidator()).purchase("starter", sheet)
        assertEquals(PurchaseOutcome.Failed("Google Play billing is not available on this device or account."), outcome)
        assertEquals(1, store.connects)
        assertTrue(sheet.opened.isEmpty())
    }

    @Test
    fun aConnectionThatCanRecoverIsRetriedWithBackoff() = runTest {
        repeat(2) { store.connections += Connection.Unavailable("unreachable", retryable = true) }
        val billing = manager(FakeValidator())
        var connection: Connection? = null
        backgroundScope.launch { connection = billing.connect() }
        runCurrent()
        assertEquals(1, store.connects)
        advanceTimeBy(1_000L)
        runCurrent()
        assertEquals(2, store.connects)
        assertNull(connection)
        advanceTimeBy(2_000L)
        runCurrent()
        assertEquals(Connection.Ready, connection)
        assertEquals(3, store.connects)
    }

    @Test
    fun aConnectionIsGivenUpAfterEveryDelay() = runTest {
        repeat(10) { store.connections += Connection.Unavailable("unreachable", retryable = true) }
        val connection = manager(FakeValidator()).connect()
        assertEquals(Connection.Unavailable("unreachable", retryable = true), connection)
        assertEquals(4, store.connects)
    }

    @Test
    fun productsArePackPricesByPackId() = runTest {
        store.listed = listOf(
            StoreProduct(STARTER, "€2,99"),
            StoreProduct(POPULAR, "€24,99"),
            StoreProduct("com.guitaripod.pixie.plus.weekly", "€1,99")
        )
        val billing = manager(FakeValidator())
        val products = billing.products(listOf("starter", "popular", "enterprise"))
        assertEquals(mapOf("starter" to StoreProduct(STARTER, "€2,99"), "popular" to StoreProduct(POPULAR, "€24,99")), products)

        store.listed = null
        assertTrue(billing.products(listOf("starter")).isEmpty())
    }

    @Test
    fun reconcilingLeavesEverythingButPaidPacksAlone() = runTest {
        store.owned = mutableListOf(
            paid("sub", "com.guitaripod.pixie.plus.weekly"),
            StorePurchase("odd", listOf(STARTER), null, StorePurchaseState.UNSPECIFIED),
            StorePurchase("none", emptyList(), null, StorePurchaseState.PURCHASED),
            paid("pack")
        )
        val validator = FakeValidator(credited())
        val outcomes = manager(validator).reconcile()
        assertEquals(listOf<PurchaseOutcome>(PurchaseOutcome.Credited(STARTER, "purchase-1", 150, 250)), outcomes)
        assertEquals(listOf("pack"), store.consumed)
    }

    @Test
    fun aQuietReconcileReturnsOutcomesWithoutAnnouncingThem() = runTest {
        store.owned = mutableListOf(paid("t1"))
        val billing = manager(FakeValidator(credited()))
        val announced = mutableListOf<PurchaseOutcome>()
        backgroundScope.launch { billing.outcomes.collect { announced += it } }
        runCurrent()
        assertEquals(1, billing.reconcile(announce = false).size)
        runCurrent()
        assertTrue(announced.isEmpty())
    }

    @Test
    fun reconcilingWithoutPlayDoesNothing() = runTest {
        store.owned = null
        assertTrue(manager(FakeValidator()).reconcile().isEmpty())
    }

    @Test
    fun packIdsAndProductIdsMapBothWays() {
        assertEquals(STARTER, productIdOf("starter"))
        assertEquals("starter", packIdOf(STARTER))
        assertNull(packIdOf("com.guitaripod.pixie.credits."))
        assertNull(packIdOf("com.guitaripod.pixie.plus.weekly"))
        assertNull(packIdOf("starter"))
    }
}
