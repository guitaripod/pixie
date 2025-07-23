package com.guitaripod.pixie.utils

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.IOException
import java.net.URL
import java.text.SimpleDateFormat
import java.util.*

class ImageSaver(private val context: Context) {
    
    companion object {
        const val ALBUM_NAME = "Pixie"
    }
    
    suspend fun saveImageToGallery(
        imageUrl: String,
        fileName: String? = null
    ): Result<Uri> = withContext(Dispatchers.IO) {
        try {
            val bitmap = downloadImage(imageUrl)
            val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                saveImageToMediaStore(bitmap, fileName)
            } else {
                saveImageToExternalStorage(bitmap, fileName)
            }
            Result.success(uri)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    suspend fun saveMultipleImages(
        imageUrls: List<String>
    ): List<Result<Uri>> = withContext(Dispatchers.IO) {
        imageUrls.map { url ->
            saveImageToGallery(url)
        }
    }
    
    private suspend fun downloadImage(imageUrl: String): Bitmap = withContext(Dispatchers.IO) {
        try {
            val url = URL(imageUrl)
            val connection = url.openConnection()
            connection.doInput = true
            connection.connect()
            val input = connection.getInputStream()
            BitmapFactory.decodeStream(input) ?: throw IOException("Failed to decode image")
        } catch (e: Exception) {
            throw IOException("Failed to download image: ${e.message}", e)
        }
    }
    
    private fun saveImageToMediaStore(bitmap: Bitmap, fileName: String?): Uri {
        val resolver = context.contentResolver
        val imageCollection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        }
        
        val timeStamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
        val displayName = fileName ?: "PIXIE_$timeStamp"
        
        val imageDetails = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, displayName)
            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            put(MediaStore.Images.Media.DATE_ADDED, System.currentTimeMillis() / 1000)
            put(MediaStore.Images.Media.DATE_MODIFIED, System.currentTimeMillis() / 1000)
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Images.Media.RELATIVE_PATH, "${Environment.DIRECTORY_PICTURES}/$ALBUM_NAME")
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
        }
        
        val imageUri = resolver.insert(imageCollection, imageDetails)
            ?: throw IOException("Failed to create MediaStore entry")
        
        resolver.openOutputStream(imageUri).use { outputStream ->
            if (outputStream == null) throw IOException("Failed to open output stream")
            if (!bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)) {
                throw IOException("Failed to save bitmap")
            }
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            imageDetails.clear()
            imageDetails.put(MediaStore.Images.Media.IS_PENDING, 0)
            resolver.update(imageUri, imageDetails, null, null)
        }
        
        return imageUri
    }
    
    private fun saveImageToExternalStorage(bitmap: Bitmap, fileName: String?): Uri {
        val picturesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
        val pixieDir = java.io.File(picturesDir, ALBUM_NAME)
        
        if (!pixieDir.exists() && !pixieDir.mkdirs()) {
            throw IOException("Failed to create album directory")
        }
        
        val timeStamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
        val imageFileName = fileName ?: "PIXIE_$timeStamp.png"
        val imageFile = java.io.File(pixieDir, imageFileName)
        
        java.io.FileOutputStream(imageFile).use { outputStream ->
            if (!bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)) {
                throw IOException("Failed to save bitmap")
            }
        }
        
        val mediaScanIntent = Intent(Intent.ACTION_MEDIA_SCANNER_SCAN_FILE)
        mediaScanIntent.data = Uri.fromFile(imageFile)
        context.sendBroadcast(mediaScanIntent)
        
        return Uri.fromFile(imageFile)
    }
    
    suspend fun shareImageFromUrl(imageUrl: String): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val bitmap = downloadImage(imageUrl)
            val uri = saveImageToCache(bitmap)
            withContext(Dispatchers.Main) {
                shareImage(uri)
            }
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    suspend fun shareImagesFromUrls(imageUrls: List<String>): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val uris = imageUrls.map { url ->
                val bitmap = downloadImage(url)
                saveImageToCache(bitmap)
            }
            withContext(Dispatchers.Main) {
                shareImages(uris)
            }
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    private fun saveImageToCache(bitmap: Bitmap): Uri {
        val cachePath = java.io.File(context.cacheDir, "shared_images")
        cachePath.mkdirs()
        
        val timeStamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
        val file = java.io.File(cachePath, "pixie_share_$timeStamp.png")
        
        java.io.FileOutputStream(file).use { outputStream ->
            if (!bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)) {
                throw IOException("Failed to save bitmap to cache")
            }
        }
        
        return androidx.core.content.FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileprovider",
            file
        )
    }
    
    private fun shareImage(imageUri: Uri) {
        val shareIntent = Intent().apply {
            action = Intent.ACTION_SEND
            type = "image/*"
            putExtra(Intent.EXTRA_STREAM, imageUri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        
        val chooserIntent = Intent.createChooser(shareIntent, "Share image")
        chooserIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(chooserIntent)
    }
    
    private fun shareImages(imageUris: List<Uri>) {
        val shareIntent = Intent().apply {
            action = Intent.ACTION_SEND_MULTIPLE
            type = "image/*"
            putParcelableArrayListExtra(Intent.EXTRA_STREAM, ArrayList(imageUris))
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        
        val chooserIntent = Intent.createChooser(shareIntent, "Share images")
        chooserIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(chooserIntent)
    }
}