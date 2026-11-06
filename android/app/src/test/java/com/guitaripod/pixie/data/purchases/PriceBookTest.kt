package com.guitaripod.pixie.data.purchases

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class PriceBookTest {
    private fun prices(price: String) = mapOf("starter" to StoreProduct("com.guitaripod.pixie.credits.starter", price))

    @Test
    fun aSlowFailedLoadCannotPutBackPricesALaterLoadReplaced() = runTest {
        val book = PriceBook()
        book.load { prices("€2,99") }
        val slow = CompletableDeferred<Map<String, StoreProduct>>()
        launch { book.load { slow.await() } }
        runCurrent()
        launch { book.load { prices("€3,49") } }
        runCurrent()
        assertEquals("the later load waits for the one before it", prices("€2,99"), book.prices.value)

        slow.complete(emptyMap())
        runCurrent()

        assertEquals(prices("€3,49"), book.prices.value)
    }

    @Test
    fun overlappingLoadsApplyInTheOrderTheyStarted() = runTest {
        val book = PriceBook()
        val first = CompletableDeferred<Map<String, StoreProduct>>()
        launch { book.load { first.await() } }
        runCurrent()
        launch { book.load { prices("€3,49") } }
        runCurrent()
        first.complete(prices("€2,99"))
        runCurrent()
        assertEquals(prices("€3,49"), book.prices.value)
    }

    @Test
    fun anEmptyLoadKeepsWhatIsShown() = runTest {
        val book = PriceBook()
        book.load { prices("€2,99") }
        book.load { emptyMap() }
        assertEquals(prices("€2,99"), book.prices.value)
    }
}
