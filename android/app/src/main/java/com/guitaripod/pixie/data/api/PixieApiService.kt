package com.guitaripod.pixie.data.api

import com.guitaripod.pixie.data.api.model.*
import com.guitaripod.pixie.data.model.*
import retrofit2.Response
import retrofit2.http.*

interface PixieApiService {
    
    @GET("/")
    suspend fun healthCheck(): Response<String>
    
    @GET("/v1/auth/github")
    suspend fun startGithubAuth(
        @Query("redirect_uri") redirectUri: String? = null
    ): Response<Unit>
    
    @POST("/v1/auth/github/callback")
    suspend fun githubAuthCallback(
        @Body request: OAuthCallbackRequest
    ): Response<AuthResponse>
    
    @GET("/v1/auth/google")
    suspend fun startGoogleAuth(
        @Query("redirect_uri") redirectUri: String? = null
    ): Response<Unit>
    
    @POST("/v1/auth/google/callback")
    suspend fun googleAuthCallback(
        @Body request: OAuthCallbackRequest
    ): Response<AuthResponse>
    
    @POST("/v1/auth/google/token")
    suspend fun googleTokenAuth(
        @Body request: GoogleTokenRequest
    ): Response<AuthResponse>
    
    @GET("/v1/auth/apple")
    suspend fun startAppleAuth(
        @Query("redirect_uri") redirectUri: String? = null
    ): Response<Unit>
    
    @POST("/v1/auth/apple/callback/json")
    suspend fun appleAuthCallback(
        @Body request: OAuthCallbackRequest
    ): Response<AuthResponse>
    
    @POST("/v1/auth/device/code")
    suspend fun startDeviceAuth(
        @Body request: DeviceCodeRequest
    ): Response<com.guitaripod.pixie.data.api.model.DeviceCodeResponse>
    
    @POST("/v1/auth/device/token")
    suspend fun checkDeviceAuth(
        @Body request: DeviceTokenRequest
    ): Response<DeviceTokenResponse>
    
    @POST("/v1/images/generations")
    suspend fun generateImages(
        @Body request: com.guitaripod.pixie.data.model.ImageGenerationRequest,
        @Header("OpenAI-API-Key") openAiKey: String? = null
    ): Response<com.guitaripod.pixie.data.model.ImageGenerationResponse>
    
    @POST("/v1/images/edits")
    suspend fun editImages(
        @Body request: com.guitaripod.pixie.data.model.EditRequest,
        @Header("OpenAI-API-Key") openAiKey: String? = null
    ): Response<com.guitaripod.pixie.data.model.ImageGenerationResponse>
    
    @GET("/v1/images")
    suspend fun listPublicImages(
        @Query("limit") limit: Int? = null,
        @Query("offset") offset: Int? = null
    ): Response<ImageListResponse>
    
    @GET("/v1/me/images")
    suspend fun listMyImages(
        @Query("limit") limit: Int? = null,
        @Query("offset") offset: Int? = null
    ): Response<ImageListResponse>
    
    @GET("/v1/images/{image_id}")
    suspend fun getImage(
        @Path("image_id") imageId: String
    ): Response<ImageDetails>
    
    @DELETE("/v1/images/{image_id}")
    suspend fun deleteImage(
        @Path("image_id") imageId: String
    ): Response<Unit>
    
    @GET("/v1/me/credits")
    suspend fun getCredits(): Response<CreditsResponse>
    
    @GET("/v1/me/credits/history")
    suspend fun getCreditHistory(
        @Query("limit") limit: Int? = null,
        @Query("offset") offset: Int? = null
    ): Response<CreditHistoryResponse>
    
    @GET("/v1/credits/packs")
    suspend fun getCreditPacks(): Response<CreditPacksResponse>
    
    @POST("/v1/credits/estimate")
    suspend fun estimateCredits(
        @Body request: CreditEstimateRequest
    ): Response<CreditEstimateResponse>
    
    @GET("/v1/me/usage")
    suspend fun getUsage(
        @Query("start_date") startDate: String? = null,
        @Query("end_date") endDate: String? = null
    ): Response<UsageResponse>
    
    @GET("/v1/admin/stats")
    suspend fun getAdminStats(): Response<AdminStatsResponse>
    
    @POST("/v1/admin/users/{user_id}/credits")
    suspend fun adjustUserCredits(
        @Path("user_id") userId: String,
        @Body request: CreditAdjustmentRequest
    ): Response<CreditAdjustmentResponse>
}