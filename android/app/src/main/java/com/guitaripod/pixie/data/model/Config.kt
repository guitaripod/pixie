package com.guitaripod.pixie.data.model

/**
 * Configuration data matching the CLI structure
 */
data class Config(
    val apiUrl: String? = null,
    val apiKey: String? = null,
    val userId: String? = null,
    val authProvider: String? = null
) {
    /**
     * Check if the user is authenticated
     */
    fun isAuthenticated(): Boolean {
        return apiKey != null && userId != null
    }
}

/**
 * Auth providers matching CLI
 */
object AuthProvider {
    const val GITHUB = "github"
    const val GOOGLE = "google"
    const val APPLE = "apple"
}