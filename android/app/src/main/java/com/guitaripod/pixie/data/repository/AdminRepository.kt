package com.guitaripod.pixie.data.repository

import com.guitaripod.pixie.data.api.PixieApiService
import com.guitaripod.pixie.data.api.model.*
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow

interface AdminRepository {
    suspend fun checkAdminStatus(): Boolean
    fun getSystemStats(): Flow<NetworkResult<SystemStatsResponse>>
    fun adjustUserCredits(request: AdminCreditAdjustmentRequest): Flow<NetworkResult<AdminCreditAdjustmentResponse>>
    fun searchUsers(search: String? = null, page: Int? = null, perPage: Int? = null): Flow<NetworkResult<List<UserSearchResult>>>
    fun getAdjustmentHistory(userId: String): Flow<NetworkResult<AdjustmentHistoryResponse>>
}

class AdminRepositoryImpl(
    private val apiService: PixieApiService,
    private val preferencesRepository: PreferencesRepository
) : AdminRepository, BaseRepository() {
    
    override suspend fun checkAdminStatus(): Boolean {
        return try {
            val response = apiService.getAdminStats()
            if (response.isSuccessful) {
                val config = preferencesRepository.loadConfig()
                preferencesRepository.saveConfig(config.copy(isAdmin = true))
                true
            } else {
                val config = preferencesRepository.loadConfig()
                preferencesRepository.saveConfig(config.copy(isAdmin = false))
                false
            }
        } catch (e: Exception) {
            val config = preferencesRepository.loadConfig()
            preferencesRepository.saveConfig(config.copy(isAdmin = false))
            false
        }
    }
    
    override fun getSystemStats(): Flow<NetworkResult<SystemStatsResponse>> = flow {
        emit(NetworkResult.Loading)
        safeApiCall { apiService.getAdminStats() }.fold(
            onSuccess = { emit(NetworkResult.Success(it)) },
            onFailure = { emit(NetworkResult.Error(NetworkException.UnknownException(it))) }
        )
    }
    
    override fun adjustUserCredits(request: AdminCreditAdjustmentRequest): Flow<NetworkResult<AdminCreditAdjustmentResponse>> = flow {
        emit(NetworkResult.Loading)
        safeApiCall { apiService.adjustUserCredits(request) }.fold(
            onSuccess = { emit(NetworkResult.Success(it)) },
            onFailure = { emit(NetworkResult.Error(NetworkException.UnknownException(it))) }
        )
    }
    
    override fun searchUsers(search: String?, page: Int?, perPage: Int?): Flow<NetworkResult<List<UserSearchResult>>> = flow {
        emit(NetworkResult.Loading)
        safeApiCall { apiService.searchUsers(search, page, perPage) }.fold(
            onSuccess = { emit(NetworkResult.Success(it)) },
            onFailure = { emit(NetworkResult.Error(NetworkException.UnknownException(it))) }
        )
    }
    
    override fun getAdjustmentHistory(userId: String): Flow<NetworkResult<AdjustmentHistoryResponse>> = flow {
        emit(NetworkResult.Loading)
        safeApiCall { apiService.getAdjustmentHistory(userId) }.fold(
            onSuccess = { emit(NetworkResult.Success(it)) },
            onFailure = { emit(NetworkResult.Error(NetworkException.UnknownException(it))) }
        )
    }
}