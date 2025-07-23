package com.guitaripod.pixie.data.repository

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.Base64
import com.guitaripod.pixie.data.api.PixieApiService
import com.guitaripod.pixie.data.model.ImageGenerationRequest
import com.guitaripod.pixie.data.model.ImageGenerationResponse
import com.guitaripod.pixie.data.model.ApiErrorResponse
import com.guitaripod.pixie.data.model.EditRequest
import com.squareup.moshi.Moshi
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.toRequestBody
import retrofit2.HttpException
import java.io.ByteArrayOutputStream
import java.io.IOException

class ImageRepository(
    private val apiService: PixieApiService,
    private val context: Context
) {
    private val moshi = Moshi.Builder().build()
    
    fun generateImages(request: ImageGenerationRequest): Flow<Result<ImageGenerationResponse>> = flow {
        try {
            val response = apiService.generateImages(request)
            
            if (response.isSuccessful) {
                val body = response.body()
                if (body != null) {
                    emit(Result.success(body))
                } else {
                    emit(Result.failure(Exception("Empty response body")))
                }
            } else {
                val errorBody = response.errorBody()?.string()
                var errorMessage = "Generation failed"
                
                // Try to parse the error response
                if (!errorBody.isNullOrEmpty()) {
                    try {
                        val adapter = moshi.adapter(ApiErrorResponse::class.java)
                        val errorResponse = adapter.fromJson(errorBody)
                        
                        errorMessage = errorResponse?.error?.message ?: errorMessage
                        
                        // Add helpful context based on error code
                        when (errorResponse?.error?.code) {
                            "insufficient_credits" -> {
                                errorMessage = "$errorMessage\n\nYou don't have enough credits. Please purchase more credits to continue."
                            }
                            "unauthorized" -> {
                                errorMessage = "$errorMessage\n\nYour session may have expired. Please sign in again."
                            }
                            "rate_limit_exceeded" -> {
                                errorMessage = "$errorMessage\n\nYou're making requests too quickly. Please wait a moment and try again."
                            }
                            "content_policy_violation" -> {
                                errorMessage = "$errorMessage\n\nYour prompt was blocked by our content policy. Please try a different prompt."
                            }
                        }
                    } catch (e: Exception) {
                        // If we can't parse the error, fall back to status code
                        errorMessage = when (response.code()) {
                            400 -> "Invalid request. Please check your input."
                            401 -> "Unauthorized. Please sign in again."
                            403 -> "Forbidden. Your prompt may have been blocked by moderation."
                            429 -> "Too many requests. Please try again later."
                            500 -> "Server error. Please try again later."
                            else -> "Generation failed: ${response.message()}"
                        }
                    }
                } else {
                    // No error body, use status code
                    errorMessage = when (response.code()) {
                        400 -> "Invalid request. Please check your input."
                        401 -> "Unauthorized. Please sign in again."
                        403 -> "Forbidden. Your prompt may have been blocked by moderation."
                        429 -> "Too many requests. Please try again later."
                        500 -> "Server error. Please try again later."
                        else -> "Generation failed: ${response.message()}"
                    }
                }
                
                emit(Result.failure(Exception(errorMessage)))
            }
        } catch (e: IOException) {
            emit(Result.failure(Exception("Network error. Please check your connection.")))
        } catch (e: HttpException) {
            emit(Result.failure(Exception("Server error: ${e.message()}")))
        } catch (e: Exception) {
            emit(Result.failure(Exception("Unexpected error: ${e.message}")))
        }
    }
    
    fun editImage(
        imageUri: Uri,
        prompt: String,
        mask: Bitmap? = null,
        n: Int = 1,
        size: String = "1024x1024",
        quality: String = "low",
        fidelity: String = "low"
    ): Flow<Result<ImageGenerationResponse>> = flow {
        try {
            // Convert image to base64
            val imageBytes = withContext(Dispatchers.IO) {
                context.contentResolver.openInputStream(imageUri)?.use { inputStream ->
                    inputStream.readBytes()
                } ?: throw IOException("Failed to read image")
            }
            
            // Convert to base64 data URL
            val imageBase64 = Base64.encodeToString(imageBytes, Base64.NO_WRAP)
            val imageDataUrl = "data:image/png;base64,$imageBase64"
            
            // Convert mask to base64 if provided
            val maskDataUrl = mask?.let {
                val maskBytes = withContext(Dispatchers.IO) {
                    val outputStream = ByteArrayOutputStream()
                    it.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
                    outputStream.toByteArray()
                }
                val maskBase64 = Base64.encodeToString(maskBytes, Base64.NO_WRAP)
                "data:image/png;base64,$maskBase64"
            }
            
            // Create request object
            val request = EditRequest(
                image = listOf(imageDataUrl),
                prompt = prompt,
                mask = maskDataUrl,
                n = n,
                size = size,
                quality = quality,
                inputFidelity = fidelity
            )
            
            val response = apiService.editImages(request)
            
            if (response.isSuccessful) {
                val body = response.body()
                if (body != null) {
                    emit(Result.success(body))
                } else {
                    emit(Result.failure(Exception("Empty response body")))
                }
            } else {
                val errorBody = response.errorBody()?.string()
                var errorMessage = "Edit failed"
                
                // Try to parse the error response
                if (!errorBody.isNullOrEmpty()) {
                    try {
                        val adapter = moshi.adapter(ApiErrorResponse::class.java)
                        val errorResponse = adapter.fromJson(errorBody)
                        
                        errorMessage = errorResponse?.error?.message ?: errorMessage
                        
                        // Add helpful context based on error code
                        when (errorResponse?.error?.code) {
                            "insufficient_credits" -> {
                                errorMessage = "$errorMessage\n\nYou don't have enough credits. Please purchase more credits to continue."
                            }
                            "unauthorized" -> {
                                errorMessage = "$errorMessage\n\nYour session may have expired. Please sign in again."
                            }
                            "rate_limit_exceeded" -> {
                                errorMessage = "$errorMessage\n\nYou're making requests too quickly. Please wait a moment and try again."
                            }
                            "content_policy_violation" -> {
                                errorMessage = "$errorMessage\n\nYour prompt was blocked by our content policy. Please try a different prompt."
                            }
                            "file_too_large" -> {
                                errorMessage = "$errorMessage\n\nThe image file is too large. Maximum size is 50MB."
                            }
                        }
                    } catch (e: Exception) {
                        // If we can't parse the error, fall back to status code
                        errorMessage = when (response.code()) {
                            400 -> "Invalid request. Please check your input."
                            401 -> "Unauthorized. Please sign in again."
                            403 -> "Forbidden. Your prompt may have been blocked by moderation."
                            413 -> "Image file too large. Maximum size is 50MB."
                            429 -> "Too many requests. Please try again later."
                            500 -> "Server error. Please try again later."
                            else -> "Edit failed: ${response.message()}"
                        }
                    }
                } else {
                    // No error body, use status code
                    errorMessage = when (response.code()) {
                        400 -> "Invalid request. Please check your input."
                        401 -> "Unauthorized. Please sign in again."
                        403 -> "Forbidden. Your prompt may have been blocked by moderation."
                        413 -> "Image file too large. Maximum size is 50MB."
                        429 -> "Too many requests. Please try again later."
                        500 -> "Server error. Please try again later."
                        else -> "Edit failed: ${response.message()}"
                    }
                }
                
                emit(Result.failure(Exception(errorMessage)))
            }
        } catch (e: IOException) {
            emit(Result.failure(Exception("Network error. Please check your connection.")))
        } catch (e: HttpException) {
            emit(Result.failure(Exception("Server error: ${e.message()}")))
        } catch (e: Exception) {
            emit(Result.failure(Exception("Unexpected error: ${e.message}")))
        }
    }
}