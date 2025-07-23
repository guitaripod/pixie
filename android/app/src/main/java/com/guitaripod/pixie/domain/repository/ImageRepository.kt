package com.guitaripod.pixie.domain.repository

import com.guitaripod.pixie.data.local.entity.ImageEntity
import kotlinx.coroutines.flow.Flow

/**
 * Repository interface for image operations.
 * This follows the repository pattern from Clean Architecture.
 */
interface ImageRepository {
    fun getAllImages(): Flow<List<ImageEntity>>
    suspend fun getImageById(id: String): ImageEntity?
    suspend fun saveImage(image: ImageEntity)
    suspend fun deleteImage(image: ImageEntity)
}