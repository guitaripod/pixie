package com.guitaripod.pixie.data.repository

import com.guitaripod.pixie.data.local.dao.ImageDao
import com.guitaripod.pixie.data.local.entity.ImageEntity
import com.guitaripod.pixie.domain.repository.ImageRepository
import kotlinx.coroutines.flow.Flow

/**
 * Implementation of ImageRepository using local database.
 * This demonstrates how to implement repositories with our manual DI.
 */
class ImageRepositoryImpl(
    private val imageDao: ImageDao
) : ImageRepository {
    
    override fun getAllImages(): Flow<List<ImageEntity>> {
        return imageDao.getAllImages()
    }
    
    override suspend fun getImageById(id: String): ImageEntity? {
        return imageDao.getImageById(id)
    }
    
    override suspend fun saveImage(image: ImageEntity) {
        imageDao.insertImage(image)
    }
    
    override suspend fun deleteImage(image: ImageEntity) {
        imageDao.deleteImage(image)
    }
}