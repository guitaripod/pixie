package com.guitaripod.pixie.data.model

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass

/**
 * Request to start device code flow
 */
@JsonClass(generateAdapter = true)
data class DeviceCodeRequest(
    @Json(name = "client_type") val clientType: String = "android",
    @Json(name = "provider") val provider: String
)


/**
 * Request to exchange device code for token
 */
@JsonClass(generateAdapter = true)
data class DeviceTokenRequest(
    @Json(name = "device_code") val deviceCode: String,
    @Json(name = "client_type") val clientType: String = "android"
)

/**
 * Response from device token endpoint
 */
@JsonClass(generateAdapter = true)
data class DeviceTokenResponse(
    @Json(name = "api_key") val apiKey: String,
    @Json(name = "user_id") val userId: String
)

/**
 * OAuth state for security
 */
data class OAuthState(
    val state: String = java.util.UUID.randomUUID().toString(),
    val provider: String,
    val timestamp: Long = System.currentTimeMillis()
) {
    fun isValid(): Boolean {
        // State is valid for 10 minutes
        return System.currentTimeMillis() - timestamp < 10 * 60 * 1000
    }
}

/**
 * Authentication result
 */
sealed class AuthResult {
    data class Success(
        val apiKey: String,
        val userId: String,
        val provider: String
    ) : AuthResult()
    
    data class Error(val message: String) : AuthResult()
    object Cancelled : AuthResult()
    object Pending : AuthResult()
}

/**
 * Request for native Google Sign-In
 */
@JsonClass(generateAdapter = true)
data class GoogleTokenRequest(
    @Json(name = "id_token") val idToken: String
)