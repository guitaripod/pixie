package com.guitaripod.pixie.data.api.model

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass

@JsonClass(generateAdapter = true)
data class SystemStatsResponse(
    val users: UserStats,
    val credits: CreditStats,
    val revenue: RevenueStats,
    val images: ImageStats
)

@JsonClass(generateAdapter = true)
data class UserStats(
    val total: Int
)

@JsonClass(generateAdapter = true)
data class CreditStats(
    @Json(name = "total_balance") val totalBalance: Int,
    @Json(name = "total_purchased") val totalPurchased: Int,
    @Json(name = "total_spent") val totalSpent: Int
)

@JsonClass(generateAdapter = true)
data class RevenueStats(
    @Json(name = "total_usd") val totalUsd: String,
    @Json(name = "openai_costs_usd") val openaiCostsUsd: String,
    @Json(name = "gross_profit_usd") val grossProfitUsd: String,
    @Json(name = "profit_margin") val profitMargin: String
)

@JsonClass(generateAdapter = true)
data class ImageStats(
    @Json(name = "total_generated") val totalGenerated: Int
)

@JsonClass(generateAdapter = true)
data class AdminCreditAdjustmentRequest(
    @Json(name = "user_id") val userId: String,
    val amount: Int,
    val reason: String
)

@JsonClass(generateAdapter = true)
data class AdminCreditAdjustmentResponse(
    @Json(name = "new_balance") val newBalance: Int
)

@JsonClass(generateAdapter = true)
data class UserSearchResult(
    val id: String,
    val email: String?,
    @Json(name = "is_admin") val isAdmin: Boolean,
    val credits: Int,
    @Json(name = "created_at") val createdAt: String
)

@JsonClass(generateAdapter = true)
data class AdjustmentHistoryItem(
    val id: String,
    @Json(name = "user_id") val userId: String,
    @Json(name = "admin_id") val adminId: String,
    val amount: Int,
    val reason: String,
    @Json(name = "created_at") val createdAt: String,
    @Json(name = "new_balance") val newBalance: Int
)

@JsonClass(generateAdapter = true)
data class AdjustmentHistoryResponse(
    val adjustments: List<AdjustmentHistoryItem>
)