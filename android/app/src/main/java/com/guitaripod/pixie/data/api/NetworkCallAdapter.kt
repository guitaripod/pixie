package com.guitaripod.pixie.data.api

import com.guitaripod.pixie.data.api.model.*
import com.squareup.moshi.Moshi
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import retrofit2.Response
import java.io.IOException
import java.net.SocketTimeoutException
import java.net.UnknownHostException

/**
 * Helper class to safely execute network calls and convert them to NetworkResult
 */
class NetworkCallAdapter(
    private val moshi: Moshi
) {
    
    /**
     * Execute a network call and wrap the result in NetworkResult
     */
    suspend fun <T> safeApiCall(
        apiCall: suspend () -> Response<T>
    ): NetworkResult<T> = withContext(Dispatchers.IO) {
        try {
            val response = apiCall()
            
            if (response.isSuccessful) {
                response.body()?.let { data ->
                    NetworkResult.Success(data)
                } ?: NetworkResult.Error(
                    NetworkException.ApiException("Response body is null")
                )
            } else {
                // Parse error response
                val errorBody = response.errorBody()?.string()
                val networkException = when (response.code()) {
                    401 -> NetworkException.UnauthorizedException()
                    429 -> {
                        val retryAfter = response.headers()["Retry-After"]?.toIntOrNull()
                        NetworkException.RateLimitException(retryAfter)
                    }
                    in 400..499 -> {
                        val errorResponse = parseErrorResponse(errorBody)
                        NetworkException.HttpException(
                            code = response.code(),
                            errorMessage = errorResponse?.error?.message 
                                ?: "Client error",
                            errorBody = errorResponse
                        )
                    }
                    in 500..599 -> NetworkException.HttpException(
                        code = response.code(),
                        errorMessage = "Server error",
                        errorBody = parseErrorResponse(errorBody)
                    )
                    else -> NetworkException.ApiException(
                        "Unexpected response code: ${response.code()}"
                    )
                }
                NetworkResult.Error(networkException)
            }
        } catch (e: Exception) {
            NetworkResult.Error(mapException(e))
        }
    }
    
    /**
     * Parse error response body
     */
    private fun parseErrorResponse(errorBody: String?): ErrorResponse? {
        return try {
            errorBody?.let {
                moshi.adapter(ErrorResponse::class.java).fromJson(it)
            }
        } catch (e: Exception) {
            null
        }
    }
    
    /**
     * Map general exceptions to specific NetworkException types
     */
    private fun mapException(exception: Exception): NetworkException {
        return when (exception) {
            is UnknownHostException -> NetworkException.NoInternetException()
            is SocketTimeoutException -> NetworkException.TimeoutException()
            is IOException -> NetworkException.ApiException(
                exception.message ?: "Network error"
            )
            is NetworkException -> exception
            else -> NetworkException.UnknownException(exception)
        }
    }
}

/**
 * Extension function to execute API calls with NetworkResult
 */
suspend fun <T> Response<T>.toNetworkResult(
    moshi: Moshi
): NetworkResult<T> {
    val adapter = NetworkCallAdapter(moshi)
    return adapter.safeApiCall { this }
}