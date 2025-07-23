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
import com.guitaripod.pixie.data.repository.PreferencesRepository
import com.guitaripod.pixie.data.repository.PreferencesRepositoryImpl
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
    
    // Configuration and preferences
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
        // Use custom API URL if set, otherwise use default
        val baseUrl = configManager.getApiUrl() 
            ?: "https://openai-image-proxy.guitaripod.workers.dev/"
        
        Retrofit.Builder()
            .baseUrl(baseUrl)
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
    
    // GitHub OAuth Manager
    val gitHubOAuthManager: GitHubOAuthManager by lazy {
        GitHubOAuthManager(context, pixieApiService, configManager, networkCallAdapter)
    }
    
    // Google Sign-In Manager
    val googleSignInManager: GoogleSignInManager by lazy {
        GoogleSignInManager(context, pixieApiService, configManager, networkCallAdapter)
    }
    
    // OAuth Web Flow Manager (for Apple)
    val oAuthWebFlowManager: OAuthWebFlowManager by lazy {
        OAuthWebFlowManager(context, pixieApiService, configManager, networkCallAdapter)
    }
    
    // Auth Repository
    val authRepository: AuthRepository by lazy {
        AuthRepositoryImpl(gitHubOAuthManager, googleSignInManager, oAuthWebFlowManager, preferencesRepository)
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
}