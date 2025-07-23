package com.guitaripod.pixie.data.api.model

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass

// Credit Models

@JsonClass(generateAdapter = true)
data class CreditsResponse(
    @Json(name = "credits") val credits: Int,
    @Json(name = "bonus_credits") val bonusCredits: Int,
    @Json(name = "total_credits") val totalCredits: Int
)

@JsonClass(generateAdapter = true)
data class CreditHistoryResponse(
    @Json(name = "transactions") val transactions: List<CreditTransaction>,
    @Json(name = "total") val total: Int,
    @Json(name = "limit") val limit: Int,
    @Json(name = "offset") val offset: Int
)

@JsonClass(generateAdapter = true)
data class CreditTransaction(
    @Json(name = "id") val id: String,
    @Json(name = "user_id") val userId: String,
    @Json(name = "amount") val amount: Int,
    @Json(name = "type") val type: String,
    @Json(name = "description") val description: String,
    @Json(name = "created_at") val createdAt: String,
    @Json(name = "metadata") val metadata: Map<String, Any>?
)

@JsonClass(generateAdapter = true)
data class CreditPacksResponse(
    @Json(name = "packs") val packs: List<CreditPack>
)

@JsonClass(generateAdapter = true)
data class CreditPack(
    @Json(name = "id") val id: String,
    @Json(name = "name") val name: String,
    @Json(name = "credits") val credits: Int,
    @Json(name = "bonus_credits") val bonusCredits: Int,
    @Json(name = "price_usd") val priceUsd: Double,
    @Json(name = "currency") val currency: String,
    @Json(name = "popular") val popular: Boolean = false,
    @Json(name = "description") val description: String?
)

@JsonClass(generateAdapter = true)
data class CreditEstimateRequest(
    @Json(name = "quality") val quality: String,
    @Json(name = "size") val size: String,
    @Json(name = "n") val n: Int = 1,
    @Json(name = "is_edit") val isEdit: Boolean = false
)

@JsonClass(generateAdapter = true)
data class CreditEstimateResponse(
    @Json(name = "estimated_credits") val estimatedCredits: Int,
    @Json(name = "per_image") val perImage: Int,
    @Json(name = "total") val total: Int,
    @Json(name = "breakdown") val breakdown: CreditBreakdown?
)

@JsonClass(generateAdapter = true)
data class CreditBreakdown(
    @Json(name = "base_cost") val baseCost: Int,
    @Json(name = "quality_multiplier") val qualityMultiplier: Double,
    @Json(name = "size_multiplier") val sizeMultiplier: Double,
    @Json(name = "edit_cost") val editCost: Int?
)