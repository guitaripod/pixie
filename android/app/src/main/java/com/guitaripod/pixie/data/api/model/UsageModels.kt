package com.guitaripod.pixie.data.api.model

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass

// Usage Models

@JsonClass(generateAdapter = true)
data class UsageResponse(
    @Json(name = "user_id") val userId: String,
    @Json(name = "period") val period: UsagePeriod,
    @Json(name = "total_requests") val totalRequests: Int,
    @Json(name = "total_credits") val totalCredits: Int,
    @Json(name = "total_images") val totalImages: Int,
    @Json(name = "breakdown") val breakdown: UsageBreakdown
)

@JsonClass(generateAdapter = true)
data class UsagePeriod(
    @Json(name = "start_date") val startDate: String,
    @Json(name = "end_date") val endDate: String
)

@JsonClass(generateAdapter = true)
data class UsageBreakdown(
    @Json(name = "by_quality") val byQuality: Map<String, Int>,
    @Json(name = "by_size") val bySize: Map<String, Int>,
    @Json(name = "by_type") val byType: Map<String, Int>,
    @Json(name = "daily") val daily: List<DailyUsage>?
)

@JsonClass(generateAdapter = true)
data class DailyUsage(
    @Json(name = "date") val date: String,
    @Json(name = "requests") val requests: Int,
    @Json(name = "credits") val credits: Int,
    @Json(name = "images") val images: Int
)

// Admin Models

@JsonClass(generateAdapter = true)
data class AdminStatsResponse(
    @Json(name = "total_users") val totalUsers: Int,
    @Json(name = "active_users") val activeUsers: Int,
    @Json(name = "total_images") val totalImages: Int,
    @Json(name = "total_credits_used") val totalCreditsUsed: Long,
    @Json(name = "storage_used_bytes") val storageUsedBytes: Long,
    @Json(name = "daily_stats") val dailyStats: List<DailyStats>
)

@JsonClass(generateAdapter = true)
data class DailyStats(
    @Json(name = "date") val date: String,
    @Json(name = "new_users") val newUsers: Int,
    @Json(name = "active_users") val activeUsers: Int,
    @Json(name = "images_generated") val imagesGenerated: Int,
    @Json(name = "credits_used") val creditsUsed: Int,
    @Json(name = "revenue_usd") val revenueUsd: Double
)

@JsonClass(generateAdapter = true)
data class CreditAdjustmentRequest(
    @Json(name = "amount") val amount: Int,
    @Json(name = "reason") val reason: String
)

@JsonClass(generateAdapter = true)
data class CreditAdjustmentResponse(
    @Json(name = "user_id") val userId: String,
    @Json(name = "previous_balance") val previousBalance: Int,
    @Json(name = "adjustment") val adjustment: Int,
    @Json(name = "new_balance") val newBalance: Int,
    @Json(name = "reason") val reason: String,
    @Json(name = "admin_id") val adminId: String,
    @Json(name = "created_at") val createdAt: String
)