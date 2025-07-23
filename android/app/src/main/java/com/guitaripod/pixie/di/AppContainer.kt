package com.guitaripod.pixie.di

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.preferencesDataStore
import androidx.room.Room
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import com.guitaripod.pixie.data.api.NetworkCallAdapter
import com.guitaripod.pixie.data.api.NetworkConnectivityObserver
import com.guitaripod.pixie.data.api.PixieApiService
import com.guitaripod.pixie.data.api.interceptor.AuthInterceptor
import com.guitaripod.pixie.data.local.PixieDatabase
import com.guitaripod.pixie.data.repository.ImageRepositoryImpl
import com.guitaripod.pixie.domain.repository.ImageRepository
import com.squareup.moshi.Moshi
import com.squareup.moshi.kotlin.reflect.KotlinJsonAdapterFactory
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.moshi.MoshiConverterFactory
import java.util.concurrent.TimeUnit

// DataStore extension
private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "pixie_preferences")

/**
 * Dependency container for the app.
 * This is a simple manual DI solution that provides all dependencies.
 */
class AppContainer(private val context: Context) {
    
    // Coroutine Dispatchers
    val ioDispatcher: CoroutineDispatcher = Dispatchers.IO
    val mainDispatcher: CoroutineDispatcher = Dispatchers.Main
    val defaultDispatcher: CoroutineDispatcher = Dispatchers.Default
    
    // Networking
    private val moshi: Moshi by lazy {
        Moshi.Builder()
            .add(KotlinJsonAdapterFactory())
            .build()
    }
    
    val authInterceptor: AuthInterceptor by lazy {
        AuthInterceptor(encryptedPreferences)
    }
    
    private val okHttpClient: OkHttpClient by lazy {
        val loggingInterceptor = HttpLoggingInterceptor().apply {
            level = if (com.guitaripod.pixie.BuildConfig.DEBUG) {
                HttpLoggingInterceptor.Level.BODY
            } else {
                HttpLoggingInterceptor.Level.NONE
            }
        }
        
        OkHttpClient.Builder()
            .addInterceptor(authInterceptor)
            .addInterceptor(loggingInterceptor)
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)
            .build()
    }
    
    val retrofit: Retrofit by lazy {
        Retrofit.Builder()
            .baseUrl("https://openai-image-proxy.guitaripod.workers.dev/")
            .client(okHttpClient)
            .addConverterFactory(MoshiConverterFactory.create(moshi))
            .build()
    }
    
    // API Service
    val pixieApiService: PixieApiService by lazy {
        retrofit.create(PixieApiService::class.java)
    }
    
    // Network call adapter for error handling
    val networkCallAdapter: NetworkCallAdapter by lazy {
        NetworkCallAdapter(moshi)
    }
    
    // Network connectivity observer
    val networkConnectivityObserver: NetworkConnectivityObserver by lazy {
        NetworkConnectivityObserver(context)
    }
    
    // Storage
    val dataStore: DataStore<Preferences> by lazy {
        context.dataStore
    }
    
    val masterKey: MasterKey by lazy {
        MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
    }
    
    val encryptedPreferences by lazy {
        EncryptedSharedPreferences.create(
            context,
            "pixie_secure_prefs",
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }
    
    // Database
    val database: PixieDatabase by lazy {
        Room.databaseBuilder(
            context,
            PixieDatabase::class.java,
            "pixie_database"
        )
            .fallbackToDestructiveMigration()
            .build()
    }
    
    // DAOs
    val imageDao by lazy { database.imageDao() }
    
    // Repositories
    val imageRepository: ImageRepository by lazy {
        ImageRepositoryImpl(imageDao)
    }
}