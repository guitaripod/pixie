package com.guitaripod.pixie.data.local

import androidx.room.Database
import androidx.room.RoomDatabase
import androidx.room.TypeConverters
import com.guitaripod.pixie.data.local.converter.DateConverter
import com.guitaripod.pixie.data.local.dao.ImageDao
import com.guitaripod.pixie.data.local.entity.ImageEntity

@Database(
    entities = [ImageEntity::class],
    version = 1,
    exportSchema = false
)
@TypeConverters(DateConverter::class)
abstract class PixieDatabase : RoomDatabase() {
    abstract fun imageDao(): ImageDao
}