package com.guitaripod.pixie.utils

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class NotificationHelper(private val context: Context) {
    
    companion object {
        const val CHANNEL_ID = "pixie_downloads"
        const val CHANNEL_NAME = "Image Downloads"
        const val CHANNEL_DESCRIPTION = "Shows progress when saving images"
        private const val NOTIFICATION_ID = 2001
    }
    
    init {
        createNotificationChannel()
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = CHANNEL_DESCRIPTION
                setShowBadge(false)
                setSound(null, null)
            }
            
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    fun showDownloadProgress(message: String, progress: Int, max: Int): Int {
        val notificationId = System.currentTimeMillis().toInt()
        
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
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
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
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
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download_done)
            .setContentTitle("Pixie")
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setAutoCancel(true)
            .setSilent(true)
            .build()
        
        NotificationManagerCompat.from(context).notify(notificationId, notification)
    }
    
    fun cancelNotification(notificationId: Int) {
        NotificationManagerCompat.from(context).cancel(notificationId)
    }
}