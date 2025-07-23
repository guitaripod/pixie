package com.guitaripod.pixie.data.api.model

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass

// Authentication Models

@JsonClass(generateAdapter = true)
data class OAuthCallbackRequest(
    @Json(name = "code") val code: String,
    @Json(name = "state") val state: String? = null,
    @Json(name = "redirect_uri") val redirectUri: String
)

@JsonClass(generateAdapter = true)
data class AuthResponse(
    @Json(name = "user_id") val userId: String,
    @Json(name = "email") val email: String,
    @Json(name = "name") val name: String,
    @Json(name = "api_key") val apiKey: String,
    @Json(name = "credits") val credits: Int,
    @Json(name = "provider") val provider: String
)

@JsonClass(generateAdapter = true)
data class DeviceCodeResponse(
    @Json(name = "device_code") val deviceCode: String,
    @Json(name = "user_code") val userCode: String,
    @Json(name = "verification_uri") val verificationUri: String,
    @Json(name = "verification_uri_complete") val verificationUriComplete: String?,
    @Json(name = "expires_in") val expiresIn: Int,
    @Json(name = "interval") val interval: Int
)

@JsonClass(generateAdapter = true)
data class DeviceAuthRequest(
    @Json(name = "device_code") val deviceCode: String
)