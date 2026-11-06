package com.guitaripod.pixie.data.purchases

import org.junit.Assert.assertEquals
import org.junit.Test

class CreditPricesTest {
    private val starter = "starter" to StoreProduct("com.guitaripod.pixie.credits.starter", "€2,99")
    private val popular = "popular" to StoreProduct("com.guitaripod.pixie.credits.popular", "€24,99")

    @Test
    fun aFailedLoadKeepsThePricesAlreadyShown() {
        assertEquals(mapOf(starter, popular), pricesAfter(mapOf(starter, popular), emptyMap()))
    }

    @Test
    fun aLoadThatAnswersReplacesThePrices() {
        val repriced = "starter" to StoreProduct("com.guitaripod.pixie.credits.starter", "€3,49")
        assertEquals(mapOf(repriced), pricesAfter(mapOf(starter, popular), mapOf(repriced)))
        assertEquals(mapOf(starter), pricesAfter(emptyMap(), mapOf(starter)))
    }

    @Test
    fun nothingLoadedYetStaysEmpty() {
        assertEquals(emptyMap<String, StoreProduct>(), pricesAfter(emptyMap(), emptyMap()))
    }
}
