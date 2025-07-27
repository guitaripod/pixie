package com.guitaripod.pixie.di

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.preferencesDataStore
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import com.guitaripod.pixie.data.api.NetworkCallAdapter
import com.guitaripod.pixie.data.api.NetworkConnectivityObserver
import com.guitaripod.pixie.data.api.PixieApiService
import com.guitaripod.pixie.data.api.interceptor.AuthInterceptor
import com.guitaripod.pixie.data.auth.GitHubOAuthManager
import com.guitaripod.pixie.data.auth.GoogleSignInManager
import com.guitaripod.pixie.data.auth.OAuthWebFlowManager
import com.guitaripod.pixie.data.local.ConfigManager
import com.guitaripod.pixie.data.local.PreferencesDataStore
import com.guitaripod.pixie.data.repository.AuthRepository
import com.guitaripod.pixie.data.repository.AuthRepositoryImpl
import com.guitaripod.pixie.data.repository.ImageRepository
import com.guitaripod.pixie.data.repository.PreferencesRepository
import com.guitaripod.pixie.data.repository.PreferencesRepositoryImpl
import com.guitaripod.pixie.data.repository.GalleryRepository
import com.guitaripod.pixie.data.repository.CreditsRepository
import com.guitaripod.pixie.data.repository.AdminRepository
import com.guitaripod.pixie.data.repository.AdminRepositoryImpl
import com.guitaripod.pixie.data.purchases.RevenueCatManager
import com.guitaripod.pixie.data.purchases.CreditPurchaseManager
import com.guitaripod.pixie.utils.ImageSaver
import com.guitaripod.pixie.utils.CacheManager
import com.guitaripod.pixie.utils.NotificationHelper
import com.guitaripod.pixie.utils.HapticFeedbackManager
import com.squareup.moshi.Moshi
import com.squareup.moshi.kotlin.reflect.KotlinJsonAdapterFactory
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.moshi.MoshiConverterFactory
import java.util.concurrent.TimeUnit

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "pixie_preferences")

class AppContainer(private val context: Context) {
        val ioDispatcher: CoroutineDispatcher = Dispatchers.IO
    val mainDispatcher: CoroutineDispatcher = Dispatchers.Main
    val defaultDispatcher: CoroutineDispatcher = Dispatchers.Default
        private val moshi: Moshi by lazy {
        Moshi.Builder()
            .add(KotlinJsonAdapterFactory())
            .build()
    }
        val configManager: ConfigManager by lazy {
        ConfigManager(encryptedPreferences)
    }
    
    val preferencesDataStore: PreferencesDataStore by lazy {
        PreferencesDataStore(dataStore)
    }
    
    val preferencesRepository: PreferencesRepository by lazy {
        PreferencesRepositoryImpl(configManager, preferencesDataStore)
    }
    
    val authInterceptor: AuthInterceptor by lazy {
        AuthInterceptor(configManager)
    }
    
    private val okHttpClient: OkHttpClient by lazy {
        val builder = OkHttpClient.Builder()
            .addInterceptor(authInterceptor)
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)
        
        // Only add logging interceptor in debug builds
        if (com.guitaripod.pixie.BuildConfig.DEBUG) {
            val loggingInterceptor = HttpLoggingInterceptor().apply {
                level = HttpLoggingInterceptor.Level.BODY
            }
            builder.addInterceptor(loggingInterceptor)
        }
        
        builder.build()
    }
    
    val retrofit: Retrofit by lazy {
        val baseUrl = configManager.getApiUrl() 
            ?: "https://openai-image-proxy.guitaripod.workers.dev/"
        
        Retrofit.Builder()
            .baseUrl(baseUrl)
            .client(okHttpClient)
            .addConverterFactory(MoshiConverterFactory.create(moshi))
            .build()
    }
        val pixieApiService: PixieApiService by lazy {
        retrofit.create(PixieApiService::class.java)
    }
        val networkCallAdapter: NetworkCallAdapter by lazy {
        NetworkCallAdapter(moshi)
    }
        val networkConnectivityObserver: NetworkConnectivityObserver by lazy {
        NetworkConnectivityObserver(context)
    }
        val gitHubOAuthManager: GitHubOAuthManager by lazy {
        GitHubOAuthManager(context, pixieApiService, configManager, networkCallAdapter)
    }
        val googleSignInManager: GoogleSignInManager by lazy {
        GoogleSignInManager(context, pixieApiService, configManager, networkCallAdapter)
    }
        val oAuthWebFlowManager: OAuthWebFlowManager by lazy {
        OAuthWebFlowManager(context, pixieApiService, configManager, networkCallAdapter)
    }
        val authRepository: AuthRepository by lazy {
        AuthRepositoryImpl(gitHubOAuthManager, googleSignInManager, oAuthWebFlowManager, preferencesRepository, revenueCatManager)
    }
        val imageRepository: ImageRepository by lazy {
        ImageRepository(pixieApiService, context)
    }
    
    val galleryRepository: GalleryRepository by lazy {
        GalleryRepository(pixieApiService, configManager)
    }
    
    val creditsRepository: CreditsRepository by lazy {
        CreditsRepository(pixieApiService)
    }
    
    val adminRepository: AdminRepository by lazy {
        AdminRepositoryImpl(pixieApiService, preferencesRepository)
    }
    
    val imageSaver: ImageSaver by lazy {
        ImageSaver(context)
    }
    
    val revenueCatManager: RevenueCatManager by lazy {
        RevenueCatManager(context.applicationContext as android.app.Application)
    }
    
    val creditPurchaseManager: CreditPurchaseManager by lazy {
        CreditPurchaseManager(revenueCatManager, pixieApiService, creditsRepository)
    }
    
    val cacheManager: CacheManager by lazy {
        CacheManager(context)
    }
    
    val notificationHelper: NotificationHelper by lazy {
        NotificationHelper(context)
    }
    
    val hapticFeedbackManager: HapticFeedbackManager by lazy {
        HapticFeedbackManager(context)
    }
        val dataStore: DataStore<Preferences> by lazy {
        context.dataStore
    }
    
    val masterKey: MasterKey by lazy {
        MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
    }
    
    val encryptedPreferences by lazy {
        try {
            EncryptedSharedPreferences.create(
                context,
                "pixie_secure_prefs",
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            )
        } catch (e: Exception) {
            // If decryption fails, delete the corrupted preferences and recreate
            context.getSharedPreferences("pixie_secure_prefs", Context.MODE_PRIVATE)
                .edit()
                .clear()
                .commit()
            
            // Also clear the keystore preferences used by EncryptedSharedPreferences
            context.getSharedPreferences("pixie_secure_prefs_preferences_pb", Context.MODE_PRIVATE)
                .edit()
                .clear()
                .commit()
            
            // Recreate with fresh encryption
            EncryptedSharedPreferences.create(
                context,
                "pixie_secure_prefs",
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            )
        }
    }
}