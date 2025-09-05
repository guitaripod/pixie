package com.guitaripod.pixie.data.api.model

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass
import androidx.compose.ui.graphics.Color

@JsonClass(generateAdapter = true)
data class CreditBalance(
    @Json(name = "balance") val balance: Int,
    @Json(name = "currency") val currency: String = "USD"
)

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
    @Json(name = "type") val transactionType: String,
    @Json(name = "amount") val amount: Int,
    @Json(name = "balance_after") val balanceAfter: Int,
    @Json(name = "description") val description: String,
    @Json(name = "created_at") val createdAt: String,
    @Json(name = "reference_id") val referenceId: String? = null
)

enum class TransactionType(val value: String) {
    PURCHASE("purchase"),
    SPEND("spend"),
    REFUND("refund"),
    BONUS("bonus"),
    ADMIN_ADJUSTMENT("admin_adjustment");
    
    companion object {
        fun fromString(value: String): TransactionType = 
            values().find { it.value == value } ?: SPEND
    }
}

@JsonClass(generateAdapter = true)
data class CreditPacksResponse(
    @Json(name = "packs") val packs: List<CreditPack>
)

@JsonClass(generateAdapter = true)
data class CreditPack(
    @Json(name = "id") val id: String,
    @Json(name = "name") val name: String,
    @Json(name = "credits") val credits: Int,
    @Json(name = "price_usd_cents") val priceUsdCents: Int,
    @Json(name = "bonus_credits") val bonusCredits: Int,
    @Json(name = "description") val description: String,
    @Json(name = "popular") val popular: Boolean = false
) {
    val totalCredits: Int
        get() = credits + bonusCredits
}

@JsonClass(generateAdapter = true)
data class CreditEstimateRequest(
    @Json(name = "model") val model: String? = null,
    @Json(name = "quality") val quality: String,
    @Json(name = "size") val size: String,
    @Json(name = "n") val n: Int = 1,
    @Json(name = "is_edit") val isEdit: Boolean = false
)

@JsonClass(generateAdapter = true)
data class CreditEstimateResponse(
    @Json(name = "estimated_credits") val estimatedCredits: Int,
    @Json(name = "estimated_usd") val estimatedUsd: String,
    @Json(name = "note") val note: String
)

@JsonClass(generateAdapter = true)
data class CreditBreakdown(
    @Json(name = "base_cost") val baseCost: Int,
    @Json(name = "quality_multiplier") val qualityMultiplier: Double,
    @Json(name = "size_multiplier") val sizeMultiplier: Double,
    @Json(name = "edit_cost") val editCost: Int?
)

fun String.toTransactionType(): TransactionType = TransactionType.fromString(this)

fun TransactionType.getDisplayName(): String = when (this) {
    TransactionType.PURCHASE -> "Purchase"
    TransactionType.SPEND -> "Spent"
    TransactionType.REFUND -> "Refund"
    TransactionType.BONUS -> "Bonus"
    TransactionType.ADMIN_ADJUSTMENT -> "Adjustment"
}

fun TransactionType.getColor(): Color = when (this) {
    TransactionType.PURCHASE -> Color(0xFF4CAF50)
    TransactionType.SPEND -> Color(0xFFF44336)
    TransactionType.REFUND -> Color(0xFF00BCD4)
    TransactionType.BONUS -> Color(0xFFFFEB3B)
    TransactionType.ADMIN_ADJUSTMENT -> Color(0xFF2196F3)
}

fun CreditBalance.getBalanceColor(): Color = when {
    balance == 0 -> Color(0xFFF44336)
    balance < 50 -> Color(0xFFFF9800)
    else -> Color(0xFF4CAF50)
}

fun CreditBalance.canGenerate(quality: String, size: String = "1024x1024"): Pair<Boolean, Int> {
    val cost = getCreditCost(quality, size)
    return Pair(balance >= cost, balance / cost)
}

fun getCreditCost(quality: String, size: String, isEdit: Boolean = false, model: String? = null): Int {
    if (model?.startsWith("gemini") == true) {
        return 15
    }
    
    val baseCost = when (quality.lowercase()) {
        "low" -> when (size) {
            "1024x1024" -> 4
            "1536x1024", "1024x1536" -> 6
            else -> 5
        }
        "medium" -> when (size) {
            "1024x1024" -> 16
            "1536x1024", "1024x1536" -> 24
            else -> 20
        }
        "high" -> when (size) {
            "1024x1024" -> 62
            "1536x1024", "1024x1536" -> 94
            else -> 78
        }
        "auto" -> when (size) {
            "1024x1024" -> 50
            else -> 75
        }
        else -> 50
    }
    
    return if (isEdit) {
        baseCost + when (quality.lowercase()) {
            "low", "medium" -> 3
            "high" -> 20
            "auto" -> 18
            else -> 10
        }
    } else {
        baseCost
    }
}