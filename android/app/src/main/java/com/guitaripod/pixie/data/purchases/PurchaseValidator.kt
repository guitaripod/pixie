package com.guitaripod.pixie.data.purchases

import com.guitaripod.pixie.data.api.PixieApiService
import com.squareup.moshi.Json
import com.squareup.moshi.JsonAdapter
import com.squareup.moshi.JsonClass
import com.squareup.moshi.Moshi
import kotlinx.coroutines.CancellationException

/** What mako answered for a purchase it was asked to credit. */
sealed interface Validation {
    data class Credited(val purchaseId: String, val creditsAdded: Int, val newBalance: Int) : Validation

    /** Credited before, by an earlier call. The purchase may be consumed. */
    data object AlreadyProcessed : Validation

    /** Not credited yet, and asking again later can credit it: keep the purchase unconsumed. */
    data class Pending(val reason: String) : Validation

    /** Never credited, whatever the retry: refunded, unknown to Google, or not this account's. */
    data class Refused(val message: String) : Validation
}

/** Asks mako to credit a Play purchase. The real one is [MakoPurchaseValidator]. */
fun interface PurchaseValidator {
    suspend fun validate(request: PurchaseValidationRequest): Validation
}

@JsonClass(generateAdapter = true)
data class PurchaseValidationRequest(
    @Json(name = "pack_id") val packId: String,
    @Json(name = "purchase_token") val purchaseToken: String,
    @Json(name = "product_id") val productId: String,
    @Json(name = "platform") val platform: String = "android",
    @Json(name = "play_order_id") val playOrderId: String? = null
)

@JsonClass(generateAdapter = true)
data class PurchaseValidationResponse(
    @Json(name = "success") val success: Boolean,
    @Json(name = "purchase_id") val purchaseId: String,
    @Json(name = "credits_added") val creditsAdded: Int,
    @Json(name = "new_balance") val newBalance: Int
)

@JsonClass(generateAdapter = true)
data class MakoErrorEnvelope(
    @Json(name = "error") val error: MakoError?
)

@JsonClass(generateAdapter = true)
data class MakoError(
    @Json(name = "message") val message: String?,
    @Json(name = "code") val code: String?
)

/** Asks mako's `POST /v1/credits/purchase/validate`, which verifies the token with Google Play and credits the pack. */
class MakoPurchaseValidator(
    private val apiService: PixieApiService,
    moshi: Moshi
) : PurchaseValidator {
    private val errors: JsonAdapter<MakoErrorEnvelope> = moshi.adapter(MakoErrorEnvelope::class.java)

    override suspend fun validate(request: PurchaseValidationRequest): Validation =
        try {
            val response = apiService.validatePurchase(request)
            validationOf(response.code(), response.body(), response.errorBody()?.string(), errors)
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (failure: Exception) {
            Validation.Pending(failure.message ?: failure.javaClass.simpleName)
        }
}

/**
 * Reads mako's answer. Success and `already_processed` mean the purchase may be consumed. `refunded`,
 * `unverifiable_purchase`, any other 400, 403 and 404 are final. Everything else (`credit_pending`,
 * `not_configured`, `wallet_unavailable`, 401 before a sign-in, 429, 5xx, an unreadable body) can still turn into a
 * credit, so the purchase is kept.
 */
fun validationOf(
    status: Int,
    body: PurchaseValidationResponse?,
    errorBody: String?,
    errors: JsonAdapter<MakoErrorEnvelope>
): Validation {
    if (status in 200..299) {
        return when {
            body != null && body.success -> Validation.Credited(body.purchaseId, body.creditsAdded, body.newBalance)
            else -> Validation.Pending("mako answered $status without a credit")
        }
    }
    val error = errorBody?.let { text -> runCatching { errors.fromJson(text) }.getOrNull()?.error }
    val code = error?.code
    val message = error?.message?.takeIf { it.isNotBlank() } ?: "The purchase could not be credited ($status)."
    return when {
        code == "already_processed" -> Validation.AlreadyProcessed
        status == 400 || status == 403 || status == 404 -> Validation.Refused(message)
        else -> Validation.Pending(code ?: "mako answered $status")
    }
}
