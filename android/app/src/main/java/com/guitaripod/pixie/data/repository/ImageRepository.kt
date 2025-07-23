package com.guitaripod.pixie.data.repository

import com.guitaripod.pixie.data.api.PixieApiService
import com.guitaripod.pixie.data.model.ImageGenerationRequest
import com.guitaripod.pixie.data.model.ImageGenerationResponse
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import retrofit2.HttpException
import java.io.IOException

class ImageRepository(
    private val apiService: PixieApiService
) {
    
    fun generateImages(request: ImageGenerationRequest): Flow<Result<ImageGenerationResponse>> = flow {
        try {
            val response = apiService.generateImages(request)
            
            if (response.isSuccessful) {
                response.body()?.let { body ->
                    emit(Result.success(body))
                } ?: emit(Result.failure(Exception("Empty response body")))
            } else {
                val errorMessage = when (response.code()) {
                    400 -> "Invalid request. Please check your input."
                    401 -> "Unauthorized. Please sign in again."
                    403 -> "Forbidden. Your prompt may have been blocked by moderation."
                    429 -> "Too many requests. Please try again later."
                    500 -> "Server error. Please try again later."
                    else -> "Generation failed: ${response.message()}"
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