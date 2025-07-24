package com.guitaripod.pixie.data.repository

import com.guitaripod.pixie.data.api.PixieApiService
import com.guitaripod.pixie.data.api.model.*

class CreditsRepository(
    private val apiService: PixieApiService
) : BaseRepository() {
    
    suspend fun getCreditBalance(): Result<CreditBalance> = safeApiCall {
        apiService.getCreditBalance()
    }
    
    suspend fun getCreditTransactions(limit: Int = 20): Result<CreditHistoryResponse> = safeApiCall {
        apiService.getCreditTransactions(limit)
    }
    
    suspend fun getCreditPacks(): Result<CreditPacksResponse> = safeApiCall {
        apiService.getCreditPacks()
    }
    
    suspend fun estimateCredits(
        quality: String,
        size: String,
        isEdit: Boolean = false
    ): Result<CreditEstimateResponse> = safeApiCall {
        apiService.estimateCredits(
            CreditEstimateRequest(
                quality = quality,
                size = size,
                isEdit = isEdit
            )
        )
    }
    
    suspend fun getUsage(
        startDate: String? = null,
        endDate: String? = null
    ): Result<UsageResponse> = safeApiCall {
        apiService.getUsage(startDate, endDate)
    }
}