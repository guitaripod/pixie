package com.guitaripod.pixie.data.model

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass

@JsonClass(generateAdapter = true)
data class DeviceCodeRequest(
    @Json(name = "client_type") val clientType: String = "android",
    @Json(name = "provider") val provider: String
)
@JsonClass(generateAdapter = true)
data class DeviceTokenRequest(
    @Json(name = "device_code") val deviceCode: String,
    @Json(name = "client_type") val clientType: String = "android"
)
@JsonClass(generateAdapter = true)
data class DeviceTokenResponse(
    @Json(name = "api_key") val apiKey: String,
    @Json(name = "user_id") val userId: String
)
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
@JsonClass(generateAdapter = true)
data class GoogleTokenRequest(
    @Json(name = "id_token") val idToken: String
)
@JsonClass(generateAdapter = true)
data class User(
    val id: String,
    val provider: String,
    val email: String? = null,
    val name: String? = null,
    val avatar_url: String? = null,
    val created_at: String? = null
)
@JsonClass(generateAdapter = true)
data class LoginResponse(
    val user: User,
    val api_key: String
)

@JsonClass(generateAdapter = true)
data class ApiError(
    val message: String,
    val type: String? = null,
    val param: String? = null,
    val code: String? = null
)

@JsonClass(generateAdapter = true)
data class ApiErrorResponse(
    val error: ApiError
)