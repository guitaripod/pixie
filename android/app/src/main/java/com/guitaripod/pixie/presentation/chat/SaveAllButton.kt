package com.guitaripod.pixie.presentation.chat

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.filled.DownloadForOffline
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import com.guitaripod.pixie.utils.ImageSaver
import com.guitaripod.pixie.utils.NotificationHelper
import com.guitaripod.pixie.utils.rememberHapticFeedback
import kotlinx.coroutines.launch

@Composable
fun SaveAllButton(
    imageUrls: List<String>,
    onSaveSuccess: (String) -> Unit,
    onSaveError: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val imageSaver = remember { ImageSaver(context) }
    val notificationHelper = remember { NotificationHelper(context) }
    
    var isSaving by remember { mutableStateOf(false) }
    var progress by remember { mutableStateOf(0) }
    
    val hasStoragePermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        true
    } else {
        ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.WRITE_EXTERNAL_STORAGE
        ) == PackageManager.PERMISSION_GRANTED
    }
    
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        if (isGranted) {
            scope.launch {
                saveAllImages(imageUrls, imageSaver, notificationHelper, onSaveSuccess, onSaveError) { saving, prog ->
                    isSaving = saving
                    progress = prog
                }
            }
        } else {
            onSaveError("Storage permission denied")
        }
    }
    
    val haptic = rememberHapticFeedback()
    
    Surface(
        onClick = {
            if (!isSaving) {
                haptic.click()
                if (hasStoragePermission) {
                    scope.launch {
                        saveAllImages(imageUrls, imageSaver, notificationHelper, onSaveSuccess, onSaveError) { saving, prog ->
                            isSaving = saving
                            progress = prog
                        }
                    }
                } else {
                    permissionLauncher.launch(Manifest.permission.WRITE_EXTERNAL_STORAGE)
                }
            }
        },
        enabled = !isSaving,
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.secondaryContainer,
        modifier = modifier.fillMaxWidth()
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically
        ) {
            if (isSaving) {
                CircularProgressIndicator(
                    modifier = Modifier.size(20.dp),
                    strokeWidth = 2.dp
                )
                Spacer(modifier = Modifier.width(12.dp))
                Text(
                    text = "Saving... $progress/${imageUrls.size}",
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.Medium
                )
            } else {
                Icon(
                    imageVector = Icons.Default.DownloadForOffline,
                    contentDescription = null,
                    modifier = Modifier.size(20.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = "Save all ${imageUrls.size} images",
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.Medium
                )
            }
        }
    }
}

private suspend fun saveAllImages(
    imageUrls: List<String>,
    imageSaver: ImageSaver,
    notificationHelper: NotificationHelper,
    onSuccess: (String) -> Unit,
    onError: (String) -> Unit,
    onProgress: (Boolean, Int) -> Unit
) {
    onProgress(true, 0)
    var savedCount = 0
    var failedCount = 0
    
    val notificationId = if (imageUrls.size > 2) {
        notificationHelper.showDownloadProgress("Saving images...", 0, imageUrls.size)
    } else null
    
    imageUrls.forEachIndexed { index, url ->
        notificationId?.let {
            notificationHelper.updateDownloadProgress(
                it, 
                "Saving image ${index + 1} of ${imageUrls.size}...", 
                index, 
                imageUrls.size
            )
        }
        
        imageSaver.saveImageToGallery(url).fold(
            onSuccess = { savedCount++ },
            onFailure = { failedCount++ }
        )
        onProgress(true, index + 1)
    }
    
    onProgress(false, imageUrls.size)
    
    val resultMessage = when {
        failedCount == 0 -> "All $savedCount images saved to gallery"
        savedCount == 0 -> "Failed to save images"
        else -> "$savedCount images saved, $failedCount failed"
    }
    
    notificationId?.let {
        notificationHelper.showDownloadComplete(it, resultMessage)
    }
    
    when {
        failedCount == 0 -> onSuccess(resultMessage)
        savedCount == 0 -> onError(resultMessage)
        else -> onSuccess(resultMessage)
    }
}