package com.guitaripod.pixie.service

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.guitaripod.pixie.MainActivity
import com.guitaripod.pixie.R
import com.guitaripod.pixie.data.model.ImageGenerationRequest
import com.guitaripod.pixie.di.AppContainer
import com.guitaripod.pixie.utils.NotificationHelper
import com.squareup.moshi.Moshi
import com.squareup.moshi.kotlin.reflect.KotlinJsonAdapterFactory
import kotlinx.coroutines.*

class ImageGenerationForegroundService : Service() {
    
    companion object {
        const val ACTION_START_GENERATION = "START_GENERATION"
        const val ACTION_START_EDIT = "START_EDIT"
        const val ACTION_STOP_GENERATION = "STOP_GENERATION"
        const val EXTRA_REQUEST = "request"
        const val EXTRA_EDIT_REQUEST = "edit_request"
        const val EXTRA_EDIT_DATA = "edit_data"
        const val EXTRA_PROMPT = "prompt"
        
        const val NOTIFICATION_ID = 1001
        
        fun startService(context: Context, request: ImageGenerationRequest) {
            val moshi = Moshi.Builder()
                .add(KotlinJsonAdapterFactory())
                .build()
            val adapter = moshi.adapter(ImageGenerationRequest::class.java)
            val requestJson = adapter.toJson(request)
            
            val intent = Intent(context, ImageGenerationForegroundService::class.java).apply {
                action = ACTION_START_GENERATION
                putExtra(EXTRA_REQUEST, requestJson)
                putExtra(EXTRA_PROMPT, request.prompt)
            }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
        
        fun startEditService(context: Context, editData: com.guitaripod.pixie.data.model.EditImageData) {
            val moshi = Moshi.Builder()
                .add(KotlinJsonAdapterFactory())
                .build()
            val adapter = moshi.adapter(com.guitaripod.pixie.data.model.EditImageData::class.java)
            val editDataJson = adapter.toJson(editData)
            
            val intent = Intent(context, ImageGenerationForegroundService::class.java).apply {
                action = ACTION_START_EDIT
                putExtra(EXTRA_EDIT_DATA, editDataJson)
                putExtra(EXTRA_PROMPT, "Editing: ${editData.prompt}")
            }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
        
        fun stopService(context: Context) {
            val intent = Intent(context, ImageGenerationForegroundService::class.java).apply {
                action = ACTION_STOP_GENERATION
            }
            context.stopService(intent)
        }
    }
    
    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var currentJob: Job? = null
    private lateinit var appContainer: AppContainer
    private val moshi = Moshi.Builder()
        .add(KotlinJsonAdapterFactory())
        .build()
    
    override fun onCreate() {
        super.onCreate()
        appContainer = (application as com.guitaripod.pixie.PixieApplication).appContainer
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_GENERATION -> {
                val requestJson = intent.getStringExtra(EXTRA_REQUEST)
                val prompt = intent.getStringExtra(EXTRA_PROMPT) ?: "Generating image..."
                
                if (requestJson != null) {
                    startForeground(NOTIFICATION_ID, createNotification(prompt))
                    
                    currentJob?.cancel()
                    currentJob = serviceScope.launch {
                        try {
                            val adapter = moshi.adapter(ImageGenerationRequest::class.java)
                            val request = adapter.fromJson(requestJson)
                            
                            if (request != null) {
                                generateImage(request)
                            }
                        } catch (e: Exception) {
                            showErrorNotification(e.message ?: "Failed to generate image")
                        } finally {
                            stopSelf()
                        }
                    }
                } else {
                    stopSelf()
                }
            }
            ACTION_START_EDIT -> {
                val editDataJson = intent.getStringExtra(EXTRA_EDIT_DATA)
                val prompt = intent.getStringExtra(EXTRA_PROMPT) ?: "Editing image..."
                android.util.Log.d("ImageGenerationForegroundService", "Received ACTION_START_EDIT with prompt: $prompt")
                
                if (editDataJson != null) {
                    startForeground(NOTIFICATION_ID, createNotification(prompt))
                    
                    currentJob?.cancel()
                    currentJob = serviceScope.launch {
                        try {
                            val adapter = moshi.adapter(com.guitaripod.pixie.data.model.EditImageData::class.java)
                            val editData = adapter.fromJson(editDataJson)
                            
                            if (editData != null) {
                                android.util.Log.d("ImageGenerationForegroundService", "Parsed EditImageData, calling editImage")
                                editImage(editData)
                            } else {
                                android.util.Log.e("ImageGenerationForegroundService", "Failed to parse EditImageData from JSON")
                                showErrorNotification("Failed to parse edit request")
                            }
                        } catch (e: Exception) {
                            android.util.Log.e("ImageGenerationForegroundService", "Exception in edit coroutine", e)
                            showErrorNotification(e.message ?: "Failed to edit image")
                            sendErrorBroadcast(e.message ?: "Failed to edit image")
                        } finally {
                            stopSelf()
                        }
                    }
                } else {
                    android.util.Log.e("ImageGenerationForegroundService", "No edit data JSON provided for edit")
                    stopSelf()
                }
            }
            ACTION_STOP_GENERATION -> {
                currentJob?.cancel()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
        
        return START_NOT_STICKY
    }
    
    private fun createNotification(prompt: String): Notification {
        val notificationIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        
        val pendingIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.getActivity(
                this,
                0,
                notificationIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        } else {
            PendingIntent.getActivity(
                this,
                0,
                notificationIntent,
                PendingIntent.FLAG_UPDATE_CURRENT
            )
        }
        
        val truncatedPrompt = if (prompt.length > 100) {
            prompt.take(97) + "..."
        } else {
            prompt
        }
        
        val title = if (prompt.startsWith("Editing")) "Editing Image" else "Generating Image"
        
        return NotificationCompat.Builder(this, NotificationHelper.CHANNEL_ID_GENERATION)
            .setContentTitle(title)
            .setContentText(truncatedPrompt)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(pendingIntent)
            .setProgress(0, 0, true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setSilent(true)
            .build()
    }
    
    private suspend fun generateImage(request: ImageGenerationRequest) {
        try {
            val response = appContainer.pixieApiService.generateImages(request)
            
            if (response.isSuccessful) {
                val body = response.body()
                if (body != null) {
                    val imageUrls = body.data.map { it.url }
                    showSuccessNotification("Generated ${imageUrls.size} image${if (imageUrls.size > 1) "s" else ""}")
                    
                    sendBroadcast(Intent("com.guitaripod.pixie.IMAGE_GENERATED").apply {
                        putStringArrayListExtra("imageUrls", ArrayList(imageUrls))
                        setPackage(packageName)
                    })
                } else {
                    showErrorNotification("Empty response from server")
                    sendErrorBroadcast("Empty response from server")
                }
            } else {
                val errorMessage = parseErrorResponse(response)
                showErrorNotification(errorMessage)
                sendErrorBroadcast(errorMessage)
            }
        } catch (e: Exception) {
            val error = e.message ?: "Network error"
            showErrorNotification(error)
            sendErrorBroadcast(error)
        }
    }
    
    private fun parseErrorResponse(response: retrofit2.Response<*>): String {
        return try {
            val errorBody = response.errorBody()?.string()
            if (!errorBody.isNullOrEmpty()) {
                val jsonAdapter = moshi.adapter(com.guitaripod.pixie.data.model.ApiErrorResponse::class.java)
                val errorResponse = jsonAdapter.fromJson(errorBody)
                
                when (errorResponse?.error?.code) {
                    "insufficient_credits" -> {
                        val details = errorResponse.error.details
                        val required = details?.required_credits
                        val available = details?.available_credits
                        
                        if (required != null && available != null) {
                            "Insufficient credits: You have $available credits but need $required credits for this generation."
                        } else {
                            "Insufficient credits. Please purchase more credits to continue."
                        }
                    }
                    "unauthorized" -> "Session expired. Please sign in again."
                    "rate_limit_exceeded" -> "Too many requests. Please wait a moment and try again."
                    "content_policy_violation" -> "Your prompt was blocked by content policy. Please try a different prompt."
                    else -> errorResponse?.error?.message ?: "Generation failed: ${response.code()}"
                }
            } else {
                when (response.code()) {
                    400 -> "Invalid request. Please check your input."
                    401 -> "Unauthorized. Please sign in again."
                    403 -> "Forbidden. Your prompt may have been blocked."
                    429 -> "Too many requests. Please try again later."
                    500 -> "Server error. Please try again later."
                    else -> "Generation failed: ${response.message()}"
                }
            }
        } catch (e: Exception) {
            "Generation failed: ${response.code()} ${response.message()}"
        }
    }
    
    private fun showSuccessNotification(message: String) {
        val notificationIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        
        val pendingIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.getActivity(
                this,
                0,
                notificationIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        } else {
            PendingIntent.getActivity(
                this,
                0,
                notificationIntent,
                PendingIntent.FLAG_UPDATE_CURRENT
            )
        }
        
        val notification = NotificationCompat.Builder(this, NotificationHelper.CHANNEL_ID_GENERATION)
            .setContentTitle("Image Generated Successfully")
            .setContentText(message)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .build()
        
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID + 1, notification)
    }
    
    private fun showErrorNotification(message: String) {
        val notificationIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        
        val pendingIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.getActivity(
                this,
                0,
                notificationIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        } else {
            PendingIntent.getActivity(
                this,
                0,
                notificationIntent,
                PendingIntent.FLAG_UPDATE_CURRENT
            )
        }
        
        val notification = NotificationCompat.Builder(this, NotificationHelper.CHANNEL_ID_GENERATION)
            .setContentTitle("Generation Failed")
            .setContentText(message)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .build()
        
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID + 1, notification)
    }
    
    private fun sendErrorBroadcast(error: String) {
        sendBroadcast(Intent("com.guitaripod.pixie.IMAGE_GENERATION_ERROR").apply {
            putExtra("error", error)
            setPackage(packageName)
        })
    }
    
    private suspend fun editImage(editData: com.guitaripod.pixie.data.model.EditImageData) {
        try {
            android.util.Log.d("ImageGenerationForegroundService", "Starting edit with prompt: ${editData.prompt}")
            
            val imageUri = android.net.Uri.parse(editData.imageUri)
            val repository = com.guitaripod.pixie.data.repository.ImageRepository(appContainer.pixieApiService, applicationContext)
            
            repository.editImage(
                imageUri = imageUri,
                prompt = editData.prompt,
                model = editData.model,
                n = editData.variations,
                size = editData.size,
                quality = editData.quality,
                fidelity = editData.fidelity
            ).collect { result ->
                result.fold(
                    onSuccess = { response ->
                        val imageUrls = response.data.map { it.url }
                        android.util.Log.d("ImageGenerationForegroundService", "Edit successful, got ${imageUrls.size} images")
                        showSuccessNotification("Edited ${imageUrls.size} image${if (imageUrls.size > 1) "s" else ""}")
                        
                        sendBroadcast(Intent("com.guitaripod.pixie.IMAGE_GENERATED").apply {
                            putStringArrayListExtra("imageUrls", ArrayList(imageUrls))
                            setPackage(packageName)
                        })
                    },
                    onFailure = { exception ->
                        val error = exception.message ?: "Edit failed"
                        android.util.Log.e("ImageGenerationForegroundService", "Edit failed", exception)
                        showErrorNotification(error)
                        sendErrorBroadcast(error)
                    }
                )
            }
        } catch (e: Exception) {
            val error = e.message ?: "Network error"
            android.util.Log.e("ImageGenerationForegroundService", "Edit exception", e)
            showErrorNotification(error)
            sendErrorBroadcast(error)
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        currentJob?.cancel()
        serviceScope.cancel()
    }
}