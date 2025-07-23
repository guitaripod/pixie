package com.guitaripod.pixie.data.api.model

/**
 * Sealed class representing network operation results.
 * This provides type-safe error handling for API calls.
 */
sealed class NetworkResult<out T> {
    data class Success<T>(val data: T) : NetworkResult<T>()
    data class Error(val exception: NetworkException) : NetworkResult<Nothing>()
    object Loading : NetworkResult<Nothing>()
}

/**
 * Sealed class for different types of network errors
 */
sealed class NetworkException(
    message: String? = null,
    cause: Throwable? = null
) : Exception(message, cause) {
    
    // HTTP errors
    data class HttpException(
        val code: Int,
        val errorMessage: String,
        val errorBody: ErrorResponse? = null
    ) : NetworkException("HTTP $code: $errorMessage")
    
    // Network connectivity errors
    class NoInternetException : NetworkException("No internet connection")
    
    // Timeout errors
    class TimeoutException : NetworkException("Request timed out")
    
    // Authentication errors
    class UnauthorizedException(
        override val message: String = "Authentication required"
    ) : NetworkException(message)
    
    // Rate limiting
    data class RateLimitException(
        val retryAfter: Int? = null
    ) : NetworkException("Rate limit exceeded")
    
    // Generic API errors
    data class ApiException(
        override val message: String,
        val errorCode: String? = null
    ) : NetworkException(message)
    
    // Unknown errors
    data class UnknownException(
        override val cause: Throwable
    ) : NetworkException("Unknown error occurred", cause)
}

/**
 * Standard error response from the API
 */
@com.squareup.moshi.JsonClass(generateAdapter = true)
data class ErrorResponse(
    @com.squareup.moshi.Json(name = "error") val error: ErrorDetail
)

@com.squareup.moshi.JsonClass(generateAdapter = true)
data class ErrorDetail(
    @com.squareup.moshi.Json(name = "message") val message: String,
    @com.squareup.moshi.Json(name = "type") val type: String? = null,
    @com.squareup.moshi.Json(name = "code") val code: String? = null
)

/**
 * Extension functions for NetworkResult
 */
inline fun <T> NetworkResult<T>.onSuccess(action: (value: T) -> Unit): NetworkResult<T> {
    if (this is NetworkResult.Success) {
        action(data)
    }
    return this
}

inline fun <T> NetworkResult<T>.onError(action: (exception: NetworkException) -> Unit): NetworkResult<T> {
    if (this is NetworkResult.Error) {
        action(exception)
    }
    return this
}

inline fun <T> NetworkResult<T>.onLoading(action: () -> Unit): NetworkResult<T> {
    if (this is NetworkResult.Loading) {
        action()
    }
    return this
}

/**
 * Map success data to another type
 */
inline fun <T, R> NetworkResult<T>.map(transform: (T) -> R): NetworkResult<R> {
    return when (this) {
        is NetworkResult.Success -> NetworkResult.Success(transform(data))
        is NetworkResult.Error -> this
        is NetworkResult.Loading -> this
    }
}

/**
 * Get data or null
 */
fun <T> NetworkResult<T>.getOrNull(): T? {
    return when (this) {
        is NetworkResult.Success -> data
        else -> null
    }
}

/**
 * Get data or throw exception
 */
fun <T> NetworkResult<T>.getOrThrow(): T {
    return when (this) {
        is NetworkResult.Success -> data
        is NetworkResult.Error -> throw exception
        is NetworkResult.Loading -> throw IllegalStateException("Cannot get data while loading")
    }
}