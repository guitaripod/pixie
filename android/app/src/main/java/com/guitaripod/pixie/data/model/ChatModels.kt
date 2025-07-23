package com.guitaripod.pixie.data.model

import java.util.UUID

sealed class ChatMessage {
    abstract val id: String
    abstract val timestamp: Long
    
    data class UserMessage(
        override val id: String = UUID.randomUUID().toString(),
        override val timestamp: Long = System.currentTimeMillis(),
        val prompt: String,
        val quality: String,
        val size: String,
        val actualSize: String,
        val quantity: Int,
        val background: String? = null,
        val format: String? = null,
        val compression: Int? = null,
        val moderation: String? = null
    ) : ChatMessage()
    
    data class ImageResponse(
        override val id: String = UUID.randomUUID().toString(),
        override val timestamp: Long = System.currentTimeMillis(),
        val imageUrls: List<String>,
        val isLoading: Boolean = false,
        val error: String? = null
    ) : ChatMessage()
}