package com.guitaripod.pixie.data.local.entity

import androidx.room.Entity
import androidx.room.PrimaryKey
import java.util.Date

@Entity(tableName = "images")
data class ImageEntity(
    @PrimaryKey
    val id: String,
    val prompt: String,
    val imageUrl: String,
    val size: String,
    val quality: String,
    val createdAt: Date,
    val localPath: String? = null,
    val isFavorite: Boolean = false
)