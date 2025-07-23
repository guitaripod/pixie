package com.guitaripod.pixie.data.repository

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import retrofit2.Response

abstract class BaseRepository {
    
    protected suspend fun <T> safeApiCall(
        apiCall: suspend () -> Response<T>
    ): Result<T> = withContext(Dispatchers.IO) {
        try {
            val response = apiCall()
            if (response.isSuccessful) {
                response.body()?.let {
                    Result.success(it)
                } ?: Result.failure(Exception("Response body is null"))
            } else {
                Result.failure(
                    Exception("API Error: ${response.code()} - ${response.message()}")
                )
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    protected suspend fun <T> safeDatabaseCall(
        databaseCall: suspend () -> T
    ): Result<T> = withContext(Dispatchers.IO) {
        try {
            Result.success(databaseCall())
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}