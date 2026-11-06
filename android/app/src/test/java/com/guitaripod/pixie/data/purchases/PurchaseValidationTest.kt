package com.guitaripod.pixie.data.purchases

import com.guitaripod.pixie.presentation.credits.PurchaseMessage
import com.guitaripod.pixie.presentation.credits.PurchaseUiState
import com.guitaripod.pixie.presentation.credits.restoreMessage
import com.guitaripod.pixie.presentation.credits.stateAfter
import com.squareup.moshi.Moshi
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PurchaseValidationTest {
    private val moshi = Moshi.Builder().build()
    private val errors = moshi.adapter(MakoErrorEnvelope::class.java)

    private fun error(code: String, message: String) = """{"error":{"message":"$message","type":"t","param":null,"code":"$code"}}"""

    private fun answer(status: Int, errorBody: String?) = validationOf(status, null, errorBody, errors)

    @Test
    fun aCreditIsReadFromTheBody() {
        val body = PurchaseValidationResponse(success = true, purchaseId = "p-1", creditsAdded = 150, newBalance = 250)
        assertEquals(Validation.Credited("p-1", 150, 250), validationOf(200, body, null, errors))
        assertTrue(validationOf(200, body.copy(success = false), null, errors) is Validation.Pending)
        assertTrue(validationOf(200, null, null, errors) is Validation.Pending)
    }

    @Test
    fun alreadyProcessedMayBeConsumed() {
        assertEquals(Validation.AlreadyProcessed, answer(400, error("already_processed", "Purchase has already been processed")))
    }

    @Test
    fun finalRefusalsCarryMakosMessage() {
        val refunded = "This purchase was refunded, so it is not credited."
        assertEquals(Validation.Refused(refunded), answer(400, error("refunded", refunded)))
        assertEquals(Validation.Refused("Purchase could not be verified."), answer(400, error("unverifiable_purchase", "Purchase could not be verified.")))
        assertEquals(Validation.Refused("The purchase was not made by this account."), answer(403, error("forbidden", "The purchase was not made by this account.")))
        assertEquals(Validation.Refused("The purchase could not be credited (400)."), answer(400, "<html>bad gateway</html>"))
        assertTrue(answer(404, null) is Validation.Refused)
    }

    @Test
    fun everythingThatCanStillCreditKeepsThePurchase() {
        assertEquals(Validation.Pending("credit_pending"), answer(409, error("credit_pending", "Could not verify the purchase right now")))
        assertEquals(Validation.Pending("not_configured"), answer(503, error("not_configured", "Google Play purchases cannot be verified")))
        assertEquals(Validation.Pending("wallet_unavailable"), answer(503, error("wallet_unavailable", "x")))
        for (status in listOf(401, 408, 429, 500, 502)) {
            assertTrue("$status", answer(status, null) is Validation.Pending)
        }
    }

    @Test
    fun theRequestCarriesThePlayFieldsMakoReads() {
        val json = moshi.adapter(PurchaseValidationRequest::class.java)
            .toJson(PurchaseValidationRequest("starter", "token-1", "com.guitaripod.pixie.credits.starter", playOrderId = "GPA.1"))
        assertEquals(
            """{"pack_id":"starter","purchase_token":"token-1","product_id":"com.guitaripod.pixie.credits.starter","platform":"android","play_order_id":"GPA.1"}""",
            json
        )
        val withoutOrder = moshi.adapter(PurchaseValidationRequest::class.java)
            .toJson(PurchaseValidationRequest("starter", "token-1", "com.guitaripod.pixie.credits.starter"))
        assertFalse(withoutOrder.contains("play_order_id"))
    }

    @Test
    fun theScreenShowsEachOutcome() {
        val credited = stateAfter(PurchaseUiState(), PurchaseOutcome.Credited("p", "purchase-1", 150, 250))
        assertTrue(credited.showSuccessDialog)
        assertEquals(250, credited.lastPurchaseResult?.newBalance)
        assertEquals(PurchaseUiState(), stateAfter(PurchaseUiState(), PurchaseOutcome.Cancelled))
        assertEquals("Purchase received", stateAfter(PurchaseUiState(), PurchaseOutcome.Pending("p", "credit_pending")).message?.title)
        assertEquals("Payment pending", stateAfter(PurchaseUiState(), PurchaseOutcome.AwaitingPayment("p")).message?.title)
        assertEquals(PurchaseMessage("Purchase error", "No Play"), stateAfter(PurchaseUiState(), PurchaseOutcome.Failed("No Play")).message)
        assertTrue(stateAfter(PurchaseUiState(), PurchaseOutcome.Refused("p", "Refunded.")).message!!.text.startsWith("Refunded. "))
    }

    @Test
    fun restoringSummarisesWhatItFound() {
        assertEquals("No purchases are waiting to be credited.", restoreMessage(emptyList()).text)
        val mixed = restoreMessage(
            listOf(
                PurchaseOutcome.Credited("a", "1", 150, 250),
                PurchaseOutcome.Credited("b", "2", 550, 800),
                PurchaseOutcome.Pending("c", "credit_pending")
            )
        )
        assertEquals(
            "Added 700 credits from 2 purchases.\n\n1 purchase is still being confirmed; the credits are added automatically.",
            mixed.text
        )
        assertEquals(
            "Could not reach Google Play. Check your connection and try again.",
            restoreMessage(listOf(PurchaseOutcome.Failed("Could not reach Google Play. Check your connection and try again."))).text
        )
    }
}
