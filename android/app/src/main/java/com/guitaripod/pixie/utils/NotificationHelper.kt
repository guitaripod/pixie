package com.guitaripod.pixie.utils

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import android.content.pm.PackageManager
import android.Manifest
import android.app.PendingIntent
import android.content.Intent
import com.guitaripod.pixie.MainActivity
import com.guitaripod.pixie.R

class NotificationHelper(private val context: Context) {
    
    companion object {
        const val CHANNEL_ID_DOWNLOADS = "pixie_downloads"
        const val CHANNEL_NAME_DOWNLOADS = "Image Downloads"
        const val CHANNEL_DESCRIPTION_DOWNLOADS = "Shows progress when saving images"
        
        const val CHANNEL_ID_GENERATION = "pixie_generation"
        const val CHANNEL_NAME_GENERATION = "Image Generation"
        const val CHANNEL_DESCRIPTION_GENERATION = "Shows progress when generating images"
        
        private const val NOTIFICATION_ID = 2001
    }
    
    init {
        createNotificationChannels()
    }
    
    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            val downloadChannel = NotificationChannel(
                CHANNEL_ID_DOWNLOADS,
                CHANNEL_NAME_DOWNLOADS,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = CHANNEL_DESCRIPTION_DOWNLOADS
                setShowBadge(false)
                setSound(null, null)
            }
            
            val generationChannel = NotificationChannel(
                CHANNEL_ID_GENERATION,
                CHANNEL_NAME_GENERATION,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = CHANNEL_DESCRIPTION_GENERATION
                setShowBadge(false)
                setSound(null, null)
            }
            
            notificationManager.createNotificationChannel(downloadChannel)
            notificationManager.createNotificationChannel(generationChannel)
        }
    }
    
    fun showDownloadProgress(message: String, progress: Int, max: Int): Int {
        val notificationId = System.currentTimeMillis().toInt()
        
        if (!hasNotificationPermission()) {
            return notificationId
        }
        
        val notification = NotificationCompat.Builder(context, CHANNEL_ID_DOWNLOADS)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle("Pixie")
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setProgress(max, progress, progress == 0)
            .setOngoing(true)
            .setSilent(true)
            .build()
        
        NotificationManagerCompat.from(context).notify(notificationId, notification)
        return notificationId
    }
    
    fun updateDownloadProgress(notificationId: Int, message: String, progress: Int, max: Int) {
        if (!hasNotificationPermission()) {
            return
        }
        
        val notification = NotificationCompat.Builder(context, CHANNEL_ID_DOWNLOADS)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle("Pixie")
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setProgress(max, progress, false)
            .setOngoing(true)
            .setSilent(true)
            .build()
        
        NotificationManagerCompat.from(context).notify(notificationId, notification)
    }
    
    fun showDownloadComplete(notificationId: Int, message: String) {
        if (!hasNotificationPermission()) {
            return
        }
        
        val notification = NotificationCompat.Builder(context, CHANNEL_ID_DOWNLOADS)
            .setSmallIcon(android.R.drawable.stat_sys_download_done)
            .setContentTitle("Pixie")
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setAutoCancel(true)
            .setSilent(true)
            .build()
        
        NotificationManagerCompat.from(context).notify(notificationId, notification)
    }
    
    fun showGenerationProgress(prompt: String): Int {
        val notificationId = System.currentTimeMillis().toInt()
        
        if (!hasNotificationPermission()) {
            return notificationId
        }
        
        val truncatedPrompt = if (prompt.length > 100) {
            prompt.take(97) + "..."
        } else {
            prompt
        }
        
        val pendingIntent = createPendingIntent()
        
        val notification = NotificationCompat.Builder(context, CHANNEL_ID_GENERATION)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("Generating Image")
            .setContentText(truncatedPrompt)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setProgress(0, 0, true)
            .setOngoing(true)
            .setSilent(true)
            .build()
        
        NotificationManagerCompat.from(context).notify(notificationId, notification)
        return notificationId
    }
    
    fun showGenerationComplete(notificationId: Int, success: Boolean, message: String? = null) {
        if (!hasNotificationPermission()) {
            return
        }
        
        val (title, text) = if (success) {
            Pair(
                "Image Generated Successfully",
                message ?: "Your image is ready!"
            )
        } else {
            Pair(
                "Generation Failed",
                message ?: "Failed to generate image"
            )
        }
        
        val pendingIntent = createPendingIntent()
        
        val notification = NotificationCompat.Builder(context, CHANNEL_ID_GENERATION)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setAutoCancel(true)
            .setSilent(true)
            .build()
        
        NotificationManagerCompat.from(context).notify(notificationId, notification)
    }
    
    fun cancelNotification(notificationId: Int) {
        if (!hasNotificationPermission()) {
            return
        }
        NotificationManagerCompat.from(context).cancel(notificationId)
    }
    
    private fun hasNotificationPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }
    
    private fun createPendingIntent(): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        } else {
            PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT
            )
        }
    }
}