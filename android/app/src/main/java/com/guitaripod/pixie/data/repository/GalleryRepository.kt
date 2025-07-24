package com.guitaripod.pixie.data.repository

import com.guitaripod.pixie.data.api.PixieApiService
import com.guitaripod.pixie.data.api.model.ImageListResponse
import com.guitaripod.pixie.data.api.model.ImageDetails
import com.guitaripod.pixie.data.local.ConfigManager
import retrofit2.HttpException
import java.io.IOException

class GalleryRepository(
    private val apiService: PixieApiService,
    private val configManager: ConfigManager
) {
    
    suspend fun getPublicGallery(
        page: Int = 1,
        perPage: Int = 20
    ): Result<ImageListResponse> {
        return try {
            val response = apiService.listPublicImages(
                page = page,
                perPage = perPage
            )
            
            if (response.isSuccessful) {
                response.body()?.let { 
                    Result.success(it) 
                } ?: Result.failure(Exception("Empty response"))
            } else {
                val errorMessage = when (response.code()) {
                    401 -> "Please sign in to view the gallery"
                    403 -> "Access denied"
                    429 -> "Too many requests. Please try again later."
                    500 -> "Server error. Please try again later."
                    else -> "Failed to load gallery: ${response.message()}"
                }
                Result.failure(Exception(errorMessage))
            }
        } catch (e: IOException) {
            Result.failure(Exception("Network error. Please check your connection."))
        } catch (e: HttpException) {
            Result.failure(Exception("Server error: ${e.message()}"))
        } catch (e: Exception) {
            Result.failure(Exception("Unexpected error: ${e.message}"))
        }
    }
    
    suspend fun getMyImages(
        page: Int = 1,
        perPage: Int = 20
    ): Result<ImageListResponse> {
        return try {
            val config = configManager.loadConfig()
            val userId = config.userId ?: return Result.failure(Exception("User not authenticated"))
            
            val response = apiService.listMyImages(
                userId = userId,
                page = page,
                perPage = perPage
            )
            
            if (response.isSuccessful) {
                response.body()?.let { 
                    Result.success(it) 
                } ?: Result.failure(Exception("Empty response"))
            } else {
                val errorMessage = when (response.code()) {
                    401 -> "Please sign in to view your images"
                    403 -> "Access denied"
                    429 -> "Too many requests. Please try again later."
                    500 -> "Server error. Please try again later."
                    else -> "Failed to load your images: ${response.message()}"
                }
                Result.failure(Exception(errorMessage))
            }
        } catch (e: IOException) {
            Result.failure(Exception("Network error. Please check your connection."))
        } catch (e: HttpException) {
            Result.failure(Exception("Server error: ${e.message()}"))
        } catch (e: Exception) {
            Result.failure(Exception("Unexpected error: ${e.message}"))
        }
    }
    
    suspend fun getImageDetails(imageId: String): Result<ImageDetails> {
        return try {
            val response = apiService.getImage(imageId)
            
            if (response.isSuccessful) {
                response.body()?.let { 
                    Result.success(it) 
                } ?: Result.failure(Exception("Image not found"))
            } else {
                val errorMessage = when (response.code()) {
                    401 -> "Please sign in to view this image"
                    403 -> "You don't have permission to view this image"
                    404 -> "Image not found"
                    429 -> "Too many requests. Please try again later."
                    500 -> "Server error. Please try again later."
                    else -> "Failed to load image: ${response.message()}"
                }
                Result.failure(Exception(errorMessage))
            }
        } catch (e: IOException) {
            Result.failure(Exception("Network error. Please check your connection."))
        } catch (e: HttpException) {
            Result.failure(Exception("Server error: ${e.message()}"))
        } catch (e: Exception) {
            Result.failure(Exception("Unexpected error: ${e.message}"))
        }
    }
    
    suspend fun deleteImage(imageId: String): Result<Unit> {
        return try {
            val response = apiService.deleteImage(imageId)
            
            if (response.isSuccessful) {
                Result.success(Unit)
            } else {
                val errorMessage = when (response.code()) {
                    401 -> "Please sign in to delete images"
                    403 -> "You can only delete your own images"
                    404 -> "Image not found"
                    429 -> "Too many requests. Please try again later."
                    500 -> "Server error. Please try again later."
                    else -> "Failed to delete image: ${response.message()}"
                }
                Result.failure(Exception(errorMessage))
            }
        } catch (e: IOException) {
            Result.failure(Exception("Network error. Please check your connection."))
        } catch (e: HttpException) {
            Result.failure(Exception("Server error: ${e.message()}"))
        } catch (e: Exception) {
            Result.failure(Exception("Unexpected error: ${e.message}"))
        }
    }
}