package com.guitaripod.pixie.utils

import android.content.Context
import coil.disk.DiskCache
import coil.memory.MemoryCache
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File

class CacheManager(private val context: Context) {
    
    suspend fun getCacheSize(): Long = withContext(Dispatchers.IO) {
        val coilCacheDir = File(context.cacheDir, "image_cache")
        val cacheSize = if (coilCacheDir.exists()) {
            calculateDirectorySize(coilCacheDir)
        } else {
            0L
        }
        
        // Add other cache directories if any
        val tempShareDir = File(context.cacheDir, "temp_shares")
        val tempShareSize = if (tempShareDir.exists()) {
            calculateDirectorySize(tempShareDir)
        } else {
            0L
        }
        
        cacheSize + tempShareSize
    }
    
    suspend fun clearCache() = withContext(Dispatchers.IO) {
        // Clear Coil cache
        val coilCacheDir = File(context.cacheDir, "image_cache")
        if (coilCacheDir.exists()) {
            coilCacheDir.deleteRecursively()
        }
        
        // Clear temp share directory
        val tempShareDir = File(context.cacheDir, "temp_shares")
        if (tempShareDir.exists()) {
            tempShareDir.deleteRecursively()
        }
        
        // Clear Coil memory cache (if we have access to it)
        // Note: This would require passing the ImageLoader instance
    }
    
    private fun calculateDirectorySize(directory: File): Long {
        var size = 0L
        
        directory.listFiles()?.forEach { file ->
            size += if (file.isDirectory) {
                calculateDirectorySize(file)
            } else {
                file.length()
            }
        }
        
        return size
    }
}